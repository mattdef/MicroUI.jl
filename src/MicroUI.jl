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
# Exports (étendus)
# -----------------------------------------------------------------------------
export Context, Vec2, Rect, Color, color, rect, vec2
export init!, begin_frame!, end_frame!, set_focus!
export get_id!, push_id!, pop_id!
export text!, label!, button!, checkbox!, input_textbox!
export slider!, number_input!, scrollbar!, tree_node! 
export input_mousemove!, input_mousedown!, input_mouseup!
export input_scroll!, input_keydown!, input_keyup!, input_text!
export attach_renderer!, create_context_with_buffer_renderer, BufferRenderer
export begin_window!, end_window!, bring_to_front!, save_buffer_as_ppm!
export layout_row!, end_layout_row!
export push_clip_rect!, pop_clip_rect!, current_clip_rect, check_clip
export UIColor, UIIcon, UIOption, ClipResult

# -----------------------------------------------------------------------------
# Enums et constantes (étendus)
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
    COLOR_SCROLLBAR = 0x2A2A2AFF 
    COLOR_SCROLLBAR_THUMB = 0x555555FF 
    COLOR_SLIDER_TRACK = 0x2B2B2BFF  
    COLOR_SLIDER_THUMB = 0x4A90E2FF 
    COLOR_NUMBER_INPUT = 0x3A3A3AFF 
end

@enum UIIcon::Int32 begin
    ICON_CLOSE = 1
    ICON_CHECK = 2
    ICON_COLLAPSED = 3
    ICON_EXPANDED = 4
    ICON_ARROW_UP = 5  
    ICON_ARROW_DOWN = 6 
    ICON_ARROW_LEFT = 7 
    ICON_ARROW_RIGHT = 8 
    ICON_MINUS = 9   
    ICON_PLUS = 10 
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

# Structure Color compacte (32 bits total)
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

# Conversion depuis les enums (pré-calculé) - étendu
const COLOR_CACHE = Dict{UIColor, Color}(
    COLOR_TEXT => Color(0xE6, 0xE6, 0xE6, 0xFF),
    COLOR_BUTTON => Color(0x4B, 0x4B, 0x4B, 0xFF),
    COLOR_BUTTON_HOVER => Color(0x5F, 0x5F, 0x5F, 0xFF),
    COLOR_BUTTON_FOCUS => Color(0x73, 0x73, 0x73, 0xFF),
    COLOR_BORDER => Color(0x20, 0x20, 0x20, 0xFF),
    COLOR_WINDOW => Color(0x32, 0x32, 0x32, 0xFF),
    COLOR_TITLEBG => Color(0x19, 0x19, 0x19, 0xFF),
    COLOR_TITLETEXT => Color(0xF0, 0xF0, 0xF0, 0xFF),
    COLOR_SCROLLBAR => Color(0x2A, 0x2A, 0x2A, 0xFF),
    COLOR_SCROLLBAR_THUMB => Color(0x55, 0x55, 0x55, 0xFF),
    COLOR_SLIDER_TRACK => Color(0x2A, 0x2A, 0x2A, 0xFF),
    COLOR_SLIDER_THUMB => Color(0x4A, 0x90, 0xE2, 0xFF),
    COLOR_NUMBER_INPUT => Color(0x3A, 0x3A, 0x3A, 0xFF)
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
        return Rect{T}(x, y, w, h)
    else
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
        idx = pool.next_index
        if isassigned(pool.strings, idx) && pool.lengths[idx] >= length(s)
            pool.next_index += 1
            return s
        end
    end
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

struct RectCommand{T<:Real}
    rect::Rect{T}
    color::Color
end

struct TextCommand{T<:Real}
    pos::Vec2{T}
    color::Color
    text::String
end

struct IconCommand{T<:Real}
    rect::Rect{T}
    id::UIIcon
    color::Color
end

struct ClipCommand{T<:Real}
    rect::Rect{T}
end

struct SliderCommand{T<:Real}
    track_rect::Rect{T}
    thumb_rect::Rect{T}
    track_color::Color
    thumb_color::Color
end

const DrawCommand{T} = Union{
    RectCommand{T},
    TextCommand{T},
    IconCommand{T},
    ClipCommand{T},
    SliderCommand{T}
} where T<:Real

# -----------------------------------------------------------------------------
# OPTIMISATION 5: Structures avec pools intégrés
# -----------------------------------------------------------------------------

mutable struct Style{T<:Real}
    font::Any
    padding::T
    spacing::T
    size::Vec2{T}
    colors::Dict{UIColor, Color}
    slider_thumb_size::T
    scrollbar_size::T
    number_input_button_width::T
    tree_indent::T
    
    function Style{T}() where T<:Real
        colors = Dict{UIColor, Color}(
            COLOR_TEXT => COLOR_CACHE[COLOR_TEXT],
            COLOR_BUTTON => COLOR_CACHE[COLOR_BUTTON],
            COLOR_BUTTON_HOVER => COLOR_CACHE[COLOR_BUTTON_HOVER],
            COLOR_BUTTON_FOCUS => COLOR_CACHE[COLOR_BUTTON_FOCUS],
            COLOR_BORDER => COLOR_CACHE[COLOR_BORDER],
            COLOR_WINDOW => COLOR_CACHE[COLOR_WINDOW],
            COLOR_TITLEBG => COLOR_CACHE[COLOR_TITLEBG],
            COLOR_TITLETEXT => COLOR_CACHE[COLOR_TITLETEXT],
            COLOR_SCROLLBAR => COLOR_CACHE[COLOR_SCROLLBAR],
            COLOR_SCROLLBAR_THUMB => COLOR_CACHE[COLOR_SCROLLBAR_THUMB],
            COLOR_SLIDER_TRACK => COLOR_CACHE[COLOR_SLIDER_TRACK],
            COLOR_SLIDER_THUMB => COLOR_CACHE[COLOR_SLIDER_THUMB],
            COLOR_NUMBER_INPUT => COLOR_CACHE[COLOR_NUMBER_INPUT]
        )
        
        new{T}(nothing, T(4), T(4), vec2(T, 64, 14), colors, 
               T(12), T(16), T(20), T(16)) 
    end
end

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
        widths = Vector{T}(undef, 32)
        new{T}(
            rect(T, 0, 0, 0, 0), rect(T, 0, 0, 0, 0), 
            vec2(T, 0, 0), vec2(T, 0, 0), vec2(T, -1000000, -1000000),
            widths, 0, 0, 0, T(0)
        )
    end
end

# -----------------------------------------------------------------------------
# OPTIMISATION 7: Container avec pools
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
    scroll_x::T
    scroll_y::T
    max_scroll_x::T
    max_scroll_y::T
end

function Container{T}(title::String, rect_arg::Rect{T}) where T<:Real
    Container{T}(
        title, rect_arg, rect(T, 0, 0, 0, 0), true,
        vec2(T, 0, 0), false, T(0), T(0), T(0),
        vec2(T, 0, 0), 0,
        T(0), T(0), T(0), T(0) 
    )
end

function Container(title::String, rect_arg::Rect{T}) where T<:Real
    Container{T}(title, rect_arg)
end

# -----------------------------------------------------------------------------
# État pour les contrôles étendus (évite les allocations répétées)
# -----------------------------------------------------------------------------

# État global pour les tree nodes
mutable struct TreeNodeState
    expanded_nodes::Set{UInt32}
    TreeNodeState() = new(Set{UInt32}())
end

# État global pour les sliders (évite le drag flottant)
mutable struct SliderState{T<:Real}
    active_slider::UInt32
    start_value::T
    start_mouse_pos::T
    SliderState{T}() where T = new{T}(0, T(0), T(0))
end

# -----------------------------------------------------------------------------
# OPTIMISATION 8: Context avec pools intégrés (étendu)
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
    scroll_delta::Vec2{T} 

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

    # --- États pour les nouveaux contrôles ---
    tree_state::TreeNodeState
    slider_state::SliderState{T}

    # --- Divers ---
    cursor_blink::Int

    function Context{T}() where T<:Real
        unclipped_rect = rect(T, -1000000, -1000000, 2000000, 2000000)
        
        command_list = Vector{DrawCommand{T}}()
        sizehint!(command_list, 1000)
        
        clip_stack = Vector{Rect{T}}()
        sizehint!(clip_stack, 16)
        push!(clip_stack, unclipped_rect)
        
        id_stack = Vector{UInt32}()
        sizehint!(id_stack, 32)
        push!(id_stack, UInt32(2166136261))
        
        new{T}(
            Style{T}(), nothing, identity, identity,
            vec2(T, 0, 0), vec2(T, 0, 0), vec2(T, 0, 0),
            false, false, "", nothing, vec2(T, 0, 0), 
            0, 0, 0, false, 0, id_stack,
            Dict{String, Container{T}}(), nothing, 
            Container{T}[], Layout{T}[],
            command_list, clip_stack, 0,
            RectPool{T}(), StringPool(),
            TreeNodeState(), SliderState{T}(), 
            0
        )
    end
end

Context() = Context{Float32}()

# -----------------------------------------------------------------------------
# OPTIMISATION 9: Fonctions begin/end frame avec reset des pools
# -----------------------------------------------------------------------------

function begin_frame!(ctx::Context{T}) where T
    reset_pool!(ctx.rect_pool)
    reset_pool!(ctx.string_pool)
    empty!(ctx.command_list)
    
    ctx.mouse_pressed = false
    ctx.current_window = nothing
    ctx.mouse_delta = ctx.mouse_pos - ctx.last_mouse_pos
    ctx.cursor_blink += 1
    ctx.updated_focus = false
    ctx.scroll_delta = vec2(T, 0, 0) 
end

function end_frame!(ctx::Context)
    if !ctx.updated_focus
        ctx.focus_id = 0
    end
    
    ctx.active_id = ctx.mouse_down ? ctx.active_id : 0
    ctx.hot_id = 0
    
    # Reset du slider state si plus de souris enfoncée
    if !ctx.mouse_down
        ctx.slider_state.active_slider = 0
    end

    ctx.mouse_pressed = false
    ctx.key_pressed = nothing
    ctx.last_mouse_pos = ctx.mouse_pos
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

@inline function clamp_value(value::T, min_val::T, max_val::T) where T
    return min(max(value, min_val), max_val)
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
    color_val = color_arg isa UIColor ? get_color(ctx.style, color_arg) : color_arg
    draw_rect!(ctx, rect(T, rect_arg.x + 1, rect_arg.y, rect_arg.w - 2, 1), color_val)
    draw_rect!(ctx, rect(T, rect_arg.x + 1, rect_arg.y + rect_arg.h - 1, rect_arg.w - 2, 1), color_val)
    draw_rect!(ctx, rect(T, rect_arg.x, rect_arg.y, 1, rect_arg.h), color_val)
    draw_rect!(ctx, rect(T, rect_arg.x + rect_arg.w - 1, rect_arg.y, 1, rect_arg.h), color_val)
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
    draw_rect!(ctx, rect_arg, colorid)
    
    if colorid in (COLOR_TITLEBG,)
        return
    end
    
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
# Fenêtre + layout horizontal/vertical simple
# -----------------------------------------------------------------------------
function begin_window!(ctx::Context{T}, title::String, x::Int=50, y::Int=50, w::Int=200, h::Int=100) where T
    push_id!(ctx, title)

    rect_window = rect(T, x, y, w, h)
    container = get!(ctx.containers, title) do
        Container(title, rect_window)
    end
    
    if !container.open
        return false
    end

    ctx.current_window = container
    
    draw_frame!(ctx, container.rect, COLOR_WINDOW)
    
    body = container.rect

    title_height = ctx.style.size[2] + ctx.style.padding * 2
    tr = rect(T, container.rect.x, container.rect.y, container.rect.w, title_height)
    
    draw_frame!(ctx, tr, COLOR_TITLEBG)

    body = rect(T, body.x, body.y + tr.h, body.w, body.h - tr.h)
    
    draw_text!(ctx, ctx.style.font, title, vec2(T, tr.x + ctx.style.padding, tr.y + ctx.style.padding), COLOR_TITLETEXT)
    
    title_id = get_id!(ctx, "!title")

    hovered = point_in_rect(ctx.mouse_pos, tr)

    if hovered && !ctx.mouse_down
        ctx.hot_id = title_id
    end
    if ctx.hot_id == title_id && ctx.mouse_pressed
        ctx.active_id = title_id
    end
    
    if ctx.active_id == title_id && ctx.mouse_down
        container.rect = rect(T, container.rect.x + ctx.mouse_delta[1], 
                                 container.rect.y + ctx.mouse_delta[2], 
                                 container.rect.w, container.rect.h)
    end

    r_close = rect(T, tr.x + tr.w - tr.h, tr.y, tr.h, tr.h)
    close_id = get_id!(ctx, "!close")

    draw_icon!(ctx, ICON_CLOSE, r_close, COLOR_TITLETEXT)

    hovered_close = point_in_rect(ctx.mouse_pos, r_close)
    
    if hovered_close && !ctx.mouse_down
        ctx.hot_id = close_id
    end
    if ctx.hot_id == close_id && ctx.mouse_pressed
        ctx.active_id = close_id
    end

    if !ctx.mouse_down && ctx.hot_id == close_id && ctx.active_id == close_id
        container.open = false
    end
    
    container.body = body
    container.cursor = vec2(T, container.rect.x + ctx.style.padding, 
                               container.rect.y + title_height + ctx.style.padding)
    
    push_clip_rect!(ctx, body)

    return true
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

function fnv1a_hash(data::Vector{UInt8}, seed::UInt32)::UInt32
    h = seed
    for byte in data
        h = (h ⊻ byte) * HASH_FACTOR
    end
    return h
end

function get_id!(ctx::Context, data::Union{String, Symbol, Number})::UInt32
    bytes = Vector{UInt8}(string(data))
    parent_id = last(ctx.id_stack)
    ctx.last_id = fnv1a_hash(bytes, parent_id)
    return ctx.last_id
end

push_id!(ctx::Context, data) = push!(ctx.id_stack, get_id!(ctx, data))

pop_id!(ctx::Context) = length(ctx.id_stack) > 1 && pop!(ctx.id_stack)

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
# Contrôles de base
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
    w = h
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

    if ctx.focus_id == id
        ctx.updated_focus = true
    end

    if hovered && ctx.mouse_pressed
        set_focus!(ctx, id)
    end

    if !hovered && ctx.mouse_pressed && ctx.focus_id == id
        set_focus!(ctx, UInt32(0))
    end

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

    if ctx.focus_id == id && (ctx.cursor_blink % 60) < 30
        tw = ctx.text_width(nothing, buffer[])
        cx = text_x + tw
        draw_text!(ctx, ctx.style.font, "|", vec2(T, cx, text_y), COLOR_TEXT)
    end

    if ctx.focus_id == id && !isempty(ctx.input_buffer)
        buffer[] *= ctx.input_buffer
        ctx.input_buffer = ""
    end

    if ctx.focus_id == id && ctx.key_pressed == :backspace
        buffer[] = isempty(buffer[]) ? "" : buffer[][1:end-1]
    end
end

"""
Slider horizontal pour valeurs numériques avec optimisations.
"""
function slider!(ctx::Context{T}, label::String, value::Base.RefValue{<:Real}, 
                min_val::Real=0.0, max_val::Real=1.0, width::Real=120) where T
    if ctx.current_window === nothing
        return false
    end
    
    id = get_id!(ctx, label)
    
    h = ctx.style.size[2] + ctx.style.padding
    r = next_control_rect(ctx, width, h)
    
    # Zone du track (rail)
    track_rect = rect(T, r.x, r.y + h÷4, r.w, h÷2)
    
    # Calcul de la position du thumb
    normalized_val = (T(value[]) - T(min_val)) / (T(max_val) - T(min_val))
    normalized_val = clamp_value(normalized_val, T(0), T(1))
    
    thumb_size = ctx.style.slider_thumb_size
    thumb_x = r.x + normalized_val * (r.w - thumb_size)
    thumb_rect = rect(T, thumb_x, r.y, thumb_size, h)
    
    hovered = point_in_rect(ctx.mouse_pos, r)
    thumb_hovered = point_in_rect(ctx.mouse_pos, thumb_rect)
    
    # Gestion des interactions
    if (hovered || thumb_hovered) && !ctx.mouse_down
        ctx.hot_id = id
    end
    
    if ctx.hot_id == id && ctx.mouse_pressed
        ctx.active_id = id
        ctx.slider_state.active_slider = id
        ctx.slider_state.start_value = T(value[])
        ctx.slider_state.start_mouse_pos = ctx.mouse_pos[1]
    end
    
    # Mise à jour de la valeur pendant le drag
    changed = false
    if ctx.active_id == id && ctx.mouse_down && ctx.slider_state.active_slider == id
        # Calcul de la nouvelle position relative
        relative_pos = (ctx.mouse_pos[1] - r.x) / r.w
        relative_pos = clamp_value(relative_pos, T(0), T(1))
        
        new_value = T(min_val) + relative_pos * (T(max_val) - T(min_val))
        if new_value != value[]
            value[] = new_value
            changed = true
        end
    end
    
    # Rendu
    draw_rect!(ctx, track_rect, COLOR_SLIDER_TRACK)
    
    # Couleur du thumb basée sur l'état
    thumb_color = if ctx.active_id == id
        COLOR_BUTTON_FOCUS
    elseif ctx.hot_id == id
        COLOR_SLIDER_THUMB
    else
        COLOR_BUTTON
    end
    
    draw_rect!(ctx, thumb_rect, thumb_color)
    
    # Affichage de la valeur (optionnel)
    value_text = string(round(value[], digits=2))
    text_w = ctx.text_width(nothing, value_text)
    text_x = r.x + r.w + ctx.style.spacing
    draw_text!(ctx, ctx.style.font, value_text, 
              vec2(T, text_x, r.y), COLOR_TEXT)
    
    return changed
end

"""
Input numérique avec boutons +/- et saisie directe.
"""
function number_input!(ctx::Context{T}, label::String, value::Base.RefValue{<:Real}, 
                      step::Real=1.0, min_val::Real=-Inf, max_val::Real=Inf, 
                      width::Real=120) where T
    if ctx.current_window === nothing
        return false
    end
    
    push_id!(ctx, label)
    
    h = ctx.style.size[2] + 2 * ctx.style.padding
    button_w = ctx.style.number_input_button_width
    input_w = width - 2 * button_w
    
    total_r = next_control_rect(ctx, width, h)
    
    # Bouton moins (-)
    minus_r = rect(T, total_r.x, total_r.y, button_w, h)
    minus_id = get_id!(ctx, "minus")
    minus_hovered = point_in_rect(ctx.mouse_pos, minus_r)
    minus_pressed = false
    
    if minus_hovered && !ctx.mouse_down
        ctx.hot_id = minus_id
    end
    if ctx.hot_id == minus_id && ctx.mouse_pressed
        ctx.active_id = minus_id
        minus_pressed = true
    end
    
    minus_color = if ctx.active_id == minus_id
        COLOR_BUTTON_FOCUS
    elseif ctx.hot_id == minus_id
        COLOR_BUTTON_HOVER
    else
        COLOR_BUTTON
    end
    
    draw_frame!(ctx, minus_r, minus_color)
    draw_icon!(ctx, ICON_MINUS, minus_r, COLOR_TEXT)
    
    # Zone de saisie du nombre
    input_r = rect(T, total_r.x + button_w, total_r.y, input_w, h)
    input_id = get_id!(ctx, "input")
    input_hovered = point_in_rect(ctx.mouse_pos, input_r)
    
    if input_hovered && ctx.mouse_pressed
        set_focus!(ctx, input_id)
    end
    if !input_hovered && ctx.mouse_pressed && ctx.focus_id == input_id
        set_focus!(ctx, UInt32(0))
    end
    
    input_color = if ctx.focus_id == input_id
        COLOR_NUMBER_INPUT
    elseif input_hovered
        COLOR_BUTTON_HOVER
    else
        COLOR_NUMBER_INPUT
    end
    
    draw_frame!(ctx, input_r, input_color)
    
    # Affichage de la valeur
    value_text = string(value[])
    text_x = input_r.x + ctx.style.padding
    text_y = input_r.y + ctx.style.padding
    draw_text!(ctx, ctx.style.font, value_text, vec2(T, text_x, text_y), COLOR_TEXT)
    
    # Curseur clignotant si focus
    if ctx.focus_id == input_id && (ctx.cursor_blink % 60) < 30
        tw = ctx.text_width(nothing, value_text)
        cx = text_x + tw
        draw_text!(ctx, ctx.style.font, "|", vec2(T, cx, text_y), COLOR_TEXT)
    end
    
    # Bouton plus (+)
    plus_r = rect(T, total_r.x + button_w + input_w, total_r.y, button_w, h)
    plus_id = get_id!(ctx, "plus")
    plus_hovered = point_in_rect(ctx.mouse_pos, plus_r)
    plus_pressed = false
    
    if plus_hovered && !ctx.mouse_down
        ctx.hot_id = plus_id
    end
    if ctx.hot_id == plus_id && ctx.mouse_pressed  
        ctx.active_id = plus_id
        plus_pressed = true
    end
    
    plus_color = if ctx.active_id == plus_id
        COLOR_BUTTON_FOCUS
    elseif ctx.hot_id == plus_id
        COLOR_BUTTON_HOVER
    else
        COLOR_BUTTON
    end
    
    draw_frame!(ctx, plus_r, plus_color)
    draw_icon!(ctx, ICON_PLUS, plus_r, COLOR_TEXT)
    
    # Logique de changement de valeur
    changed = false
    
    if minus_pressed && !ctx.mouse_down
        new_val = value[] - step
        if new_val >= min_val
            value[] = new_val
            changed = true
        end
    end
    
    if plus_pressed && !ctx.mouse_down
        new_val = value[] + step
        if new_val <= max_val
            value[] = new_val
            changed = true
        end
    end
    
    # Gestion saisie directe (simplifié)
    if ctx.focus_id == input_id && !isempty(ctx.input_buffer)
        # Ici on pourrait parser la saisie, pour l'instant on ignore
        ctx.input_buffer = ""
    end
    
    pop_id!(ctx)
    return changed
end

"""
Scrollbar verticale avec thumb proportionnel au contenu.
"""
function scrollbar!(ctx::Context{T}, id_str::String, scroll_value::Base.RefValue{<:Real}, 
                   content_size::Real, visible_size::Real, 
                   x::Real, y::Real, height::Real) where T
    if content_size <= visible_size
        return false # Pas besoin de scrollbar
    end
    
    id = get_id!(ctx, id_str)
    
    # Rectangle de la scrollbar
    sb_w = ctx.style.scrollbar_size
    r = rect(T, x, y, sb_w, height)
    
    # Calcul du thumb
    thumb_ratio = visible_size / content_size
    thumb_height = max(T(20), height * thumb_ratio) # Hauteur minimale de 20px
    
    max_scroll = content_size - visible_size
    scroll_ratio = scroll_value[] / max_scroll
    scroll_ratio = clamp_value(T(scroll_ratio), T(0), T(1))
    
    thumb_y = y + scroll_ratio * (height - thumb_height)
    thumb_r = rect(T, x, thumb_y, sb_w, thumb_height)
    
    hovered = point_in_rect(ctx.mouse_pos, r)
    thumb_hovered = point_in_rect(ctx.mouse_pos, thumb_r)
    
    if (hovered || thumb_hovered) && !ctx.mouse_down
        ctx.hot_id = id
    end
    
    if ctx.hot_id == id && ctx.mouse_pressed
        ctx.active_id = id
    end
    
    # Mise à jour pendant le drag
    changed = false
    if ctx.active_id == id && ctx.mouse_down
        # Calcul de la nouvelle position
        relative_pos = (ctx.mouse_pos[2] - y - thumb_height/2) / (height - thumb_height)
        relative_pos = clamp_value(relative_pos, T(0), T(1))
        
        new_scroll = relative_pos * max_scroll
        if abs(new_scroll - scroll_value[]) > 0.1  # Seuil pour éviter les micro-changements
            scroll_value[] = new_scroll
            changed = true
        end
    end
    
    # Rendu
    draw_rect!(ctx, r, COLOR_SCROLLBAR)
    
    thumb_color = if ctx.active_id == id
        COLOR_BUTTON_FOCUS
    elseif ctx.hot_id == id
        COLOR_BUTTON_HOVER
    else
        COLOR_SCROLLBAR_THUMB
    end
    
    draw_rect!(ctx, thumb_r, thumb_color)
    
    return changed
end

"""
Tree node avec état d'expansion persistant.
"""
function tree_node!(ctx::Context{T}, label::String, expanded::Base.RefValue{Bool}, 
                   level::Int=0) where T
    if ctx.current_window === nothing
        return false
    end
    
    id = get_id!(ctx, label)
    
    # Calcul de l'indentation
    indent = level * ctx.style.tree_indent
    h = ctx.style.size[2] + ctx.style.padding
    icon_size = h
    text_w = ctx.text_width(nothing, label)
    total_w = indent + icon_size + ctx.style.spacing + text_w
    
    r = next_control_rect(ctx, total_w, h)
    
    # Rectangle pour l'icône d'expansion
    icon_r = rect(T, r.x + indent, r.y, icon_size, h)
    
    hovered = point_in_rect(ctx.mouse_pos, icon_r)
    
    if hovered && !ctx.mouse_down
        ctx.hot_id = id
    end
    
    if ctx.hot_id == id && ctx.mouse_pressed
        ctx.active_id = id
        expanded[] = !expanded[]
    end
    
    # Choix de l'icône
    icon = expanded[] ? ICON_EXPANDED : ICON_COLLAPSED
    
    # Couleur basée sur l'état
    icon_color = if ctx.hot_id == id
        COLOR_BUTTON_HOVER
    else
        COLOR_TEXT
    end
    
    # Rendu
    draw_icon!(ctx, icon, icon_r, icon_color)
    
    # Texte du label
    text_x = r.x + indent + icon_size + ctx.style.spacing
    draw_text!(ctx, ctx.style.font, label, vec2(T, text_x, r.y), COLOR_TEXT)
    
    return expanded[]
end

# -----------------------------------------------------------------------------
# Fonctions d'entrée
# -----------------------------------------------------------------------------

@inline input_mousemove!(ctx::Context{T}, x::Real, y::Real) where T = 
    (ctx.mouse_pos = vec2(T, x, y))
@inline input_mousemove!(ctx::Context{T}, pos::Vec2{T}) where T = 
    (ctx.mouse_pos = pos)
@inline input_mousedown!(ctx::Context, x::Real, y::Real, btn::Integer) = 
    (ctx.mouse_down = true; ctx.mouse_pressed = true)
@inline input_mouseup!(ctx::Context, x::Real, y::Real, btn::Integer) = 
    (ctx.mouse_down = false)

@inline function input_scroll!(ctx::Context{T}, x::Real, y::Real) where T
    ctx.scroll_delta = vec2(T, x, y)
    
    # Application automatique du scroll au conteneur actuel si il y en a un
    if ctx.current_window !== nothing
        ctx.current_window.scroll_y = clamp_value(
            ctx.current_window.scroll_y - T(y * 20), # Facteur de scroll
            T(0), ctx.current_window.max_scroll_y
        )
    end
end

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
    println("[RECT] ($(rect.x),$(rect.y),$(rect.w)x$(rect.h)) color=($(color.r),$(color.g),$(color.b))")
end

function buffer_draw_icon!(r::BufferRenderer, icon::UIIcon, rect::Rect, color::Color)
    icon_names = Dict(
        ICON_CLOSE => "×", ICON_CHECK => "✓", ICON_COLLAPSED => "▶",
        ICON_EXPANDED => "▼", ICON_ARROW_UP => "↑", ICON_ARROW_DOWN => "↓",
        ICON_ARROW_LEFT => "←", ICON_ARROW_RIGHT => "→", ICON_MINUS => "−",
        ICON_PLUS => "+"
    )
    symbol = get(icon_names, icon, "?")
    println("[ICON] $symbol @ ($(rect.x),$(rect.y),$(rect.w)x$(rect.h))")
end

function buffer_draw_slider!(r::BufferRenderer, track::Rect, thumb::Rect, track_color::Color, thumb_color::Color)
    println("[SLIDER] track:($(track.x),$(track.y),$(track.w)x$(track.h)) thumb:($(thumb.x),$(thumb.y),$(thumb.w)x$(thumb.h))")
end

# -----------------------------------------------------------------------------
# Fonctions utilitaires restantes
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

# -----------------------------------------------------------------------------
# Fonctions utilitaires pour la sauvegarde (stub pour compatibilité)
# -----------------------------------------------------------------------------
function save_buffer_as_ppm!(renderer::BufferRenderer, filename::String)
    println("[SAVE] Saving buffer to $filename (stub implementation)")
end

end # module