# ===== LAYOUT MANAGEMENT =====
# Functions for managing widget positioning and sizing

"""Layout positioning modes"""
const RELATIVE = 1
const ABSOLUTE = 2

"""
Create new layout context with given body rectangle and scroll offset
Used when entering containers or column layouts
"""
function push_layout!(ctx::Context, body::Rect, scroll::Vec2)
    layout = Layout()
    layout.body = Rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h)
    layout.max = Vec2(typemin(Int32), typemin(Int32))
    push!(ctx.layout_stack, layout)
    width = 0
    layout_row!(ctx, 1, [width], 0)
end

"""Get current layout context from stack"""
function get_layout(ctx::Context)
    @assert ctx.layout_stack.idx > 0 "No layout on stack"
    return ctx.layout_stack.items[ctx.layout_stack.idx]
end

"""
Pop container and update its content size
Called when exiting containers to finalize layout
"""
function pop_container!(ctx::Context)
    cnt = get_current_container(ctx)
    layout = get_layout(ctx)
    cnt.content_size = Vec2(
        layout.max.x - layout.body.x,
        layout.max.y - layout.body.y
    )
    pop!(ctx.container_stack)
    pop!(ctx.layout_stack)
    pop_id!(ctx)
end

"""Start column layout context within current layout"""
function layout_begin_column!(ctx::Context)
    push_layout!(ctx, layout_next(ctx), Vec2(0, 0))
end

"""
End column layout and merge extents with parent
Updates parent layout's position and maximum extents
"""
function layout_end_column!(ctx::Context)
    b = get_layout(ctx)
    pop!(ctx.layout_stack)
    # Inherit position/next_row/max from child layout
    a = get_layout(ctx)
    a.position = Vec2(
        max(a.position.x, b.position.x + b.body.x - a.body.x),
        a.position.y
    )
    a.next_row = max(a.next_row, b.next_row + b.body.y - a.body.y)
    a.max = Vec2(max(a.max.x, b.max.x), max(a.max.y, b.max.y))
end

"""
Set up new layout row with specified items and dimensions
Controls how widgets are positioned horizontally
"""
function layout_row!(ctx::Context, items::Int, widths::Union{Nothing, Vector{Int}}, height::Int)
    layout = get_layout(ctx)
    if widths !== nothing
        @assert items <= MAX_WIDTHS "Too many layout items"
        for i in 1:items
            layout.widths[i] = Int32(widths[i])
        end
    end
    layout.items = Int32(items)
    layout.position = Vec2(layout.indent, layout.next_row)
    layout.size = Vec2(layout.size.x, Int32(height))
    layout.item_index = 0
end

"""Set default width for next widget"""
function layout_width!(ctx::Context, width::Int)
    get_layout(ctx).size = Vec2(Int32(width), get_layout(ctx).size.y)
end

"""Set default height for next widget"""
function layout_height!(ctx::Context, height::Int)
    get_layout(ctx).size = Vec2(get_layout(ctx).size.x, Int32(height))
end

"""
Manually set rectangle for next widget
Can be relative to current position or absolute
"""
function layout_set_next!(ctx::Context, r::Rect, relative::Bool)
    layout = get_layout(ctx)
    layout.next = r
    layout.next_type = relative ? RELATIVE : ABSOLUTE
end

"""
Calculate and return rectangle for next widget
Handles both manual positioning and automatic layout flow
"""
function layout_next(ctx::Context)
    layout = get_layout(ctx)
    style = ctx.style
    
    if layout.next_type != 0
        # Use manually set rectangle
        type = layout.next_type
        layout.next_type = 0
        res = layout.next
        if type == ABSOLUTE
            ctx.last_rect = res
            return res
        end
    else
        # Automatic layout positioning
        if layout.item_index == layout.items
            layout_row!(ctx, Int(layout.items), nothing, Int(layout.size.y))
        end
        
        # Calculate position
        res = Rect(layout.position.x, layout.position.y, 0, 0)
        
        # Calculate size
        if layout.items > 0
            res = Rect(res.x, res.y, layout.widths[layout.item_index + 1], res.h)
        else
            res = Rect(res.x, res.y, layout.size.x, res.h)
        end
        
        res = Rect(res.x, res.y, res.w, layout.size.y)
        
        # Apply default sizes if zero
        if res.w == 0
            res = Rect(res.x, res.y, style.size.x + style.padding * 2, res.h)
        end
        if res.h == 0  
            res = Rect(res.x, res.y, res.w, style.size.y + style.padding * 2)
        end
        # Handle negative sizes (fill remaining space)
        if res.w < 0
            res = Rect(res.x, res.y, res.w + layout.body.w - res.x + 1, res.h)
        end
        if res.h < 0
            res = Rect(res.x, res.y, res.w, res.h + layout.body.h - res.y + 1)
        end
        
        layout.item_index += 1
    end
    
    # Update layout position for next widget
    layout.position = Vec2(layout.position.x + res.w + style.spacing, layout.position.y)
    layout.next_row = max(layout.next_row, res.y + res.h + style.spacing)
    
    # Convert to screen coordinates
    res = Rect(res.x + layout.body.x, res.y + layout.body.y, res.w, res.h)
    
    # Track maximum extents
    layout.max = Vec2(max(layout.max.x, res.x + res.w), max(layout.max.y, res.y + res.h))
    
    ctx.last_rect = res
    return res
end