module MicroUI

export Context, Vec2, Rect, Color, Font
export init!, begin_frame, end_frame, set_focus!, get_id, push_id!, pop_id!
export push_clip_rect!, pop_clip_rect!, get_clip_rect, check_clip, expand_rect
export input_mousemove!, input_mousedown!, input_mouseup!, input_scroll!
export input_keydown!, input_keyup!, input_text!
export draw_rect!, draw_box!, draw_text!, draw_icon!, intersect_rects
export layout_row!, layout_width!, layout_height!, layout_begin_column!, layout_end_column!
export layout_set_next!, layout_next, get_current_container
export text, label, button, button_ex, checkbox!, textbox!, textbox_ex!
export slider!, slider_ex!, number!, number_ex!, header, header_ex
export begin_treenode, begin_treenode_ex, end_treenode
export begin_window, begin_window_ex, end_window
export open_popup!, begin_popup, end_popup
export begin_panel, begin_panel_ex, end_panel

# Constants
const VERSION = "0.4.0"
const COMMANDLIST_SIZE = 256 * 1024
const ROOTLIST_SIZE = 32
const CONTAINERSTACK_SIZE = 32
const CLIPSTACK_SIZE = 32
const IDSTACK_SIZE = 32
const LAYOUTSTACK_SIZE = 16
const CONTAINERPOOL_SIZE = 48
const TREENODEPOOL_SIZE = 48
const MAX_WIDTHS = 16
const MAX_FMT = 127

# Enums using Julia's @enum
@enum ClipResult::UInt8 begin
    CLIP_NONE = 0
    CLIP_PART = 1
    CLIP_ALL = 2
end

@enum CommandType::UInt8 begin
    COMMAND_JUMP = 1
    COMMAND_CLIP = 2
    COMMAND_RECT = 3
    COMMAND_TEXT = 4
    COMMAND_ICON = 5
end

@enum ColorId::UInt8 begin
    COLOR_TEXT = 1
    COLOR_BORDER = 2
    COLOR_WINDOWBG = 3
    COLOR_TITLEBG = 4
    COLOR_TITLETEXT = 5
    COLOR_PANELBG = 6
    COLOR_BUTTON = 7
    COLOR_BUTTONHOVER = 8
    COLOR_BUTTONFOCUS = 9
    COLOR_BASE = 10
    COLOR_BASEHOVER = 11
    COLOR_BASEFOCUS = 12
    COLOR_SCROLLBASE = 13
    COLOR_SCROLLTHUMB = 14
end

@enum IconId::UInt8 begin
    ICON_CLOSE = 1
    ICON_CHECK = 2
    ICON_COLLAPSED = 3
    ICON_EXPANDED = 4
end

@enum MouseButton::UInt8 begin
    MOUSE_LEFT = 1 << 0
    MOUSE_RIGHT = 1 << 1
    MOUSE_MIDDLE = 1 << 2
end

@enum Key::UInt8 begin
    KEY_SHIFT = 1 << 0
    KEY_CTRL = 1 << 1
    KEY_ALT = 1 << 2
    KEY_BACKSPACE = 1 << 3
    KEY_RETURN = 1 << 4
end

@enum Option::UInt16 begin
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

@enum Result::UInt8 begin
    RES_ACTIVE = 1 << 0
    RES_SUBMIT = 1 << 1
    RES_CHANGE = 1 << 2
end

# Type aliases
const Id = UInt32
const Real = Float32
const Font = Any  # User-defined font type

# Basic structures
struct Vec2
    x::Int64
    y::Int64

    Vec2(x::Int32, y::Int32) = new(Int64(x), Int64(y))
    Vec2(x::Int64, y::Int64) = new(Int64(x), Int64(y))
    Vec2(x::Int32, y::Int64) = new(Int64(x), Int64(y))
    Vec2(x::Int64, y::Int32) = new(Int64(x), Int64(y))
end

struct Rect
    x::Int32
    y::Int32
    w::Int32
    h::Int32
end

struct Color
    r::UInt8
    g::UInt8
    b::UInt8
    a::UInt8
end

mutable struct PoolItem
    id::Id
    last_update::Int32
end

# Commands - Using Julia's type system for better performance
abstract type Command end

struct JumpCommand <: Command
    type::CommandType
    size::Int32
    dst::Ptr{UInt8}
end

struct ClipCommand <: Command
    type::CommandType
    size::Int32
    rect::Rect
end

struct RectCommand <: Command
    type::CommandType
    size::Int32
    rect::Rect
    color::Color
end

struct TextCommand <: Command
    type::CommandType
    size::Int32
    font::Font
    pos::Vec2
    color::Color
    str::String  # Julia strings are more efficient than C strings
end

struct IconCommand <: Command
    type::CommandType
    size::Int32
    rect::Rect
    id::IconId
    color::Color
end

# Layout structure
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
    control_count::Int32
end

# Container structure
mutable struct Container
    head::Union{Nothing, Ptr{Command}}
    tail::Union{Nothing, Ptr{Command}}
    rect::Rect
    body::Rect
    content_size::Vec2
    scroll::Vec2
    zindex::Int32
    open::Bool
end

# Style structure with sensible defaults
struct Style
    font::Font
    size::Vec2
    padding::Int32
    spacing::Int32
    indent::Int32
    title_height::Int32
    scrollbar_size::Int32
    thumb_size::Int32
    colors::Vector{Color}
end

# Stack implementation using Julia's type system
mutable struct Stack{T, N}
    items::Vector{T}
    idx::Int32
    
    Stack{T, N}() where {T, N} = new(Vector{T}(undef, N), 0)
end

function push!(s::Stack{T, N}, val::T) where {T, N}
    s.idx < N || error("Stack overflow")
    s.idx += 1
    s.items[s.idx] = val
end

function pop!(s::Stack)
    s.idx > 0 || error("Stack underflow")
    s.idx -= 1
end

function Base.isempty(s::Stack)
    s.idx == 0
end

function top(s::Stack)
    s.idx > 0 || error("Stack is empty")
    s.items[s.idx]
end

# Main context structure
mutable struct Context
    # Callbacks
    text_width::Function
    text_height::Function
    draw_frame::Function
    
    # Core state
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
    command_list::Vector{UInt8}
    command_idx::Int32
    root_list::Stack{Container, ROOTLIST_SIZE}
    container_stack::Stack{Container, CONTAINERSTACK_SIZE}
    clip_stack::Stack{Rect, CLIPSTACK_SIZE}
    id_stack::Stack{Id, IDSTACK_SIZE}
    layout_stack::Stack{Layout, LAYOUTSTACK_SIZE}
    
    # Pools
    container_pool::Vector{PoolItem}
    containers::Vector{Container}
    treenode_pool::Vector{PoolItem}
    
    # Input state
    mouse_pos::Vec2
    last_mouse_pos::Vec2
    mouse_delta::Vec2
    scroll_delta::Vec2
    mouse_down::UInt8
    mouse_pressed::UInt8
    key_down::UInt8
    key_pressed::UInt8
    input_text::String
end

# Default style
const DEFAULT_STYLE = Style(
    nothing,  # font
    Vec2(68, 10),  # size
    5,  # padding
    4,  # spacing
    24, # indent
    24, # title_height
    12, # scrollbar_size
    8,  # thumb_size
    [
        Color(230, 230, 230, 255), # TEXT
        Color(25, 25, 25, 255),    # BORDER
        Color(50, 50, 50, 255),    # WINDOWBG
        Color(25, 25, 25, 255),    # TITLEBG
        Color(240, 240, 240, 255), # TITLETEXT
        Color(0, 0, 0, 0),         # PANELBG
        Color(75, 75, 75, 255),    # BUTTON
        Color(95, 95, 95, 255),    # BUTTONHOVER
        Color(115, 115, 115, 255), # BUTTONFOCUS
        Color(30, 30, 30, 255),    # BASE
        Color(35, 35, 35, 255),    # BASEHOVER
        Color(40, 40, 40, 255),    # BASEFOCUS
        Color(43, 43, 43, 255),    # SCROLLBASE
        Color(30, 30, 30, 255),    # SCROLLTHUMB
    ]
)

# Utility functions
clamp(x, a, b) = max(a, min(b, x))

function expand_rect(r::Rect, n::Int32)
    Rect(r.x - n, r.y - n, r.w + n * 2, r.h + n * 2)
end

function intersect_rects(r1::Rect, r2::Rect)
    x1 = max(r1.x, r2.x)
    y1 = max(r1.y, r2.y)
    x2 = min(r1.x + r1.w, r2.x + r2.w)
    y2 = min(r1.y + r1.h, r2.y + r2.h)
    x2 = max(x2, x1)
    y2 = max(y2, y1)
    Rect(x1, y1, x2 - x1, y2 - y1)
end

function rect_overlaps_vec2(r::Rect, p::Vec2)
    p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h
end

# Default draw frame function
function default_draw_frame(ctx::Context, rect::Rect, colorid::ColorId)
    draw_rect!(ctx, rect, ctx.style.colors[Int(colorid)])
    if colorid == COLOR_SCROLLBASE || colorid == COLOR_SCROLLTHUMB || colorid == COLOR_TITLEBG
        return
    end
    # Draw border
    if ctx.style.colors[Int(COLOR_BORDER)].a > 0
        draw_box!(ctx, expand_rect(rect, Int32(1)), ctx.style.colors[Int(COLOR_BORDER)])
    end
end

# Initialize context
function init!(ctx::Context)
    ctx.text_width = (font, str) -> length(str) * 8  # Default implementation
    ctx.text_height = font -> 16  # Default implementation
    ctx.draw_frame = default_draw_frame
    ctx.style = DEFAULT_STYLE
    ctx.hover = 0
    ctx.focus = 0
    ctx.last_id = 0
    ctx.last_rect = Rect(0, 0, 0, 0)
    ctx.last_zindex = 0
    ctx.updated_focus = false
    ctx.frame = 0
    ctx.hover_root = nothing
    ctx.next_hover_root = nothing
    ctx.scroll_target = nothing
    ctx.number_edit_buf = ""
    ctx.number_edit = 0
    
    # Initialize stacks
    ctx.command_list = Vector{UInt8}(undef, COMMANDLIST_SIZE)
    ctx.command_idx = 0
    ctx.root_list = Stack{Container, ROOTLIST_SIZE}()
    ctx.container_stack = Stack{Container, CONTAINERSTACK_SIZE}()
    ctx.clip_stack = Stack{Rect, CLIPSTACK_SIZE}()
    ctx.id_stack = Stack{Id, IDSTACK_SIZE}()
    ctx.layout_stack = Stack{Layout, LAYOUTSTACK_SIZE}()
    
    # Initialize pools
    ctx.container_pool = [PoolItem(0, 0) for _ in 1:CONTAINERPOOL_SIZE]
    ctx.containers = [Container(nothing, nothing, Rect(0,0,0,0), Rect(0,0,0,0), 
                                Vec2(0,0), Vec2(0,0), 0, false) for _ in 1:CONTAINERPOOL_SIZE]
    ctx.treenode_pool = [PoolItem(0, 0) for _ in 1:TREENODEPOOL_SIZE]
    
    # Initialize input state
    ctx.mouse_pos = Vec2(0, 0)
    ctx.last_mouse_pos = Vec2(0, 0)
    ctx.mouse_delta = Vec2(0, 0)
    ctx.scroll_delta = Vec2(0, 0)
    ctx.mouse_down = 0
    ctx.mouse_pressed = 0
    ctx.key_down = 0
    ctx.key_pressed = 0
    ctx.input_text = ""
end

# Constructor with initialization
function Context()
    ctx = Context(
        identity, identity, default_draw_frame,
        DEFAULT_STYLE,
        0, 0, 0, Rect(0,0,0,0), 0, false, 0,
        nothing, nothing, nothing,
        "", 0,
        Vector{UInt8}(undef, COMMANDLIST_SIZE), 0,
        Stack{Container, ROOTLIST_SIZE}(),
        Stack{Container, CONTAINERSTACK_SIZE}(),
        Stack{Rect, CLIPSTACK_SIZE}(),
        Stack{Id, IDSTACK_SIZE}(),
        Stack{Layout, LAYOUTSTACK_SIZE}(),
        Vector{PoolItem}(undef, CONTAINERPOOL_SIZE),
        Vector{Container}(undef, CONTAINERPOOL_SIZE),
        Vector{PoolItem}(undef, TREENODEPOOL_SIZE),
        Vec2(0,0), Vec2(0,0), Vec2(0,0), Vec2(0,0),
        0, 0, 0, 0, ""
    )
    init!(ctx)
    return ctx
end

# Frame management
function begin_frame(ctx::Context)
    ctx.command_idx = 0
    empty!(ctx.command_list)
    ctx.root_list.idx = 0
    ctx.scroll_target = nothing
    ctx.hover_root = ctx.next_hover_root
    ctx.next_hover_root = nothing
    ctx.mouse_delta = Vec2(ctx.mouse_pos.x - ctx.last_mouse_pos.x,
                          ctx.mouse_pos.y - ctx.last_mouse_pos.y)
    ctx.frame += 1
end

function end_frame(ctx::Context)
    # Check stacks are empty
    @assert ctx.container_stack.idx == 0 "Container stack not empty"
    @assert ctx.clip_stack.idx == 0 "Clip stack not empty"
    @assert ctx.id_stack.idx == 0 "ID stack not empty"
    @assert ctx.layout_stack.idx == 0 "Layout stack not empty"
    
    # Handle scroll input
    if ctx.scroll_target !== nothing
        ctx.scroll_target.scroll = Vec2(
            ctx.scroll_target.scroll.x + ctx.scroll_delta.x,
            ctx.scroll_target.scroll.y + ctx.scroll_delta.y
        )
    end
    
    # Unset focus if not touched this frame
    if !ctx.updated_focus
        ctx.focus = 0
    end
    ctx.updated_focus = false
    
    # Bring hover root to front if mouse pressed
    if ctx.mouse_pressed != 0 && ctx.next_hover_root !== nothing &&
       ctx.next_hover_root.zindex < ctx.last_zindex && ctx.next_hover_root.zindex >= 0
        bring_to_front!(ctx, ctx.next_hover_root)
    end
    
    # Reset input state
    ctx.key_pressed = 0
    ctx.input_text = ""
    ctx.mouse_pressed = 0
    ctx.scroll_delta = Vec2(0, 0)
    ctx.last_mouse_pos = ctx.mouse_pos
    
    # Sort root containers by zindex
    if ctx.root_list.idx > 0
        sort!(view(ctx.root_list.items, 1:ctx.root_list.idx), by = c -> c.zindex)
    end

end

# ID generation using FNV-1a hash
const HASH_INITIAL = 0x811c9dc5

function hash_bytes(h::UInt32, data::Vector{UInt8})
    for byte in data
        h = (h ⊻ byte) * 0x01000193
    end
    return h
end

function format_number(value, decimal_places)
    rounded_value = round(value, digits=decimal_places)
    str_value = string(rounded_value)
    decimal_index = findfirst('.', str_value)
    if decimal_index === nothing
        str_value *= "." * "0"^decimal_places
    else
        current_decimals = length(str_value) - decimal_index
        if current_decimals <= decimal_places
            str_value *= "0"^(decimal_places - (current_decimals - 1))
        end
    end
    return str_value
end

function get_id(ctx::Context, str::AbstractString)
    h = ctx.id_stack.idx > 0 ? top(ctx.id_stack) : HASH_INITIAL
    # Hasher directement sans allocation Vector
    for byte in codeunits(str)
        h = (h ⊻ byte) * 0x01000193
    end
    ctx.last_id = h
    return h
end

function get_id(ctx::Context, data::Tuple)
    base_hash = ctx.id_stack.idx > 0 ? UInt64(top(ctx.id_stack)) : UInt64(HASH_INITIAL)

    # Inclure la position du contrôle dans le layout
    if ctx.layout_stack.idx > 0
        layout = get_layout(ctx)
        # Inclure la position séquentielle dans l'ID
        data_with_pos = (data..., layout.control_count)
        h = hash(data_with_pos, base_hash)
        layout.control_count += 1  # Incrémenter pour le prochain contrôle
    else
        h = hash(data, base_hash)
    end

    # Convertir en UInt32 pour notre système d'ID
    ctx.last_id = UInt32(h & 0xffffffff)  # Garder seulement les 32 bits bas
    return ctx.last_id
end

function get_id(ctx::Context, data::Vector{UInt8})
    h = ctx.id_stack.idx > 0 ? top(ctx.id_stack) : HASH_INITIAL
    h = hash_bytes(h, data)
    ctx.last_id = h
    return h
end

function get_id(ctx::Context, ptr::Ptr, size::Int)
    data = unsafe_wrap(Vector{UInt8}, Ptr{UInt8}(ptr), size)
    get_id(ctx, data)
end

function get_id(ctx::Context, buf::Ref{String})
    ptr = pointer_from_objref(buf)
    get_id(ctx, [reinterpret(UInt8, [ptr])...])
end

# Stack operations
function push_id!(ctx::Context, data)
    push!(ctx.id_stack, get_id(ctx, data))
end

function pop_id!(ctx::Context)
    pop!(ctx.id_stack)
end

function push_clip_rect!(ctx::Context, rect::Rect)
    last = get_clip_rect(ctx)
    push!(ctx.clip_stack, intersect_rects(rect, last))
end

function pop_clip_rect!(ctx::Context)
    pop!(ctx.clip_stack)
end

function get_clip_rect(ctx::Context)
    default = ctx.clip_stack.idx == 0 ? Rect(0, 0, typemax(Int32), typemax(Int32)) : top(ctx.clip_stack)
    return default
end

function check_clip(ctx::Context, r::Rect)
    cr = get_clip_rect(ctx)
    if cr.w == typemax(Int32) && cr.h == typemax(Int32)
        # Pas de clipping nécessaire
        return CLIP_NONE
    end
    if r.x > cr.x + cr.w || r.x + r.w < cr.x ||
       r.y > cr.y + cr.h || r.y + r.h < cr.y
        return CLIP_ALL
    end
    if r.x >= cr.x && r.x + r.w <= cr.x + cr.w &&
       r.y >= cr.y && r.y + r.h <= cr.y + cr.h
        return CLIP_NONE
    end
    return CLIP_PART
end

# Container management
function get_current_container(ctx::Context)
    ctx.container_stack.idx > 0 || error("No active container")
    top(ctx.container_stack)
end

function bring_to_front!(ctx::Context, cnt::Container)
    ctx.last_zindex += 1
    cnt.zindex = ctx.last_zindex
end

# Pool management
function pool_init!(ctx::Context, items::Vector{PoolItem}, id::Id)
    n = -1
    f = ctx.frame
    for i in 1:length(items)
        if items[i].last_update < f
            f = items[i].last_update
            n = i
        end
    end
    n > 0 || error("Pool full")
    items[n].id = id
    pool_update!(ctx, items, n)
    return n
end

function pool_get(ctx::Context, items::Vector{PoolItem}, id::Id)
    for i in 1:length(items)
        if items[i].id == id
            return i
        end
    end
    return -1
end

function pool_update!(ctx::Context, items::Vector{PoolItem}, idx::Int)
    items[idx].last_update = ctx.frame
end

# Input handlers
function input_mousemove!(ctx::Context, x::Int, y::Int)
    ctx.mouse_pos = Vec2(Int32(x), Int32(y))
end

function input_mousedown!(ctx::Context, x::Int, y::Int, btn::MouseButton)
    input_mousemove!(ctx, x, y)
    ctx.mouse_down |= UInt8(btn)
    ctx.mouse_pressed |= UInt8(btn)
end

function input_mouseup!(ctx::Context, x::Int, y::Int, btn::MouseButton)
    input_mousemove!(ctx, x, y)
    ctx.mouse_down &= ~UInt8(btn)
end

function input_scroll!(ctx::Context, x::Int, y::Int)
    ctx.scroll_delta = Vec2(ctx.scroll_delta.x + Int32(x), ctx.scroll_delta.y + Int32(y))
end

function input_keydown!(ctx::Context, key::Key)
    ctx.key_pressed |= UInt8(key)
    ctx.key_down |= UInt8(key)
end

function input_keyup!(ctx::Context, key::Key)
    ctx.key_down &= ~UInt8(key)
end

function input_text!(ctx::Context, text::String)
    ctx.input_text *= text
end

# Command buffer management (simplified for Julia)
function push_command!(ctx::Context, cmd::Command)
    # In Julia, we'll store commands differently than C
    # This is a simplified version - in production, you'd optimize this
    ctx.command_idx += 1
    return cmd
end

# Drawing commands
function set_clip!(ctx::Context, rect::Rect)
    push_command!(ctx, ClipCommand(COMMAND_CLIP, sizeof(ClipCommand), rect))
end

function draw_rect!(ctx::Context, rect::Rect, color::Color)
    rect = intersect_rects(rect, get_clip_rect(ctx))
    if rect.w > 0 && rect.h > 0
        push_command!(ctx, RectCommand(COMMAND_RECT, sizeof(RectCommand), rect, color))
    end
end

function draw_box!(ctx::Context, rect::Rect, color::Color)
    draw_rect!(ctx, Rect(rect.x + 1, rect.y, rect.w - 2, 1), color)
    draw_rect!(ctx, Rect(rect.x + 1, rect.y + rect.h - 1, rect.w - 2, 1), color)
    draw_rect!(ctx, Rect(rect.x, rect.y, 1, rect.h), color)
    draw_rect!(ctx, Rect(rect.x + rect.w - 1, rect.y, 1, rect.h), color)
end

function draw_text!(ctx::Context, font::Font, str::String, pos::Vec2, color::Color)
    rect = Rect(pos.x, pos.y, 
                Int32(ctx.text_width(font, str)), 
                Int32(ctx.text_height(font)))
    clipped = check_clip(ctx, rect)
    if clipped == CLIP_ALL
        return
    end
    if clipped == CLIP_PART
        set_clip!(ctx, get_clip_rect(ctx))
    end
    
    push_command!(ctx, TextCommand(COMMAND_TEXT, sizeof(TextCommand), font, pos, color, str))
    
    if clipped != CLIP_NONE
        set_clip!(ctx, Rect(0, 0, typemax(Int32), typemax(Int32)))
    end
end

function draw_icon!(ctx::Context, id::IconId, rect::Rect, color::Color)
    clipped = check_clip(ctx, rect)
    if clipped == CLIP_ALL
        return
    end
    if clipped == CLIP_PART
        set_clip!(ctx, get_clip_rect(ctx))
    end
    
    push_command!(ctx, IconCommand(COMMAND_ICON, sizeof(IconCommand), rect, id, color))
    
    if clipped != CLIP_NONE
        set_clip!(ctx, Rect(0, 0, typemax(Int32), typemax(Int32)))
    end
end

# Layout management
function push_layout!(ctx::Context, body::Rect, scroll::Vec2)
    layout = Layout(
        Rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h),
        Rect(0, 0, 0, 0),
        Vec2(0, 0),
        Vec2(0, 0),
        Vec2(typemin(Int32), typemin(Int32)),
        zeros(Int32, MAX_WIDTHS),
        0, 0, 0, 0, 0, 0
    )
    push!(ctx.layout_stack, layout)
    layout_row!(ctx, 1, [0], 0)
end

function get_layout(ctx::Context)
    ctx.layout_stack.idx > 0 || error("No active layout")
    top(ctx.layout_stack)
end

function layout_row!(ctx::Context, items::Int, widths::Union{Nothing, Vector{Int}}, height::Int)
    layout = get_layout(ctx)
    if widths !== nothing
        @assert items <= MAX_WIDTHS "Too many items"
        for i in 1:items
            layout.widths[i] = Int32(widths[i])
        end
    end
    layout.items = Int32(items)
    layout.position = Vec2(layout.indent, layout.next_row)
    layout.size = Vec2(layout.size.x, Int32(height))
    layout.item_index = 0
end

function layout_width!(ctx::Context, width::Int)
    get_layout(ctx).size = Vec2(Int32(width), get_layout(ctx).size.y)
end

function layout_height!(ctx::Context, height::Int)
    get_layout(ctx).size = Vec2(get_layout(ctx).size.x, Int32(height))
end

function layout_set_next!(ctx::Context, r::Rect, relative::Bool)
    layout = get_layout(ctx)
    layout.next = r
    layout.next_type = relative ? 1 : 2
end

function layout_next(ctx::Context)
    layout = get_layout(ctx)
    style = ctx.style
    
    if layout.next_type != 0
        type = layout.next_type
        layout.next_type = 0
        res = layout.next
        if type == 2  # ABSOLUTE
            ctx.last_rect = res
            return res
        end
    else
        # Handle next row
        if layout.item_index == layout.items
            layout_row!(ctx, Int(layout.items), nothing, Int(layout.size.y))
        end
        
        # Calculate position and size
        res = Rect(layout.position.x, layout.position.y, 0, 0)
        
        # Width
        if layout.items > 0
            res = Rect(res.x, res.y, layout.widths[layout.item_index + 1], res.h)
        else
            res = Rect(res.x, res.y, layout.size.x, res.h)
        end
        
        if res.w == 0
            res = Rect(res.x, res.y, style.size.x + style.padding * 2, res.h)
        elseif res.w < 0
            res = Rect(res.x, res.y, res.w + layout.body.w - res.x + 1, res.h)
        end
        
        # Height
        res = Rect(res.x, res.y, res.w, layout.size.y)
        if res.h == 0
            res = Rect(res.x, res.y, res.w, style.size.y + style.padding * 2)
        elseif res.h < 0
            res = Rect(res.x, res.y, res.w, res.h + layout.body.h - res.y + 1)
        end
        
        layout.item_index += 1
    end
    
    # Update position
    layout.position = Vec2(layout.position.x + res.w + style.spacing, layout.position.y)
    layout.next_row = max(layout.next_row, res.y + res.h + style.spacing)
    
    # Apply body offset
    res = Rect(res.x + layout.body.x, res.y + layout.body.y, res.w, res.h)
    
    # Update max
    layout.max = Vec2(max(layout.max.x, res.x + res.w),
                     max(layout.max.y, res.y + res.h))
    
    ctx.last_rect = res
    return res
end

function layout_begin_column!(ctx::Context)
    push_layout!(ctx, layout_next(ctx), Vec2(0, 0))
end

function layout_end_column!(ctx::Context)
    b = get_layout(ctx)
    pop!(ctx.layout_stack)
    a = get_layout(ctx)
    
    # Inherit position/next_row/max from child layout
    a.position = Vec2(max(a.position.x, b.position.x + b.body.x - a.body.x),
                     a.position.y)
    a.next_row = max(a.next_row, b.next_row + b.body.y - a.body.y)
    a.max = Vec2(max(a.max.x, b.max.x), max(a.max.y, b.max.y))
end

# Control helpers
function in_hover_root(ctx::Context)
    i = ctx.container_stack.idx
    result = false
    
    while i > 0
        if ctx.container_stack.items[i] === ctx.hover_root
            result = true
            break
        end
        # Stop at root container
        if ctx.container_stack.items[i].head !== nothing
            break
        end
        i -= 1
    end
    
    return result
end

function draw_control_frame!(ctx::Context, id::Id, rect::Rect, colorid::ColorId, opt::UInt16)
    if (opt & UInt16(OPT_NOFRAME)) != 0
        return
    end
    color_idx = Int(colorid)
    if ctx.focus == id
        color_idx += 2
    elseif ctx.hover == id
        color_idx += 1
    end
    ctx.draw_frame(ctx, rect, ColorId(color_idx))
end

function draw_control_text!(ctx::Context, str::String, rect::Rect, colorid::ColorId, opt::UInt16)
    font = ctx.style.font
    tw = ctx.text_width(font, str)
    push_clip_rect!(ctx, rect)
    
    pos_y = rect.y + (rect.h - ctx.text_height(font)) ÷ 2
    
    if (opt & UInt16(OPT_ALIGNCENTER)) != 0
        pos_x = rect.x + (rect.w - tw) ÷ 2
    elseif (opt & UInt16(OPT_ALIGNRIGHT)) != 0
        pos_x = rect.x + rect.w - tw - ctx.style.padding
    else
        pos_x = rect.x + ctx.style.padding
    end
    
    draw_text!(ctx, font, str, Vec2(pos_x, pos_y), ctx.style.colors[Int(colorid)])
    pop_clip_rect!(ctx)
end

function mouse_over(ctx::Context, rect::Rect)
    overlaps = rect_overlaps_vec2(rect, ctx.mouse_pos)
    clip_overlaps = rect_overlaps_vec2(get_clip_rect(ctx), ctx.mouse_pos)
    in_hover = in_hover_root(ctx)
    
    return overlaps && clip_overlaps && in_hover
end

function update_control!(ctx::Context, id::Id, rect::Rect, opt::UInt16)
    mouseover = mouse_over(ctx, rect)
    
    if ctx.focus == id
        ctx.updated_focus = true
    end
    
    if (opt & UInt16(OPT_NOINTERACT)) != 0
        return
    end
    
    if mouseover && ctx.mouse_down == 0
        ctx.hover = id
    end
    
    if ctx.focus == id
        if ctx.mouse_pressed != 0 && !mouseover
            set_focus!(ctx, 0)
        end
        if ctx.mouse_down == 0 && (opt & UInt16(OPT_HOLDFOCUS)) == 0
            set_focus!(ctx, 0)
        end
    end
    
    if ctx.hover == id
        if ctx.mouse_pressed != 0
            set_focus!(ctx, id)
        elseif !mouseover
            ctx.hover = 0
        end
    end
end

function set_focus!(ctx::Context, id::Id)
    ctx.focus = id
    ctx.updated_focus = true
end

# Widget implementations
function text(ctx::Context, text::String)
    font = ctx.style.font
    color = ctx.style.colors[Int(COLOR_TEXT)]
    layout_begin_column!(ctx)
    layout_row!(ctx, 1, [-1], ctx.text_height(font))
    
    p = 1
    while p <= length(text)
        r = layout_next(ctx)
        w = 0
        start_pos = p
        end_pos = p
        
        # Word wrapping
        while p <= length(text) && text[p] != '\n'
            word_start = p
            while p <= length(text) && text[p] != ' ' && text[p] != '\n'
                p += 1
            end
            word_width = ctx.text_width(font, text[word_start:p-1])
            
            if w + word_width > r.w && end_pos != start_pos
                break
            end
            
            w += word_width
            if p <= length(text) && text[p] == ' '
                w += ctx.text_width(font, " ")
                p += 1
            end
            end_pos = p - 1
        end
        
        if end_pos >= start_pos
            draw_text!(ctx, font, text[start_pos:end_pos], Vec2(r.x, r.y), color)
        end
        
        if p <= length(text) && text[p] == '\n'
            p += 1
        end
    end
    
    layout_end_column!(ctx)
end

function label(ctx::Context, text::String)
    draw_control_text!(ctx, text, layout_next(ctx), COLOR_TEXT, UInt16(0))
end

function button_ex(ctx::Context, label::String, icon::Union{Nothing, IconId}, opt::UInt16)
    res = 0
    id = label != "" ? get_id(ctx, (label, :button)) : get_id(ctx, pointer_from_objref(icon), sizeof(IconId))
    r = layout_next(ctx)
    update_control!(ctx, id, r, opt)
    
    # Handle click
    if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0 && ctx.focus == id
        res |= Int(RES_SUBMIT)
    end
    
    # Draw
    draw_control_frame!(ctx, id, r, COLOR_BUTTON, opt)
    if label != ""
        draw_control_text!(ctx, label, r, COLOR_TEXT, opt)
    end
    if icon !== nothing
        draw_icon!(ctx, icon, r, ctx.style.colors[Int(COLOR_TEXT)])
    end
    
    return res
end

button(ctx::Context, label::String) = button_ex(ctx, label, nothing, UInt16(OPT_ALIGNCENTER))

function checkbox!(ctx::Context, label::String, state::Ref{Bool})
    res = 0
    id = get_id(ctx, (label, :checkbox))

    r = layout_next(ctx)
    box = Rect(r.x, r.y, r.w, r.h)
    update_control!(ctx, id, r, UInt16(0))
    
    # Handle click
    if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0 && ctx.focus == id
        res |= Int(RES_CHANGE)
        state[] = !state[]
    end
    
    # Draw
    draw_control_frame!(ctx, id, box, COLOR_BASE, UInt16(0))
    if state[]
        draw_icon!(ctx, ICON_CHECK, box, ctx.style.colors[Int(COLOR_TEXT)])
    end
    
    r = Rect(r.x + box.w, r.y, r.w - box.w, r.h)
    draw_control_text!(ctx, label, r, COLOR_TEXT, UInt16(0))
    
    return res
end

function textbox_raw!(ctx::Context, buf::Ref{String}, id::Id, r::Rect, opt::UInt16)
    res = 0
    update_control!(ctx, id, r, opt | UInt16(OPT_HOLDFOCUS))
    
    if ctx.focus == id
        # Handle text input
        if length(ctx.input_text) > 0
            buf[] *= ctx.input_text
            res |= Int(RES_CHANGE)
        end
        
        # Handle backspace
        if (ctx.key_pressed & UInt8(KEY_BACKSPACE)) != 0 && length(buf[]) > 0
            # Handle UTF-8 properly
            buf[] = buf[][1:prevind(buf[], lastindex(buf[]))]
            res |= Int(RES_CHANGE)
        end
        
        # Handle return
        if (ctx.key_pressed & UInt8(KEY_RETURN)) != 0
            set_focus!(ctx, 0)
            res |= Int(RES_SUBMIT)
        end
    end
    
    # Draw
    draw_control_frame!(ctx, id, r, COLOR_BASE, opt)
    if ctx.focus == id
        color = ctx.style.colors[Int(COLOR_TEXT)]
        font = ctx.style.font
        textw = ctx.text_width(font, buf[])
        texth = ctx.text_height(font)
        ofx = r.w - ctx.style.padding - textw - 1
        textx = r.x + min(ofx, ctx.style.padding)
        texty = r.y + (r.h - texth) ÷ 2
        
        push_clip_rect!(ctx, r)
        draw_text!(ctx, font, buf[], Vec2(textx, texty), color)
        draw_rect!(ctx, Rect(textx + textw, texty, 1, texth), color)
        pop_clip_rect!(ctx)
    else
        draw_control_text!(ctx, buf[], r, COLOR_TEXT, opt)
    end
    
    return res
end

function textbox_ex!(ctx::Context, label::String, buf::Ref{String}, opt::UInt16)
    id = get_id(ctx, (label, :textbox))
    r = layout_next(ctx)
    return textbox_raw!(ctx, buf, id, r, opt)
end

textbox!(ctx::Context, label::String, buf::Ref{String}) = textbox_ex!(ctx, label, buf, UInt16(0))

function number_textbox!(ctx::Context, value::Ref{Real}, r::Rect, id::Id)
    if ctx.mouse_pressed == UInt8(MOUSE_LEFT) && 
       (ctx.key_down & UInt8(KEY_SHIFT)) != 0 && 
       ctx.hover == id
        ctx.number_edit = id
        ctx.number_edit_buf = string(value[])
    end
    
    if ctx.number_edit == id
        buf = Ref(ctx.number_edit_buf)
        res = textbox_raw!(ctx, buf, id, r, 0)
        ctx.number_edit_buf = buf[]
        
        if (res & Int(RES_SUBMIT)) != 0 || ctx.focus != id
            try
                value[] = parse(Real, ctx.number_edit_buf)
            catch
                # Keep old value on parse error
            end
            ctx.number_edit = 0
        else
            return true
        end
    end
    return false
end

function slider_ex!(ctx::Context, label::String, value::Ref{Real}, low::Real, high::Real,
                   step::Real, opt::UInt16)
    res = 0
    last = value[]
    v = last
    id = get_id(ctx, (label, :slider))
    base = layout_next(ctx)
    
    # Handle text input mode
    if number_textbox!(ctx, value, base, id)
        return res
    end
    
    # Handle normal mode
    update_control!(ctx, id, base, opt)
    
    # Handle input
    if ctx.focus == id && (ctx.mouse_down & UInt8(MOUSE_LEFT)) != 0
        v = low + (ctx.mouse_pos.x - base.x) * (high - low) / base.w
        if step > 0
            v = round(v / step) * step
        end
    end
    
    # Clamp and store value
    value[] = v = clamp(v, low, high)
    if last != v
        res |= Int(RES_CHANGE)
    end
    
    # Draw base
    draw_control_frame!(ctx, id, base, COLOR_BASE, opt)
    
    # Draw thumb
    w = ctx.style.thumb_size
    x = round(Int32, (v - low) * (base.w - w) / (high - low))
    thumb = Rect(base.x + x, base.y, w, base.h)
    draw_control_frame!(ctx, id, thumb, COLOR_BUTTON, opt)
    
    # Draw text
    text = format_number(value[], 2)
    draw_control_text!(ctx, text, base, COLOR_TEXT, opt)
    
    return res
end

slider!(ctx::Context, label::String, value::Ref{Real}, low::Real, high::Real) = 
    slider_ex!(ctx, label, value, low, high, Real(0.0), UInt16(OPT_ALIGNCENTER))

function number_ex!(ctx::Context, label::String, value::Ref{Real}, step::Real, fmt::String, opt::UInt16)
    res = 0
    id = get_id(ctx, (label, :number))
    base = layout_next(ctx)
    last = value[]
    
    # Handle text input mode
    if number_textbox!(ctx, value, base, id)
        return res
    end
    
    # Handle normal mode
    update_control!(ctx, id, base, opt)
    
    # Handle input
    if ctx.focus == id && ctx.mouse_down == UInt8(MOUSE_LEFT)
        value[] += ctx.mouse_delta.x * step
    end
    
    if value[] != last
        res |= Int(RES_CHANGE)
    end
    
    # Draw
    draw_control_frame!(ctx, id, base, COLOR_BASE, opt)
    text = format_number(value[], 2)
    #if occursin("%", fmt)
    #    text = Printf.sprintf(fmt, value[])
    #else
    #    error("fmt must be a valid format string containing a format specifier like %d, %f, %s, etc.")
    #end
    draw_control_text!(ctx, text, base, COLOR_TEXT, opt)
    
    return res
end

number!(ctx::Context, label::String, value::Ref{Real}, step::Real) = 
    number_ex!(ctx, label, value, step, "%.2f", UInt16(OPT_ALIGNCENTER))

function header_impl(ctx::Context, label::String, istreenode::Bool, opt::UInt16)
    id = get_id(ctx, (label, :header))
    idx = pool_get(ctx, ctx.treenode_pool, id)
    
    active = idx >= 0
    expanded = (opt & UInt16(OPT_EXPANDED)) != 0 ? !active : active
    
    layout_row!(ctx, 1, [-1], 0)
    r = layout_next(ctx)
    update_control!(ctx, id, r, UInt16(0))
    
    # Handle click
    if ctx.mouse_pressed == UInt8(MOUSE_LEFT) && ctx.focus == id
        active = !active
    end
    
    # Update pool
    if idx >= 0
        if active
            pool_update!(ctx, ctx.treenode_pool, idx)
        else
            ctx.treenode_pool[idx] = PoolItem(0, 0)
        end
    elseif active
        pool_init!(ctx, ctx.treenode_pool, id)
    end
    
    # Draw
    if istreenode
        if ctx.hover == id
            ctx.draw_frame(ctx, r, COLOR_BUTTONHOVER)
        end
    else
        draw_control_frame!(ctx, id, r, COLOR_BUTTON, UInt16(0))
    end
    
    icon_rect = Rect(r.x, r.y, r.h, r.h)
    draw_icon!(ctx, expanded ? ICON_EXPANDED : ICON_COLLAPSED, 
               icon_rect, ctx.style.colors[Int(COLOR_TEXT)])
    
    r = Rect(r.x + r.h - ctx.style.padding, r.y, 
             r.w - r.h + ctx.style.padding, r.h)
    draw_control_text!(ctx, label, r, COLOR_TEXT, UInt16(0))
    
    return expanded ? Int(RES_ACTIVE) : 0
end

header_ex(ctx::Context, label::String, opt::UInt16) = header_impl(ctx, label, false, opt)
header(ctx::Context, label::String) = header_ex(ctx, label, UInt16(0))

function begin_treenode_ex(ctx::Context, label::String, opt::UInt16)
    res = header_impl(ctx, label, true, opt)
    if res & Int(RES_ACTIVE) != 0
        layout = get_layout(ctx)
        layout.indent += ctx.style.indent
        push!(ctx.id_stack, ctx.last_id)
    end
    return res
end
begin_treenode(ctx::Context, label::String) = begin_treenode_ex(ctx, label, UInt16(0))

function end_treenode(ctx::Context)
    layout = get_layout(ctx)
    layout.indent -= ctx.style.indent
    pop_id!(ctx)
end

# Container management
function get_container(ctx::Context, id::Id, opt::UInt16)
    # Try to get existing container
    idx = pool_get(ctx, ctx.container_pool, id)
    if idx >= 0
        if ctx.containers[idx].open || (opt & UInt16(OPT_CLOSED)) == 0
            pool_update!(ctx, ctx.container_pool, idx)
        end
        return ctx.containers[idx]
    end
    
    if (opt & UInt16(OPT_CLOSED)) != 0
        return nothing
    end
    
    # Init new container
    idx = pool_init!(ctx, ctx.container_pool, id)
    cnt = ctx.containers[idx]
    cnt.open = true
    cnt.head = nothing
    cnt.tail = nothing
    cnt.rect = Rect(0, 0, 0, 0)
    cnt.body = Rect(0, 0, 0, 0)
    cnt.content_size = Vec2(0, 0)
    cnt.scroll = Vec2(0, 0)
    cnt.zindex = 0
    bring_to_front!(ctx, cnt)
    return cnt
end

function get_container(ctx::Context, name::Tuple)
    id = get_id(ctx, name)
    return get_container(ctx, id, UInt16(0))
end

# Scrollbar implementation
function scrollbars!(ctx::Context, cnt::Container, body::Ref{Rect})
    sz = ctx.style.scrollbar_size
    cs = Vec2(cnt.content_size.x + ctx.style.padding * 2,
              cnt.content_size.y + ctx.style.padding * 2)
    
    push_clip_rect!(ctx, body[])

    # Resize body for scrollbars
    if cs.y > cnt.body.h
        body[] = Rect(body[].x, body[].y, body[].w - sz, body[].h)
    end
    if cs.x > cnt.body.w
        body[] = Rect(body[].x, body[].y, body[].w, body[].h - sz)
    end

    # Vertical scrollbar
    maxscroll = cs.y - body[].h
    if maxscroll > 0 && body[].h > 0
        id = get_id(ctx, "!scrollbary")
        base = Rect(body[].x + body[].w, body[].y, sz, body[].h)
        
        update_control!(ctx, id, base, UInt16(0))
        if ctx.focus == id && ctx.mouse_down == UInt8(MOUSE_LEFT)
            # Utiliser Int64 pour les calculs intermédiaires
            new_scroll_y = Int64(cnt.scroll.y) + 
                          (Int64(ctx.mouse_delta.y) * Int64(cs.y) ÷ Int64(base.h))

            # Clamper avant de convertir en Int32
            cnt.scroll = Vec2(cnt.scroll.x, 
                             clamp(Int32(new_scroll_y), 0, maxscroll))
        end
        
        cnt.scroll = Vec2(cnt.scroll.x, clamp(cnt.scroll.y, 0, maxscroll))
        
        # Draw scrollbar
        ctx.draw_frame(ctx, base, COLOR_SCROLLBASE)
        thumb_h = max(ctx.style.thumb_size, base.h * body[].h ÷ cs.y)
        thumb_y = base.y + cnt.scroll.y * (base.h - thumb_h) ÷ maxscroll
        thumb = Rect(base.x, thumb_y, sz, thumb_h)
        ctx.draw_frame(ctx, thumb, COLOR_SCROLLTHUMB)
        
        # Set scroll target
        if mouse_over(ctx, body[])
            ctx.scroll_target = cnt
        end
    else
        cnt.scroll = Vec2(cnt.scroll.x, 0)
    end
    
    # Horizontal scrollbar
    maxscroll_x = cs.x - body[].w
    if maxscroll_x > 0 && body[].w > 0
        id = get_id(ctx, "!scrollbarx")
        base = Rect(body[].x, body[].y + body[].h, body[].w, sz)
        
        update_control!(ctx, id, base, UInt16(0))
        if ctx.focus == id && ctx.mouse_down == UInt8(MOUSE_LEFT)
            # Utiliser Int64 pour les calculs intermédiaires
            new_scroll_x = Int64(cnt.scroll.x) + 
                          (Int64(ctx.mouse_delta.x) * Int64(cs.x) ÷ Int64(base.w))
            
            # Clamper avant de convertir en Int32
            cnt.scroll = Vec2(clamp(Int32(new_scroll_x), 0, maxscroll_x), 
                             cnt.scroll.y)
        end
        
        cnt.scroll = Vec2(clamp(cnt.scroll.x, 0, maxscroll_x), cnt.scroll.y)
        
        # Draw scrollbar
        ctx.draw_frame(ctx, base, COLOR_SCROLLBASE)
        thumb_w = max(ctx.style.thumb_size, base.w * body[].w ÷ cs.x)
        thumb_x = base.x + cnt.scroll.x * (base.w - thumb_w) ÷ maxscroll_x
        thumb = Rect(thumb_x, base.y, thumb_w, sz)
        ctx.draw_frame(ctx, thumb, COLOR_SCROLLTHUMB)
    else
        cnt.scroll = Vec2(0, cnt.scroll.y)
    end
    
    pop_clip_rect!(ctx)
end

function push_container_body!(ctx::Context, cnt::Container, body::Rect, opt::UInt16)
    body_ref = Ref(body)
    if (opt & UInt16(OPT_NOSCROLL)) == 0
        scrollbars!(ctx, cnt, body_ref)
    end
    push_layout!(ctx, expand_rect(body_ref[], -ctx.style.padding), cnt.scroll)
    cnt.body = body_ref[]
end

function pop_container!(ctx::Context)
    cnt = get_current_container(ctx)
    layout = get_layout(ctx)
    cnt.content_size = Vec2(layout.max.x - layout.body.x,
                           layout.max.y - layout.body.y)
    pop!(ctx.container_stack)
    pop!(ctx.layout_stack)
    pop_id!(ctx)
end

function begin_root_container!(ctx::Context, cnt::Container)
    push!(ctx.container_stack, cnt)
    push!(ctx.root_list, cnt)
    cnt.head = nothing  # Simplified command handling
    
    # Set as hover root
    if rect_overlaps_vec2(cnt.rect, ctx.mouse_pos) &&
       (ctx.next_hover_root === nothing || cnt.zindex > ctx.next_hover_root.zindex)
        ctx.next_hover_root = cnt
    end
    
    push!(ctx.clip_stack, Rect(0, 0, typemax(Int32), typemax(Int32)))
end

function end_root_container!(ctx::Context)
    pop_clip_rect!(ctx)
    pop_container!(ctx)
end

# Window management
function begin_window_ex(ctx::Context, title::String, rect::Rect, opt::UInt16)
    id = get_id(ctx, (title, :window))
    cnt = get_container(ctx, id, opt)
    if cnt === nothing || !cnt.open
        return false
    end
    
    push!(ctx.id_stack, id)
    
    if cnt.rect.w == 0
        cnt.rect = rect
    end
    begin_root_container!(ctx, cnt)
    rect = body = cnt.rect
    
    # Draw frame
    if (opt & UInt16(OPT_NOFRAME)) == 0
        ctx.draw_frame(ctx, rect, COLOR_WINDOWBG)
    end
    
    # Title bar
    if (opt & UInt16(OPT_NOTITLE)) == 0
        tr = Rect(rect.x, rect.y, rect.w, ctx.style.title_height)
        ctx.draw_frame(ctx, tr, COLOR_TITLEBG)
        
        # Title text and dragging
        id = get_id(ctx, "!title")
        update_control!(ctx, id, tr, opt)
        draw_control_text!(ctx, title, tr, COLOR_TITLETEXT, opt)
        if id == ctx.focus && ctx.mouse_down == UInt8(MOUSE_LEFT)
            cnt.rect = Rect(cnt.rect.x + ctx.mouse_delta.x,
                           cnt.rect.y + ctx.mouse_delta.y,
                           cnt.rect.w, cnt.rect.h)
        end
        body = Rect(body.x, body.y + tr.h, body.w, body.h - tr.h)
        
        # Close button
        if (opt & UInt16(OPT_NOCLOSE)) == 0
            id = get_id(ctx, "!close")
            r = Rect(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h)
            tr = Rect(tr.x, tr.y, tr.w - r.w, tr.h)
            draw_icon!(ctx, ICON_CLOSE, r, ctx.style.colors[Int(COLOR_TITLETEXT)])
            update_control!(ctx, id, r, opt)
            if ctx.mouse_pressed == UInt8(MOUSE_LEFT) && id == ctx.focus
                cnt.open = false
            end
        end
    end
    
    push_container_body!(ctx, cnt, body, opt)
    
    # Resize handle
    if (opt & UInt16(OPT_NORESIZE)) == 0
        sz = ctx.style.title_height
        id = get_id(ctx, "!resize")
        r = Rect(rect.x + rect.w - sz, rect.y + rect.h - sz, sz, sz)
        update_control!(ctx, id, r, opt)
        if id == ctx.focus && ctx.mouse_down == UInt8(MOUSE_LEFT)
            cnt.rect = Rect(cnt.rect.x, cnt.rect.y,
                           max(96, cnt.rect.w + ctx.mouse_delta.x),
                           max(64, cnt.rect.h + ctx.mouse_delta.y))
        end
    end
    
    # Auto-resize
    if (opt & UInt16(OPT_AUTOSIZE)) != 0
        r = get_layout(ctx).body
        cnt.rect = Rect(cnt.rect.x, cnt.rect.y,
                       cnt.content_size.x + (cnt.rect.w - r.w),
                       cnt.content_size.y + (cnt.rect.h - r.h))
    end
    
    # Close popup on outside click
    if (opt & UInt16(OPT_POPUP)) != 0 && ctx.mouse_pressed != 0 && ctx.hover_root !== cnt
        cnt.open = false
    end
    
    push_clip_rect!(ctx, cnt.body)
    return RES_ACTIVE
end

begin_window(ctx::Context, title::String, rect::Rect) = begin_window_ex(ctx, title, rect, UInt16(0))

function end_window(ctx::Context)
    pop_clip_rect!(ctx)
    end_root_container!(ctx)
end

function open_popup!(ctx::Context, name::String)
    cnt = get_container(ctx, (name, :popup))
    if cnt !== nothing
        ctx.hover_root = ctx.next_hover_root = cnt
        cnt.rect = Rect(ctx.mouse_pos.x, ctx.mouse_pos.y, 1, 1)
        cnt.open = true
        bring_to_front!(ctx, cnt)
    end
end

function begin_popup_ex(ctx::Context, title::String, rect::Rect, opt::UInt16)
    id = get_id(ctx, (title, :popup))
    cnt = get_container(ctx, id, opt)
    if cnt === nothing || !cnt.open
        return false
    end
    
    push!(ctx.id_stack, id)
    
    if cnt.rect.w == 0
        cnt.rect = rect
    end
    begin_root_container!(ctx, cnt)
    rect = body = cnt.rect
    
    # Draw frame
    if (opt & UInt16(OPT_NOFRAME)) == 0
        ctx.draw_frame(ctx, rect, COLOR_WINDOWBG)
    end
    
    # Title bar
    if (opt & UInt16(OPT_NOTITLE)) == 0
        tr = Rect(rect.x, rect.y, rect.w, ctx.style.title_height)
        ctx.draw_frame(ctx, tr, COLOR_TITLEBG)
        
        # Title text and dragging
        id = get_id(ctx, "!title")
        update_control!(ctx, id, tr, opt)
        draw_control_text!(ctx, title, tr, COLOR_TITLETEXT, opt)
        if id == ctx.focus && ctx.mouse_down == UInt8(MOUSE_LEFT)
            cnt.rect = Rect(cnt.rect.x + ctx.mouse_delta.x,
                           cnt.rect.y + ctx.mouse_delta.y,
                           cnt.rect.w, cnt.rect.h)
        end
        body = Rect(body.x, body.y + tr.h, body.w, body.h - tr.h)
        
        # Close button
        if (opt & UInt16(OPT_NOCLOSE)) == 0
            id = get_id(ctx, "!close")
            r = Rect(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h)
            tr = Rect(tr.x, tr.y, tr.w - r.w, tr.h)
            draw_icon!(ctx, ICON_CLOSE, r, ctx.style.colors[Int(COLOR_TITLETEXT)])
            update_control!(ctx, id, r, opt)
            if ctx.mouse_pressed == UInt8(MOUSE_LEFT) && id == ctx.focus
                cnt.open = false
            end
        end
    end
    
    push_container_body!(ctx, cnt, body, opt)
    
    # Resize handle
    if (opt & UInt16(OPT_NORESIZE)) == 0
        sz = ctx.style.title_height
        id = get_id(ctx, "!resize")
        r = Rect(rect.x + rect.w - sz, rect.y + rect.h - sz, sz, sz)
        update_control!(ctx, id, r, opt)
        if id == ctx.focus && ctx.mouse_down == UInt8(MOUSE_LEFT)
            cnt.rect = Rect(cnt.rect.x, cnt.rect.y,
                           max(96, cnt.rect.w + ctx.mouse_delta.x),
                           max(64, cnt.rect.h + ctx.mouse_delta.y))
        end
    end
    
    # Auto-resize
    if (opt & UInt16(OPT_AUTOSIZE)) != 0
        r = get_layout(ctx).body
        cnt.rect = Rect(cnt.rect.x, cnt.rect.y,
                       cnt.content_size.x + (cnt.rect.w - r.w),
                       cnt.content_size.y + (cnt.rect.h - r.h))
    end
    
    # Close popup on outside click
    if (opt & UInt16(OPT_POPUP)) != 0 && ctx.mouse_pressed != 0 && ctx.hover_root !== cnt
        cnt.open = false
    end
    
    push_clip_rect!(ctx, cnt.body)
    return RES_ACTIVE
end

function begin_popup(ctx::Context, name::String)
    opt = UInt16(OPT_POPUP) | UInt16(OPT_AUTOSIZE) | UInt16(OPT_NORESIZE) |
          UInt16(OPT_NOSCROLL) | UInt16(OPT_NOTITLE) | UInt16(OPT_CLOSED)
    return begin_popup_ex(ctx, name, Rect(0, 0, 0, 0), opt)
end

function end_popup(ctx::Context)
    pop_clip_rect!(ctx)
    end_root_container!(ctx)
end

function begin_panel_ex(ctx::Context, name::String, opt::UInt16)
    push_id!(ctx, name)
    cnt = get_container(ctx, ctx.last_id, opt)
    if cnt !== nothing
        cnt.rect = layout_next(ctx)
        if (opt & UInt16(OPT_NOFRAME)) == 0
            ctx.draw_frame(ctx, cnt.rect, COLOR_PANELBG)
        end
        push!(ctx.container_stack, cnt)
        push_container_body!(ctx, cnt, cnt.rect, opt)
        push_clip_rect!(ctx, cnt.body)
    end
end

begin_panel(ctx::Context, name::String) = begin_panel_ex(ctx, name, UInt16(0))

function end_panel(ctx::Context)
    pop_clip_rect!(ctx)
    pop_container!(ctx)
end

# Utility functions for easier use
Base.:+(a::Vec2, b::Vec2) = Vec2(a.x + b.x, a.y + b.y)
Base.:-(a::Vec2, b::Vec2) = Vec2(a.x - b.x, a.y - b.y)
Base.:*(a::Vec2, s::Number) = Vec2(Int32(a.x * s), Int32(a.y * s))

end # module