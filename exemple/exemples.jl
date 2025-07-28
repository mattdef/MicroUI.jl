# Exemple d'utilisation de MicroUI.jl avec un backend de rendu simple
using Printf

include("../src/MicroUI.jl")
using .MicroUI

# État de l'application
mutable struct AppState
    show_demo::Bool
    bg_color::Vector{Float32}
    text_input::String
    counter::Int
    slider_value::Float32
    check_state::Bool
    selected_item::Int
end

# Fonction de démonstration
function demo_window(ctx::Context, state::AppState)
    if begin_window(ctx, "Demo Window", Rect(40, 40, 300, 450)) == MicroUI.RES_ACTIVE
        # Colonnes pour le layout
        layout_row!(ctx, 2, [60, -1], 0)
        label(ctx, "First:")
        label(ctx, "Hello world!")
        
        # Boutons
        if button(ctx, "Increment") != 0
            state.counter += 1
        end
        label(ctx, "Counter: $(state.counter)")
        
        # Slider
        layout_row!(ctx, 2, [60, -1], 0)
        label(ctx, "Value:")
        slider!(ctx, "slider", Ref(state.slider_value), 0.0f0, 100.0f0)
        
        # Checkbox
        layout_row!(ctx, 1, [-1], 0)
        checkbox!(ctx, "Check me!", Ref(state.check_state))
        
        # Text input
        layout_row!(ctx, 1, [-1], 0)
        textbox!(ctx, "Textbox", Ref(state.text_input))
        
        # Tree node
        if begin_treenode(ctx, "More Options") != 0
            layout_row!(ctx, 2, [100, -1], 0)
            label(ctx, "Background R:")
            slider!(ctxctx, "slider", Ref(state.bg_color[1]), 0.0f0, 255.0f0)
            
            label(ctx, "Background G:")
            slider!(ctx, "slider", Ref(state.bg_color[2]), 0.0f0, 255.0f0)
            
            label(ctx, "Background B:")
            slider!(ctx, "slider", Ref(state.bg_color[3]), 0.0f0, 255.0f0)
            
            end_treenode(ctx)
        end
        
        # Panel dans la fenêtre
        begin_panel(ctx, "Sub Panel")
        layout_row!(ctx, 1, [-1], 0)
        text(ctx, "This is a panel inside the window. It can have its own scroll area and content.")
        
        for i in 1:5
            if button(ctx, "Item $i") != 0
                state.selected_item = i
            end
        end
        
        if state.selected_item > 0
            label(ctx, "Selected: Item $(state.selected_item)")
        end
        end_panel(ctx)
        
        end_window(ctx)
    end
end

# Backend de rendu minimal (exemple avec sortie texte)
mutable struct SimpleRenderer
    commands::Vector{String}
end

function render_frame(renderer::SimpleRenderer, ctx::Context)
    empty!(renderer.commands)
    
    # Parcourir les commandes
    cmd_ptr = Ptr{UInt8}(pointer(ctx.command_list))
    cmd_end = cmd_ptr + ctx.command_idx
    
    while cmd_ptr < cmd_end
        cmd_type = unsafe_load(Ptr{UInt8}(cmd_ptr))
        
        if cmd_type == UInt8(MicroUI.COMMAND_RECT)
            # Lire la commande rect
            rect_cmd = unsafe_load(Ptr{MicroUI.RectCommand}(cmd_ptr))
            push!(renderer.commands, 
                  "RECT: pos=($(rect_cmd.rect.x),$(rect_cmd.rect.y)) " *
                  "size=($(rect_cmd.rect.w),$(rect_cmd.rect.h)) " *
                  "color=($(rect_cmd.color.r),$(rect_cmd.color.g),$(rect_cmd.color.b),$(rect_cmd.color.a))")
            
        elseif cmd_type == UInt8(MicroUI.COMMAND_TEXT)
            # Pour le texte, c'est plus complexe car la taille varie
            push!(renderer.commands, "TEXT: ...")
            
        elseif cmd_type == UInt8(MicroUI.COMMAND_ICON)
            icon_cmd = unsafe_load(Ptr{MicroUI.IconCommand}(cmd_ptr))
            push!(renderer.commands, "ICON: id=$(icon_cmd.id)")
            
        elseif cmd_type == UInt8(MicroUI.COMMAND_CLIP)
            clip_cmd = unsafe_load(Ptr{MicroUI.ClipCommand}(cmd_ptr))
            push!(renderer.commands, 
                  "CLIP: rect=($(clip_cmd.rect.x),$(clip_cmd.rect.y)," *
                  "$(clip_cmd.rect.w),$(clip_cmd.rect.h))")
        end
        
        # Avancer au prochain
        size = unsafe_load(Ptr{Int32}(cmd_ptr + sizeof(UInt8)))
        cmd_ptr += size
    end
end

# Programme principal
function main()
    # Initialiser le contexte
    ctx = Context()
    
    # Configurer les callbacks de mesure de texte
    ctx.text_width = (font, str) -> length(str) * 8
    ctx.text_height = font -> 16
    
    # État de l'application
    state = AppState(
        true,                    # show_demo
        [90.0f0, 95.0f0, 100.0f0],  # bg_color
        "Type here",             # text_input
        0,                       # counter
        50.0f0,                  # slider_value
        false,                   # check_state
        0                        # selected_item
    )
    
    # Renderer
    renderer = SimpleRenderer(String[])
    
    # Simulation de quelques frames
    for frame in 1:3
        println("\n=== Frame $frame ===")
        
        # Simuler des entrées souris
        input_mousemove!(ctx, 100 + frame * 10, 100 + frame * 5)
        
        # Commencer la frame
        begin_frame(ctx)
        
        # Dessiner l'interface
        demo_window(ctx, state)
        
        # Terminer la frame
        end_frame(ctx)
        
        # Rendre (ici on affiche juste les commandes)
        render_frame(renderer, ctx)
        
        println("Generated $(length(renderer.commands)) render commands")
        for (i, cmd) in enumerate(renderer.commands[1:min(5, end)])
            println("  $i: $cmd")
        end
        if length(renderer.commands) > 5
            println("  ... and $(length(renderer.commands) - 5) more")
        end
    end
end

# Exemple d'intégration avec un vrai backend graphique (pseudo-code)
function integrate_with_graphics_backend()
    # Avec CImGui.jl ou autre backend
    ctx = Context()
    
    # Configurer avec de vraies métriques de police
    # ctx.text_width = (font, str) -> ImGui.CalcTextSize(str).x
    # ctx.text_height = font -> ImGui.GetFontSize()
    
    # Dans la boucle de rendu:
    # while !should_close
    #     # Gérer les événements
    #     if mouse_moved
    #         input_mousemove!(ctx, mouse_x, mouse_y)
    #     end
    #     if mouse_clicked
    #         input_mousedown!(ctx, mouse_x, mouse_y, MOUSE_LEFT)
    #     end
    #     
    #     # Dessiner
    #     begin_frame(ctx)
    #     draw_ui(ctx)
    #     end_frame(ctx)
    #     
    #     # Exécuter les commandes de rendu
    #     execute_render_commands(ctx)
    # end
end

# Utilitaires pour créer des widgets personnalisés
module CustomWidgets

using ..MicroUI

# Widget de sélection de couleur simple
function color_picker!(ctx::Context, label::String, color::Ref{Vector{Float32}})
    changed = false
    
    if header(ctx, label) != 0
        layout_row!(ctx, 2, [50, -1], 0)
        
        labels = ["R:", "G:", "B:"]
        for i in 1:3
            label(ctx, labels[i])
            if slider!(ctx, "slider", Ref(color[][i]), 0.0f0, 255.0f0) != 0
                changed = true
            end
        end
        
        # Aperçu de la couleur
        layout_row!(ctx, 1, [-1], 40)
        r = layout_next(ctx)
        c = Color(
            round(UInt8, color[][1]),
            round(UInt8, color[][2]),
            round(UInt8, color[][3]),
            255
        )
        draw_rect!(ctx, r, c)
    end
    
    return changed
end

# Liste déroulante
function dropdown!(ctx::Context, items::Vector{String}, selected::Ref{Int})
    layout_row!(ctx, 1, [-1], 0)
    
    current = selected[] > 0 ? items[selected[]] : "Select..."
    
    if button(ctx, current * " ▼") != 0
        open_popup!(ctx, "!dropdown")
    end
    
    if begin_popup(ctx, "!dropdown")
        for (i, item) in enumerate(items)
            if button(ctx, item) != 0
                selected[] = i
            end
        end
        end_popup(ctx)
    end
    
    return selected[]
end

# Graphique simple
function plot!(ctx::Context, values::Vector{Float32}, label::String="")
    r = layout_next(ctx)
    
    # Fond
    draw_rect!(ctx, r, ctx.style.colors[Int(COLOR_BASE)])
    
    if !isempty(values)
        # Calculer l'échelle
        min_val = minimum(values)
        max_val = maximum(values)
        range = max_val - min_val
        
        if range > 0
            # Dessiner les lignes
            step = r.w / (length(values) - 1)
            for i in 2:length(values)
                x1 = r.x + round(Int32, (i-2) * step)
                x2 = r.x + round(Int32, (i-1) * step)
                y1 = r.y + r.h - round(Int32, (values[i-1] - min_val) / range * r.h)
                y2 = r.y + r.h - round(Int32, (values[i] - min_val) / range * r.h)
                
                # Ligne simple avec des rectangles
                draw_rect!(ctx, 
                    Rect(min(x1, x2), min(y1, y2), 
                         abs(x2 - x1) + 1, abs(y2 - y1) + 1),
                    ctx.style.colors[Int(COLOR_TEXT)])
            end
        end
    end
    
    # Label
    if label != ""
        draw_control_text!(ctx, label, r, COLOR_TEXT, OPT_ALIGNCENTER)
    end
end

end # module CustomWidgets

# Si exécuté directement
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end