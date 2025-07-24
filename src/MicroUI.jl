"""
MicroUI.jl - Port Julia de la bibliothèque MicroUI
Copyright (c) 2024 - Basé sur MicroUI par rxi

Une bibliothèque d'interface utilisateur immédiate (immediate mode GUI) légère pour Julia.
"""

module MicroUI

export Context, Vec2, Rect, Color, PoolItem, Command, Layout, Container, Style
export mu_vec2, mu_rect, mu_color, mu_init, mu_begin, mu_end
export mu_button, mu_textbox, mu_slider, mu_number, mu_header, mu_begin_treenode
export mu_begin_window, mu_begin_panel, mu_text, mu_label, mu_checkbox
export mu_input_mousemove, mu_input_mousedown, mu_input_mouseup, mu_input_scroll
export mu_input_keydown, mu_input_keyup, mu_input_text
export create_context_with_buffer_renderer, save_buffer_as_ppm

# Constantes
const MU_VERSION = "0.02"
const MU_COMMANDLIST_SIZE = 256 * 1024
const MU_ROOTLIST_SIZE = 32
const MU_CONTAINERSTACK_SIZE = 32
const MU_CLIPSTACK_SIZE = 32
const MU_IDSTACK_SIZE = 32
const MU_LAYOUTSTACK_SIZE = 16
const MU_CONTAINERPOOL_SIZE = 48
const MU_TREENODEPOOL_SIZE = 48
const MU_MAX_WIDTHS = 16
const MU_REAL_FMT = "%.3g"
const MU_SLIDER_FMT = "%.2f"
const MU_MAX_FMT = 127

# Enums
@enum ClipType begin
    MU_CLIP_PART = 1
    MU_CLIP_ALL
end

@enum CommandType begin
    MU_COMMAND_JUMP = 1
    MU_COMMAND_CLIP
    MU_COMMAND_RECT
    MU_COMMAND_TEXT
    MU_COMMAND_ICON
    MU_COMMAND_MAX
end

@enum ColorId begin
    MU_COLOR_TEXT = 1
    MU_COLOR_BORDER
    MU_COLOR_WINDOWBG
    MU_COLOR_TITLEBG
    MU_COLOR_TITLETEXT
    MU_COLOR_PANELBG
    MU_COLOR_BUTTON
    MU_COLOR_BUTTONHOVER
    MU_COLOR_BUTTONFOCUS
    MU_COLOR_BASE
    MU_COLOR_BASEHOVER
    MU_COLOR_BASEFOCUS
    MU_COLOR_SCROLLBASE
    MU_COLOR_SCROLLTHUMB
    MU_COLOR_MAX
end

@enum IconId begin
    MU_ICON_CLOSE = 1
    MU_ICON_CHECK
    MU_ICON_COLLAPSED
    MU_ICON_EXPANDED
    MU_ICON_MAX
end

@enum ResultFlags begin
    MU_RES_ACTIVE = 1 << 0
    MU_RES_SUBMIT = 1 << 1
    MU_RES_CHANGE = 1 << 2
end

@enum OptionFlags begin
    MU_OPT_ALIGNCENTER = 1 << 0
    MU_OPT_ALIGNRIGHT = 1 << 1
    MU_OPT_NOINTERACT = 1 << 2
    MU_OPT_NOFRAME = 1 << 3
    MU_OPT_NORESIZE = 1 << 4
    MU_OPT_NOSCROLL = 1 << 5
    MU_OPT_NOCLOSE = 1 << 6
    MU_OPT_NOTITLE = 1 << 7
    MU_OPT_HOLDFOCUS = 1 << 8
    MU_OPT_AUTOSIZE = 1 << 9
    MU_OPT_POPUP = 1 << 10
    MU_OPT_CLOSED = 1 << 11
    MU_OPT_EXPANDED = 1 << 12
end

@enum MouseButton begin
    MU_MOUSE_LEFT = 1 << 0
    MU_MOUSE_RIGHT = 1 << 1
    MU_MOUSE_MIDDLE = 1 << 2
end

@enum KeyCode begin
    MU_KEY_SHIFT = 1 << 0
    MU_KEY_CTRL = 1 << 1
    MU_KEY_ALT = 1 << 2
    MU_KEY_BACKSPACE = 1 << 3
    MU_KEY_RETURN = 1 << 4
end

# Types de base
const Id = UInt32
const Real = Float32

mutable struct Vec2
    x::Int32
    y::Int32
end

mutable struct Rect
    x::Int32
    y::Int32
    w::Int32
    h::Int32
end

mutable struct Color
    r::UInt8
    g::UInt8
    b::UInt8
    a::UInt8
end

mutable struct PoolItem
    id::Id
    last_update::Int32
end

# Commandes
abstract type BaseCommand end

mutable struct JumpCommand <: BaseCommand
    type::Int32
    size::Int32
    dst::Union{Nothing, Any}
end

mutable struct ClipCommand <: BaseCommand
    type::Int32
    size::Int32
    rect::Rect
end

mutable struct RectCommand <: BaseCommand
    type::Int32
    size::Int32
    rect::Rect
    color::Color
end

mutable struct TextCommand <: BaseCommand
    type::Int32
    size::Int32
    font::Union{Nothing, Any}
    pos::Vec2
    color::Color
    str::String
end

mutable struct IconCommand <: BaseCommand
    type::Int32
    size::Int32
    rect::Rect
    id::Int32
    color::Color
end

const Command = Union{JumpCommand, ClipCommand, RectCommand, TextCommand, IconCommand}

# Stack générique
mutable struct Stack{T}
    idx::Int32
    items::Vector{T}
    
    Stack{T}(n::Int) where T = new{T}(0, Vector{T}(undef, n))
end

function push!(stack::Stack{T}, val::T) where T
    @assert stack.idx < length(stack.items) "Stack overflow"
    stack.idx += 1
    stack.items[stack.idx] = val
end

function pop!(stack::Stack{T}) where T
    @assert stack.idx > 0 "Stack underflow"
    val = stack.items[stack.idx]
    stack.idx -= 1
    return val
end

function peek(stack::Stack{T}) where T
    @assert stack.idx > 0 "Stack empty"
    return stack.items[stack.idx]
end

# Layout
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
    next_type::Int32
    indent::Int32
    
    Layout() = new(
        Rect(0, 0, 0, 0), Rect(0, 0, 0, 0),
        Vec2(0, 0), Vec2(0, 0), Vec2(0, 0),
        zeros(Int32, MU_MAX_WIDTHS),
        0, 0, 0, 0, 0
    )
end

# Container
mutable struct Container
    head::Union{Nothing, Command}
    tail::Union{Nothing, Command}
    rect::Rect
    body::Rect
    content_size::Vec2
    scroll::Vec2
    zindex::Int32
    open::Bool
    
    Container() = new(
        nothing, nothing,
        Rect(0, 0, 0, 0), Rect(0, 0, 0, 0),
        Vec2(0, 0), Vec2(0, 0),
        0, false
    )
end

# Style
mutable struct Style
    font::Union{Nothing, Any}
    size::Vec2
    padding::Int32
    spacing::Int32
    indent::Int32
    title_height::Int32
    scrollbar_size::Int32
    thumb_size::Int32
    colors::Vector{Color}
    
    Style() = new(
        nothing, Vec2(68, 10), 5, 4, 24, 24, 12, 8,
        [
            Color(230, 230, 230, 255), # MU_COLOR_TEXT
            Color(25, 25, 25, 255),    # MU_COLOR_BORDER
            Color(50, 50, 50, 255),    # MU_COLOR_WINDOWBG
            Color(25, 25, 25, 255),    # MU_COLOR_TITLEBG
            Color(240, 240, 240, 255), # MU_COLOR_TITLETEXT
            Color(0, 0, 0, 0),         # MU_COLOR_PANELBG
            Color(75, 75, 75, 255),    # MU_COLOR_BUTTON
            Color(95, 95, 95, 255),    # MU_COLOR_BUTTONHOVER
            Color(115, 115, 115, 255), # MU_COLOR_BUTTONFOCUS
            Color(30, 30, 30, 255),    # MU_COLOR_BASE
            Color(35, 35, 35, 255),    # MU_COLOR_BASEHOVER
            Color(40, 40, 40, 255),    # MU_COLOR_BASEFOCUS
            Color(43, 43, 43, 255),    # MU_COLOR_SCROLLBASE
            Color(30, 30, 30, 255)     # MU_COLOR_SCROLLTHUMB
        ]
    )
end

# Context principal
mutable struct Context
    # Callbacks
    text_width::Union{Nothing, Function}
    text_height::Union{Nothing, Function}
    draw_frame::Union{Nothing, Function}
    
    # État principal
    _style::Style
    style::Style
    hover::Id
    focus::Id
    last_id::Id
    last_rect::Rect
    last_zindex::Int32
    updated_focus::Bool
    frame::Int32
    hover_root::Union{Nothing, Container}
    next_hover_root::Union{Nothing, Container}
    scroll_target::Union{Nothing, Container}
    number_edit_buf::String
    number_edit::Id
    
    # Stacks
    command_list::Stack{UInt8}
    root_list::Stack{Container}
    container_stack::Stack{Container}
    clip_stack::Stack{Rect}
    id_stack::Stack{Id}
    layout_stack::Stack{Layout}
    
    # Pools d'état
    container_pool::Vector{PoolItem}
    containers::Vector{Container}
    treenode_pool::Vector{PoolItem}
    
    # État d'entrée
    mouse_pos::Vec2
    last_mouse_pos::Vec2
    mouse_delta::Vec2
    scroll_delta::Vec2
    mouse_down::Int32
    mouse_pressed::Int32
    key_down::Int32
    key_pressed::Int32
    input_text::String
    
    Context() = new(
        nothing, nothing, nothing,
        Style(), Style(),
        0, 0, 0, Rect(0, 0, 0, 0), 0, false, 0,
        nothing, nothing, nothing,
        "", 0,
        Stack{UInt8}(MU_COMMANDLIST_SIZE),
        Stack{Container}(MU_ROOTLIST_SIZE),
        Stack{Container}(MU_CONTAINERSTACK_SIZE),
        Stack{Rect}(MU_CLIPSTACK_SIZE),
        Stack{Id}(MU_IDSTACK_SIZE),
        Stack{Layout}(MU_LAYOUTSTACK_SIZE),
        [PoolItem(0, 0) for _ in 1:MU_CONTAINERPOOL_SIZE],
        [Container() for _ in 1:MU_CONTAINERPOOL_SIZE],
        [PoolItem(0, 0) for _ in 1:MU_TREENODEPOOL_SIZE],
        Vec2(0, 0), Vec2(0, 0), Vec2(0, 0), Vec2(0, 0),
        0, 0, 0, 0, ""
    )
end

# Fonctions utilitaires
mu_vec2(x::Int, y::Int) = Vec2(x, y)
mu_rect(x::Int, y::Int, w::Int, h::Int) = Rect(x, y, w, h)
mu_color(r::Int, g::Int, b::Int, a::Int) = Color(r, g, b, a)

mu_min(a, b) = a < b ? a : b
mu_max(a, b) = a > b ? a : b
mu_clamp(x, a, b) = mu_min(b, mu_max(a, x))

function expand_rect(rect::Rect, n::Int)
    return mu_rect(rect.x - n, rect.y - n, rect.w + n * 2, rect.h + n * 2)
end

function intersect_rects(r1::Rect, r2::Rect)
    x1 = mu_max(r1.x, r2.x)
    y1 = mu_max(r1.y, r2.y)
    x2 = mu_min(r1.x + r1.w, r2.x + r2.w)
    y2 = mu_min(r1.y + r1.h, r2.y + r2.h)
    x2 = x2 < x1 ? x1 : x2
    y2 = y2 < y1 ? y1 : y2
    return mu_rect(x1, y1, x2 - x1, y2 - y1)
end

function rect_overlaps_vec2(r::Rect, p::Vec2)
    return p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h
end

function default_draw_frame(ctx::Context, rect::Rect, colorid::Int)
    mu_draw_rect(ctx, rect, ctx.style.colors[colorid])
    if colorid == Int(MU_COLOR_SCROLLBASE) ||
       colorid == Int(MU_COLOR_SCROLLTHUMB) ||
       colorid == Int(MU_COLOR_TITLEBG)
        return
    end
    # Dessiner la bordure
    if ctx.style.colors[Int(MU_COLOR_BORDER)].a > 0
        mu_draw_box(ctx, expand_rect(rect, 1), ctx.style.colors[Int(MU_COLOR_BORDER)])
    end
end

# Initialisation
function mu_init(ctx::Context)
    ctx._style = Style()
    ctx.style = ctx._style
    ctx.draw_frame = default_draw_frame
end

function mu_begin(ctx::Context)
    @assert !isnothing(ctx.text_width) && !isnothing(ctx.text_height) "Callbacks text_width et text_height requis"
    ctx.command_list.idx = 0
    ctx.root_list.idx = 0
    ctx.scroll_target = nothing
    ctx.hover_root = ctx.next_hover_root
    ctx.next_hover_root = nothing
    ctx.mouse_delta.x = ctx.mouse_pos.x - ctx.last_mouse_pos.x
    ctx.mouse_delta.y = ctx.mouse_pos.y - ctx.last_mouse_pos.y
    ctx.frame += 1
end

function mu_end(ctx::Context)
    @assert ctx.container_stack.idx == 0 "Stack container non vide"
    @assert ctx.clip_stack.idx == 0 "Stack clip non vide"
    @assert ctx.id_stack.idx == 0 "Stack id non vide"
    @assert ctx.layout_stack.idx == 0 "Stack layout non vide"
    
    # Gérer le scroll
    if !isnothing(ctx.scroll_target)
        ctx.scroll_target.scroll.x += ctx.scroll_delta.x
        ctx.scroll_target.scroll.y += ctx.scroll_delta.y
    end
    
    # Réinitialiser le focus si non utilisé
    if !ctx.updated_focus
        ctx.focus = 0
    end
    ctx.updated_focus = false
    
    # Réinitialiser l'état d'entrée
    ctx.key_pressed = 0
    ctx.input_text = ""
    ctx.mouse_pressed = 0
    ctx.scroll_delta = mu_vec2(0, 0)
    ctx.last_mouse_pos = ctx.mouse_pos
end

# Hash 32bit fnv-1a
const HASH_INITIAL = 2166136261

function hash_bytes(hash_val::Id, data::Vector{UInt8})
    for byte in data
        hash_val = (hash_val ⊻ byte) * 16777619
    end
    return hash_val
end

function mu_get_id(ctx::Context, data::String)
    idx = ctx.id_stack.idx
    res = idx > 0 ? ctx.id_stack.items[idx] : HASH_INITIAL
    res = hash_bytes(res, Vector{UInt8}(data))
    ctx.last_id = res
    return res
end

function mu_push_id(ctx::Context, data::String)
    push!(ctx.id_stack, mu_get_id(ctx, data))
end

function mu_pop_id(ctx::Context)
    pop!(ctx.id_stack)
end

# Gestion des entrées
function mu_input_mousemove(ctx::Context, x::Int, y::Int)
    ctx.mouse_pos = mu_vec2(x, y)
end

function mu_input_mousedown(ctx::Context, x::Int, y::Int, btn::Int)
    mu_input_mousemove(ctx, x, y)
    ctx.mouse_down |= btn
    ctx.mouse_pressed |= btn
end

function mu_input_mouseup(ctx::Context, x::Int, y::Int, btn::Int)
    mu_input_mousemove(ctx, x, y)
    ctx.mouse_down &= ~btn
end

function mu_input_scroll(ctx::Context, x::Int, y::Int)
    ctx.scroll_delta.x += x
    ctx.scroll_delta.y += y
end

function mu_input_keydown(ctx::Context, key::Int)
    ctx.key_pressed |= key
    ctx.key_down |= key
end

function mu_input_keyup(ctx::Context, key::Int)
    ctx.key_down &= ~key
end

function mu_input_text(ctx::Context, text::String)
    ctx.input_text *= text
end

# ============================================================================
# BACKENDS DE RENDU
# ============================================================================

# Backend abstrait
abstract type Renderer end

# Interface commune pour tous les renderers
function setup!(renderer::Renderer, width::Int, height::Int) end
function clear!(renderer::Renderer, color::Color) end
function present!(renderer::Renderer) end
function draw_rect!(renderer::Renderer, rect::Rect, color::Color) end
function draw_text!(renderer::Renderer, text::String, pos::Vec2, color::Color, font=nothing) end
function draw_icon!(renderer::Renderer, icon_id::Int, rect::Rect, color::Color) end
function get_text_width(renderer::Renderer, text::String, font=nothing) end
function get_text_height(renderer::Renderer, font=nothing) end

# ============================================================================
# BUFFER RENDERER (pour tests et rendu en mémoire)
# ============================================================================

mutable struct BufferRenderer <: Renderer
    width::Int
    height::Int
    buffer::Matrix{UInt32}  # ARGB
    font_width::Int
    font_height::Int
    
    BufferRenderer(width::Int, height::Int) = new(width, height, zeros(UInt32, height, width), 6, 10)
end

function setup!(renderer::BufferRenderer, width::Int, height::Int)
    renderer.width = width
    renderer.height = height
    renderer.buffer = zeros(UInt32, height, width)
end

function clear!(renderer::BufferRenderer, color::Color)
    argb = (UInt32(color.a) << 24) | (UInt32(color.r) << 16) | (UInt32(color.g) << 8) | UInt32(color.b)
    fill!(renderer.buffer, argb)
end

function present!(renderer::BufferRenderer)
    # Pour un renderer buffer, on pourrait sauvegarder l'image ou l'afficher
    println("Frame rendered to buffer ($(renderer.width)x$(renderer.height))")
end

function color_to_argb(color::Color)
    return (UInt32(color.a) << 24) | (UInt32(color.r) << 16) | (UInt32(color.g) << 8) | UInt32(color.b)
end

function draw_rect!(renderer::BufferRenderer, rect::Rect, color::Color)
    argb = color_to_argb(color)
    
    # Clipping
    x1 = max(1, rect.x + 1)
    y1 = max(1, rect.y + 1)
    x2 = min(renderer.width, rect.x + rect.w)
    y2 = min(renderer.height, rect.y + rect.h)
    
    if x1 <= x2 && y1 <= y2
        for y in y1:y2
            for x in x1:x2
                renderer.buffer[y, x] = argb
            end
        end
    end
end

function draw_text!(renderer::BufferRenderer, text::String, pos::Vec2, color::Color, font=nothing)
    # Rendu de texte bitmap simple (pixels)
    argb = color_to_argb(color)
    x_pos = pos.x + 1  # Conversion vers indexation base 1
    y_pos = pos.y + 1
    
    for (i, char) in enumerate(text)
        char_x = x_pos + (i - 1) * renderer.font_width
        if char_x >= 1 && char_x + renderer.font_width <= renderer.width &&
           y_pos >= 1 && y_pos + renderer.font_height <= renderer.height
            
            # Dessiner un rectangle simple pour chaque caractère
            for dy in 0:(renderer.font_height-1)
                for dx in 0:(renderer.font_width-2)  # Espacement entre caractères
                    if y_pos + dy <= renderer.height && char_x + dx <= renderer.width
                        # Pattern simple pour simuler du texte
                        if (dx + dy) % 3 == 0  # Pattern arbitraire
                            renderer.buffer[y_pos + dy, char_x + dx] = argb
                        end
                    end
                end
            end
        end
    end
end

function draw_icon!(renderer::BufferRenderer, icon_id::Int, rect::Rect, color::Color)
    argb = color_to_argb(color)
    
    # Dessiner des icônes simples selon l'ID
    x1 = max(1, rect.x + 1)
    y1 = max(1, rect.y + 1)
    x2 = min(renderer.width, rect.x + rect.w)
    y2 = min(renderer.height, rect.y + rect.h)
    
    if x1 <= x2 && y1 <= y2
        center_x = (x1 + x2) ÷ 2
        center_y = (y1 + y2) ÷ 2
        
        if icon_id == Int(MU_ICON_CHECK)
            # Dessiner un checkmark simple
            for i in -2:2
                if center_x + i >= x1 && center_x + i <= x2 && 
                   center_y >= y1 && center_y <= y2
                    renderer.buffer[center_y, center_x + i] = argb
                end
            end
        elseif icon_id == Int(MU_ICON_CLOSE)
            # Dessiner une croix
            for i in -2:2
                if center_x + i >= x1 && center_x + i <= x2 && 
                   center_y + i >= y1 && center_y + i <= y2
                    renderer.buffer[center_y + i, center_x + i] = argb
                    renderer.buffer[center_y - i, center_x + i] = argb
                end
            end
        elseif icon_id == Int(MU_ICON_COLLAPSED)
            # Flèche vers la droite
            for i in 0:3
                if center_x + i >= x1 && center_x + i <= x2
                    for j in -i:i
                        if center_y + j >= y1 && center_y + j <= y2
                            renderer.buffer[center_y + j, center_x + i] = argb
                        end
                    end
                end
            end
        elseif icon_id == Int(MU_ICON_EXPANDED)
            # Flèche vers le bas
            for i in 0:3
                if center_y + i >= y1 && center_y + i <= y2
                    for j in -i:i
                        if center_x + j >= x1 && center_x + j <= x2
                            renderer.buffer[center_y + i, center_x + j] = argb
                        end
                    end
                end
            end
        end
    end
end

function get_text_width(renderer::BufferRenderer, text::String, font=nothing)
    return length(text) * renderer.font_width
end

function get_text_height(renderer::BufferRenderer, font=nothing)
    return renderer.font_height
end

# ============================================================================
# SDL2 RENDERER (nécessite SDL2.jl)
# ============================================================================

# Remarque: Ce code nécessite le package SDL2.jl
# using SDL2

mutable struct SDL2Renderer <: Renderer
    window::Any  # SDL_Window
    renderer::Any  # SDL_Renderer
    width::Int
    height::Int
    font_width::Int
    font_height::Int
    
    SDL2Renderer() = new(nothing, nothing, 800, 600, 8, 12)
end

# Ces fonctions nécessiteraient SDL2.jl installé
function setup_sdl2!(renderer::SDL2Renderer, width::Int, height::Int, title::String="MicroUI Window")
    # Code conceptuel - nécessite SDL2.jl
    error("SDL2Renderer nécessite le package SDL2.jl. Utilisez BufferRenderer pour les tests.")
    
    # # Code qui serait utilisé avec SDL2.jl :
    # SDL.init(SDL.INIT_VIDEO)
    # renderer.window = SDL.create_window(title, 100, 100, width, height, SDL.WINDOW_SHOWN)
    # renderer.renderer = SDL.create_renderer(renderer.window, -1, SDL.RENDERER_ACCELERATED)
    # renderer.width = width
    # renderer.height = height
end

# ============================================================================
# OPENGL RENDERER (nécessite ModernGL.jl)
# ============================================================================

mutable struct OpenGLRenderer <: Renderer
    width::Int
    height::Int
    shader_program::UInt32
    vao::UInt32
    vbo::UInt32
    font_width::Int
    font_height::Int
    
    OpenGLRenderer() = new(800, 600, 0, 0, 0, 8, 12)
end

function setup_opengl!(renderer::OpenGLRenderer, width::Int, height::Int)
    error("OpenGLRenderer nécessite les packages ModernGL.jl et GLFW.jl. Utilisez BufferRenderer pour les tests.")
    
    # # Code conceptuel avec ModernGL.jl :
    # renderer.width = width
    # renderer.height = height
    # 
    # # Vertex shader source
    # vertex_source = """
    # #version 330 core
    # layout (location = 0) in vec2 aPos;
    # layout (location = 1) in vec4 aColor;
    # out vec4 vertexColor;
    # uniform mat4 projection;
    # void main() {
    #     gl_Position = projection * vec4(aPos, 0.0, 1.0);
    #     vertexColor = aColor;
    # }
    # """
    # 
    # # Fragment shader source  
    # fragment_source = """
    # #version 330 core
    # in vec4 vertexColor;
    # out vec4 FragColor;
    # void main() {
    #     FragColor = vertexColor;
    # }
    # """
    # 
    # # Compiler les shaders et créer le programme
    # # ... code de compilation des shaders
end

# ============================================================================
# INTÉGRATION AVEC LE CONTEXTE MICROUI
# ============================================================================

# Fonctions de rendu utilisées par MicroUI
function mu_draw_rect(ctx::Context, rect::Rect, color::Color)
    if hasfield(typeof(ctx), :renderer) && !isnothing(ctx.renderer)
        draw_rect!(ctx.renderer, rect, color)
    else
        println("draw_rect: $(rect.x),$(rect.y) $(rect.w)x$(rect.h) color=$(color.r),$(color.g),$(color.b),$(color.a)")
    end
end

function mu_draw_box(ctx::Context, rect::Rect, color::Color)
    mu_draw_rect(ctx, mu_rect(rect.x + 1, rect.y, rect.w - 2, 1), color)
    mu_draw_rect(ctx, mu_rect(rect.x + 1, rect.y + rect.h - 1, rect.w - 2, 1), color)
    mu_draw_rect(ctx, mu_rect(rect.x, rect.y, 1, rect.h), color)
    mu_draw_rect(ctx, mu_rect(rect.x + rect.w - 1, rect.y, 1, rect.h), color)
end

function mu_draw_text(ctx::Context, font, str::String, pos::Vec2, color::Color)
    if hasfield(typeof(ctx), :renderer) && !isnothing(ctx.renderer)
        draw_text!(ctx.renderer, str, pos, color, font)
    else
        println("draw_text: '$(str)' at $(pos.x),$(pos.y) color=$(color.r),$(color.g),$(color.b),$(color.a)")
    end
end

function mu_draw_icon(ctx::Context, id::Int, rect::Rect, color::Color)
    if hasfield(typeof(ctx), :renderer) && !isnothing(ctx.renderer)
        draw_icon!(ctx.renderer, id, rect, color)
    else
        println("draw_icon: id=$(id) at $(rect.x),$(rect.y) $(rect.w)x$(rect.h)")
    end
end

# Fonction pour attacher un renderer au contexte
function attach_renderer!(ctx::Context, renderer::Renderer)
    # Ajouter le renderer au contexte
    if !hasfield(typeof(ctx), :renderer)
        # Si le contexte n'a pas de champ renderer, on le simule avec un dictionnaire
        if !isdefined(ctx, :_renderer_storage)
            ctx._renderer_storage = Dict{Symbol, Any}()
        end
        ctx._renderer_storage[:renderer] = renderer
    else
        ctx.renderer = renderer
    end
    
    # Configurer les callbacks
    ctx.text_width = (font, text) -> get_text_width(renderer, text, font)
    ctx.text_height = (font) -> get_text_height(renderer, font)
end

# Version modifiée du contexte avec support renderer
mutable struct ContextWithRenderer
    base::Context
    renderer::Union{Nothing, Renderer}
    
    ContextWithRenderer() = new(Context(), nothing)
end

function mu_init(ctx::ContextWithRenderer)
    mu_init(ctx.base)
end

function attach_renderer!(ctx::ContextWithRenderer, renderer::Renderer)
    ctx.renderer = renderer
    ctx.base.text_width = (font, text) -> get_text_width(renderer, text, font)
    ctx.base.text_height = (font) -> get_text_height(renderer, font)
end

# Fonctions de dessin modifiées pour ContextWithRenderer
function mu_draw_rect(ctx::ContextWithRenderer, rect::Rect, color::Color)
    if !isnothing(ctx.renderer)
        draw_rect!(ctx.renderer, rect, color)
    else
        mu_draw_rect(ctx.base, rect, color)
    end
end

function mu_draw_text(ctx::ContextWithRenderer, font, str::String, pos::Vec2, color::Color)
    if !isnothing(ctx.renderer)
        draw_text!(ctx.renderer, str, pos, color, font)
    else
        mu_draw_text(ctx.base, font, str, pos, color)
    end
end

function mu_draw_icon(ctx::ContextWithRenderer, id::Int, rect::Rect, color::Color)
    if !isnothing(ctx.renderer)
        draw_icon!(ctx.renderer, id, rect, color)
    else
        mu_draw_icon(ctx.base, id, rect, color)
    end
end

# Layout
const RELATIVE = 1
const ABSOLUTE = 2

function push_layout(ctx::Context, body::Rect, scroll::Vec2)
    layout = Layout()
    layout.body = mu_rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h)
    layout.max = mu_vec2(-0x1000000, -0x1000000)
    push!(ctx.layout_stack, layout)
    mu_layout_row(ctx, 1, [0], 0)
end

function get_layout(ctx::Context)
    return ctx.layout_stack.items[ctx.layout_stack.idx]
end

function mu_layout_row(ctx::Context, items::Int, widths::Vector{Int}, height::Int)
    layout = get_layout(ctx)
    if !isempty(widths)
        @assert items <= MU_MAX_WIDTHS
        layout.widths[1:items] = widths[1:items]
    end
    layout.items = items
    layout.position = mu_vec2(layout.indent, layout.next_row)
    layout.size.y = height
    layout.item_index = 0
end

function mu_layout_next(ctx::Context)
    layout = get_layout(ctx)
    style = ctx.style
    
    if layout.next_type != 0
        # Gérer le rect défini par mu_layout_set_next
        type = layout.next_type
        layout.next_type = 0
        res = layout.next
        if type == ABSOLUTE
            ctx.last_rect = res
            return res
        end
    else
        # Gérer la ligne suivante
        if layout.item_index == layout.items
            mu_layout_row(ctx, layout.items, Int[], layout.size.y)
        end
        
        # Position
        res = mu_rect(layout.position.x, layout.position.y, 0, 0)
        
        # Taille
        res.w = layout.items > 0 ? layout.widths[layout.item_index + 1] : layout.size.x
        res.h = layout.size.y
        if res.w == 0; res.w = style.size.x + style.padding * 2; end
        if res.h == 0; res.h = style.size.y + style.padding * 2; end
        if res.w < 0; res.w += layout.body.w - res.x + 1; end
        if res.h < 0; res.h += layout.body.h - res.y + 1; end
        
        layout.item_index += 1
        
        # Mettre à jour la position
        layout.position.x += res.w + style.spacing
        layout.next_row = mu_max(layout.next_row, res.y + res.h + style.spacing)
        
        # Appliquer l'offset du body
        res.x += layout.body.x
        res.y += layout.body.y
        
        # Mettre à jour la position max
        layout.max.x = mu_max(layout.max.x, res.x + res.w)
        layout.max.y = mu_max(layout.max.y, res.y + res.h)
        
        ctx.last_rect = res
        return res
    end
end

# Contrôles de base
function mu_text(ctx::Context, text::String)
    font = ctx.style.font
    color = ctx.style.colors[Int(MU_COLOR_TEXT)]
    
    # Layout simple pour le texte
    width = -1
    mu_layout_row(ctx, 1, [width], ctx.text_height !== nothing ? ctx.text_height(font) : 10)
    
    rect = mu_layout_next(ctx)
    mu_draw_text(ctx, font, text, mu_vec2(rect.x, rect.y), color)
end

function mu_label(ctx::Context, text::String)
    rect = mu_layout_next(ctx)
    mu_draw_control_text(ctx, text, rect, Int(MU_COLOR_TEXT), 0)
end

function mu_draw_control_text(ctx::Context, str::String, rect::Rect, colorid::Int, opt::Int)
    font = ctx.style.font
    tw = ctx.text_width !== nothing ? ctx.text_width(font, str) : length(str) * 6
    
    pos_y = rect.y + (rect.h - (ctx.text_height !== nothing ? ctx.text_height(font) : 10)) ÷ 2
    
    if (opt & Int(MU_OPT_ALIGNCENTER)) != 0
        pos_x = rect.x + (rect.w - tw) ÷ 2
    elseif (opt & Int(MU_OPT_ALIGNRIGHT)) != 0
        pos_x = rect.x + rect.w - tw - ctx.style.padding
    else
        pos_x = rect.x + ctx.style.padding
    end
    
    mu_draw_text(ctx, font, str, mu_vec2(pos_x, pos_y), ctx.style.colors[colorid])
end

function mu_button(ctx::Context, label::String)
    return mu_button_ex(ctx, label, 0, Int(MU_OPT_ALIGNCENTER))
end

function mu_button_ex(ctx::Context, label::String, icon::Int, opt::Int)
    res = 0
    id = mu_get_id(ctx, label)
    rect = mu_layout_next(ctx)
    
    # Simulation de mu_update_control et logique de clic
    # (implémentation simplifiée)
    
    # Dessiner
    if !isnothing(ctx.draw_frame)
        ctx.draw_frame(ctx, rect, Int(MU_COLOR_BUTTON))
    end
    
    if !isempty(label)
        mu_draw_control_text(ctx, label, rect, Int(MU_COLOR_TEXT), opt)
    end
    
    if icon != 0
        mu_draw_icon(ctx, icon, rect, ctx.style.colors[Int(MU_COLOR_TEXT)])
    end
    
    return res
end

# Macros pour les contrôles avec paramètres par défaut
macro mu_button(ctx, label)
    :(mu_button_ex($ctx, $label, 0, Int(MU_OPT_ALIGNCENTER)))
end

# ============================================================================
# FONCTIONS DE CONVENANCE ET EXEMPLES
# ============================================================================

# Fonction pour créer un contexte avec renderer
function create_context_with_buffer_renderer(width::Int=800, height::Int=600)
    ctx = ContextWithRenderer()
    renderer = BufferRenderer(width, height)
    
    mu_init(ctx)
    attach_renderer!(ctx, renderer)
    setup!(renderer, width, height)
    
    return ctx, renderer
end

# Délégation des fonctions principales vers le contexte de base
mu_begin(ctx::ContextWithRenderer) = mu_begin(ctx.base)
mu_end(ctx::ContextWithRenderer) = mu_end(ctx.base)
mu_input_mousemove(ctx::ContextWithRenderer, x::Int, y::Int) = mu_input_mousemove(ctx.base, x, y)
mu_input_mousedown(ctx::ContextWithRenderer, x::Int, y::Int, btn::Int) = mu_input_mousedown(ctx.base, x, y, btn)
mu_input_mouseup(ctx::ContextWithRenderer, x::Int, y::Int, btn::Int) = mu_input_mouseup(ctx.base, x, y, btn)
mu_input_scroll(ctx::ContextWithRenderer, x::Int, y::Int) = mu_input_scroll(ctx.base, x, y)
mu_input_keydown(ctx::ContextWithRenderer, key::Int) = mu_input_keydown(ctx.base, key)
mu_input_keyup(ctx::ContextWithRenderer, key::Int) = mu_input_keyup(ctx.base, key)
mu_input_text(ctx::ContextWithRenderer, text::String) = mu_input_text(ctx.base, text)

mu_layout_next(ctx::ContextWithRenderer) = mu_layout_next(ctx.base)
mu_layout_row(ctx::ContextWithRenderer, items::Int, widths::Vector{Int}, height::Int) = mu_layout_row(ctx.base, items, widths, height)

mu_text(ctx::ContextWithRenderer, text::String) = mu_text(ctx.base, text)
mu_label(ctx::ContextWithRenderer, text::String) = mu_label(ctx.base, text)
mu_button(ctx::ContextWithRenderer, label::String) = mu_button(ctx.base, label)
mu_button_ex(ctx::ContextWithRenderer, label::String, icon::Int, opt::Int) = mu_button_ex(ctx.base, label, icon, opt)

# Fonction pour sauvegarder le buffer en tant qu'image simple
function save_buffer_as_ppm(renderer::BufferRenderer, filename::String)
    open(filename, "w") do f
        println(f, "P3")
        println(f, "$(renderer.width) $(renderer.height)")
        println(f, "255")
        
        for y in 1:renderer.height
            for x in 1:renderer.width
                argb = renderer.buffer[y, x]
                r = (argb >> 16) & 0xFF
                g = (argb >> 8) & 0xFF  
                b = argb & 0xFF
                print(f, "$r $g $b ")
            end
            println(f)
        end
    end
    println("Buffer sauvegardé dans $filename")
end

# ============================================================================
# EXEMPLE D'UTILISATION
# ============================================================================

"""
Exemple d'utilisation de MicroUI avec le BufferRenderer

```julia
using MicroUI

# Créer un contexte avec renderer
ctx, renderer = create_context_with_buffer_renderer(800, 600)

# Boucle de rendu simple
function render_frame()
    clear!(renderer, mu_color(50, 50, 50, 255))  # Fond gris foncé
    
    mu_begin(ctx)
    
    # Fenêtre principale
    if mu_begin_window(ctx, "Ma Fenêtre", mu_rect(50, 50, 300, 200)) != 0
        mu_text(ctx, "Hello World from MicroUI.jl!")
        
        if (mu_button(ctx, "Cliquez-moi") & Int(MU_RES_SUBMIT)) != 0
            println("Bouton cliqué!")
        end
        
        mu_label(ctx, "Ceci est un label")
        
        mu_end_window(ctx)
    end
    
    mu_end(ctx)
    present!(renderer)
end

# Rendre une frame
render_frame()

# Sauvegarder le résultat
save_buffer_as_ppm(renderer, "output.ppm")
```
"""

end # module MicroUI