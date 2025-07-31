# ===== DRAWING FUNCTIONS =====
# High-level drawing functions that create appropriate commands

"""
Draw filled rectangle with clipping
Only draws visible portions of the rectangle
"""
function draw_rect!(ctx::Context, rect::Rect, color::Color)
    rect = intersect_rects(rect, get_clip_rect(ctx))
    if rect.w > 0 && rect.h > 0
        rect_cmd = RectCommand(
            BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
            rect, color
        )
        push_command!(ctx, rect_cmd)
    end
end

"""
Draw rectangle outline (border)
Draws four separate rectangles for top, bottom, left, and right edges
"""
function draw_box!(ctx::Context, rect::Rect, color::Color)
    draw_rect!(ctx, Rect(rect.x + 1, rect.y, rect.w - 2, 1), color)
    draw_rect!(ctx, Rect(rect.x + 1, rect.y + rect.h - 1, rect.w - 2, 1), color)
    draw_rect!(ctx, Rect(rect.x, rect.y, 1, rect.h), color)
    draw_rect!(ctx, Rect(rect.x + rect.w - 1, rect.y, 1, rect.h), color)
end

"""Unclipped rectangle for resetting clipping state"""
const UNCLIPPED_RECT = Rect(0, 0, 0x1000000, 0x1000000)

"""
Draw text string with automatic clipping handling
Sets up clipping if needed and creates text command
"""
function draw_text!(ctx::Context, font::Font, str::String, len::Int, pos::Vec2, color::Color)
    rect = Rect(
        pos.x, pos.y,
        Int32(ctx.text_width(font, str)),
        Int32(ctx.text_height(font))
    )
    clipped = check_clip(ctx, rect)
    
    if clipped == CLIP_ALL
        return
    end
    
    if clipped == CLIP_PART
        set_clip!(ctx, get_clip_rect(ctx))
    end
    
    # Create text command
    if len < 0
        len = length(str)
    end
    
    substr = len == length(str) ? str : str[1:min(len, length(str))]
    push_text_command!(ctx, font, substr, pos, color)
    
    # Reset clipping if it was modified
    if clipped != CLIP_NONE
        set_clip!(ctx, UNCLIPPED_RECT)
    end
end

"""
Draw built-in icon with automatic clipping
Icons are simple geometric shapes rendered by the backend
"""
function draw_icon!(ctx::Context, id::IconId, rect::Rect, color::Color)
    clipped = check_clip(ctx, rect)
    
    if clipped == CLIP_ALL
        return
    end
    
    if clipped == CLIP_PART
        set_clip!(ctx, get_clip_rect(ctx))
    end
    
    icon_cmd = IconCommand(
        BaseCommand(COMMAND_ICON, sizeof(IconCommand)),
        rect, id, color
    )
    push_command!(ctx, icon_cmd)
    
    if clipped != CLIP_NONE
        set_clip!(ctx, UNCLIPPED_RECT)
    end
end