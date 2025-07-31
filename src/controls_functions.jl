# ===== CONTROL HELPERS =====
# Helper functions for implementing interactive widgets

"""
Check if current container stack contains the hover root
Used to determine if widgets should respond to mouse input
"""
function in_hover_root(ctx::Context)
    i = ctx.container_stack.idx
    while i > 0
        if ctx.container_stack.items[i] === ctx.hover_root
            return true
        end
        # Only root containers have their head field set
        if ctx.container_stack.items[i].head != 0
            break
        end
        i -= 1
    end
    return false
end

"""
Draw control frame with state-dependent styling
Automatically selects color based on focus and hover state
"""
function draw_control_frame!(ctx::Context, id::Id, rect::Rect, colorid::ColorId, opt::UInt16)
    if (opt & UInt16(OPT_NOFRAME)) != 0
        return
    end
    color_idx = Int(colorid)
    if ctx.focus == id
        color_idx += 2  # Use focused color variant
    elseif ctx.hover == id
        color_idx += 1  # Use hover color variant
    end
    ctx.draw_frame(ctx, rect, ColorId(color_idx))
end

"""
Draw control text with proper alignment and clipping
Handles text positioning within widget rectangles
"""
function draw_control_text!(ctx::Context, str::String, rect::Rect, colorid::ColorId, opt::UInt16)
    font = ctx.style.font
    tw = ctx.text_width(font, str)
    push_clip_rect!(ctx, rect)
    
    pos_y = rect.y + (rect.h - ctx.text_height(font)) ÷ 2
    
    # Handle text alignment
    if (opt & UInt16(OPT_ALIGNCENTER)) != 0
        pos_x = rect.x + (rect.w - tw) ÷ 2
    elseif (opt & UInt16(OPT_ALIGNRIGHT)) != 0
        pos_x = rect.x + rect.w - tw - ctx.style.padding
    else
        pos_x = rect.x + ctx.style.padding
    end
    
    draw_text!(ctx, font, str, -1, Vec2(pos_x, pos_y), ctx.style.colors[Int(colorid)])
    pop_clip_rect!(ctx)
end

"""
Test if mouse is over widget rectangle
Considers clipping and hover root for proper interaction
"""
function mouse_over(ctx::Context, rect::Rect)
    return rect_overlaps_vec2(rect, ctx.mouse_pos) &&
           rect_overlaps_vec2(get_clip_rect(ctx), ctx.mouse_pos) &&
           in_hover_root(ctx)
end

"""
Update widget interaction state
Handles hover, focus, and click detection for interactive widgets
"""
function update_control!(ctx::Context, id::Id, rect::Rect, opt::UInt16)
    mouseover = mouse_over(ctx, rect)
    
    if ctx.focus == id
        ctx.updated_focus = true
    end
    
    if (opt & UInt16(OPT_NOINTERACT)) != 0
        return
    end
    
    # Set hover when mouse over and no buttons pressed
    if mouseover && ctx.mouse_down == 0
        ctx.hover = id
    end
    
    # Handle focus changes
    if ctx.focus == id
        if ctx.mouse_pressed != 0 && !mouseover
            set_focus!(ctx, UInt32(0))
        end
        if ctx.mouse_down == 0 && (opt & UInt16(OPT_HOLDFOCUS)) == 0
            set_focus!(ctx, UInt32(0))
        end
    end
    
    # Handle hover changes and focus acquisition
    if ctx.hover == id
        if ctx.mouse_pressed != 0
            set_focus!(ctx, id)
        elseif !mouseover
            ctx.hover = 0
        end
    end
end

# ===== WIDGETS =====
# Implementation of all interactive UI widgets

"""
Multi-line text display widget
Automatically handles word wrapping and line breaks
"""
function text(ctx::Context, text::String)
    # Early return for empty text
    if isempty(text)
        return
    end
    
    # Cache frequently used values
    font = ctx.style.font
    color = ctx.style.colors[Int(COLOR_TEXT)]
    
    # Get container dimensions directly (bypasses layout system)
    container = get_current_container(ctx)
    available_width = container.body.w - (ctx.style.padding * 2)
    line_height = ctx.text_height(font)
    
    # Starting position
    x = container.body.x + ctx.style.padding
    y = container.body.y + ctx.style.padding
    
    # Pre-calculate space width once (optimization)
    space_width = ctx.text_width(font, " ")
    car_width = ctx.text_width(font, "W")
    
    # Text processing variables (C-style approach)
    text_len = length(text)
    pos = 1  # Current position in text (1-based indexing)
    
    # Main text processing loop
    while pos <= text_len
        # Line building variables
        line_start = pos
        line_width = 0
        last_word_end = pos
        words_on_line = 0
        
        # Phase 1: Determine line break position (zero allocations)
        while pos <= text_len
            # Skip leading spaces
            while pos <= text_len && text[pos] == ' '
                pos += 1
            end
            
            # Check for end of text
            if pos > text_len
                break
            end
            
            # Handle explicit newlines
            if text[pos] == '\n'
                pos += 1
                break
            end
            
            # Find end of current word
            word_start = pos
            while pos <= text_len && text[pos] != ' ' && text[pos] != '\n'
                pos += 1
            end
            
            # Calculate word width (using character count estimation for speed)
            # Note: 8px per character is a rough estimate - adjust based on your font
            word_len = pos - word_start
            estimated_word_width = word_len * car_width
            
            # Calculate space needed (only if not first word on line)
            space_needed = (words_on_line > 0) ? space_width : 0
            total_needed = line_width + space_needed + estimated_word_width
            
            # Check if word fits on current line
            if total_needed > available_width && words_on_line > 0
                # Word doesn't fit, break line here
                break
            end
            
            # Word fits, add it to current line
            line_width = total_needed
            last_word_end = pos
            words_on_line += 1
        end
        
        # Phase 2: Render the line (one allocation per line for draw_text!)
        if last_word_end > line_start
            # Trim trailing spaces
            actual_end = last_word_end
            while actual_end > line_start && 
                  actual_end <= text_len && 
                  text[actual_end-1] == ' '
                actual_end -= 1
            end
            
            # Render line if it has content
            if actual_end > line_start
                # Single substring allocation per line (unavoidable with current API)
                line_text = text[line_start:actual_end-1]
                draw_text!(ctx, font, line_text, -1, Vec2(x, y), color)
            end
        end
        
        # Move to next line
        y += line_height
        
        # Safety check to prevent infinite loops
        if pos == line_start
            pos += 1
        end
    end
end

"""
Simple text label widget
Displays single line of text within widget rectangle
"""
function label(ctx::Context, text::String)
    draw_control_text!(ctx, text, layout_next(ctx), COLOR_TEXT, UInt16(0))
end

"""
Button widget with full customization options
Returns RES_SUBMIT flag when clicked
"""
function button_ex(ctx::Context, label::String, icon::Union{Nothing, IconId}, opt::UInt16)
    res = 0
    id = if !isempty(label)
        get_id(ctx, label)
    elseif icon !== nothing
        get_id(ctx, string(Int(icon)))
    else
        get_id(ctx, "button")
    end
    r = layout_next(ctx)
    update_control!(ctx, id, r, opt)
    
    # Handle click
    if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0 && ctx.focus == id
        res |= Int(RES_SUBMIT)
    end
    
    # Draw button
    draw_control_frame!(ctx, id, r, COLOR_BUTTON, opt)
    if !isempty(label)
        draw_control_text!(ctx, label, r, COLOR_TEXT, opt)
    end
    if icon !== nothing
        draw_icon!(ctx, icon, r, ctx.style.colors[Int(COLOR_TEXT)])
    end
    
    return res
end

"""
Simple button widget with label
Default button with center-aligned text
"""
button(ctx::Context, label::String) = button_ex(ctx, label, nothing, UInt16(OPT_ALIGNCENTER))

"""
Checkbox widget for boolean values
Returns RES_CHANGE when toggled
"""
function checkbox!(ctx::Context, label::String, state::Ref{Bool})
    res = 0
    id = get_id(ctx, "checkbox_" * string(objectid(state)))
    r = layout_next(ctx)
    box = Rect(r.x, r.y, r.h, r.h)
    update_control!(ctx, id, r, UInt16(0))
    
    # Handle click
    if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0 && ctx.focus == id
        res |= Int(RES_CHANGE)
        state[] = !state[]
    end
    
    # Draw checkbox
    draw_control_frame!(ctx, id, box, COLOR_BASE, UInt16(0))
    if state[]
        draw_icon!(ctx, ICON_CHECK, box, ctx.style.colors[Int(COLOR_TEXT)])
    end
    
    # Draw label next to checkbox
    r = Rect(r.x + box.w, r.y, r.w - box.w, r.h)
    draw_control_text!(ctx, label, r, COLOR_TEXT, UInt16(0))
    
    return res
end

"""
Raw textbox implementation with full control
Handles text input, editing, and cursor display
"""
function textbox_raw!(ctx::Context, buf::Ref{String}, bufsz::Int, id::Id, r::Rect, opt::UInt16)
    res = 0
    update_control!(ctx, id, r, opt | UInt16(OPT_HOLDFOCUS))
    
    if ctx.focus == id
        # Handle text input
        len = length(buf[])
        n = min(bufsz - len - 1, length(ctx.input_text))
        if n > 0
            buf[] *= ctx.input_text[1:n]
            res |= Int(RES_CHANGE)
        end
        
        # Handle backspace
        if (ctx.key_pressed & UInt8(KEY_BACKSPACE)) != 0 && len > 0
            # Skip UTF-8 continuation bytes for proper character deletion
            new_len = len
            while new_len > 0
                new_len -= 1
                if new_len == 0 || (codeunit(buf[], new_len + 1) & 0xc0) != 0x80
                    break
                end
            end
            buf[] = buf[][1:new_len]
            res |= Int(RES_CHANGE)
        end
        
        # Handle enter key
        if (ctx.key_pressed & UInt8(KEY_RETURN)) != 0
            set_focus!(ctx, 0)
            res |= Int(RES_SUBMIT)
        end
    end
    
    # Draw textbox
    draw_control_frame!(ctx, id, r, COLOR_BASE, opt)
    if ctx.focus == id
        # Draw text with cursor when focused
        color = ctx.style.colors[Int(COLOR_TEXT)]
        font = ctx.style.font
        textw = ctx.text_width(font, buf[])
        texth = ctx.text_height(font)
        ofx = r.w - ctx.style.padding - textw - 1
        textx = r.x + min(ofx, ctx.style.padding)
        texty = r.y + (r.h - texth) ÷ 2
        
        push_clip_rect!(ctx, r)
        draw_text!(ctx, font, buf[], -1, Vec2(textx, texty), color)
        draw_rect!(ctx, Rect(textx + textw, texty, 1, texth), color)
        pop_clip_rect!(ctx)
    else
        # Draw text normally when not focused
        draw_control_text!(ctx, buf[], r, COLOR_TEXT, opt)
    end
    
    return res
end

"""
Textbox widget with options
Provides text input with specified buffer size
"""
function textbox_ex!(ctx::Context, buf::Ref{String}, bufsz::Int, opt::UInt16)
    id = get_id(ctx, "textbox_" * string(objectid(buf)))
    r = layout_next(ctx)
    return textbox_raw!(ctx, buf, bufsz, id, r, opt)
end

"""
Simple textbox widget
Default textbox with no special options
"""
textbox!(ctx::Context, buf::Ref{String}, bufsz::Int) = textbox_ex!(ctx, buf, bufsz, UInt16(0))

"""
Number editing textbox for slider/number widgets
Handles special number editing mode with shift+click
"""
function number_textbox!(ctx::Context, value::Ref{Real}, r::Rect, id::Id)
    if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0 && 
       (ctx.key_down & UInt8(KEY_SHIFT)) != 0 && 
       ctx.hover == id
        ctx.number_edit = id
        ctx.number_edit_buf = format_real(value[], REAL_FMT)
    end
    
    if ctx.number_edit == id
        buf_ref = Ref(ctx.number_edit_buf)
        res = textbox_raw!(ctx, buf_ref, length(ctx.number_edit_buf) + 10, id, r, UInt16(0))
        ctx.number_edit_buf = buf_ref[]
        
        if (res & Int(RES_SUBMIT)) != 0 || ctx.focus != id
            try
                value[] = Real(parse(Float64, ctx.number_edit_buf))
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

"""
Slider widget with full customization
Allows dragging to adjust value within specified range
"""
function slider_ex!(ctx::Context, value::Ref{Real}, low::Real, high::Real, step::Real, fmt::String, opt::UInt16)
    res = 0
    last = value[]
    v = last
    id = get_id(ctx, "slider_" * string(objectid(value)))
    base = layout_next(ctx)
    
    # Handle text input mode
    if number_textbox!(ctx, value, base, id)
        return res
    end
    
    # Handle normal slider mode
    update_control!(ctx, id, base, opt)
    
    # Handle dragging input
    if ctx.focus == id && (ctx.mouse_down & UInt8(MOUSE_LEFT)) != 0
        v = low + Real(ctx.mouse_pos.x - base.x) * (high - low) / Real(base.w)
        if step != 0
            v = round(v / step) * step
        end
    end
    
    # Clamp value and check for changes
    value[] = v = clamp(v, low, high)
    if last != v
        res |= Int(RES_CHANGE)
    end
    
    # Draw slider base
    draw_control_frame!(ctx, id, base, COLOR_BASE, opt)
    
    # Draw slider thumb
    w = ctx.style.thumb_size
    x = Int32(round((v - low) * Real(base.w - w) / (high - low)))
    thumb = Rect(base.x + x, base.y, w, base.h)
    draw_control_frame!(ctx, id, thumb, COLOR_BUTTON, opt)
    
    # Draw value text
    buf = format_real(v, fmt)
    draw_control_text!(ctx, buf, base, COLOR_TEXT, opt)
    
    return res
end

"""
Simple slider widget
Default slider with standard formatting
"""
slider!(ctx::Context, value::Ref{Real}, low::Real, high::Real) = 
    slider_ex!(ctx, value, low, high, Real(0.0), SLIDER_FMT, UInt16(OPT_ALIGNCENTER))

"""
Number input widget with drag adjustment
Allows precise number input and mouse drag adjustment
"""
function number_ex!(ctx::Context, value::Ref{Real}, step::Real, fmt::String, opt::UInt16)
    res = 0
    id = get_id(ctx, "number_" * string(objectid(value)))
    base = layout_next(ctx)
    last = value[]
    
    # Handle text input mode
    if number_textbox!(ctx, value, base, id)
        return res
    end
    
    # Handle normal mode with drag adjustment
    update_control!(ctx, id, base, opt)
    
    # Handle mouse drag input
    if ctx.focus == id && (ctx.mouse_down & UInt8(MOUSE_LEFT)) != 0
        value[] += Real(ctx.mouse_delta.x) * step
    end
    
    # Check for value changes
    if value[] != last
        res |= Int(RES_CHANGE)
    end
    
    # Draw number widget
    draw_control_frame!(ctx, id, base, COLOR_BASE, opt)
    
    # Draw formatted value
    buf = format_real(value[], fmt)
    draw_control_text!(ctx, buf, base, COLOR_TEXT, opt)
    
    return res
end

"""
Simple number widget
Default number input with standard step and formatting
"""
number!(ctx::Context, value::Ref{Real}, step::Real) = 
    number_ex!(ctx, value, step, SLIDER_FMT, UInt16(OPT_ALIGNCENTER))

"""
Implementation for header and treenode widgets
Handles expand/collapse state and visual styling
"""
function header_impl(ctx::Context, label::String, istreenode::Bool, opt::UInt16)
    expanded = false
    id = get_id(ctx, label)
    idx = pool_get(ctx, ctx.treenode_pool, TREENODEPOOL_SIZE, id)
    width = -1
    layout_row!(ctx, 1, [width], 0)
    
    # Determine expanded state
    active = idx >= 0
    expanded = (opt & UInt16(OPT_EXPANDED)) != 0 ? !active : active
    r = layout_next(ctx)
    update_control!(ctx, id, r, UInt16(0))
    
    # Handle click to toggle state
    if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0 && ctx.focus == id
        active = !active
    end
    
    # Update pool reference
    if idx >= 0
        if active
            pool_update!(ctx, ctx.treenode_pool, idx)
        else
            ctx.treenode_pool[idx] = PoolItem(0, 0)
        end
    elseif active
        pool_init!(ctx, ctx.treenode_pool, TREENODEPOOL_SIZE, id)
    end
    
    # Draw header/treenode
    if istreenode
        if ctx.hover == id
            ctx.draw_frame(ctx, r, COLOR_BUTTONHOVER)
        end
    else
        draw_control_frame!(ctx, id, r, COLOR_BUTTON, UInt16(0))
    end
    
    # Draw expand/collapse icon
    icon_id = expanded ? ICON_EXPANDED : ICON_COLLAPSED
    draw_icon!(ctx, icon_id, Rect(r.x, r.y, r.h, r.h), ctx.style.colors[Int(COLOR_TEXT)])
    
    # Draw label text
    r = Rect(r.x + r.h - ctx.style.padding, r.y, r.w - r.h + ctx.style.padding, r.h)
    draw_control_text!(ctx, label, r, COLOR_TEXT, UInt16(0))
    
    return expanded ? Int(RES_ACTIVE) : 0
end

"""Header widget for grouping content"""
header_ex(ctx::Context, label::String, opt::UInt16) = header_impl(ctx, label, false, opt)

"""Simple header widget"""
header(ctx::Context, label::String) = header_ex(ctx, label, UInt16(0))

"""
Begin collapsible treenode section
Returns RES_ACTIVE if expanded
"""
function begin_treenode_ex(ctx::Context, label::String, opt::UInt16)
    res = header_impl(ctx, label, true, opt)
    if (res & Int(RES_ACTIVE)) != 0
        layout = get_layout(ctx)
        layout.indent += ctx.style.indent
        push!(ctx.id_stack, ctx.last_id)
    end
    return res
end

"""Simple treenode widget"""
begin_treenode(ctx::Context, label::String) = begin_treenode_ex(ctx, label, UInt16(0))

"""End treenode section"""
function end_treenode(ctx::Context)
    layout = get_layout(ctx)
    layout.indent -= ctx.style.indent
    pop_id!(ctx)
end

# ===== CONTAINER MANAGEMENT =====
# Functions for scrollbars and container body management

"""
Draw scrollbar for given axis
Handles scrollbar interaction and thumb positioning
"""
function draw_scrollbar!(ctx::Context, cnt::Container, body::Rect, cs::Vec2, axis_name::String)
    if axis_name == "y"
        maxscroll = cs.y - body.h
        if maxscroll > 0 && body.h > 0
            id = get_id(ctx, "!scrollbar" * axis_name)
            base = Rect(body.x + body.w, body.y, ctx.style.scrollbar_size, body.h)
            
            update_control!(ctx, id, base, UInt16(0))
            if ctx.focus == id && (ctx.mouse_down & UInt8(MOUSE_LEFT)) != 0
                cnt.scroll = Vec2(cnt.scroll.x, cnt.scroll.y + ctx.mouse_delta.y * cs.y ÷ base.h)
            end
            
            cnt.scroll = Vec2(cnt.scroll.x, clamp(cnt.scroll.y, 0, maxscroll))
            
            # Draw scrollbar track and thumb
            ctx.draw_frame(ctx, base, COLOR_SCROLLBASE)
            thumb_h = max(ctx.style.thumb_size, base.h * body.h ÷ cs.y)
            thumb_y = base.y + cnt.scroll.y * (base.h - thumb_h) ÷ maxscroll
            thumb = Rect(base.x, thumb_y, ctx.style.scrollbar_size, thumb_h)
            ctx.draw_frame(ctx, thumb, COLOR_SCROLLTHUMB)
            
            # Set scroll target for wheel input
            if mouse_over(ctx, body)
                ctx.scroll_target = cnt
            end
        else
            cnt.scroll = Vec2(cnt.scroll.x, 0)
        end
    else  # x axis
        maxscroll = cs.x - body.w
        if maxscroll > 0 && body.w > 0
            id = get_id(ctx, "!scrollbar" * axis_name)
            base = Rect(body.x, body.y + body.h, body.w, ctx.style.scrollbar_size)
            
            update_control!(ctx, id, base, UInt16(0))
            if ctx.focus == id && (ctx.mouse_down & UInt8(MOUSE_LEFT)) != 0
                cnt.scroll = Vec2(cnt.scroll.x + ctx.mouse_delta.x * cs.x ÷ base.w, cnt.scroll.y)
            end
            
            cnt.scroll = Vec2(clamp(cnt.scroll.x, 0, maxscroll), cnt.scroll.y)
            
            # Draw scrollbar track and thumb
            ctx.draw_frame(ctx, base, COLOR_SCROLLBASE)
            thumb_w = max(ctx.style.thumb_size, base.w * body.w ÷ cs.x)
            thumb_x = base.x + cnt.scroll.x * (base.w - thumb_w) ÷ maxscroll
            thumb = Rect(thumb_x, base.y, thumb_w, ctx.style.scrollbar_size)
            ctx.draw_frame(ctx, thumb, COLOR_SCROLLTHUMB)
        else
            cnt.scroll = Vec2(0, cnt.scroll.y)
        end
    end
end

"""
Handle scrollbars for container
Adjusts body rectangle to make room for scrollbars
"""
function scrollbars!(ctx::Context, cnt::Container, body::Ref{Rect})
    sz = ctx.style.scrollbar_size
    cs = Vec2(cnt.content_size.x + ctx.style.padding * 2,
              cnt.content_size.y + ctx.style.padding * 2)
    
    push_clip_rect!(ctx, body[])
    
    # Adjust body size to make room for scrollbars
    if cs.y > cnt.body.h
        body[] = Rect(body[].x, body[].y, body[].w - sz, body[].h)
    end
    if cs.x > cnt.body.w
        body[] = Rect(body[].x, body[].y, body[].w, body[].h - sz)
    end
    
    # Draw both scrollbars
    draw_scrollbar!(ctx, cnt, body[], cs, "x")
    draw_scrollbar!(ctx, cnt, body[], cs, "y")
    
    pop_clip_rect!(ctx)
end

"""
Set up container body with scrollbars and layout
Prepares container for content rendering
"""
function push_container_body!(ctx::Context, cnt::Container, body::Rect, opt::UInt16)
    body_ref = Ref(body)
    if (opt & UInt16(OPT_NOSCROLL)) == 0
        scrollbars!(ctx, cnt, body_ref)
    end
    push_layout!(ctx, expand_rect(body_ref[], -ctx.style.padding), cnt.scroll)
    cnt.body = body_ref[]
end

"""
Initialize root container for rendering
Sets up command buffer region and hover detection
"""
function begin_root_container!(ctx::Context, cnt::Container)
    push!(ctx.container_stack, cnt)
    push!(ctx.root_list, cnt)
    cnt.head = push_jump_command!(ctx, CommandPtr(0))
    
    # Update hover root if this container is under mouse
    if rect_overlaps_vec2(cnt.rect, ctx.mouse_pos) &&
       (ctx.next_hover_root === nothing || cnt.zindex > ctx.next_hover_root.zindex)
        ctx.next_hover_root = cnt
    end
    
    push!(ctx.clip_stack, UNCLIPPED_RECT)
end

"""
Finalize root container
Sets up command buffer tail and cleans up stacks
"""
function end_root_container!(ctx::Context)
    cnt = get_current_container(ctx)
    cnt.tail = push_jump_command!(ctx, CommandPtr(0))
    
    # Update head jump to skip past itself
    head_jump = JumpCommand(
        BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
        cnt.head + sizeof(JumpCommand)
    )
    ptr = pointer(ctx.command_list.buffer, cnt.head + 1)
    unsafe_store!(Ptr{JumpCommand}(ptr), head_jump)
    
    pop_clip_rect!(ctx)
    pop_container!(ctx)
end