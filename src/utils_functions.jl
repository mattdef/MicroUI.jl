# ===== UTILITY FUNCTIONS =====
# Common mathematical and utility functions

"""Push item onto stack with overflow checking"""
@inline function push!(s::Stack{T}, val::T) where T
    s.idx >= length(s.items) && error("Stack overflow")
    s.idx += 1
    s.items[s.idx] = val
end

"""Pop item from stack with underflow checking"""
@inline function pop!(s::Stack)
    s.idx <= 0 && error("Stack underflow")
    s.idx -= 1
end

"""Get top item from stack without removing it"""
@inline function top(s::Stack)
    s.idx <= 0 && error("Stack is empty")
    return s.items[s.idx]
end

"""Check if stack is empty"""
@inline Base.isempty(s::Stack) = s.idx == 0

"""Clamp value between minimum and maximum bounds"""
clamp(x, a, b) = max(a, min(b, x))

"""
Expand rectangle by given amount in all directions
Useful for creating borders and padding
"""
function expand_rect(r::Rect, n::Int32)
    Rect(r.x - n, r.y - n, r.w + n * 2, r.h + n * 2)
end

"""
Test if point is inside rectangle
Used for hit testing and mouse interaction
"""
function rect_overlaps_vec2(r::Rect, p::Vec2)
    p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h
end

"""
Format real numbers for display in widgets
Provides consistent number formatting throughout the UI
"""
function format_real(value::Real, fmt::String)
    val = Float64(value)
    
    if fmt == REAL_FMT || fmt == "%.3g"
        if abs(val) >= 1000
            return string(round(Int, val))
        elseif abs(val) >= 10
            return string(round(val, digits=1))
        else
            return string(round(val, digits=2))
        end
    elseif fmt == SLIDER_FMT || fmt == "%.2f"
        return string(round(val, digits=2))
    else
        return string(round(val, digits=2))
    end
end

"""
Default frame drawing function
Draws a filled rectangle with optional border
"""
function default_draw_frame(ctx::Context, rect::Rect, colorid::ColorId)
    draw_rect!(ctx, rect, ctx.style.colors[Int(colorid)])
    if colorid == COLOR_SCROLLBASE || colorid == COLOR_SCROLLTHUMB || colorid == COLOR_TITLEBG
        return
    end
    # Draw border for most elements
    if ctx.style.colors[Int(COLOR_BORDER)].a > 0
        draw_box!(ctx, expand_rect(rect, Int32(1)), ctx.style.colors[Int(COLOR_BORDER)])
    end
end

"""
Create new context with default settings
Applications should call init! after creation
"""
function Context()
    ctx = Context(
        (font, str) -> length(str) * 8,  # Default text_width function
        font -> 16,                      # Default text_height function
        default_draw_frame,              # Default draw_frame function
        DEFAULT_STYLE,
        0, 0, 0, Rect(0,0,0,0), 0, false, 0,
        nothing, nothing, nothing, "", 0,
        CommandList(),
        Stack{Container}(ROOTLIST_SIZE),
        Stack{Container}(CONTAINERSTACK_SIZE),
        Stack{Rect}(CLIPSTACK_SIZE),
        Stack{Id}(IDSTACK_SIZE),
        Stack{Layout}(LAYOUTSTACK_SIZE),
        [PoolItem(0, 0) for _ in 1:CONTAINERPOOL_SIZE],
        [Container() for _ in 1:CONTAINERPOOL_SIZE],
        [PoolItem(0, 0) for _ in 1:TREENODEPOOL_SIZE],
        Vec2(0,0), Vec2(0,0), Vec2(0,0), Vec2(0,0),
        0, 0, 0, 0, ""
    )
    return ctx
end

"""
Initialize or reset context to default state
Should be called before first use and when resetting UI state
"""
function init!(ctx::Context)
    ctx.command_list = CommandList()
    ctx.root_list.idx = 0
    ctx.container_stack.idx = 0
    ctx.clip_stack.idx = 0
    ctx.id_stack.idx = 0
    ctx.layout_stack.idx = 0
    
    ctx.hover = 0
    ctx.focus = 0
    ctx.frame = 0
    ctx.last_zindex = 0
    ctx.updated_focus = false
    ctx.hover_root = nothing
    ctx.next_hover_root = nothing
    ctx.scroll_target = nothing
    ctx.number_edit_buf = ""
    ctx.number_edit = 0
    
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

"""
Set keyboard focus to specific widget
Widget will receive keyboard input and be highlighted
"""
function set_focus!(ctx::Context, id::Id)
    ctx.focus = id
    ctx.updated_focus = true
end

# ===== POOL MANAGEMENT =====
# Resource pooling system for containers and treenodes

"""
Initialize pool item with given ID
Finds least recently used slot and assigns it to the ID
"""
function pool_init!(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id)
    n = -1
    f = ctx.frame
    for i in 1:len
        if items[i].last_update < f
            f = items[i].last_update
            n = i
        end
    end
    @assert n > 0 "Pool exhausted"
    items[n].id = id
    pool_update!(ctx, items, n)
    return n
end

"""
Find pool item by ID
Returns index if found, -1 if not found
"""
function pool_get(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id)
    for i in 1:len
        if items[i].id == id
            return i
        end
    end
    return -1
end

"""Update pool item's last access time to current frame"""
function pool_update!(ctx::Context, items::Vector{PoolItem}, idx::Int)
    items[idx].last_update = ctx.frame
end

# ===== UTILITY OPERATIONS =====
# Vector arithmetic operations for convenience

"""Add two vectors"""
Base.:+(a::Vec2, b::Vec2) = Vec2(a.x + b.x, a.y + b.y)

"""Subtract two vectors"""
Base.:-(a::Vec2, b::Vec2) = Vec2(a.x - b.x, a.y - b.y)

"""Scale vector by scalar"""
Base.:*(a::Vec2, s::Number) = Vec2(Int32(a.x * s), Int32(a.y * s))