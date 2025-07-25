"""
MicroUI.jl - Port Julia de la bibliothèque MicroUI
Copyright (c) 2024 - Basé sur MicroUI par rxi

Une bibliothèque d'interface utilisateur immédiate (immediate mode GUI) légère pour Julia.
"""

module MicroUI

# -----------------------------------------------------------------------------
# Exports
# -----------------------------------------------------------------------------
export Context, Vec2, Rect, Color, mu_color, mu_rect, mu_vec2
export mu_init, mu_begin, mu_end, mu_set_focus!
export mu_get_id, mu_push_id!, mu_pop_id!
export mu_text, mu_label, mu_button, mu_checkbox, mu_input_textbox
export mu_input_mousemove, mu_input_mousedown, mu_input_mouseup
export mu_input_scroll, mu_input_keydown, mu_input_keyup, mu_input_text
export attach_renderer!, create_context_with_buffer_renderer, BufferRenderer
export mu_begin_window, mu_end_window, mu_bring_to_front!, save_buffer_as_ppm
export mu_layout_row, end_layout_row
export mu_push_clip_rect, mu_pop_clip_rect, current_clip_rect, mu_check_clip

# -----------------------------------------------------------------------------
# Types de base
# -----------------------------------------------------------------------------
mutable struct Vec2; x::Int32; y::Int32; end
mutable struct Rect; x::Int32; y::Int32; w::Int32; h::Int32; end
mutable struct Color; r::UInt8; g::UInt8; b::UInt8; a::UInt8; end

mu_vec2(x::Integer, y::Integer) = Vec2(Int32(x), Int32(y))
mu_rect(x::Integer, y::Integer, w::Integer, h::Integer) = Rect(Int32(x), Int32(y), Int32(w), Int32(h))
mu_color(r::Integer, g::Integer, b::Integer, a::Integer) =
    Color(UInt8(clamp(r, 0, 255)),
          UInt8(clamp(g, 0, 255)),
          UInt8(clamp(b, 0, 255)),
          UInt8(clamp(a, 0, 255)))

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
const HASH_INITIAL = UInt32(2166136261)
const HASH_FACTOR = UInt32(16777619)

const MU_CLIP_ALL = 1
const MU_CLIP_PART = 2
const MU_ICON_CLOSE = 1

# -----------------------------------------------------------------------------
# DÉFINITION DES COMMANDES DE DESSIN
# (Équivalent aux structs mu_*Command dans microui.h)
# -----------------------------------------------------------------------------

abstract type AbstractCommand end

struct RectCommand <: AbstractCommand
    rect::Rect
    color::Color
end

struct TextCommand <: AbstractCommand
    pos::Vec2
    font::Any # Le type de la police est laissé générique
    color::Color
    text::String
end

struct IconCommand <: AbstractCommand
    rect::Rect
    id::Int
    color::Color
end

struct ClipCommand <: AbstractCommand
    rect::Rect
end


# -----------------------------------------------------------------------------
# Context & style minimal
# -----------------------------------------------------------------------------
mutable struct Style
    font::Any
    padding::Int32
    spacing::Int32
    size::Vec2
    colors::Dict{Symbol, Color}
end

function default_style()
    Style(nothing, 4, 4, mu_vec2(64, 14), Dict(
        :text => mu_color(230,230,230,255),
        :button => mu_color(75,75,75,255),
        :button_hover => mu_color(95,95,95,255),
        :button_focus => mu_color(115,115,115,255),
        :border => mu_color(25,25,25,255),
        :window => mu_color(50,50,50,255),
        :titlebg => mu_color(25,25,25,255),
        :titletext => mu_color(240,240,240,255)
    ))
end

"""
Structure pour la gestion du layout, miroir de mu_Layout en C.
"""
mutable struct Layout
    body::Rect
    next::Rect
    position::Vec2
    size::Vec2
    max::Vec2
    widths::Vector{Int32}
    items::Int32
    item_index::Int32
    next_row::Int32
    indent::Int32
    
    Layout() = new(mu_rect(0,0,0,0), mu_rect(0,0,0,0), mu_vec2(0,0), mu_vec2(0,0),
                   mu_vec2(-1000000, -1000000), Int32[], 0, 0, 0, 0)
end

"""
Structure Container.
"""
mutable struct Container
    title::String
    rect::Rect
    body::Rect
    open::Bool
    cursor::Vec2
    row_mode::Bool
    row_x::Int32
    row_y::Int32
    row_h::Int32
    content_size::Vec2
    zindex::Int32
end

"""
Structure Context.
"""
mutable struct Context
    # --- Champs de base ---
    style::Style
    renderer::Any
    text_width::Function
    text_height::Function

    # --- État de l'input ---
    mouse_pos::Vec2
    last_mouse_pos::Vec2
    mouse_delta::Vec2
    mouse_down::Bool
    mouse_pressed::Bool
    input_buffer::String
    key_pressed::Union{Nothing, Symbol}

    # --- Gestion des ID et du Focus ---
    hot_id::UInt32
    active_id::UInt32
    focus_id::UInt32
    updated_focus::Bool
    last_id::UInt32
    id_stack::Vector{UInt32}

    # --- Gestion des conteneurs et du layout ---
    containers::Dict{String, Container}
    current_window::Union{Nothing, Container}
    container_stack::Vector{Container}
    layout_stack::Vector{Layout}

    # --- Rendu et Clipping ---
    command_list::Vector{Any}
    clip_stack::Vector{Rect}
    last_zindex::Int32

    # --- Divers ---
    cursor_blink::Int
end


# -----------------------------------------------------------------------------
# Initialisation
# -----------------------------------------------------------------------------
function mu_init(ctx::Context)
    ctx.style = default_style()
    ctx.containers = Dict{String, Container}()
end

# -----------------------------------------------------------------------------
# Entrées utilisateur
# -----------------------------------------------------------------------------
mu_input_mousemove(ctx::Context, x, y) = (ctx.mouse_pos = mu_vec2(x, y))
mu_input_mousedown(ctx::Context, x, y, btn) = (ctx.mouse_down = true; ctx.mouse_pressed = true)
mu_input_mouseup(ctx::Context, x, y, btn) = (ctx.mouse_down = false)
# mu_input_scroll(_, x, y) = nothing
# mu_input_keydown(_, key) = nothing
# mu_input_keyup(_, key) = nothing
# mu_input_text(_, text) = nothing

# -----------------------------------------------------------------------------
# Rendu abstrait
# -----------------------------------------------------------------------------
abstract type Renderer end

function attach_renderer!(ctx::Context, renderer::Renderer)
    ctx.renderer = renderer
    ctx.text_width = (f, s) -> get_text_width(renderer, s, f)
    ctx.text_height = f -> get_text_height(renderer, f)
end

# -----------------------------------------------------------------------------
# BufferRenderer simple
# -----------------------------------------------------------------------------
mutable struct BufferRenderer <: Renderer
    width::Int
    height::Int
    buffer::Matrix{UInt32}
    font_width::Int
    font_height::Int
end

function BufferRenderer(w::Int, h::Int)
    BufferRenderer(w, h, zeros(UInt32, h, w), 6, 10)
end

function get_text_width(r::BufferRenderer, s::String, _) length(s) * r.font_width end
function get_text_height(r::BufferRenderer, _) r.font_height end

function draw_text!(r::BufferRenderer, s::String, p::Vec2, color::Color, _)
    println("[TEXT] $s @ ($(p.x), $(p.y))")
end

function draw_rect!(r::BufferRenderer, rect::Rect, color::Color)
    println("[RECT] ($(rect.x),$(rect.y),$(rect.w)x$(rect.h))")
end

function present!(r::BufferRenderer)
    println("[FRAME] presented")
end

function save_buffer_as_ppm(r::BufferRenderer, filename::String)
    println("[PPM] $filename saved")
end


# -----------------------------------------------------------------------------
# 3. IMPLÉMENTATION DES FONCTIONS DE PORTAGE
# -----------------------------------------------------------------------------

# --- Fonctions utilitaires pour le clipping ---

function intersect_rects(r1::Rect, r2::Rect)
    x1 = max(r1.x, r2.x)
    y1 = max(r1.y, r2.y)
    x2 = min(r1.x + r1.w, r2.x + r2.w)
    y2 = min(r1.y + r1.h, r2.y + r2.h)
    return mu_rect(x1, y1, max(0, x2 - x1), max(0, y2 - y1))
end

mu_push_clip_rect(ctx::Context, rect::Rect) = push!(ctx.clip_stack, intersect_rects(rect, current_clip_rect(ctx)))
mu_pop_clip_rect(ctx::Context) = length(ctx.clip_stack) > 1 && pop!(ctx.clip_stack)
current_clip_rect(ctx::Context) = last(ctx.clip_stack)

"""
Équivalent de mu_push_command en C.
Ajoute une commande à la liste de commandes du contexte.
"""
function mu_push_command(ctx::Context, cmd::AbstractCommand)
    push!(ctx.command_list, cmd)
end

"""
Portage de mu_draw_rect.
Ajoute une commande pour dessiner un rectangle plein.
Le rectangle est clippé par la zone de clipping actuelle.
"""
function mu_draw_rect(ctx::Context, rect::Rect, color::Color)
    clipped_rect = intersect_rects(rect, current_clip_rect(ctx))
    if clipped_rect.w > 0 && clipped_rect.h > 0
        mu_push_command(ctx, RectCommand(clipped_rect, color))
    end
end

"""
Portage de mu_draw_box.
Ajoute des commandes pour dessiner le contour d'un rectangle.
"""
function mu_draw_box(ctx::Context, rect::Rect, color::Color)
    # Dessine les 4 côtés du rectangle avec une épaisseur de 1 pixel
    mu_draw_rect(ctx, mu_rect(rect.x + 1, rect.y, rect.w - 2, 1), color) # Haut
    mu_draw_rect(ctx, mu_rect(rect.x + 1, rect.y + rect.h - 1, rect.w - 2, 1), color) # Bas
    mu_draw_rect(ctx, mu_rect(rect.x, rect.y, 1, rect.h), color) # Gauche
    mu_draw_rect(ctx, mu_rect(rect.x + rect.w - 1, rect.y, 1, rect.h), color) # Droite
end

"""
Portage de mu_draw_text.
Ajoute une commande pour dessiner du texte.
"""
function mu_draw_text(ctx::Context, font::Any, text::String, pos::Vec2, color::Color)
    # En C, le clipping est géré plus finement. Ici, on se contente d'ajouter la commande,
    # le renderer devra gérer le clipping final. C'est une simplification idiomatique.
    # Pour une fidélité parfaite, il faudrait vérifier le clipping ici.
    mu_push_command(ctx, TextCommand(pos, font, color, text))
end

"""
Portage de mu_draw_icon.
Ajoute une commande pour dessiner une icône.
"""
function mu_draw_icon(ctx::Context, id::Int, rect::Rect, color::Color)
    # Comme pour le texte, on ne vérifie pas le clipping ici par simplification.
    # Le renderer s'en chargera.
    mu_push_command(ctx, IconCommand(rect, id, color))
end

"""
Portage de draw_frame en C.
Dessine le fond et la bordure d'un contrôle ou d'une fenêtre.
"""
function draw_frame(ctx::Context, rect::Rect, colorid::Symbol)
    # Dessine le fond du contrôle
    mu_draw_rect(ctx, rect, ctx.style.colors[colorid])
    
    # Certains types n'ont pas de bordure
    if colorid in (:titlebg, :scrollbase, :scrollthumb)
        return
    end
    
    # Dessine la bordure si la couleur de bordure est visible
    border_color = ctx.style.colors[:border]
    if border_color.a > 0
        # `expand_rect` n'existe pas en C, mais c'est ce que fait `mu_draw_box`
        # avec un rectangle agrandi de 1.
        expanded_rect = mu_rect(rect.x - 1, rect.y - 1, rect.w + 2, rect.h + 2)
        mu_draw_box(ctx, expanded_rect, border_color)
    end
end

"Vérifie si un rectangle est visible dans la zone de clipping actuelle."
function mu_check_clip(ctx::Context, r::Rect)
    cr = current_clip_rect(ctx)
    if r.x > cr.x + cr.w || r.x + r.w < cr.x || r.y > cr.y + cr.h || r.y + r.h < cr.y
        return MU_CLIP_ALL
    end
    if r.x >= cr.x && r.x + r.w <= cr.x + cr.w && r.y >= cr.y && r.y + r.h <= cr.y + cr.h
        return 0 # Totalement visible
    end
    return MU_CLIP_PART
end

"Retourne le conteneur actuellement actif."
mu_get_current_container(ctx::Context) = last(ctx.container_stack)

"Place un conteneur au premier plan."
mu_bring_to_front!(ctx::Context, cnt::Container) = cnt.zindex = (ctx.last_zindex += 1)


# -----------------------------------------------------------------------------
# Création de contexte + renderer
# -----------------------------------------------------------------------------
function create_context_with_buffer_renderer(w=800, h=600)
    # Rectangle "infini" pour le clipping initial, comme `unclipped_rect` en C
    unclipped_rect = mu_rect(-1000000, -1000000, 2000000, 2000000)
    
    ctx = Context(
        default_style(), 
        nothing,
        identity,
        identity,
        mu_vec2(0,0), 
        mu_vec2(0,0), 
        mu_vec2(0,0), 
        false, 
        false, 
        "", 
        nothing,
        0, 
        0, 
        0, 
        false, 
        0, 
        [HASH_INITIAL],
        Dict{String, Container}(), 
        nothing, 
        [], 
        [],
        [], 
        [unclipped_rect], 
        0,
        0
    )
    
    renderer = BufferRenderer(w, h)
    attach_renderer!(ctx, renderer)
    return ctx, renderer
end

# -----------------------------------------------------------------------------
# API principale 
# -----------------------------------------------------------------------------
function mu_begin(ctx::Context)
    ctx.mouse_pressed = false
    ctx.current_window = nothing
    ctx.mouse_delta = mu_vec2(ctx.mouse_pos.x - ctx.last_mouse_pos.x, 
                              ctx.mouse_pos.y - ctx.last_mouse_pos.y)
    ctx.cursor_blink += 1
    ctx.updated_focus = false
end

function mu_end(ctx::Context)
    if !ctx.updated_focus
        ctx.focus_id = 0
    end
    
    ctx.active_id = ctx.mouse_down ? ctx.active_id : 0
    ctx.hot_id = 0

    # Réinitialiser les entrées "one-shot" pour la prochaine frame
    ctx.mouse_pressed = false
    ctx.key_pressed = nothing
    
    ctx.last_mouse_pos = ctx.mouse_pos
    
    # Vider la liste de commandes (le rendu devrait se faire avant)
    # empty!(ctx.command_list)
    
    present!(ctx.renderer)
end

# -----------------------------------------------------------------------------
# Fenêtre + layout horizontal/vertical simple
# -----------------------------------------------------------------------------
function mu_begin_window(ctx::Context, title::String, x::Int=50, y::Int=50, w::Int=200, h::Int=100)
    # Pousse l'ID de la fenêtre sur la pile pour que les contrôles internes
    # puissent en dériver leur propre ID.
    mu_push_id!(ctx, title)

    # Récupère ou crée le conteneur de la fenêtre [cite: 1, 11]
    rect = mu_rect(x, y, w, h)
    container = get!(ctx.containers, title) do
        Container(title, rect, mu_rect(0,0,0,0), true, mu_vec2(0,0), false, 0, 0, 0, mu_vec2(0,0), 0)
    end
    
    # Si la fenêtre est fermée, ne rien faire
    if !container.open
        return false
    end

    ctx.current_window = container
    
    # --- Dessin de la fenêtre (équivalent de MU_OPT_NOFRAME) ---
    draw_frame(ctx, container.rect, :window) # :window correspond à MU_COLOR_WINDOWBG [cite: 1, 4]
    
    body = container.rect

    # --- Barre de titre (équivalent de MU_OPT_NOTITLE) ---
    title_height = ctx.style.size.y + ctx.style.padding * 2
    tr = mu_rect(container.rect.x, container.rect.y, container.rect.w, title_height)
    
    # Dessine le fond de la barre de titre 
    draw_frame(ctx, tr, :titlebg) # :titlebg correspond à MU_COLOR_TITLEBG [cite: 1, 4]

    # Zone de contenu (body) est réduite par la hauteur de la barre de titre 
    body = mu_rect(body.x, body.y + tr.h, body.w, body.h - tr.h)
    
    # Titre du texte
    mu_draw_text(ctx, ctx.style.font, title, mu_vec2(tr.x + ctx.style.padding, tr.y + ctx.style.padding), ctx.style.colors[:titletext])
    
    # --- Gestion des interactions de la barre de titre (déplacement) ---
    title_id = mu_get_id(ctx, "!title")

    hovered = ctx.mouse_pos.x >= tr.x && ctx.mouse_pos.x <= tr.x + tr.w &&
              ctx.mouse_pos.y >= tr.y && ctx.mouse_pos.y <= tr.y + tr.h

    if hovered && !ctx.mouse_down
        ctx.hot_id = title_id
    end
    if ctx.hot_id == title_id && ctx.mouse_pressed
        ctx.active_id = title_id
    end
    
    # Déplacer la fenêtre si la barre de titre est active (cliquée-glissée) 
    if ctx.active_id == title_id && ctx.mouse_down
        container.rect.x += ctx.mouse_delta.x
        container.rect.y += ctx.mouse_delta.y
    end

    # --- Bouton de fermeture (équivalent de MU_OPT_NOCLOSE) ---
    r_close = mu_rect(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h) # Bouton carré 
    tr.w -= r_close.w # Réduit la zone de la barre de titre pour ne pas chevaucher
    close_id = mu_get_id(ctx, "!close")

    # Dessine l'icône de fermeture 
    mu_draw_icon(ctx, MU_ICON_CLOSE, r_close, ctx.style.colors[:titletext])

    # Logique de clic sur le bouton de fermeture
    hovered_close = ctx.mouse_pos.x >= r_close.x && ctx.mouse_pos.x <= r_close.x + r_close.w &&
                    ctx.mouse_pos.y >= r_close.y && ctx.mouse_pos.y <= r_close.y + r_close.h
    
    if hovered_close && !ctx.mouse_down
        ctx.hot_id = close_id
    end
    if ctx.hot_id == close_id && ctx.mouse_pressed
        ctx.active_id = close_id
    end

    # Si le bouton est cliqué, on ferme la fenêtre 
    if !ctx.mouse_down && ctx.hot_id == close_id && ctx.active_id == close_id
        container.open = false
    end
    
    # --- Finalisation ---
    # Met à jour la géométrie du conteneur et prépare le layout
    container.body = body # L'ancienne version n'avait pas ce champ
    container.cursor = mu_vec2(container.rect.x + ctx.style.padding, 
                               container.rect.y + title_height + ctx.style.padding)
    
    # Applique le clipping à la zone de contenu de la fenêtre 
    mu_push_clip_rect(ctx, body)

    return true # La fenêtre est ouverte et active
end

function mu_end_window(ctx::Context)
    mu_pop_clip_rect(ctx)
    mu_pop_id!(ctx)
    !isempty(ctx.container_stack) && pop!(ctx.container_stack)
    ctx.current_window = nothing
end

# -----------------------------------------------------------------------------
# GESTION DES ID (REMPLACE id_counter)
# -----------------------------------------------------------------------------

"""
Algorithme de hachage FNV-1a 32-bit, comme en C.
"""
function fnv1a_hash(data::Vector{UInt8}, seed::UInt32)::UInt32
    h = seed
    for byte in data
        h = (h ⊻ byte) * HASH_FACTOR
    end
    return h
end

"""
Génère un ID stable et unique pour un contrôle.
"""
function mu_get_id(ctx::Context, data::Union{String, Symbol, Number})::UInt
    bytes = Vector{UInt8}(string(data))
    parent_id = last(ctx.id_stack)
    ctx.last_id = fnv1a_hash(bytes, parent_id)
    return ctx.last_id
end

"Pousse un nouvel ID sur la pile pour créer un contexte de nommage."
mu_push_id!(ctx::Context, data) = push!(ctx.id_stack, mu_get_id(ctx, data))

"Retire le dernier ID de la pile."
mu_pop_id!(ctx::Context) = length(ctx.id_stack) > 1 && pop!(ctx.id_stack)

# -----------------------------------------------------------------------------
# GESTION DU FOCUS
# -----------------------------------------------------------------------------

"Définit le contrôle qui a le focus programmatiquement."
function mu_set_focus!(ctx::Context, id::UInt)
    ctx.focus_id = id
    ctx.updated_focus = true
end


# -----------------------------------------------------------------------------
# Layout
# -----------------------------------------------------------------------------

function mu_layout_row(ctx::Context)
    win = ctx.current_window
    win.row_mode = true
    win.row_x = win.cursor.x
    win.row_y = win.cursor.y
    win.row_h = 0
end

function next_control_rect(ctx::Context, w::Int, h::Int)
    win = ctx.current_window
    if win.row_mode
        r = mu_rect(win.cursor.x, win.row_y, w, h)
        win.cursor.x += w + ctx.style.spacing
        win.row_h = max(win.row_h, h)
        return r
    else
        r = mu_rect(win.cursor.x, win.cursor.y, w, h)
        win.cursor.y += h + ctx.style.spacing
        return r
    end
end

end_layout_row(ctx::Context) = (ctx.current_window.cursor.y += ctx.current_window.row_h + ctx.style.spacing; ctx.current_window.row_mode = false)


# -----------------------------------------------------------------------------
# Contrôles de base avec gestion survol / focus
# -----------------------------------------------------------------------------

function mu_text(ctx::Context, text::String)
    w = get_text_width(ctx.renderer, text, nothing)
    h = get_text_height(ctx.renderer, nothing)
    r = next_control_rect(ctx, w, h)
    draw_text!(ctx.renderer, text, mu_vec2(r.x, r.y), ctx.style.colors[:text], ctx.style.font)
end

mu_label(ctx::Context, text::String) = mu_text(ctx, text)

function mu_button(ctx::Context, label::String)
    # Utilise le nouveau système d'ID au lieu de id_counter
    id = mu_get_id(ctx, label) 

    w = get_text_width(ctx.renderer, label, nothing) + 2 * ctx.style.padding
    h = get_text_height(ctx.renderer, nothing) + 2 * ctx.style.padding
    r = next_control_rect(ctx, w, h)

    hovered = ctx.mouse_pos.x >= r.x && ctx.mouse_pos.x <= r.x + r.w &&
              ctx.mouse_pos.y >= r.y && ctx.mouse_pos.y <= r.y + r.h

    if hovered
        ctx.hot_id = id
        if ctx.mouse_pressed
            ctx.active_id = id
        end
    end

    color = ctx.style.colors[:button]
    if ctx.active_id == id
        color = ctx.style.colors[:button_focus]
    elseif ctx.hot_id == id
        color = ctx.style.colors[:button_hover]
    end

    pressed = !ctx.mouse_down && ctx.hot_id == id && ctx.active_id == id

    draw_rect!(ctx.renderer, r, color)
    draw_text!(ctx.renderer, label, mu_vec2(r.x + ctx.style.padding, r.y + ctx.style.padding), ctx.style.colors[:text], nothing)

    return pressed
end

function mu_checkbox(ctx::Context, label::String, state::Base.RefValue{Bool})
    id = mu_get_id(ctx, label) 

    h = get_text_height(ctx.renderer, nothing) + 2 * ctx.style.padding
    w = h  # case carrée
    r = next_control_rect(ctx, w + 4 + get_text_width(ctx.renderer, label, nothing), h)
    box = mu_rect(r.x, r.y, h, h)

    hovered = ctx.mouse_pos.x >= box.x && ctx.mouse_pos.x <= box.x + box.w &&
              ctx.mouse_pos.y >= box.y && ctx.mouse_pos.y <= box.y + box.h

    if hovered
        ctx.hot_id = id
        if ctx.mouse_pressed
            ctx.active_id = id
            state[] = !state[]
        end
    end

    draw_rect!(ctx.renderer, box, ctx.style.colors[:button_hover])
    if state[]
        draw_text!(ctx.renderer, "✓", mu_vec2(box.x + 4, box.y), ctx.style.colors[:text], nothing)
    end
    draw_text!(ctx.renderer, label, mu_vec2(box.x + h + 4, box.y), ctx.style.colors[:text], nothing)
end

function mu_input_textbox(ctx::Context, label::String, buffer::Base.RefValue{String}, width::Int=200)
    id = mu_get_id(ctx, label) 

    h = get_text_height(ctx.renderer, nothing) + 2 * ctx.style.padding
    r = next_control_rect(ctx, width, h)

    hovered = ctx.mouse_pos.x >= r.x && ctx.mouse_pos.x <= r.x + r.w &&
              ctx.mouse_pos.y >= r.y && ctx.mouse_pos.y <= r.y + r.h

    # Si ce contrôle a le focus, on le signale au contexte.
    if ctx.focus_id == id
        ctx.updated_focus = true
    end

    # Donner le focus au clic
    if hovered && ctx.mouse_pressed
        mu_set_focus!(ctx, id)
    end

    # Perdre le focus si on clique ailleurs
    if !hovered && ctx.mouse_pressed && ctx.focus_id == id
        mu_set_focus!(ctx, 0)
    end

    #=
    if hovered
        ctx.hot_id = id
        if ctx.mouse_pressed
            ctx.active_id = id
        end
    end
    =#

    # Logique de dessin du fond
    bg = ctx.style.colors[:button]
    if ctx.focus_id == id
        bg = ctx.style.colors[:button_focus]
    elseif hovered
        bg = ctx.style.colors[:button_hover]
    end
    draw_rect!(ctx.renderer, r, bg)

    text_x = r.x + ctx.style.padding
    text_y = r.y + ctx.style.padding
    draw_text!(ctx.renderer, buffer[], mu_vec2(text_x, text_y), ctx.style.colors[:text], nothing)

    # curseur clignotant si focus
    if ctx.focus_id == id && (ctx.cursor_blink % 60) < 30
        tw = get_text_width(ctx.renderer, buffer[], nothing)
        cx = text_x + tw
        draw_text!(ctx.renderer, "|", mu_vec2(cx, text_y), ctx.style.colors[:text], nothing)
    end

    # Utiliser focus_id pour la gestion des entrées
    # Gestion entrée texte
    if ctx.focus_id == id && !isempty(ctx.input_buffer)
        buffer[] *= ctx.input_buffer
        ctx.input_buffer = ""
    end

    # Gestion touche retour arrière
    if ctx.focus_id == id && ctx.key_pressed == :backspace
        buffer[] = isempty(buffer[]) ? "" : buffer[][1:end-1]
    end
end

# -----------------------------------------------------------------------------
# Gestion des touches clavier et du texte
# -----------------------------------------------------------------------------
function mu_input_text(ctx::Context, text::String)
    ctx.input_buffer *= text
end

function mu_input_keydown(ctx::Context, key)
    ctx.key_pressed = key
end

function mu_input_keyup(ctx::Context, key)
    ctx.key_pressed = nothing
end

end # module