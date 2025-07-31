# ===== CLIPPING FUNCTIONS =====
# Functions for managing clipping rectangles

"""Push new clipping rectangle onto stack"""
function push_clip_rect!(ctx::Context, rect::Rect)
    last = get_clip_rect(ctx)
    push!(ctx.clip_stack, intersect_rects(rect, last))
end

"""Remove current clipping rectangle from stack"""
function pop_clip_rect!(ctx::Context)
    pop!(ctx.clip_stack)
end

"""Get current clipping rectangle"""
function get_clip_rect(ctx::Context)
    @assert ctx.clip_stack.idx > 0 "No clip rect on stack"
    return ctx.clip_stack.items[ctx.clip_stack.idx]
end

"""
Test if rectangle is visible within current clipping region
Returns clipping result for optimization decisions
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

"""Expand rectangle by n pixels in all directions"""
function expand_rect(r::Rect, n::Int)
    return Rect(r.x - n, r.y - n, r.w + n * 2, r.h + n * 2)
end

"""
Calculate intersection of two rectangles
Returns rectangle representing overlapping area
"""
function intersect_rects(r1::Rect, r2::Rect)
    x1 = max(r1.x, r2.x)
    y1 = max(r1.y, r2.y)
    x2 = min(r1.x + r1.w, r2.x + r2.w)
    y2 = min(r1.y + r1.h, r2.y + r2.h)
    Rect(x1, y1, max(0, x2-x1), max(0, y2-y1))
end