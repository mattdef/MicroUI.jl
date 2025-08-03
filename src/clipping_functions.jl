# ===== CLIPPING FUNCTIONS =====
# Functions for managing clipping rectangles

"""
    push_clip_rect!(ctx::Context, rect::Rect)

Push a new clipping rectangle onto the clipping stack.

This function establishes a new clipping region by intersecting the provided
rectangle with the current clipping rectangle and pushing the result onto
the clipping stack. This creates nested clipping behavior where each new
clipping region is constrained by all parent clipping regions.

# Arguments
- `ctx::Context`: The UI context containing the clipping stack
- `rect::Rect`: The new clipping rectangle in screen coordinates

# Effects
- Calculates intersection with current clipping rectangle
- Pushes the intersected rectangle onto the clipping stack
- All subsequent drawing operations are clipped to this region
- Creates a new clipping scope for nested content

# Clipping intersection behavior
The new clipping rectangle is the intersection of:
1. **Current clip**: The rectangle currently at the top of the stack
2. **New rect**: The rectangle being pushed
3. **Result**: Only the overlapping area becomes the new clipping region

```julia
# Mathematical representation
new_clip = intersect_rects(current_clip, new_rect)
```

# Examples
```julia
# Basic clipping for a panel
panel_rect = Rect(50, 50, 200, 150)
push_clip_rect!(ctx, panel_rect)

# All drawing is now clipped to the panel area
draw_rect!(ctx, Rect(0, 0, 300, 300), color)  # Only panel area is drawn
draw_text!(ctx, font, "Text", -1, Vec2(60, 60), color)  # Clipped to panel

# Restore previous clipping
pop_clip_rect!(ctx)
```

# Nested clipping for complex layouts
```julia
# Window clipping
window_rect = Rect(10, 10, 400, 300)
push_clip_rect!(ctx, window_rect)

    # Content area within window (excluding title bar)
    content_rect = Rect(15, 35, 390, 270)
    push_clip_rect!(ctx, content_rect)
    
        # Scrollable area within content
        scroll_rect = Rect(20, 40, 360, 240)
        push_clip_rect!(ctx, scroll_rect)
        
            # Drawing here is clipped to: window ∩ content ∩ scroll
            draw_large_content(ctx)
            
        pop_clip_rect!(ctx)  # Back to content clipping
        
        # Draw scrollbars (clipped to content but not scroll area)
        draw_scrollbars(ctx)
        
    pop_clip_rect!(ctx)  # Back to window clipping
    
    # Draw window title bar (clipped to window but not content)
    draw_title_bar(ctx)
    
pop_clip_rect!(ctx)  # Back to previous clipping
```

# Container integration
This function is commonly used by container management:

```julia
# Container body setup with clipping
function push_container_body!(ctx, cnt, body, opt)
    # Set up scrollbars first
    body_ref = Ref(body)
    if (opt & OPT_NOSCROLL) == 0
        scrollbars!(ctx, cnt, body_ref)
    end
    
    # Clip to final body rectangle
    push_clip_rect!(ctx, body_ref[])
    
    # Set up layout within clipped area
    push_layout!(ctx, expand_rect(body_ref[], -ctx.style.padding), cnt.scroll)
    cnt.body = body_ref[]
end
```

# Clipping optimization
The intersection calculation optimizes rendering:
- **Early culling**: Content outside intersection is never drawn
- **Backend efficiency**: Graphics APIs can optimize clipped regions
- **Memory savings**: Invisible content doesn't consume video memory

# Text rendering with clipping
```julia
# Long text that might overflow container
container_rect = Rect(100, 100, 150, 50)
push_clip_rect!(ctx, container_rect)

# Text extends beyond container but is automatically clipped
draw_text!(ctx, font, "This is a very long text that extends beyond the container boundaries", 
          -1, Vec2(105, 120), color)

pop_clip_rect!(ctx)
```

# Scrolling content implementation
```julia
# Scrollable content area
content_bounds = Rect(50, 50, 300, 200)
content_offset = Vec2(0, -scroll_position)  # Negative Y for scrolling down

push_clip_rect!(ctx, content_bounds)

# Content is positioned with scroll offset but clipped to bounds
for i in 1:20
    item_y = 60 + i * 25 + content_offset.y
    item_rect = Rect(60, item_y, 280, 20)
    
    # Only visible items will actually be drawn
    draw_rect!(ctx, item_rect, item_color)
    draw_text!(ctx, font, "Item \$i", -1, Vec2(65, item_y + 5), text_color)
end

pop_clip_rect!(ctx)
```

# Performance considerations
- **O(1) intersection**: Rectangle intersection is constant time
- **Stack efficiency**: Simple push operation on fixed-size stack
- **GPU optimization**: Modern graphics APIs handle clipping efficiently
- **Early termination**: [`check_clip`](@ref) can skip invisible content entirely

# Error handling
- **Stack overflow**: Limited by `CLIPSTACK_SIZE` constant
- **Balanced operations**: Every push must have a corresponding pop
- **Frame validation**: [`end_frame`](@ref) validates stack is empty

# Clipping coordinate system
- **Screen coordinates**: Clipping rectangles use absolute screen coordinates
- **Pixel boundaries**: Clipping typically aligns to pixel boundaries
- **Inclusive/exclusive**: Left/top edges inclusive, right/bottom exclusive

# Common patterns
```julia
# Safe clipping with exception handling
push_clip_rect!(ctx, widget_rect)
try
    draw_widget_content(ctx)
finally
    pop_clip_rect!(ctx)  # Always restore clipping
end

# Conditional clipping
if needs_clipping
    push_clip_rect!(ctx, clip_area)
end

draw_content(ctx)

if needs_clipping
    pop_clip_rect!(ctx)
end
```

# See also
[`pop_clip_rect!`](@ref), [`get_clip_rect`](@ref), [`intersect_rects`](@ref), [`check_clip`](@ref)
"""
function push_clip_rect!(ctx::Context, rect::Rect)
    last = get_clip_rect(ctx)
    push!(ctx.clip_stack, intersect_rects(rect, last))
end

"""
    pop_clip_rect!(ctx::Context)

Remove the current clipping rectangle from the clipping stack.

This function restores the previous clipping state by removing the top
clipping rectangle from the stack. The clipping region reverts to the
state it was in before the last [`push_clip_rect!`](@ref) call.

# Arguments
- `ctx::Context`: The UI context containing the clipping stack

# Effects
- Removes the top clipping rectangle from the stack
- Restores the previous clipping region
- Subsequent drawing operations use the restored clipping

# Throws
- `ErrorException`: If the clipping stack is empty (stack underflow)

# Examples
```julia
# Balanced clipping operations
original_clip = get_clip_rect(ctx)

push_clip_rect!(ctx, widget_bounds)
draw_widget_content(ctx)  # Content clipped to widget_bounds
pop_clip_rect!(ctx)

current_clip = get_clip_rect(ctx)
@assert current_clip == original_clip  # Clipping restored
```

# Exception-safe clipping
```julia
# Ensure clipping is always restored, even if drawing throws
push_clip_rect!(ctx, content_area)
try
    draw_complex_content(ctx)  # May throw exceptions
    draw_more_content(ctx)
finally
    pop_clip_rect!(ctx)  # Always executed
end
```

# Container cleanup pattern
```julia
# Container management with proper cleanup
function draw_container(ctx, container_rect)
    push_clip_rect!(ctx, container_rect)
    
    # Draw container background
    draw_rect!(ctx, container_rect, background_color)
    
    # Draw container content (may have nested clipping)
    draw_container_content(ctx)
    
    # Draw container border (after content)
    draw_box!(ctx, container_rect, border_color)
    
    pop_clip_rect!(ctx)  # Restore previous clipping
end
```

# Multiple nested clipping cleanup
```julia
# Cleanup multiple clipping levels
push_clip_rect!(ctx, level1_bounds)
push_clip_rect!(ctx, level2_bounds) 
push_clip_rect!(ctx, level3_bounds)

try
    draw_deeply_nested_content(ctx)
finally
    # Cleanup in reverse order (LIFO)
    pop_clip_rect!(ctx)  # level3
    pop_clip_rect!(ctx)  # level2  
    pop_clip_rect!(ctx)  # level1
end
```

# Stack validation
```julia
# Check stack depth before operations
initial_depth = ctx.clip_stack.idx

push_clip_rect!(ctx, new_bounds)
# ... drawing operations ...
pop_clip_rect!(ctx)

final_depth = ctx.clip_stack.idx
@assert initial_depth == final_depth "Clipping stack unbalanced"
```

# Performance characteristics
- **O(1) operation**: Simple stack pop operation
- **No computation**: No geometric calculations required
- **Immediate effect**: Clipping change takes effect immediately
- **Stack efficiency**: Fixed-size stack with minimal overhead

# Integration with widget lifecycle
```julia
# Widget with automatic clipping management
function draw_textbox(ctx, rect, text, focused)
    # Establish clipping for text area
    text_area = Rect(rect.x + 2, rect.y + 2, rect.w - 4, rect.h - 4)
    push_clip_rect!(ctx, text_area)
    
    # Draw text (clipped to text area)
    draw_text!(ctx, font, text, -1, Vec2(text_area.x, text_area.y + 12), text_color)
    
    # Draw cursor if focused (also clipped)
    if focused
        cursor_x = text_area.x + measure_text_width(font, text)
        draw_rect!(ctx, Rect(cursor_x, text_area.y, 1, text_area.h), cursor_color)
    end
    
    pop_clip_rect!(ctx)
    
    # Draw border (not clipped to text area)
    draw_box!(ctx, rect, border_color)
end
```

# Debugging clipping issues
```julia
# Visualize clipping regions during development
function debug_draw_clip_rect(ctx)
    clip = get_clip_rect(ctx)
    # Draw semi-transparent overlay to show clipping region
    draw_rect!(ctx, clip, Color(255, 0, 0, 50))  # Red tint
end

# Use before pop_clip_rect! to see what was clipped
push_clip_rect!(ctx, debug_rect)
draw_content(ctx)
debug_draw_clip_rect(ctx)  # Visualize before popping
pop_clip_rect!(ctx)
```

# Stack underflow prevention
```julia
# Safe popping with depth checking
function safe_pop_clip_rect!(ctx)
    if ctx.clip_stack.idx > 0
        pop_clip_rect!(ctx)
        return true
    else
        @warn "Attempted to pop empty clipping stack"
        return false
    end
end
```

# Frame lifecycle integration
The function integrates with frame management:
- **Frame start**: Clipping stack should be empty or have only root clip
- **Frame end**: [`end_frame`](@ref) validates stack is properly balanced
- **Stack persistence**: Clipping stack is reset between frames

# Memory management
- **No allocation**: Uses pre-allocated stack storage
- **Bounded depth**: Maximum nesting limited by `CLIPSTACK_SIZE`
- **Automatic cleanup**: Stack is reset at frame boundaries

# See also
[`push_clip_rect!`](@ref), [`get_clip_rect`](@ref), [`Stack`](@ref), [`CLIPSTACK_SIZE`](@ref)
"""
function pop_clip_rect!(ctx::Context)
    pop!(ctx.clip_stack)
end

"""
    get_clip_rect(ctx::Context) -> Rect

Get the current active clipping rectangle from the top of the clipping stack.

This function returns the clipping rectangle that is currently in effect,
which determines the visible region for all drawing operations. The returned
rectangle represents the intersection of all nested clipping regions.

# Arguments
- `ctx::Context`: The UI context containing the clipping stack

# Returns
- `Rect`: The current clipping rectangle in screen coordinates

# Throws
- `AssertionError`: If the clipping stack is empty (no active clipping)

# Examples
```julia
# Query current clipping state
clip = get_clip_rect(ctx)
println("Clipping region: (\$(clip.x), \$(clip.y)) \$(clip.w)×\$(clip.h)")

# Check if content would be visible
content_rect = Rect(100, 100, 50, 30)
if intersect_rects(clip, content_rect).w > 0
    println("Content is visible")
    draw_content(ctx, content_rect)
else
    println("Content is clipped out")
end
```

# Visibility testing before expensive operations
```julia
# Avoid expensive rendering for invisible content
function draw_complex_widget(ctx, widget_rect)
    clip = get_clip_rect(ctx)
    intersection = intersect_rects(clip, widget_rect)
    
    if intersection.w <= 0 || intersection.h <= 0
        return  # Widget is completely clipped, skip rendering
    end
    
    # Widget is at least partially visible, proceed with rendering
    if intersection == widget_rect
        # Widget is fully visible, use fast path
        draw_widget_fast(ctx, widget_rect)
    else
        # Widget is partially clipped, use clipped rendering
        draw_widget_clipped(ctx, widget_rect, intersection)
    end
end
```

# Coordinate system queries
```julia
# Convert between coordinate systems using clipping info
clip = get_clip_rect(ctx)
layout = get_layout(ctx)

# Available drawing area within current layout
drawable_area = intersect_rects(clip, layout.body)
println("Can draw in: \$(drawable_area.w)×\$(drawable_area.h) pixels")

# Check if point is within drawable area
mouse_pos = ctx.mouse_pos
if rect_overlaps_vec2(drawable_area, mouse_pos)
    println("Mouse is in drawable area")
end
```

# Dynamic content positioning
```julia
# Adjust content based on available clipping space
clip = get_clip_rect(ctx)
content_size = Vec2(200, 100)

# Center content within clipping region
content_x = clip.x + (clip.w - content_size.x) ÷ 2
content_y = clip.y + (clip.h - content_size.y) ÷ 2
content_rect = Rect(content_x, content_y, content_size.x, content_size.y)

# Ensure content doesn't exceed clipping bounds
final_rect = intersect_rects(content_rect, clip)
draw_rect!(ctx, final_rect, content_color)
```

# Scrolling calculations
```julia
# Calculate scroll limits based on clipping region
clip = get_clip_rect(ctx)
content_size = Vec2(500, 800)  # Total content size

# Maximum scroll offsets
max_scroll_x = max(0, content_size.x - clip.w)
max_scroll_y = max(0, content_size.y - clip.h)

# Clamp current scroll to valid range
scroll_x = clamp(current_scroll.x, 0, max_scroll_x)
scroll_y = clamp(current_scroll.y, 0, max_scroll_y)
```

# Text rendering optimization
```julia
# Skip text rendering if clipping makes it invisible
function draw_text_optimized(ctx, font, text, pos, color)
    clip = get_clip_rect(ctx)
    
    # Calculate text bounds
    text_width = ctx.text_width(font, text)
    text_height = ctx.text_height(font)
    text_rect = Rect(pos.x, pos.y, text_width, text_height)
    
    # Quick visibility check
    if intersect_rects(clip, text_rect).w > 0
        draw_text!(ctx, font, text, -1, pos, color)
    end
    # If invisible, skip expensive text rendering
end
```

# Clipping-aware layout calculations
```julia
# Adjust layout based on available clipping space
function layout_within_clip(ctx)
    clip = get_clip_rect(ctx)
    layout = get_layout(ctx)
    
    # Calculate how much of the layout is actually visible
    visible_layout = intersect_rects(layout.body, clip)
    
    if visible_layout.w < 100
        # Not enough space for normal layout, use compact mode
        layout_row!(ctx, 1, [-1], 20)  # Single column, small height
    else
        # Enough space for normal layout
        layout_row!(ctx, 2, [100, -1], 30)  # Two columns
    end
end
```

# Debugging and development tools
```julia
# Visualize current clipping region
function debug_show_clipping(ctx)
    clip = get_clip_rect(ctx)
    
    # Draw clipping bounds
    draw_box!(ctx, clip, Color(255, 0, 0, 255))  # Red border
    
    # Show clipping info as text
    info_text = "Clip: \$(clip.w)×\$(clip.h) at (\$(clip.x),\$(clip.y))"
    draw_text!(ctx, ctx.style.font, info_text, -1, 
              Vec2(clip.x + 5, clip.y + 5), Color(255, 255, 255, 255))
end
```

# Performance optimization patterns
```julia
# Cache clipping rectangle for multiple operations
function draw_multiple_items(ctx, items)
    clip = get_clip_rect(ctx)  # Cache once
    
    for item in items
        # Use cached clip for each item
        if intersect_rects(clip, item.bounds).w > 0
            draw_item(ctx, item)
        end
    end
end
```

# Integration with widget systems
This function is commonly used by:
- **Drawing functions**: To optimize rendering based on visibility
- **Layout systems**: To calculate available space
- **Event handling**: To determine if mouse events should be processed
- **Scrolling systems**: To calculate scroll bounds and visibility

# Coordinate space
The returned rectangle is in screen coordinates:
- **Origin**: Typically top-left corner of the display/window
- **Units**: Pixels in most implementations
- **Bounds**: Represents the actual drawable region after all clipping

# Thread safety
- **Read-only operation**: Safe to call from multiple threads if context is read-only
- **Stack consistency**: Requires external synchronization if stack is being modified
- **Atomic access**: Single rectangle read is atomic on most platforms

# See also
[`push_clip_rect!`](@ref), [`pop_clip_rect!`](@ref), [`check_clip`](@ref), [`intersect_rects`](@ref)
"""
function get_clip_rect(ctx::Context)
    @assert ctx.clip_stack.idx > 0 "No clip rect on stack"
    return ctx.clip_stack.items[ctx.clip_stack.idx]
end

"""
    check_clip(ctx::Context, r::Rect) -> ClipResult

Test the visibility of a rectangle within the current clipping region.

This function determines how a rectangle intersects with the current clipping
region, returning a result that can be used to optimize rendering decisions.
It's a key optimization function that helps avoid unnecessary drawing operations.

# Arguments
- `ctx::Context`: The UI context containing the clipping state
- `r::Rect`: The rectangle to test against the current clipping region

# Returns
- `ClipResult`: The clipping relationship between the rectangle and clip region:
  - [`CLIP_NONE`](@ref): Rectangle is fully visible (no clipping needed)
  - [`CLIP_PART`](@ref): Rectangle is partially visible (clipping required)
  - [`CLIP_ALL`](@ref): Rectangle is completely invisible (skip rendering)

# Optimization strategy
This function enables three-tier rendering optimization:

## `CLIP_ALL` - Complete culling
```julia
if check_clip(ctx, widget_rect) == CLIP_ALL
    return  # Skip all rendering for this widget
end
```

## `CLIP_NONE` - Fast path
```julia
if check_clip(ctx, widget_rect) == CLIP_NONE
    # Widget is fully visible, use optimized rendering
    draw_widget_fast(ctx, widget_rect)
end
```

## `CLIP_PART` - Careful rendering
```julia
if check_clip(ctx, widget_rect) == CLIP_PART
    # Widget is partially visible, set up clipping
    set_clip!(ctx, get_clip_rect(ctx))
    draw_widget_carefully(ctx, widget_rect)
    set_clip!(ctx, UNCLIPPED_RECT)
end
```

# Examples
```julia
# Basic visibility testing
widget_rect = Rect(100, 100, 200, 50)
clip_result = check_clip(ctx, widget_rect)

case clip_result
    CLIP_ALL  => println("Widget is invisible")
    CLIP_PART => println("Widget is partially visible") 
    CLIP_NONE => println("Widget is fully visible")
end

# Optimized widget rendering
function draw_button_optimized(ctx, rect, label)
    clip_result = check_clip(ctx, rect)
    
    if clip_result == CLIP_ALL
        return 0  # Button invisible, no interaction possible
    end
    
    # Draw button background
    if clip_result == CLIP_PART
        set_clip!(ctx, get_clip_rect(ctx))
    end
    
    draw_rect!(ctx, rect, button_color)
    draw_text!(ctx, font, label, -1, Vec2(rect.x + 5, rect.y + 10), text_color)
    
    if clip_result == CLIP_PART
        set_clip!(ctx, UNCLIPPED_RECT)
    end
    
    # Handle interaction (button is at least partially visible)
    return handle_button_interaction(ctx, rect)
end
```

# List rendering with culling
```julia
# Efficiently render large lists by culling invisible items
function draw_list(ctx, items, item_height)
    clip = get_clip_rect(ctx)
    
    for (i, item) in enumerate(items)
        item_y = i * item_height
        item_rect = Rect(clip.x, item_y, clip.w, item_height)
        
        clip_result = check_clip(ctx, item_rect)
        
        if clip_result == CLIP_ALL
            continue  # Skip invisible items completely
        end
        
        if clip_result == CLIP_PART
            # Item is partially visible, set up precise clipping
            set_clip!(ctx, get_clip_rect(ctx))
        end
        
        draw_list_item(ctx, item, item_rect)
        
        if clip_result == CLIP_PART
            set_clip!(ctx, UNCLIPPED_RECT)
        end
    end
end
```

# Text rendering with overflow handling
```julia
# Handle text that might overflow its container
function draw_text_with_overflow(ctx, font, text, container_rect)
    # Calculate text dimensions
    text_width = ctx.text_width(font, text)
    text_height = ctx.text_height(font)
    text_rect = Rect(container_rect.x, container_rect.y, text_width, text_height)
    
    clip_result = check_clip(ctx, text_rect)
    
    case clip_result
        CLIP_ALL => return  # Text is completely invisible
        
        CLIP_NONE => begin
            # Text fits completely, render normally
            draw_text!(ctx, font, text, -1, Vec2(text_rect.x, text_rect.y), color)
        end
        
        CLIP_PART => begin
            # Text overflows, need clipping or truncation
            clip = get_clip_rect(ctx)
            available_width = clip.x + clip.w - text_rect.x
            
            if text_width > available_width
                # Truncate text to fit
                truncated = truncate_text_to_width(font, text, available_width - 20)
                truncated *= "..."
                draw_text!(ctx, font, truncated, -1, Vec2(text_rect.x, text_rect.y), color)
            else
                # Text fits width but may be clipped vertically
                set_clip!(ctx, clip)
                draw_text!(ctx, font, text, -1, Vec2(text_rect.x, text_rect.y), color)
                set_clip!(ctx, UNCLIPPED_RECT)
            end
        end
    end
end
```

# Complex widget with nested elements
```julia
# Widget with multiple parts that may be clipped differently
function draw_complex_widget(ctx, widget_rect)
    # Check overall widget visibility first
    overall_clip = check_clip(ctx, widget_rect)
    
    if overall_clip == CLIP_ALL
        return  # Entire widget invisible
    end
    
    # Draw widget background (always needed if partially visible)
    if overall_clip == CLIP_PART
        set_clip!(ctx, get_clip_rect(ctx))
    end
    
    draw_rect!(ctx, widget_rect, background_color)
    
    if overall_clip == CLIP_PART
        set_clip!(ctx, UNCLIPPED_RECT)
    end
    
    # Check individual widget parts
    icon_rect = Rect(widget_rect.x + 5, widget_rect.y + 5, 16, 16)
    if check_clip(ctx, icon_rect) != CLIP_ALL
        draw_icon!(ctx, ICON_CHECK, icon_rect, icon_color)
    end
    
    text_rect = Rect(widget_rect.x + 25, widget_rect.y + 5, widget_rect.w - 30, 16)
    if check_clip(ctx, text_rect) != CLIP_ALL
        draw_text_with_overflow(ctx, font, widget_text, text_rect)
    end
    
    button_rect = Rect(widget_rect.x + widget_rect.w - 50, widget_rect.y + 25, 45, 20)
    if check_clip(ctx, button_rect) != CLIP_ALL
        draw_button(ctx, button_rect, "Action")
    end
end
```

# Performance benchmarking
```julia
# Measure clipping optimization benefits
function benchmark_clipping_optimization(ctx, widgets)
    # Without clipping optimization
    start_time = time()
    for widget in widgets
        draw_widget_always(ctx, widget)  # Always renders
    end
    time_without_opt = time() - start_time
    
    # With clipping optimization  
    start_time = time()
    for widget in widgets
        if check_clip(ctx, widget.rect) != CLIP_ALL
            draw_widget_optimized(ctx, widget)  # Conditional rendering
        end
    end
    time_with_opt = time() - start_time
    
    speedup = time_without_opt / time_with_opt
    println("Clipping optimization speedup: \$(speedup)x")
end
```

# Algorithm details
The function performs rectangle intersection testing:
```julia
# Pseudocode for the algorithm
clip = get_clip_rect(ctx)

# Test for complete separation (CLIP_ALL)
if (r.x > clip.x + clip.w) || (r.x + r.w < clip.x) ||
   (r.y > clip.y + clip.h) || (r.y + r.h < clip.y)
    return CLIP_ALL
end

# Test for complete containment (CLIP_NONE)  
if (r.x >= clip.x) && (r.x + r.w <= clip.x + clip.w) &&
   (r.y >= clip.y) && (r.y + r.h <= clip.y + clip.h)
    return CLIP_NONE
end

# Otherwise partial overlap (CLIP_PART)
return CLIP_PART
```

# Performance characteristics
- **O(1) complexity**: Constant time regardless of rectangle size
- **Branch predictable**: Common cases (CLIP_NONE) are fast
- **Cache friendly**: Uses only local rectangle data
- **Inlineable**: Simple arithmetic operations suitable for inlining

# Integration with drawing functions
All drawing functions in MicroUI use this for optimization:
- [`draw_rect!`](@ref): Culls invisible rectangles
- [`draw_text!`](@ref): Manages clipping state based on result
- [`draw_icon!`](@ref): Skips invisible icons

# See also
[`ClipResult`](@ref), [`get_clip_rect`](@ref), [`intersect_rects`](@ref), [`CLIP_NONE`](@ref), [`CLIP_PART`](@ref), [`CLIP_ALL`](@ref)
"""
function check_clip(ctx::Context, r::Rect)
    cr = get_clip_rect(ctx)
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

"""
    expand_rect(r::Rect, n::Int) -> Rect

Expand a rectangle by n pixels in all directions.

This utility function creates a new rectangle that is larger than the input
rectangle by the specified amount in each direction. The expansion is symmetric,
adding the same amount to all sides while keeping the rectangle centered.

# Arguments
- `r::Rect`: The original rectangle to expand
- `n::Int`: The number of pixels to expand in each direction

# Returns
- `Rect`: A new rectangle expanded by `n` pixels in all directions

# Expansion calculation
The expansion affects all rectangle dimensions:
```julia
# Mathematical representation
expanded = Rect(
    r.x - n,        # Left edge moves left
    r.y - n,        # Top edge moves up  
    r.w + n * 2,    # Width increases by 2n (n on each side)
    r.h + n * 2     # Height increases by 2n (n on each side)
)
```

# Examples
```julia
# Basic rectangle expansion
original = Rect(100, 100, 50, 30)
expanded = expand_rect(original, 5)
# Result: Rect(95, 95, 60, 40)

# Create padding around content
content_rect = Rect(50, 50, 200, 100)
padded_rect = expand_rect(content_rect, 10)
# Creates 10-pixel padding on all sides

# Border calculations
widget_rect = Rect(20, 20, 100, 50)
border_rect = expand_rect(widget_rect, 1)
# Creates 1-pixel border around widget

# Hit testing areas
button_rect = Rect(10, 10, 80, 25)
hit_area = expand_rect(button_rect, 3)
# Larger hit area for easier clicking
```

# Widget frame rendering
```julia
# Draw widget with background and border
function draw_widget_frame(ctx, inner_rect, background_color, border_color)
    # Expand for border
    outer_rect = expand_rect(inner_rect, 1)
    
    # Draw border first (larger rectangle)
    draw_rect!(ctx, outer_rect, border_color)
    
    # Draw background over border (smaller rectangle)
    draw_rect!(ctx, inner_rect, background_color)
end
```

# Padding and margin calculations
```julia
# Add padding around content area
content_area = layout_next(ctx)
padding = 8

# Content goes in the original area
draw_content(ctx, content_area)

# Background includes padding
background_area = expand_rect(content_area, padding)
draw_rect!(ctx, background_area, background_color)

# Border goes around everything
border_area = expand_rect(background_area, 1)
draw_box!(ctx, border_area, border_color)
```

# Hit testing and interaction zones
```julia
# Create larger interaction area for small controls
function is_mouse_over_button(ctx, button_rect)
    # Small buttons get expanded hit area for easier clicking
    hit_rect = if button_rect.w < 40 || button_rect.h < 30
        expand_rect(button_rect, 5)  # Expand small buttons
    else
        button_rect  # Normal buttons use exact bounds
    end
    
    return rect_overlaps_vec2(hit_rect, ctx.mouse_pos)
end
```

# Clipping region calculations
```julia
# Create clipping region with margin
function setup_content_clipping(ctx, container_rect)
    # Content area is inset from container edges
    margin = 5
    content_rect = Rect(
        container_rect.x + margin,
        container_rect.y + margin,
        container_rect.w - margin * 2,
        container_rect.h - margin * 2
    )
    
    # Equivalent to:
    # content_rect = expand_rect(container_rect, -margin)
    
    push_clip_rect!(ctx, content_rect)
end
```

# Negative expansion (shrinking)
```julia
# Shrink rectangle by using negative expansion
outer_rect = Rect(10, 10, 100, 80)
inner_rect = expand_rect(outer_rect, -5)
# Result: Rect(15, 15, 90, 70) - 5 pixels smaller on all sides

# Content area inside a border
border_thickness = 2
border_rect = Rect(50, 50, 120, 60)
content_rect = expand_rect(border_rect, -border_thickness)
# Content area is 2 pixels inside the border on all sides
```

# UI layout with consistent spacing
```julia
# Create grid of widgets with consistent spacing
grid_spacing = 10
widget_size = Vec2(80, 30)

for row in 0:2
    for col in 0:3
        # Base position
        base_rect = Rect(
            col * (widget_size.x + grid_spacing),
            row * (widget_size.y + grid_spacing),
            widget_size.x,
            widget_size.y
        )
        
        # Expanded for hover effect
        if is_widget_hovered(row, col)
            hover_rect = expand_rect(base_rect, 2)
            draw_rect!(ctx, hover_rect, hover_color)
        end
        
        # Draw normal widget
        draw_widget(ctx, base_rect)
    end
end
```

# Shadow and effect calculations
```julia
# Drop shadow effect
widget_rect = Rect(100, 100, 120, 40)

# Shadow is offset and expanded
shadow_offset = Vec2(3, 3)
shadow_rect = Rect(
    widget_rect.x + shadow_offset.x,
    widget_rect.y + shadow_offset.y,
    widget_rect.w,
    widget_rect.h
)
shadow_expanded = expand_rect(shadow_rect, 2)  # Blur effect

# Draw shadow first
draw_rect!(ctx, shadow_expanded, Color(0, 0, 0, 50))  # Semi-transparent black

# Draw widget on top
draw_rect!(ctx, widget_rect, widget_color)
```

# Validation and edge cases
```julia
# Handle edge cases gracefully
function safe_expand_rect(r::Rect, n::Int)
    expanded = expand_rect(r, n)
    
    # Ensure non-negative dimensions
    if expanded.w < 0
        expanded = Rect(expanded.x + expanded.w ÷ 2, expanded.y, 0, expanded.h)
    end
    if expanded.h < 0
        expanded = Rect(expanded.x, expanded.y + expanded.h ÷ 2, expanded.w, 0)
    end
    
    return expanded
end

# Example: Very small rectangle with large negative expansion
tiny_rect = Rect(100, 100, 5, 5)
over_shrunk = expand_rect(tiny_rect, -10)
# Result: Rect(90, 90, -15, -15) - Invalid dimensions!

# Safe version would clamp to zero
safe_result = safe_expand_rect(tiny_rect, -10)
# Result: Rect(97, 97, 0, 0) - Valid but empty rectangle
```

# Performance notes
- **O(1) operation**: Simple arithmetic calculations
- **No allocation**: Returns new rectangle by value
- **Inlineable**: Simple enough for compiler optimization
- **Overflow safe**: Integer arithmetic within typical coordinate ranges

# Common usage patterns
- **Widget borders**: `expand_rect(widget, 1)` for 1-pixel borders
- **Padding areas**: `expand_rect(content, padding)` for backgrounds
- **Hit testing**: `expand_rect(small_widget, 5)` for easier interaction
- **Clipping setup**: `expand_rect(container, -margin)` for content areas
- **Effect regions**: `expand_rect(widget, blur_radius)` for shadows/glows

# See also
[`Rect`](@ref), [`push_clip_rect!`](@ref), [`draw_box!`](@ref), [`rect_overlaps_vec2`](@ref)
"""
function expand_rect(r::Rect, n::Int)
    return Rect(r.x - n, r.y - n, r.w + n * 2, r.h + n * 2)
end

"""
    intersect_rects(r1::Rect, r2::Rect) -> Rect

Calculate the intersection of two rectangles.

This function computes the overlapping area between two rectangles,
returning a new rectangle that represents only the region where both
input rectangles overlap. If there is no overlap, the result will be
a rectangle with zero or negative width/height.

# Arguments
- `r1::Rect`: The first rectangle
- `r2::Rect`: The second rectangle

# Returns
- `Rect`: The intersection rectangle representing the overlapping area

# Intersection algorithm
The intersection is calculated by finding the overlapping bounds:
```julia
# Mathematical representation
left = max(r1.x, r2.x)                    # Rightmost left edge
top = max(r1.y, r2.y)                     # Bottommost top edge  
right = min(r1.x + r1.w, r2.x + r2.w)     # Leftmost right edge
bottom = min(r1.y + r1.h, r2.y + r2.h)    # Topmost bottom edge

intersection = Rect(left, top, max(0, right - left), max(0, bottom - top))
```

# Examples
```julia
# Basic intersection
rect1 = Rect(10, 10, 100, 80)    # Rectangle from (10,10) to (110,90)
rect2 = Rect(50, 30, 80, 60)     # Rectangle from (50,30) to (130,90)
overlap = intersect_rects(rect1, rect2)
# Result: Rect(50, 30, 60, 60) - from (50,30) to (110,90)

# No intersection
rect1 = Rect(0, 0, 50, 50)       # Rectangle from (0,0) to (50,50)
rect2 = Rect(100, 100, 50, 50)   # Rectangle from (100,100) to (150,150)
overlap = intersect_rects(rect1, rect2)
# Result: Rect(100, 100, 0, 0) - no overlap, zero area

# Partial intersection
rect1 = Rect(20, 20, 60, 40)     # Rectangle from (20,20) to (80,60)
rect2 = Rect(70, 10, 40, 40)     # Rectangle from (70,10) to (110,50)
overlap = intersect_rects(rect1, rect2)
# Result: Rect(70, 20, 10, 30) - small overlapping area
```

# Clipping system integration
```julia
# Used extensively in the clipping system
function push_clip_rect!(ctx, new_clip)
    current_clip = get_clip_rect(ctx)
    effective_clip = intersect_rects(current_clip, new_clip)
    push!(ctx.clip_stack, effective_clip)
end

# Only the intersection of all clipping regions is actually drawable
window_clip = Rect(0, 0, 800, 600)      # Window bounds
panel_clip = Rect(50, 50, 300, 200)     # Panel within window
widget_clip = Rect(60, 80, 150, 100)    # Widget within panel

# Effective clipping is the intersection of all three
final_clip = intersect_rects(
    intersect_rects(window_clip, panel_clip),
    widget_clip
)
# Result: Rect(60, 80, 150, 100) - widget is fully within panel and window
```

# Visibility testing
```julia
# Test if a widget is visible within current clipping
function is_widget_visible(ctx, widget_rect)
    clip = get_clip_rect(ctx)
    intersection = intersect_rects(widget_rect, clip)
    return intersection.w > 0 && intersection.h > 0
end

# Calculate visible portion of content
function get_visible_content_area(content_rect, viewport_rect)
    visible_area = intersect_rects(content_rect, viewport_rect)
    
    if visible_area.w <= 0 || visible_area.h <= 0
        return nothing  # No visible content
    end
    
    return visible_area
end
```

# Scrolling calculations
```julia
# Calculate which portion of scrolled content is visible
function calculate_visible_scroll_region(content_size, viewport_rect, scroll_offset)
    # Content rectangle accounting for scroll
    content_rect = Rect(
        viewport_rect.x - scroll_offset.x,
        viewport_rect.y - scroll_offset.y,
        content_size.x,
        content_size.y
    )
    
    # Only the intersection with viewport is actually visible
    visible_region = intersect_rects(content_rect, viewport_rect)
    
    return visible_region
end

# Example: Scrollable text area
text_content_size = Vec2(500, 1000)  # Large text content
text_viewport = Rect(100, 100, 200, 150)  # Small viewport
current_scroll = Vec2(50, 200)  # Scrolled right 50, down 200

visible_text = calculate_visible_scroll_region(
    text_content_size, text_viewport, current_scroll
)
# Only this portion of the text needs to be rendered
```

# Collision detection
```julia
# Test if two UI elements collide (useful for drag & drop)
function elements_collide(element1_rect, element2_rect)
    collision_area = intersect_rects(element1_rect, element2_rect)
    return collision_area.w > 0 && collision_area.h > 0
end

# Find overlapping widgets in a layout
function find_overlapping_widgets(widgets)
    overlaps = []
    
    for i in 1:length(widgets)
        for j in (i+1):length(widgets)
            intersection = intersect_rects(widgets[i].rect, widgets[j].rect)
            if intersection.w > 0 && intersection.h > 0
                push!(overlaps, (i, j, intersection))
            end
        end
    end
    
    return overlaps
end
```

# Layout constraint solving
```julia
# Fit content within available space
function fit_content_to_bounds(content_rect, bounds_rect)
    # Calculate intersection to see how much fits
    fitting_area = intersect_rects(content_rect, bounds_rect)
    
    if fitting_area.w >= content_rect.w && fitting_area.h >= content_rect.h
        # Content fits completely
        return content_rect
    else
        # Content needs to be clipped or resized
        return Rect(
            max(content_rect.x, bounds_rect.x),
            max(content_rect.y, bounds_rect.y),
            min(content_rect.w, bounds_rect.w),
            min(content_rect.h, bounds_rect.h)
        )
    end
end
```

# Multi-region operations
```julia
# Calculate intersection of multiple rectangles
function intersect_multiple_rects(rects::Vector{Rect})
    if isempty(rects)
        return Rect(0, 0, 0, 0)
    end
    
    result = rects[1]
    for i in 2:length(rects)
        result = intersect_rects(result, rects[i])
        if result.w <= 0 || result.h <= 0
            return Rect(0, 0, 0, 0)  # No intersection
        end
    end
    
    return result
end

# Example: Widget visible in nested containers
widget_rect = Rect(75, 75, 50, 30)
container_clips = [
    Rect(50, 50, 200, 150),  # Outer container
    Rect(70, 60, 100, 80),   # Middle container  
    Rect(60, 70, 80, 60)     # Inner container
]

# Widget is only visible where all containers overlap
visible_widget = intersect_multiple_rects([widget_rect, container_clips...])
```

# Performance optimization
```julia
# Early termination for obviously non-intersecting rectangles
function fast_intersect_rects(r1::Rect, r2::Rect)
    # Quick separation tests (most common case)
    if r1.x > r2.x + r2.w || r2.x > r1.x + r1.w ||
       r1.y > r2.y + r2.h || r2.y > r1.y + r1.h
        return Rect(0, 0, 0, 0)  # No intersection
    end
    
    # Calculate actual intersection (less common case)
    return intersect_rects(r1, r2)
end
```

# Debugging and visualization
```julia
# Visualize rectangle intersections for debugging
function debug_show_intersection(ctx, r1, r2)
    intersection = intersect_rects(r1, r2)
    
    # Draw original rectangles
    draw_box!(ctx, r1, Color(255, 0, 0, 255))    # Red outline
    draw_box!(ctx, r2, Color(0, 255, 0, 255))    # Green outline
    
    # Highlight intersection
    if intersection.w > 0 && intersection.h > 0
        draw_rect!(ctx, intersection, Color(255, 255, 0, 128))  # Yellow overlay
    end
end
```

# Edge cases and validation
- **No intersection**: Results in rectangle with zero or negative area
- **Identical rectangles**: Intersection equals the original rectangles  
- **Contained rectangles**: Smaller rectangle is the intersection
- **Point intersections**: May result in zero-area rectangles
- **Negative coordinates**: Algorithm works with negative coordinate values

# Performance characteristics
- **O(1) complexity**: Constant time regardless of rectangle size
- **No allocation**: Returns rectangle by value
- **Cache friendly**: Simple arithmetic operations
- **Predictable branches**: Common cases are optimized by CPU branch prediction

# See also
[`Rect`](@ref), [`check_clip`](@ref), [`push_clip_rect!`](@ref), [`expand_rect`](@ref)
"""
function intersect_rects(r1::Rect, r2::Rect)
    x1 = max(r1.x, r2.x)
    y1 = max(r1.y, r2.y)
    x2 = min(r1.x + r1.w, r2.x + r2.w)
    y2 = min(r1.y + r1.h, r2.y + r2.h)
    Rect(x1, y1, max(0, x2-x1), max(0, y2-y1))
end