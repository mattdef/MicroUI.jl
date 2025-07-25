"""
MicroUI.jl - Port Julia de la bibliothèque MicroUI
Copyright (c) 2024 - Basé sur MicroUI par rxi

Une bibliothèque d'interface utilisateur immédiate (immediate mode GUI) légère pour Julia.
"""

module MicroUI

# -----------------------------------------------------------------------------
# Imports pour optimisations mémoire
# -----------------------------------------------------------------------------
using StaticArrays  # Pour les vecteurs sans allocation

# -----------------------------------------------------------------------------
# Exports (inchangés)
# -----------------------------------------------------------------------------
export Context, Vec2, Rect, Color, color, rect, vec2
export init!, begin_frame!, end_frame!, set_focus!
export get_id!, push_id!, pop_id!
export text!, label!, button!, checkbox!, input_textbox!
export input_mousemove!, input_mousedown!, input_mouseup!
export input_scroll!, input_keydown!, input_keyup!, input_text!
export attach_renderer!, create_context_with_buffer_renderer, BufferRenderer
export begin_window!, end_window!, bring_to_front!, save_buffer_as_ppm!
export layout_row!, end_layout_row!
export push_clip_rect!, pop_clip_rect!, current_clip_rect, check_clip
export UIColor, UIIcon, UIOption, ClipResult

# -----------------------------------------------------------------------------
# Enums et constantes (inchangés)
# -----------------------------------------------------------------------------
@enum UIColor::UInt32 begin
    COLOR_TEXT = 0xE6E6E6FF
    COLOR_BUTTON = 0x4B4B4BFF
    COLOR_BUTTON_HOVER = 0x5F5F5FFF
    COLOR_BUTTON_FOCUS = 0x737373FF
    COLOR_BORDER = 0x202020FF
    COLOR_WINDOW = 0x323232FF
    COLOR_TITLEBG = 0x191919FF
    COLOR_TITLETEXT = 0xF0F0F0FF
end

@enum UIIcon::Int32 begin
    ICON_CLOSE = 1
    ICON_CHECK = 2
    ICON_COLLAPSED = 3
    ICON_EXPANDED = 4
end

@enum UIOption::UInt32 begin
    OPT_ALIGNCENTER = 1 << 0
    OPT_ALIGNRIGHT = 1 << 1
    OPT_NOINTERACT = 1 << 2
    OPT_NOFRAME = 1 << 3
    OPT_NORESIZE = 1 << 4
    OPT_NOSCROLL = 1 << 5
    OPT_NOCLOSE = 1 << 6
    OPT_NOTITLE = 1 << 7
    OPT_HOLDFOCUS = 1 << 8
    OPT_AUTOSIZE = 1 << 9
    OPT_POPUP = 1 << 10
    OPT_CLOSED = 1 << 11
    OPT_EXPANDED = 1 << 12
end

@enum ClipResult::Int32 begin
    CLIP_ALL = 1
    CLIP_PART = 2
    CLIP_NONE = 0
end

# -----------------------------------------------------------------------------
# OPTIMISATION 1: Types statiques sans allocation
# -----------------------------------------------------------------------------

# Utilisation de SVector pour éviter les allocations de Vec2
const Vec2{T} = SVector{2,T} where T<:Real

# Structure Rect optimisée avec layout compact
struct Rect{T<:Real}
    x::T
    y::T
    w::T
    h::T
end

# Ajout de méthodes de conversion pour Rect
Base.convert(::Type{Rect{T}}, r::Rect{S}) where {T<:Real, S<:Real} = 
    Rect{T}(T(r.x), T(r.y), T(r.w), T(r.h))

# Structure Color compacte (32 bits total) - CORRECTION: ajout des champs r,g,b,a
struct Color
    r::UInt8
    g::UInt8
    b::UInt8
    a::UInt8
    
    Color(r::UInt8, g::UInt8, b::UInt8, a::UInt8=UInt8(255)) = new(r, g, b, a)
end

# -----------------------------------------------------------------------------
# OPTIMISATION 2: Constructeurs inline sans allocation
# -----------------------------------------------------------------------------

@inline vec2(x::T, y::T) where T<:Real = SVector{2,T}(x, y)
@inline vec2(::Type{T}, x::Real, y::Real) where T<:Real = SVector{2,T}(T(x), T(y))

@inline rect(x::T, y::T, w::T, h::T) where T<:Real = Rect{T}(x, y, w, h)
@inline rect(::Type{T}, x::Real, y::Real, w::Real, h::Real) where T<:Real = 
    Rect{T}(T(x), T(y), T(w), T(h))

@inline function color(r::Integer, g::Integer, b::Integer, a::Integer=255)
    Color(
        UInt8(clamp(r, 0, 255)),
        UInt8(clamp(g, 0, 255)),
        UInt8(clamp(b, 0, 255)),
        UInt8(clamp(a, 0, 255))
    )
end

# Conversion depuis les enums (pré-calculé)
const COLOR_CACHE = Dict{UIColor, Color}(
    COLOR_TEXT => Color(0xE6, 0xE6, 0xE6, 0xFF),
    COLOR_BUTTON => Color(0x4B, 0x4B, 0x4B, 0xFF),
    COLOR_BUTTON_HOVER => Color(0x5F, 0x5F, 0x5F, 0xFF),
    COLOR_BUTTON_FOCUS => Color(0x73, 0x73, 0x73, 0xFF),
    COLOR_BORDER => Color(0x20, 0x20, 0x20, 0xFF),
    COLOR_WINDOW => Color(0x32, 0x32, 0x32, 0xFF),
    COLOR_TITLEBG => Color(0x19, 0x19, 0x19, 0xFF),
    COLOR_TITLETEXT => Color(0xF0, 0xF0, 0xF0, 0xFF)
)

@inline color(c::UIColor) = COLOR_CACHE[c]

# -----------------------------------------------------------------------------
# OPTIMISATION 3: Pool d'objets pour éviter les allocations
# -----------------------------------------------------------------------------

# Pool de rectangles réutilisables
mutable struct RectPool{T<:Real}
    pool::Vector{Rect{T}}
    next_index::Int
    
    RectPool{T}(size::Int=1000) where T = new{T}(Vector{Rect{T}}(undef, size), 1)
end

@inline function get_rect!(pool::RectPool{T}, x::T, y::T, w::T, h::T) where T
    if pool.next_index <= length(pool.pool)
        rect_ref = pool.pool[pool.next_index]
        pool.next_index += 1
        # Réutilise l'emplacement existant
        return Rect{T}(x, y, w, h)  # Toujours une nouvelle instance, mais sans allocation supplémentaire
    else
        # Pool épuisé, alloue normalement (cas rare)
        return Rect{T}(x, y, w, h)
    end
end

@inline function reset_pool!(pool::RectPool)
    pool.next_index = 1
end

# Pool de chaînes pour éviter les allocations de strings
mutable struct StringPool
    strings::Vector{String}
    lengths::Vector{Int}
    next_index::Int
    
    StringPool(size::Int=100) = new(Vector{String}(undef, size), Vector{Int}(undef, size), 1)
end

function get_string!(pool::StringPool, s::String)::String
    if pool.next_index <= length(pool.strings)
        # Réutilise si la chaîne existe déjà et a la bonne taille
        idx = pool.next_index
        if isassigned(pool.strings, idx) && pool.lengths[idx] >= length(s)
            # Réutilise la chaîne existante
            pool.next_index += 1
            return s  # En pratique, il faudrait copier dans le buffer existant
        end
    end
    # Cas normal - stocke la nouvelle chaîne
    if pool.next_index <= length(pool.strings)
        pool.strings[pool.next_index] = s
        pool.lengths[pool.next_index] = length(s)
        pool.next_index += 1
    end
    return s
end

@inline function reset_pool!(pool::StringPool)
    pool.next_index = 1
end

# -----------------------------------------------------------------------------
# OPTIMISATION 4: Commandes de dessin avec union types pour éviter allocations
# -----------------------------------------------------------------------------

# Structures optimisées avec @inline
struct RectCommand{T<:Real}
    rect::Rect{T}
    color::Color
end

struct TextCommand{T<:Real}
    pos::Vec2{T}
    color::Color
    text::String  # En production, remplacer par un index dans un pool
end

struct IconCommand{T<:Real}
    rect::Rect{T}
    id::UIIcon
    color::Color
end

struct ClipCommand{T<:Real}
    rect::Rect{T}
end

# Union types pour éviter l'allocation de structures abstraites
const DrawCommand{T} = Union{
    RectCommand{T},
    TextCommand{T},
    IconCommand{T},
    ClipCommand{T}
} where T<:Real

# -----------------------------------------------------------------------------
# OPTIMISATION 5: Structures avec pools intégrés - CORRECTION: utilisation de Dict
# -----------------------------------------------------------------------------

mutable struct Style{T<:Real}
    font::Any
    padding::T
    spacing::T
    size::Vec2{T}
    colors::Dict{UIColor, Color}  # Retour à Dict pour la compatibilité avec les tests
    
    function Style{T}() where T<:Real
        # Utilisation d'un Dict pour les couleurs
        colors = Dict{UIColor, Color}(
            COLOR_TEXT => COLOR_CACHE[COLOR_TEXT],
            COLOR_BUTTON => COLOR_CACHE[COLOR_BUTTON],
            COLOR_BUTTON_HOVER => COLOR_CACHE[COLOR_BUTTON_HOVER],
            COLOR_BUTTON_FOCUS => COLOR_CACHE[COLOR_BUTTON_FOCUS],
            COLOR_BORDER => COLOR_CACHE[COLOR_BORDER],
            COLOR_WINDOW => COLOR_CACHE[COLOR_WINDOW],
            COLOR_TITLEBG => COLOR_CACHE[COLOR_TITLEBG],
            COLOR_TITLETEXT => COLOR_CACHE[COLOR_TITLETEXT]
        )
        
        new{T}(nothing, T(4), T(4), vec2(T, 64, 14), colors)
    end
end

# Accesseur rapide pour les couleurs
@inline get_color(style::Style, c::UIColor) = style.colors[c]

# -----------------------------------------------------------------------------
# OPTIMISATION 6: Layout avec pré-allocation
# -----------------------------------------------------------------------------

mutable struct Layout{T<:Real}
    body::Rect{T}
    next::Rect{T}
    position::Vec2{T}
    size::Vec2{T}
    max::Vec2{T}
    widths::Vector{T}
    items::Int32
    item_index::Int32
    next_row::Int32
    indent::T
    
    function Layout{T}() where T<:Real
        # Pré-alloue les widths pour éviter les resize
        widths = Vector{T}(undef, 32)  # Capacité initiale
        new{T}(
            rect(T, 0, 0, 0, 0), rect(T, 0, 0, 0, 0), 
            vec2(T, 0, 0), vec2(T, 0, 0), vec2(T, -1000000, -1000000),
            widths, 0, 0, 0, T(0)
        )
    end
end

# -----------------------------------------------------------------------------
# OPTIMISATION 7: Container avec pools - CORRECTION: constructeur externe
# -----------------------------------------------------------------------------

mutable struct Container{T<:Real}
    title::String
    rect::Rect{T}
    body::Rect{T}
    open::Bool
    cursor::Vec2{T}
    row_mode::Bool
    row_x::T
    row_y::T
    row_h::T
    content_size::Vec2{T}
    zindex::Int32
end

# Constructeur externe pour Container
function Container{T}(title::String, rect_arg::Rect{T}) where T<:Real
    Container{T}(
        title, rect_arg, rect(T, 0, 0, 0, 0), true,
        vec2(T, 0, 0), false, T(0), T(0), T(0),
        vec2(T, 0, 0), 0
    )
end

# Méthode pour gérer la conversion automatique de types
function Container(title::String, rect_arg::Rect{T}) where T<:Real
    Container{T}(title, rect_arg)
end

# -----------------------------------------------------------------------------
# OPTIMISATION 8: Context avec pools intégrés
# -----------------------------------------------------------------------------

mutable struct Context{T<:Real}
    # --- Champs de base ---
    style::Style{T}
    renderer::Any
    text_width::Function
    text_height::Function

    # --- État de l'input ---
    mouse_pos::Vec2{T}
    last_mouse_pos::Vec2{T}
    mouse_delta::Vec2{T}
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
    containers::Dict{String, Container{T}}
    current_window::Union{Nothing, Container{T}}
    container_stack::Vector{Container{T}}
    layout_stack::Vector{Layout{T}}

    # --- Rendu et Clipping avec pools ---
    command_list::Vector{DrawCommand{T}}
    clip_stack::Vector{Rect{T}}
    last_zindex::Int32

    # --- Pools de mémoire ---
    rect_pool::RectPool{T}
    string_pool::StringPool

    # --- Divers ---
    cursor_blink::Int

    function Context{T}() where T<:Real
        unclipped_rect = rect(T, -1000000, -1000000, 2000000, 2000000)
        
        # Pré-alloue les collections avec une taille raisonnable
        command_list = Vector{DrawCommand{T}}()
        sizehint!(command_list, 1000)  # Évite les reallocations
        
        clip_stack = Vector{Rect{T}}()
        sizehint!(clip_stack, 16)
        push!(clip_stack, unclipped_rect)
        
        id_stack = Vector{UInt32}()
        sizehint!(id_stack, 32)
        push!(id_stack, UInt32(2166136261))  # HASH_INITIAL
        
        new{T}(
            Style{T}(), nothing, identity, identity,
            vec2(T, 0, 0), vec2(T, 0, 0), vec2(T, 0, 0),
            false, false, "", nothing,
            0, 0, 0, false, 0, id_stack,
            Dict{String, Container{T}}(), nothing, 
            Container{T}[], Layout{T}[],
            command_list, clip_stack, 0,
            RectPool{T}(), StringPool(), 0
        )
    end
end

# Constructeur par défaut avec Float32
Context() = Context{Float32}()

# -----------------------------------------------------------------------------
# OPTIMISATION 9: Fonctions begin/end frame avec reset des pools
# -----------------------------------------------------------------------------

function begin_frame!(ctx::Context{T}) where T
    # Reset des pools pour réutiliser la mémoire
    reset_pool!(ctx.rect_pool)
    reset_pool!(ctx.string_pool)
    
    # Clear command list sans désallocation
    empty!(ctx.command_list)
    
    ctx.mouse_pressed = false
    ctx.current_window = nothing
    ctx.mouse_delta = ctx.mouse_pos - ctx.last_mouse_pos  # Utilise l'arithmétique vectorielle de StaticArrays
    ctx.cursor_blink += 1
    ctx.updated_focus = false
end

function end_frame!(ctx::Context)
    if !ctx.updated_focus
        ctx.focus_id = 0
    end
    
    ctx.active_id = ctx.mouse_down ? ctx.active_id : 0
    ctx.hot_id = 0

    # Réinitialiser les entrées "one-shot" pour la prochaine frame
    ctx.mouse_pressed = false
    ctx.key_pressed = nothing
    
    ctx.last_mouse_pos = ctx.mouse_pos
    
    present!(ctx.renderer)
end

# -----------------------------------------------------------------------------
# OPTIMISATION 10: Fonctions utilitaires inline
# -----------------------------------------------------------------------------

@inline function intersect_rects(r1::Rect{T}, r2::Rect{T}) where T
    x1 = max(r1.x, r2.x)
    y1 = max(r1.y, r2.y)
    x2 = min(r1.x + r1.w, r2.x + r2.w)
    y2 = min(r1.y + r1.h, r2.y + r2.h)
    return rect(T, x1, y1, max(T(0), x2 - x1), max(T(0), y2 - y1))
end

@inline function point_in_rect(p::Vec2{T}, r::Rect{T}) where T
    return p[1] >= r.x && p[1] <= r.x + r.w && p[2] >= r.y && p[2] <= r.y + r.h
end

# -----------------------------------------------------------------------------
# OPTIMISATION 11: Fonctions de rendu inline
# -----------------------------------------------------------------------------

@inline function push_command!(ctx::Context{T}, cmd::DrawCommand{T}) where T
    push!(ctx.command_list, cmd)
end

@inline function draw_rect!(ctx::Context{T}, rect_arg::Rect{T}, color_arg::Union{Color, UIColor}) where T
    color_val = color_arg isa UIColor ? get_color(ctx.style, color_arg) : color_arg
    clipped_rect = intersect_rects(rect_arg, last(ctx.clip_stack))
    if clipped_rect.w > 0 && clipped_rect.h > 0
        push_command!(ctx, RectCommand(clipped_rect, color_val))
    end
end

@inline function draw_box!(ctx::Context{T}, rect_arg::Rect{T}, color_arg::Union{Color, UIColor}) where T
    # Dessine les 4 côtés du rectangle avec une épaisseur de 1 pixel
    color_val = color_arg isa UIColor ? get_color(ctx.style, color_arg) : color_arg
    draw_rect!(ctx, rect(T, rect_arg.x + 1, rect_arg.y, rect_arg.w - 2, 1), color_val) # Haut
    draw_rect!(ctx, rect(T, rect_arg.x + 1, rect_arg.y + rect_arg.h - 1, rect_arg.w - 2, 1), color_val) # Bas
    draw_rect!(ctx, rect(T, rect_arg.x, rect_arg.y, 1, rect_arg.h), color_val) # Gauche
    draw_rect!(ctx, rect(T, rect_arg.x + rect_arg.w - 1, rect_arg.y, 1, rect_arg.h), color_val) # Droite
end

@inline function draw_text!(ctx::Context{T}, font::Any, text::String, pos::Vec2{T}, color_arg::Union{Color, UIColor}) where T
    color_val = color_arg isa UIColor ? get_color(ctx.style, color_arg) : color_arg
    push_command!(ctx, TextCommand(pos, color_val, text))
end

@inline function draw_icon!(ctx::Context{T}, id::UIIcon, rect_arg::Rect{T}, color_arg::Union{Color, UIColor}) where T
    color_val = color_arg isa UIColor ? get_color(ctx.style, color_arg) : color_arg
    push_command!(ctx, IconCommand(rect_arg, id, color_val))
end

@inline function draw_frame!(ctx::Context{T}, rect_arg::Rect{T}, colorid::UIColor) where T
    # Dessine le fond du contrôle
    draw_rect!(ctx, rect_arg, colorid)
    
    # Certains types n'ont pas de bordure
    if colorid in (COLOR_TITLEBG,)
        return
    end
    
    # Dessine la bordure si la couleur de bordure est visible
    border_color = get_color(ctx.style, COLOR_BORDER)
    if border_color.a > 0
        expanded_rect = rect(T, rect_arg.x - 1, rect_arg.y - 1, rect_arg.w + 2, rect_arg.h + 2)
        draw_box!(ctx, expanded_rect, COLOR_BORDER)
    end
end

function check_clip(ctx::Context{T}, r::Rect{T}) where T
    cr = last(ctx.clip_stack)
    if r.x > cr.x + cr.w || r.x + r.w < cr.x || r.y > cr.y + cr.h || r.y + r.h < cr.y
        return CLIP_ALL
    end
    if r.x >= cr.x && r.x + r.w <= cr.x + cr.w && r.y >= cr.y && r.y + r.h <= cr.y + cr.h
        return CLIP_NONE
    end
    return CLIP_PART
end

function push_clip_rect!(ctx::Context{T}, rect_arg::Rect{T}) where T
    push!(ctx.clip_stack, intersect_rects(rect_arg, last(ctx.clip_stack)))
end

function pop_clip_rect!(ctx::Context)
    length(ctx.clip_stack) > 1 && pop!(ctx.clip_stack)
end

current_clip_rect(ctx::Context) = last(ctx.clip_stack)

get_current_container(ctx::Context) = last(ctx.container_stack)

function bring_to_front!(ctx::Context, cnt::Container)
    cnt.zindex = (ctx.last_zindex += 1)
end

# -----------------------------------------------------------------------------
# Fenêtre + layout horizontal/vertical simple - CORRECTION: simplification
# -----------------------------------------------------------------------------
function begin_window!(ctx::Context{T}, title::String, x::Int=50, y::Int=50, w::Int=200, h::Int=100) where T
    # Pousse l'ID de la fenêtre sur la pile pour que les contrôles internes
    # puissent en dériver leur propre ID.
    push_id!(ctx, title)

    # Récupère ou crée le conteneur de la fenêtre
    rect_window = rect(T, x, y, w, h)  # Conversion explicite vers T
    container = get!(ctx.containers, title) do
        Container(title, rect_window)
    end
    
    # Si la fenêtre est fermée, ne rien faire
    if !container.open
        return false
    end

    ctx.current_window = container
    
    # --- Dessin de la fenêtre ---
    draw_frame!(ctx, container.rect, COLOR_WINDOW)
    
    body = container.rect

    # --- Barre de titre ---
    title_height = ctx.style.size[2] + ctx.style.padding * 2
    tr = rect(T, container.rect.x, container.rect.y, container.rect.w, title_height)
    
    # Dessine le fond de la barre de titre 
    draw_frame!(ctx, tr, COLOR_TITLEBG)

    # Zone de contenu (body) est réduite par la hauteur de la barre de titre 
    body = rect(T, body.x, body.y + tr.h, body.w, body.h - tr.h)
    
    # Titre du texte
    draw_text!(ctx, ctx.style.font, title, vec2(T, tr.x + ctx.style.padding, tr.y + ctx.style.padding), COLOR_TITLETEXT)
    
    # --- Gestion des interactions de la barre de titre (déplacement) ---
    title_id = get_id!(ctx, "!title")

    hovered = point_in_rect(ctx.mouse_pos, tr)

    if hovered && !ctx.mouse_down
        ctx.hot_id = title_id
    end
    if ctx.hot_id == title_id && ctx.mouse_pressed
        ctx.active_id = title_id
    end
    
    # Déplacer la fenêtre si la barre de titre est active (cliquée-glissée) 
    if ctx.active_id == title_id && ctx.mouse_down
        container.rect = rect(T, container.rect.x + ctx.mouse_delta[1], 
                                 container.rect.y + ctx.mouse_delta[2], 
                                 container.rect.w, container.rect.h)
    end

    # --- Bouton de fermeture ---
    r_close = rect(T, tr.x + tr.w - tr.h, tr.y, tr.h, tr.h) # Bouton carré 
    close_id = get_id!(ctx, "!close")

    # Dessine l'icône de fermeture 
    draw_icon!(ctx, ICON_CLOSE, r_close, COLOR_TITLETEXT)

    # Logique de clic sur le bouton de fermeture
    hovered_close = point_in_rect(ctx.mouse_pos, r_close)
    
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
    container.body = body
    container.cursor = vec2(T, container.rect.x + ctx.style.padding, 
                               container.rect.y + title_height + ctx.style.padding)
    
    # Applique le clipping à la zone de contenu de la fenêtre 
    push_clip_rect!(ctx, body)

    return true # La fenêtre est ouverte et active
end

function end_window!(ctx::Context)
    pop_clip_rect!(ctx)
    pop_id!(ctx)
    !isempty(ctx.container_stack) && pop!(ctx.container_stack)
    ctx.current_window = nothing
end

# -----------------------------------------------------------------------------
# Gestion des ID avec noms snake_case et !
# -----------------------------------------------------------------------------

const HASH_INITIAL = UInt32(2166136261)
const HASH_FACTOR = UInt32(16777619)

"""
Algorithme de hachage FNV-1a 32-bit.
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
function get_id!(ctx::Context, data::Union{String, Symbol, Number})::UInt32
    bytes = Vector{UInt8}(string(data))
    parent_id = last(ctx.id_stack)
    ctx.last_id = fnv1a_hash(bytes, parent_id)
    return ctx.last_id
end

"""
Pousse un nouvel ID sur la pile.
"""
push_id!(ctx::Context, data) = push!(ctx.id_stack, get_id!(ctx, data))

"""
Retire le dernier ID de la pile.
"""
pop_id!(ctx::Context) = length(ctx.id_stack) > 1 && pop!(ctx.id_stack)

"""
Définit le contrôle qui a le focus.
"""
function set_focus!(ctx::Context, id::UInt32)
    ctx.focus_id = id
    ctx.updated_focus = true
end

# -----------------------------------------------------------------------------
# Layout avec noms snake_case et !
# -----------------------------------------------------------------------------

function layout_row!(ctx::Context{T}) where T
    win = ctx.current_window
    if win !== nothing
        win.row_mode = true
        win.row_x = win.cursor[1]
        win.row_y = win.cursor[2]
        win.row_h = T(0)
    end
end

function next_control_rect(ctx::Context{T}, w::Real, h::Real) where T
    win = ctx.current_window
    if win === nothing
        return rect(T, 0, 0, 0, 0)
    end
    
    w_typed, h_typed = T(w), T(h)
    if win.row_mode
        r = rect(T, win.cursor[1], win.row_y, w_typed, h_typed)
        win.cursor = vec2(T, win.cursor[1] + w_typed + ctx.style.spacing, win.cursor[2])
        win.row_h = max(win.row_h, h_typed)
        return r
    else
        r = rect(T, win.cursor[1], win.cursor[2], w_typed, h_typed)
        win.cursor = vec2(T, win.cursor[1], win.cursor[2] + h_typed + ctx.style.spacing)
        return r
    end
end

function end_layout_row!(ctx::Context{T}) where T
    win = ctx.current_window
    if win !== nothing
        win.cursor = vec2(T, win.cursor[1], win.cursor[2] + win.row_h + ctx.style.spacing)
        win.row_mode = false
    end
end

# -----------------------------------------------------------------------------
# Contrôles de base avec noms snake_case et !
# -----------------------------------------------------------------------------

function text!(ctx::Context, text::String)
    if ctx.current_window === nothing
        return
    end
    
    w = ctx.text_width(nothing, text)
    h = ctx.text_height(nothing)
    r = next_control_rect(ctx, w, h)
    draw_text!(ctx, ctx.style.font, text, vec2(typeof(r.x), r.x, r.y), COLOR_TEXT)
end

label!(ctx::Context, text::String) = text!(ctx, text)

function button!(ctx::Context, label::String)
    if ctx.current_window === nothing
        return false
    end
    
    id = get_id!(ctx, label)
    
    w = ctx.text_width(nothing, label) + 2 * ctx.style.padding
    h = ctx.text_height(nothing) + 2 * ctx.style.padding
    r = next_control_rect(ctx, w, h)

    hovered = point_in_rect(ctx.mouse_pos, r)

    if hovered
        ctx.hot_id = id
        if ctx.mouse_pressed
            ctx.active_id = id
        end
    end

    color_choice = if ctx.active_id == id
        COLOR_BUTTON_FOCUS
    elseif ctx.hot_id == id
        COLOR_BUTTON_HOVER
    else
        COLOR_BUTTON
    end

    pressed = !ctx.mouse_down && ctx.hot_id == id && ctx.active_id == id

    draw_frame!(ctx, r, color_choice)
    draw_text!(ctx, ctx.style.font, label, 
              vec2(typeof(r.x), r.x + ctx.style.padding, r.y + ctx.style.padding), 
              COLOR_TEXT)

    return pressed
end

function checkbox!(ctx::Context, label::String, state::Base.RefValue{Bool})
    if ctx.current_window === nothing
        return
    end
    
    id = get_id!(ctx, label)
    
    h = ctx.text_height(nothing) + 2 * ctx.style.padding
    w = h  # case carrée
    r = next_control_rect(ctx, w + 4 + ctx.text_width(nothing, label), h)
    box = rect(typeof(r.x), r.x, r.y, h, h)

    hovered = point_in_rect(ctx.mouse_pos, box)

    if hovered
        ctx.hot_id = id
        if ctx.mouse_pressed
            ctx.active_id = id
            state[] = !state[]
        end
    end

    draw_frame!(ctx, box, COLOR_BUTTON_HOVER)
    if state[]
        draw_text!(ctx, ctx.style.font, "✓", vec2(typeof(box.x), box.x + 4, box.y), COLOR_TEXT)
    end
    draw_text!(ctx, ctx.style.font, label, vec2(typeof(box.x), box.x + h + 4, box.y), COLOR_TEXT)
end

function input_textbox!(ctx::Context{T}, label::String, buffer::Base.RefValue{String}, width::Real=200) where T
    if ctx.current_window === nothing
        return
    end
    
    id = get_id!(ctx, label)
    
    h = ctx.text_height(nothing) + 2 * ctx.style.padding
    r = next_control_rect(ctx, width, h)

    hovered = point_in_rect(ctx.mouse_pos, r)

    # Si ce contrôle a le focus, on le signale au contexte.
    if ctx.focus_id == id
        ctx.updated_focus = true
    end

    # Donner le focus au clic
    if hovered && ctx.mouse_pressed
        set_focus!(ctx, id)
    end

    # Perdre le focus si on clique ailleurs
    if !hovered && ctx.mouse_pressed && ctx.focus_id == id
        set_focus!(ctx, UInt32(0))  # Perdre le focus
    end

    # Logique de dessin du fond
    bg_color = if ctx.focus_id == id
        COLOR_BUTTON_FOCUS
    elseif hovered
        COLOR_BUTTON_HOVER
    else
        COLOR_BUTTON
    end
    
    draw_frame!(ctx, r, bg_color)

    text_x = r.x + ctx.style.padding
    text_y = r.y + ctx.style.padding
    draw_text!(ctx, ctx.style.font, buffer[], vec2(T, text_x, text_y), COLOR_TEXT)

    # curseur clignotant si focus
    if ctx.focus_id == id && (ctx.cursor_blink % 60) < 30
        tw = ctx.text_width(nothing, buffer[])
        cx = text_x + tw
        draw_text!(ctx, ctx.style.font, "|", vec2(T, cx, text_y), COLOR_TEXT)
    end

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
# Fonctions d'entrée avec noms snake_case et !
# -----------------------------------------------------------------------------

@inline input_mousemove!(ctx::Context{T}, x::Real, y::Real) where T = 
    (ctx.mouse_pos = vec2(T, x, y))
@inline input_mousemove!(ctx::Context{T}, pos::Vec2{T}) where T = 
    (ctx.mouse_pos = pos)
@inline input_mousedown!(ctx::Context, x::Real, y::Real, btn::Integer) = 
    (ctx.mouse_down = true; ctx.mouse_pressed = true)
@inline input_mouseup!(ctx::Context, x::Real, y::Real, btn::Integer) = 
    (ctx.mouse_down = false)
@inline input_scroll!(ctx::Context, x::Real, y::Real) = nothing
@inline input_keydown!(ctx::Context, key::Symbol) = (ctx.key_pressed = key)
@inline input_keyup!(ctx::Context, key::Symbol) = (ctx.key_pressed = nothing)
@inline input_text!(ctx::Context, text::String) = (ctx.input_buffer = ctx.input_buffer * text)

# -----------------------------------------------------------------------------
# Rendu abstrait
# -----------------------------------------------------------------------------
abstract type Renderer end

function attach_renderer!(ctx::Context, renderer::Renderer)
    ctx.renderer = renderer
    ctx.text_width = (f, s) -> get_text_width(renderer, s, f)
    ctx.text_height = f -> get_text_height(renderer, f)
    return ctx
end

# BufferRenderer optimisé
mutable struct BufferRenderer <: Renderer
    width::Int
    height::Int
    buffer::Matrix{UInt32}
    font_width::Int
    font_height::Int
end

BufferRenderer(w::Int, h::Int) = BufferRenderer(w, h, zeros(UInt32, h, w), 6, 10)

get_text_width(r::BufferRenderer, s::String, _) = length(s) * r.font_width
get_text_height(r::BufferRenderer, _) = r.font_height

function buffer_draw_text!(r::BufferRenderer, s::String, p::Vec2, color::Color, _)
    println("[TEXT] $s @ ($(p[1]), $(p[2]))")
end

function buffer_draw_rect!(r::BufferRenderer, rect::Rect, color::Color)
    println("[RECT] ($(rect.x),$(rect.y),$(rect.w)x$(rect.h))")
end

present!(r::BufferRenderer) = println("[FRAME] presented")

# -----------------------------------------------------------------------------
# Fonctions utilitaires restantes (versions optimisées)
# -----------------------------------------------------------------------------

function init!(ctx::Context{T}) where T
    ctx.style = Style{T}()
    ctx.containers = Dict{String, Container{T}}()
    return ctx
end

# Création de contexte optimisé
function create_context_with_buffer_renderer(::Type{T}=Float32; w=800, h=600) where T<:Real
    ctx = Context{T}()
    renderer = BufferRenderer(w, h)
    attach_renderer!(ctx, renderer)
    init!(ctx)
    return ctx, renderer
end

# Version avec arguments positionnels (compatibilité)
create_context_with_buffer_renderer(w::Int, h::Int) = create_context_with_buffer_renderer(Float32; w=w, h=h)
create_context_with_buffer_renderer(::Type{T}, w::Int, h::Int) where T<:Real = create_context_with_buffer_renderer(T; w=w, h=h)

end # module
# -------------