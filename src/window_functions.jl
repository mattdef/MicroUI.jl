# ===== WINDOW MANAGEMENT =====
# High-level window and popup management functions

"""
Begin window with full customization options
Creates moveable, resizable window with title bar and optional controls
"""
function begin_window_ex(ctx::Context, title::String, rect::Rect, opt::UInt16)
    body = rect
    id = get_id(ctx, title)
    cnt = get_container(ctx, id, opt)
    if cnt === nothing || !cnt.open
        return 0
    end
    push_id!(ctx, title)
    
    # Initialize window rectangle if not set
    if cnt.rect.w == 0
        cnt.rect = rect
    end
    begin_root_container!(ctx, cnt)
    rect = body = cnt.rect
    
    # Draw window background
    if (opt & UInt16(OPT_NOFRAME)) == 0
        ctx.draw_frame(ctx, rect, COLOR_WINDOWBG)
    end
    
    # Handle title bar
    if (opt & UInt16(OPT_NOTITLE)) == 0
        tr = Rect(rect.x, rect.y, rect.w, ctx.style.title_height)
        ctx.draw_frame(ctx, tr, COLOR_TITLEBG)
        
        # Handle title bar dragging
        title_id = get_id(ctx, "!title")
        update_control!(ctx, title_id, tr, opt)
        draw_control_text!(ctx, title, tr, COLOR_TITLETEXT, opt)
        if title_id == ctx.focus && (ctx.mouse_down & UInt8(MOUSE_LEFT)) != 0
            cnt.rect = Rect(
                cnt.rect.x + ctx.mouse_delta.x,
                cnt.rect.y + ctx.mouse_delta.y,
                cnt.rect.w,
                cnt.rect.h
            )
        end
        body = Rect(body.x, body.y + tr.h, body.w, body.h - tr.h)
        
        # Handle close button
        if (opt & UInt16(OPT_NOCLOSE)) == 0
            close_id = get_id(ctx, "!close")
            r = Rect(tr.x + tr.w - tr.h, tr.y, tr.h, tr.h)
            tr = Rect(tr.x, tr.y, tr.w - r.w, tr.h)
            draw_icon!(ctx, ICON_CLOSE, r, ctx.style.colors[Int(COLOR_TITLETEXT)])
            update_control!(ctx, close_id, r, opt)
            if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0 && close_id == ctx.focus
                cnt.open = false
            end
        end
    end
    
    push_container_body!(ctx, cnt, body, opt)
    
    # Handle resize handle
    if (opt & UInt16(OPT_NORESIZE)) == 0
        sz = ctx.style.title_height
        resize_id = get_id(ctx, "!resize")
        r = Rect(rect.x + rect.w - sz, rect.y + rect.h - sz, sz, sz)
        update_control!(ctx, resize_id, r, opt)
        if resize_id == ctx.focus && (ctx.mouse_down & UInt8(MOUSE_LEFT)) != 0
            cnt.rect = Rect(
                cnt.rect.x,
                cnt.rect.y,
                max(96, cnt.rect.w + ctx.mouse_delta.x),
                max(64, cnt.rect.h + ctx.mouse_delta.y)
            )
        end
    end
    
    # Auto-resize to content
    if (opt & UInt16(OPT_AUTOSIZE)) != 0
        r = get_layout(ctx).body
        cnt.rect = Rect(
            cnt.rect.x,
            cnt.rect.y,
            cnt.content_size.x + (cnt.rect.w - r.w),
            cnt.content_size.y + (cnt.rect.h - r.h)
        )
    end
    
    # Close popup if clicked elsewhere
    if (opt & UInt16(OPT_POPUP)) != 0 && ctx.mouse_pressed != 0 && ctx.hover_root !== cnt
        cnt.open = false
    end
    
    push_clip_rect!(ctx, cnt.body)
    return Int(RES_ACTIVE)
end

"""Simple window widget"""
begin_window(ctx::Context, title::String, rect::Rect) = begin_window_ex(ctx, title, rect, UInt16(0))

"""End window and clean up"""
function end_window(ctx::Context)
    pop_clip_rect!(ctx)
    end_root_container!(ctx)
end

"""
Open popup window at mouse position
Sets up popup to appear at current mouse location
"""
function open_popup!(ctx::Context, name::String)
    cnt = get_container(ctx, name)
    if cnt !== nothing
        # Set as hover root so popup isn't closed immediately
        ctx.hover_root = ctx.next_hover_root = cnt
        # Position at mouse cursor
        cnt.rect = Rect(ctx.mouse_pos.x, ctx.mouse_pos.y, 1, 1)
        cnt.open = true
        bring_to_front!(ctx, cnt)
    end
end

"""
Begin popup window
Creates auto-sizing popup with no title bar or resize controls
"""
function begin_popup(ctx::Context, name::String)
    opt = UInt16(OPT_POPUP) | UInt16(OPT_AUTOSIZE) | UInt16(OPT_NORESIZE) |
          UInt16(OPT_NOSCROLL) | UInt16(OPT_NOTITLE) | UInt16(OPT_CLOSED)
    return begin_window_ex(ctx, name, Rect(0, 0, 0, 0), opt)
end

"""End popup window"""
end_popup(ctx::Context) = end_window(ctx)

"""
Begin panel container
Creates nested container within current layout
"""
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

"""Simple panel widget"""
begin_panel(ctx::Context, name::String) = begin_panel_ex(ctx, name, UInt16(0))

"""End panel container"""
function end_panel(ctx::Context)
    pop_clip_rect!(ctx)
    pop_container!(ctx)
end