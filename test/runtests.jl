using MicroUI
using Test

# -- Mock renderer to capture draw calls --
mutable struct MockRenderer <: MicroUI.Renderer
    log::Vector{String}
    font_width::Int
    font_height::Int
end

function MockRenderer()
    MockRenderer(String[], 6, 10)
end

MicroUI.get_text_width(r::MockRenderer, s::String, _) = length(s) * 6
MicroUI.get_text_height(r::MockRenderer, _) = 10

MicroUI.draw_text!(r::MockRenderer, s, pos, col, _) =
    push!(r.log, "text: $s @ ($(pos.x), $(pos.y))")

MicroUI.draw_rect!(r::MockRenderer, rect, color) =
    push!(r.log, "rect: ($(rect.x),$(rect.y),$(rect.w)x$(rect.h))")

MicroUI.present!(r::MockRenderer) = push!(r.log, "present")

# -- Helpers --
function create_test_context()
    unclipped_rect = mu_rect(-1000000, -1000000, 2000000, 2000000)

    ctx = MicroUI.Context(
        MicroUI.default_style(), nothing, MicroUI.mu_vec2(0,0),
        false, false, identity, identity, Dict(), nothing,
        0, 0, 0, 1, "", nothing, 0,
        MicroUI.AbstractCommand[],         # Liste de commandes vide
        [unclipped_rect],           # Pile de clipping avec la zone par défaut
        MicroUI.mu_vec2(0,0), # last_mouse_pos
        MicroUI.mu_vec2(0,0)  # mouse_delta
    )
    ctx.input_buffer = ""
    ctx.key_pressed = nothing
    ctx.cursor_blink = 0
    renderer = MockRenderer()
    MicroUI.attach_renderer!(ctx, renderer)
    return ctx, renderer
end

function simulate_click!(ctx::MicroUI.Context, label::String, pos::MicroUI.Vec2, window_title = "Test")
    # Frame 1 – clic appuyé
    MicroUI.mu_begin(ctx)
    # Appliquer les entrées APRÈS mu_begin
    ctx.mouse_pos = pos
    ctx.mouse_down = true
    ctx.mouse_pressed = true

    MicroUI.mu_begin_window(ctx, window_title)
    MicroUI.mu_button(ctx, label)
    MicroUI.mu_end_window(ctx)
    MicroUI.mu_end(ctx)

    # Frame 2 – relâchement du clic
    MicroUI.mu_begin(ctx)
    # Appliquer les entrées APRÈS mu_begin
    ctx.mouse_pos = pos
    ctx.mouse_pressed = false # Doit être faux pour la frame de relâchement
    ctx.mouse_down = false

    MicroUI.mu_begin_window(ctx, window_title)
    result = MicroUI.mu_button(ctx, label)
    MicroUI.mu_end_window(ctx)
    MicroUI.mu_end(ctx)

    return result
end

# -- Tests --
@testset "Button interaction" begin
    ctx, r = create_test_context()
    clicked = simulate_click!(ctx, "Click Me", MicroUI.mu_vec2(60, 80))
    @test clicked == true
end

@testset "Checkbox toggling" begin
    ctx, r = create_test_context()
    state = Ref(false)

    # Simule une frame où l'utilisateur clique sur la checkbox
    MicroUI.mu_begin(ctx)
    MicroUI.mu_begin_window(ctx, "Test")

    # Positionne la souris sur la checkbox et simule un clic
    # (la position doit correspondre à la géométrie du contrôle)
    ctx.mouse_pos = MicroUI.mu_vec2(54 + 5, 72 + 5) # Position au centre de la case
    ctx.mouse_pressed = true

    MicroUI.mu_checkbox(ctx, "Check", state)
    @test state[] == true

    MicroUI.mu_end_window(ctx)
    MicroUI.mu_end(ctx)
end

@testset "Textbox input and backspace" begin
    ctx, r = create_test_context()
    buffer = Ref("hi")

    # --- Frame 1: Cliquer pour activer le textbox ---
    MicroUI.mu_begin(ctx)
    MicroUI.mu_begin_window(ctx, "Test")
    
    # Positionne la souris sur le textbox et simule un clic
    ctx.mouse_pos = MicroUI.mu_vec2(54 + 10, 72 + 10)
    ctx.mouse_pressed = true
    ctx.mouse_down = true

    MicroUI.mu_input_textbox(ctx, buffer, 100) # L'ID du textbox est maintenant "active_id"
    MicroUI.mu_end_window(ctx)
    MicroUI.mu_end(ctx)

    # --- Frame 2: Entrer du texte ---
    MicroUI.mu_begin(ctx)
    MicroUI.mu_begin_window(ctx, "Test")

    ctx.mouse_pressed = false # Plus de clic
    ctx.mouse_down = false
    ctx.input_buffer = "!"   # Simule la saisie de texte
    
    MicroUI.mu_input_textbox(ctx, buffer, 100)
    @test buffer[] == "hi!" # Le buffer est mis à jour car active_id correspond [cite: 22]

    MicroUI.mu_end_window(ctx)
    MicroUI.mu_end(ctx)


    # --- Frame 3: Appuyer sur "Retour arrière" ---
    MicroUI.mu_begin(ctx)
    MicroUI.mu_begin_window(ctx, "Test")

    ctx.input_buffer = "" # Vide le buffer d'entrée
    ctx.key_pressed = :backspace # Simule l'appui sur la touche
    
    MicroUI.mu_input_textbox(ctx, buffer, 100)
    @test buffer[] == "hi" # La suppression est effectuée car active_id correspond [cite: 22, 23]
    
    MicroUI.mu_end_window(ctx)
    MicroUI.mu_end(ctx)
end