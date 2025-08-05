# ===== UTILITY FUNCTIONS =====
# Common mathematical and utility functions

"""
    push!(s::Stack{T}, val::T) where T

Push an item onto the stack with overflow protection.

This function adds a new item to the top of the stack while ensuring
that the stack capacity is not exceeded. The stack index is automatically
incremented after the item is added.

# Arguments
- `s::Stack{T}`: The stack to push onto
- `val::T`: The value to push onto the stack

# Throws
- `ErrorException`: If the stack is already at maximum capacity

# Examples
```julia
stack = Stack{Int}(10)
push!(stack, 42)
push!(stack, 100)
```

# See also
[`pop!`](@ref), [`top`](@ref), [`isempty`](@ref)
"""
@inline function push!(s::Stack{T}, val::T) where T
    s.idx >= length(s.items) && error("Stack overflow")
    s.idx += 1
    s.items[s.idx] = val
end

"""
    pop!(s::Stack)

Remove and return the top item from the stack with underflow protection.

This function removes the top item from the stack by decrementing the
stack index. The actual memory is not cleared for performance reasons.

# Arguments
- `s::Stack`: The stack to pop from

# Throws
- `ErrorException`: If the stack is already empty

# Examples
```julia
stack = Stack{Int}(10)
push!(stack, 42)
pop!(stack)  # Stack is now empty
```

# See also
[`push!`](@ref), [`top`](@ref), [`isempty`](@ref)
"""
@inline function pop!(s::Stack)
    s.idx <= 0 && error("Stack underflow")
    s.idx -= 1
end

"""
    top(s::Stack)

Get the top item from the stack without removing it.

This function returns the value at the top of the stack without
modifying the stack state. Useful for peeking at the current value.

# Arguments
- `s::Stack`: The stack to peek at

# Returns
- The value at the top of the stack

# Throws
- `ErrorException`: If the stack is empty

# Examples
```julia
stack = Stack{Int}(10)
push!(stack, 42)
value = top(stack)  # Returns 42, stack unchanged
```

# See also
[`push!`](@ref), [`pop!`](@ref), [`isempty`](@ref)
"""
@inline function top(s::Stack)
    s.idx <= 0 && error("Stack is empty")
    return s.items[s.idx]
end

"""
    isempty(s::Stack) -> Bool

Check if the stack contains any items.

# Arguments
- `s::Stack`: The stack to check

# Returns
- `true` if the stack is empty, `false` otherwise

# Examples
```julia
stack = Stack{Int}(10)
isempty(stack)  # Returns true
push!(stack, 42)
isempty(stack)  # Returns false
```

# See also
[`push!`](@ref), [`pop!`](@ref), [`top`](@ref)
"""
@inline Base.isempty(s::Stack) = s.idx == 0

"""
    clamp(x, a, b)

Constrain a value between minimum and maximum bounds.

This utility function ensures that the input value `x` is within
the range `[a, b]`. If `x` is less than `a`, returns `a`.
If `x` is greater than `b`, returns `b`. Otherwise returns `x`.

# Arguments
- `x`: The value to clamp
- `a`: The minimum bound (inclusive)
- `b`: The maximum bound (inclusive)

# Returns
- The clamped value within the range `[a, b]`

# Examples
```julia
clamp(5, 0, 10)   # Returns 5
clamp(-5, 0, 10)  # Returns 0
clamp(15, 0, 10)  # Returns 10
```

# Note
This is a basic implementation. Julia's Base.clamp provides more features.
"""
clamp(x, a, b) = max(a, min(b, x))

"""
    expand_rect(r::Rect, n::Int32) -> Rect

Expand a rectangle by a given amount in all directions.

This function creates a new rectangle that is larger than the input
rectangle by `n` pixels in each direction. The resulting rectangle
will be centered on the original rectangle.

# Arguments
- `r::Rect`: The original rectangle to expand
- `n::Int32`: The number of pixels to expand in each direction

# Returns
- A new `Rect` expanded by `n` pixels in all directions

# Examples
```julia
original = Rect(10, 10, 100, 50)
expanded = expand_rect(original, Int32(5))
# expanded = Rect(5, 5, 110, 60)
```

# Note
Useful for creating borders, padding, and hit-testing areas around widgets.

# See also
[`Rect`](@ref), [`intersect_rects`](@ref)
"""
function expand_rect(r::Rect, n::Int32)
    Rect(r.x - n, r.y - n, r.w + n * 2, r.h + n * 2)
end

"""
    rect_overlaps_vec2(r::Rect, p::Vec2) -> Bool

Test if a point is inside a rectangle.

This function performs hit testing to determine if a 2D point
lies within the bounds of a rectangle. Used extensively for
mouse interaction and collision detection.

# Arguments
- `r::Rect`: The rectangle to test against
- `p::Vec2`: The point to test

# Returns
- `true` if the point is inside the rectangle, `false` otherwise

# Examples
```julia
rect = Rect(10, 10, 100, 50)
point1 = Vec2(50, 30)   # Inside
point2 = Vec2(5, 5)     # Outside

rect_overlaps_vec2(rect, point1)  # Returns true
rect_overlaps_vec2(rect, point2)  # Returns false
```

# Note
The test uses `>=` for the left/top edges and `<` for the right/bottom edges,
following standard computer graphics conventions.

# See also
[`Rect`](@ref), [`Vec2`](@ref), [`expand_rect`](@ref)
"""
function rect_overlaps_vec2(r::Rect, p::Vec2)
    p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h
end

"""
    format_real(value::Real, fmt::String) -> String

Format real numbers for display in UI widgets.

This function provides consistent number formatting throughout the UI,
handling different format strings and automatically choosing appropriate
precision based on the magnitude of the value.

# Arguments
- `value::Real`: The numeric value to format
- `fmt::String`: The format string (supports `REAL_FMT`, `SLIDER_FMT`, or printf-style)

# Returns
- A formatted string representation of the number

# Examples
```julia
format_real(1234.567, REAL_FMT)    # Returns "1235"
format_real(12.34, REAL_FMT)       # Returns "12.3"
format_real(0.123, REAL_FMT)       # Returns "0.12"
format_real(0.567, SLIDER_FMT)     # Returns "0.57"
```

# Format behaviors
- For `REAL_FMT` or `"%.3g"`:
  - Values ≥ 1000: rounded to integer
  - Values ≥ 10: 1 decimal place
  - Values < 10: 2 decimal places
- For `SLIDER_FMT` or `"%.2f"`: always 2 decimal places
- Other formats: default to 2 decimal places

# See also
[`REAL_FMT`](@ref), [`SLIDER_FMT`](@ref)
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
    default_draw_frame(ctx::Context, rect::Rect, colorid::ColorId)

Default frame drawing function for UI widgets.

This function draws a filled rectangle with an optional border,
serving as the default rendering method for widget backgrounds.
Different widget types may skip the border based on their `colorid`.

# Arguments
- `ctx::Context`: The UI context containing drawing state
- `rect::Rect`: The rectangle area to draw
- `colorid::ColorId`: The color identifier for the frame

# Behavior
- Always draws a filled rectangle with the specified color
- Skips border for scrollbars (`COLOR_SCROLLBASE`, `COLOR_SCROLLTHUMB`) and title bars (`COLOR_TITLEBG`)
- Draws a 1-pixel border for other elements if border color has alpha > 0

# Examples
```julia
# This function is typically set as the default draw_frame callback
ctx.draw_frame = default_draw_frame

# It will be called automatically by widgets:
draw_control_frame!(ctx, widget_id, widget_rect, COLOR_BUTTON, options)
```

# Note
Applications can override this by setting `ctx.draw_frame` to a custom function
with the same signature.

# See also
[`draw_rect!`](@ref), [`draw_box!`](@ref), [`ColorId`](@ref)
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
    Context() -> Context

Create a new MicroUI context with default settings.

This constructor initializes a new UI context with sensible defaults
for text measurement, drawing, and styling. Applications should call
[`init!`](@ref) after creation and before use.

# Returns
- A new `Context` instance with default callbacks and empty state

# Default callbacks
- `text_width`: Estimates 8 pixels per character
- `text_height`: Returns 16 pixels
- `draw_frame`: Uses [`default_draw_frame`](@ref)

# Examples
```julia
ctx = Context()
init!(ctx)

# Set custom callbacks if needed
ctx.text_width = (font, str) -> custom_text_width(font, str)
ctx.text_height = font -> custom_text_height(font)

# Ready to use
begin_frame(ctx)
# ... UI code ...
end_frame(ctx)
```

# Note
The default text measurement functions are basic estimates. For accurate
text rendering, applications should provide proper font measurement callbacks.

# See also
[`init!`](@ref), [`begin_frame`](@ref), [`end_frame`](@ref)
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
        0, 0, 0, 0, "",
        Dict{Id, TabState}()
    )
    return ctx
end

"""
    init!(ctx::Context)

Initialize or reset a context to its default state.

This function prepares the context for use by clearing all state
and resetting all stacks and buffers. Should be called before
the first frame and when resetting the UI state.

# Arguments
- `ctx::Context`: The context to initialize

# Effects
- Resets command buffer and all stacks to empty
- Clears hover, focus, and interaction state
- Resets mouse and keyboard input state
- Initializes frame counter and Z-index tracking

# Examples
```julia
ctx = Context()
init!(ctx)  # Required before first use

# Later, to reset everything:
init!(ctx)  # Clears all state
```

# Note
This function must be called before using the context for UI rendering.
It's safe to call multiple times to reset the UI state.

# See also
[`Context`](@ref), [`begin_frame`](@ref)
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

    # Initialize tab system registry
    ctx.tab_states = Dict{Id, TabState}()
end

"""
    create_context(; text_width_fn = nothing, text_height_fn = nothing, setup_fn = nothing)

Create and initialize a MicroUI context for multi-frame applications.

This function creates a reusable MicroUI context that can be used across multiple frames
for improved performance compared to recreating contexts each frame.

# Arguments
- `text_width_fn`: Optional custom text width measurement function  
- `text_height_fn`: Optional custom text height measurement function
- `setup_fn`: Optional setup function called with the context as argument

# Returns
- `Context`: Initialized MicroUI context ready for frame processing

# Basic Usage

```julia
# Simple context with defaults
ctx = create_context()

# Context with custom text measurement
ctx = create_context(
    text_width_fn = (font, str) -> measure_real_text_width(font, str),
    text_height_fn = font -> get_real_font_height(font)
)

# Context with setup function
ctx = create_context(
    setup_fn = ctx -> begin
        println("Context \$(objectid(ctx)) initialized")
        # Additional setup here
    end
)
```

# Performance Benefits
- **Context reuse**: Significant performance improvement for animations
- **Memory efficiency**: Reduces allocations by avoiding context recreation  
- **State persistence**: Widget states are preserved between frames
- **Scalability**: Enables 60+ FPS applications with complex UIs

# See Also
- [`@frame`](@ref): Process individual frames with the created context
- [`@context`](@ref): Traditional single-frame context management
"""
function create_context(; 
    text_width_fn::Union{Function, Nothing} = nothing,
    text_height_fn::Union{Function, Nothing} = nothing, 
    setup_fn::Union{Function, Nothing} = nothing
)
    # Create and initialize context
    ctx = Context()
    init!(ctx)
    
    # Set text measurement callbacks
    ctx.text_width = isnothing(text_width_fn) ? 
        ((font, str) -> length(str) * 8) : text_width_fn
    ctx.text_height = isnothing(text_height_fn) ? 
        (font -> 16) : text_height_fn
    
    # Call optional setup function
    if !isnothing(setup_fn)
        setup_fn(ctx)
    end
    
    return ctx
end

"""
    set_focus!(ctx::Context, id::Id)

Set keyboard focus to a specific widget.

The focused widget will receive keyboard input and be visually
highlighted. Only one widget can have focus at a time.

# Arguments
- `ctx::Context`: The UI context
- `id::Id`: The unique identifier of the widget to focus (use 0 to clear focus)

# Examples
```julia
# Focus a specific widget
widget_id = get_id(ctx, "my_textbox")
set_focus!(ctx, widget_id)

# Clear focus
set_focus!(ctx, 0)
```

# Note
Setting focus also marks that focus was updated this frame,
preventing automatic focus clearing at frame end.

# See also
[`get_id`](@ref), [`Id`](@ref)
"""
function set_focus!(ctx::Context, id::Id)
    ctx.focus = id
    ctx.updated_focus = true
end

# ===== POOL MANAGEMENT =====
# Resource pooling system for containers and treenodes

"""
    pool_init!(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id) -> Int

Initialize a pool item with the given ID using LRU replacement.

This function finds the least recently used slot in the pool and
assigns it to the specified ID. The pool system allows efficient
reuse of resources like containers and tree nodes.

# Arguments
- `ctx::Context`: The UI context (used for frame number)
- `items::Vector{PoolItem}`: The pool array to search
- `len::Int`: The effective length of the pool to search
- `id::Id`: The unique identifier to assign to the pool item

# Returns
- The index of the assigned pool item

# Throws
- `AssertionError`: If no available pool slot is found (pool exhausted)

# Examples
```julia
# This is typically called internally by container management
container_idx = pool_init!(ctx, ctx.container_pool, CONTAINERPOOL_SIZE, widget_id)
```

# Note
The function uses the current frame number to implement LRU (Least Recently Used)
replacement policy for optimal resource utilization.

# See also
[`pool_get`](@ref), [`pool_update!`](@ref), [`PoolItem`](@ref)
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
    pool_get(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id) -> Int

Find a pool item by its ID.

This function searches through the pool to find an item with the
specified ID. Used to retrieve existing resources from the pool.

# Arguments
- `ctx::Context`: The UI context (currently unused but kept for consistency)
- `items::Vector{PoolItem}`: The pool array to search
- `len::Int`: The effective length of the pool to search
- `id::Id`: The unique identifier to search for

# Returns
- The index of the found item, or -1 if not found

# Examples
```julia
# This is typically called internally by container management
container_idx = pool_get(ctx, ctx.container_pool, CONTAINERPOOL_SIZE, widget_id)
if container_idx >= 0
    # Found existing container
    container = ctx.containers[container_idx]
else
    # Need to create new container
end
```

# See also
[`pool_init!`](@ref), [`pool_update!`](@ref), [`PoolItem`](@ref)
"""
function pool_get(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id)
    for i in 1:len
        if items[i].id == id
            return i
        end
    end
    return -1
end

"""
    pool_update!(ctx::Context, items::Vector{PoolItem}, idx::Int)

Update a pool item's last access time to the current frame.

This function marks a pool item as recently used by updating
its `last_update` field to the current frame number. This
prevents the item from being considered for LRU replacement.

# Arguments
- `ctx::Context`: The UI context (provides current frame number)
- `items::Vector{PoolItem}`: The pool array containing the item
- `idx::Int`: The index of the item to update

# Examples
```julia
# This is typically called internally when accessing pool items
pool_update!(ctx, ctx.container_pool, container_idx)
```

# Note
This function is crucial for the LRU replacement policy used by [`pool_init!`](@ref).

# See also
[`pool_init!`](@ref), [`pool_get`](@ref), [`PoolItem`](@ref)
"""
function pool_update!(ctx::Context, items::Vector{PoolItem}, idx::Int)
    items[idx].last_update = ctx.frame
end

# ===== UTILITY OPERATIONS =====
# Vector arithmetic operations for convenience

"""
    +(a::Vec2, b::Vec2) -> Vec2

Add two 2D vectors component-wise.

# Arguments
- `a::Vec2`: The first vector
- `b::Vec2`: The second vector

# Returns
- A new `Vec2` with the sum of the input vectors

# Examples
```julia
v1 = Vec2(10, 20)
v2 = Vec2(5, 15)
result = v1 + v2  # Vec2(15, 35)
```

# See also
[`-`](@ref), [`*`](@ref), [`Vec2`](@ref)
"""
Base.:+(a::Vec2, b::Vec2) = Vec2(a.x + b.x, a.y + b.y)

"""
    -(a::Vec2, b::Vec2) -> Vec2

Subtract two 2D vectors component-wise.

# Arguments
- `a::Vec2`: The first vector (minuend)
- `b::Vec2`: The second vector (subtrahend)

# Returns
- A new `Vec2` with the difference of the input vectors

# Examples
```julia
v1 = Vec2(10, 20)
v2 = Vec2(5, 15)
result = v1 - v2  # Vec2(5, 5)
```

# See also
[`+`](@ref), [`*`](@ref), [`Vec2`](@ref)
"""
Base.:-(a::Vec2, b::Vec2) = Vec2(a.x - b.x, a.y - b.y)

"""
    *(a::Vec2, s::Number) -> Vec2

Scale a 2D vector by a scalar value.

This function multiplies both components of the vector by the scalar
and converts the result to `Int32` for consistency with the Vec2 type.

# Arguments
- `a::Vec2`: The vector to scale
- `s::Number`: The scalar multiplier

# Returns
- A new `Vec2` with both components scaled by `s`

# Examples
```julia
v = Vec2(10, 20)
result = v * 2.5  # Vec2(25, 50)
```

# Note
The result is converted to `Int32`, so fractional parts are truncated.

# See also
[`+`](@ref), [`-`](@ref), [`Vec2`](@ref)
"""
Base.:*(a::Vec2, s::Number) = Vec2(Int32(a.x * s), Int32(a.y * s))