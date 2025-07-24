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
export mu_init, mu_begin, mu_end
export mu_text, mu_label, mu_button, mu_checkbox, mu_input_textbox
export mu_input_mousemove, mu_input_mousedown, mu_input_mouseup
export mu_input_scroll, mu_input_keydown, mu_input_keyup, mu_input_text
export attach_renderer!, create_context_with_buffer_renderer
export BufferRenderer, save_buffer_as_ppm, mu_begin_window, mu_end_window
export mu_layout_row, end_layout_row

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

mutable struct Container
    title::String
    rect::Rect
    open::Bool
    cursor::Vec2
    row_mode::Bool
    row_x::Int32
    row_y::Int32
    row_h::Int32
end

mutable struct Context
    style::Style
    renderer::Any
    mouse_pos::Vec2
    mouse_down::Bool
    mouse_pressed::Bool
    text_width::Function
    text_height::Function
    containers::Dict{String, Container}
    current_window::Union{Nothing, Container}
    hot_id::Int
    active_id::Int
    next_id::Int
    id_counter::Int
    input_buffer::String
    key_pressed::Union{Nothing, Symbol}
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
# Création de contexte + renderer
# -----------------------------------------------------------------------------
function create_context_with_buffer_renderer(w=800, h=600)
    ctx = Context(default_style(), nothing, mu_vec2(0,0), false, false, identity, identity, Dict(), nothing, 0, 0, 0, 1, "", nothing, 0)
    renderer = BufferRenderer(w, h)
    attach_renderer!(ctx, renderer)
    return ctx, renderer
end

# -----------------------------------------------------------------------------
# API principale (mu_begin/mu_end)
# -----------------------------------------------------------------------------
function mu_begin(ctx::Context)
    ctx.mouse_pressed = false
    ctx.current_window = nothing
    ctx.id_counter = 1
    ctx.cursor_blink += 1
end

function mu_end(ctx::Context)
    #ctx.active_id = ctx.mouse_down ? ctx.active_id : 0
    ctx.hot_id = 0
    present!(ctx.renderer)
end

# -----------------------------------------------------------------------------
# Fenêtre + layout horizontal/vertical simple
# -----------------------------------------------------------------------------
function mu_begin_window(ctx::Context, title::String, x::Int=50, y::Int=50, w::Int=200, h::Int=100)
    container = get!(ctx.containers, title) do
        Container(title, mu_rect(x, y, w, h), true,
                  mu_vec2(x + ctx.style.padding, y + ctx.style.padding * 2 + ctx.style.size.y),
                  false, 0, 0, 0)
    end
    container.cursor = mu_vec2(container.rect.x + ctx.style.padding,
                               container.rect.y + ctx.style.padding * 2 + ctx.style.size.y)
    container.row_mode = false
    ctx.current_window = container
    draw_rect!(ctx.renderer, container.rect, ctx.style.colors[:window])
    titlebar = mu_rect(container.rect.x, container.rect.y, container.rect.w, ctx.style.size.y + ctx.style.padding * 2)
    draw_rect!(ctx.renderer, titlebar, ctx.style.colors[:titlebg])
    draw_text!(ctx.renderer, title, mu_vec2(titlebar.x + ctx.style.padding, titlebar.y + ctx.style.padding), ctx.style.colors[:titletext], ctx.style.font)
end

mu_end_window(ctx::Context) = (ctx.current_window = nothing)

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
    id = ctx.id_counter
    ctx.id_counter += 1

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
    id = ctx.id_counter
    ctx.id_counter += 1

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

function mu_input_textbox(ctx::Context, buffer::Base.RefValue{String}, width::Int=200)
    id = ctx.id_counter
    ctx.id_counter += 1

    h = get_text_height(ctx.renderer, nothing) + 2 * ctx.style.padding
    r = next_control_rect(ctx, width, h)
    hovered = ctx.mouse_pos.x >= r.x && ctx.mouse_pos.x <= r.x + r.w &&
              ctx.mouse_pos.y >= r.y && ctx.mouse_pos.y <= r.y + r.h

    if hovered
        ctx.hot_id = id
        if ctx.mouse_pressed
            ctx.active_id = id
        end
    end

    bg = ctx.style.colors[:button]
    if ctx.active_id == id
        bg = ctx.style.colors[:button_focus]
    elseif ctx.hot_id == id
        bg = ctx.style.colors[:button_hover]
    end

    draw_rect!(ctx.renderer, r, bg)

    text_x = r.x + ctx.style.padding
    text_y = r.y + ctx.style.padding
    draw_text!(ctx.renderer, buffer[], mu_vec2(text_x, text_y), ctx.style.colors[:text], nothing)

    # curseur clignotant si focus
    if ctx.active_id == id && (ctx.cursor_blink % 60) < 30
        tw = get_text_width(ctx.renderer, buffer[], nothing)
        cx = text_x + tw
        draw_text!(ctx.renderer, "|", mu_vec2(cx, text_y), ctx.style.colors[:text], nothing)
    end

    # gestion entrée texte
    if ctx.active_id == id && !isempty(ctx.input_buffer)
        buffer[] *= ctx.input_buffer
        ctx.input_buffer = ""
    end

    # gestion touche retour arrière
    if ctx.active_id == id && ctx.key_pressed == :backspace
        buffer[] = isempty(buffer[]) ? "" : buffer[][1:end-1]
        ctx.key_pressed = nothing
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

# Ajouté au contexte pour capturer l'entrée texte
function create_context_with_buffer_renderer(w=800, h=600)
    ctx = Context(default_style(), nothing, mu_vec2(0,0), false, false, identity, identity, Dict(), nothing, 0, 0, 0, 1, "", nothing, 0)
    ctx.input_buffer = ""
    ctx.key_pressed = nothing
    ctx.cursor_blink = 0
    renderer = BufferRenderer(w, h)
    attach_renderer!(ctx, renderer)
    return ctx, renderer
end

end # module