# ===== FINAL CORRECTED TEXT RENDERER =====

"""
Corrected text-based renderer for MicroUI with precise positioning and alignment.
Handles all edge cases for proper window, text, and widget rendering.
"""
mutable struct SimpleTextRenderer
    width::Int
    height::Int
    buffer::Matrix{Char}
    char_width::Float64    # Pixels per character width
    char_height::Float64   # Pixels per character height
    
    function SimpleTextRenderer(w=80, h=25; char_width=8.0, char_height=16.0)
        new(w, h, fill(' ', h, w), char_width, char_height)
    end
end

"""
    clear!(renderer::SimpleTextRenderer) -> Nothing

Clear the renderer buffer, filling it with spaces.
"""
function clear!(renderer::SimpleTextRenderer)
    fill!(renderer.buffer, ' ')
end

"""
    pixel_to_char_x(renderer::SimpleTextRenderer, pixel_x) -> Int

Convert pixel X coordinate to character column (1-based), handling edge cases.
"""
function pixel_to_char_x(renderer::SimpleTextRenderer, pixel_x)
    # Allow for negative positions and handle edge cases properly
    char_x = round(Int, Float64(pixel_x) / renderer.char_width) + 1
    return clamp(char_x, 1, renderer.width)
end

"""
    pixel_to_char_y(renderer::SimpleTextRenderer, pixel_y) -> Int

Convert pixel Y coordinate to character row (1-based), handling edge cases.
"""
function pixel_to_char_y(renderer::SimpleTextRenderer, pixel_y)
    char_y = round(Int, Float64(pixel_y) / renderer.char_height) + 1
    return clamp(char_y, 1, renderer.height)
end

"""
    pixel_to_char_w(renderer::SimpleTextRenderer, pixel_w) -> Int

Convert pixel width to character width, with better rounding.
"""
function pixel_to_char_w(renderer::SimpleTextRenderer, pixel_w)
    char_w = max(1, round(Int, Float64(pixel_w) / renderer.char_width))
    return char_w
end

"""
    pixel_to_char_h(renderer::SimpleTextRenderer, pixel_h) -> Int

Convert pixel height to character height, with better rounding.
"""
function pixel_to_char_h(renderer::SimpleTextRenderer, pixel_h)
    char_h = max(1, round(Int, Float64(pixel_h) / renderer.char_height))
    return char_h
end

"""
    set_char!(renderer::SimpleTextRenderer, x::Int, y::Int, c::Char) -> Nothing

Set a character at specific position (1-based coordinates).
"""
function set_char!(renderer::SimpleTextRenderer, x::Int, y::Int, c::Char)
    if 1 <= x <= renderer.width && 1 <= y <= renderer.height
        renderer.buffer[y, x] = c
    end
end

"""
    draw_string!(renderer::SimpleTextRenderer, x::Int, y::Int, text::String) -> Nothing

Draw a string starting at position with better text visibility.
"""
function draw_string!(renderer::SimpleTextRenderer, x::Int, y::Int, text::String)
    if y < 1 || y > renderer.height
        return  # Skip text outside vertical bounds
    end
    
    for (i, c) in enumerate(text)
        char_x = x + i - 1
        if char_x > renderer.width
            break  # Stop if we go beyond the right edge
        end
        if char_x >= 1
            set_char!(renderer, char_x, y, c)
        end
    end
end

"""
    draw_rect!(renderer::SimpleTextRenderer, x::Int, y::Int, w::Int, h::Int, char::Char='█') -> Nothing

Draw a filled rectangle with better bounds handling.
"""
function draw_rect!(renderer::SimpleTextRenderer, x::Int, y::Int, w::Int, h::Int, char::Char='█')
    # Calculate actual drawing bounds
    start_x = max(1, x)
    start_y = max(1, y)
    end_x = min(renderer.width, x + w - 1)
    end_y = min(renderer.height, y + h - 1)
    
    # Draw rectangle
    for row in start_y:end_y
        for col in start_x:end_x
            set_char!(renderer, col, row, char)
        end
    end
end

"""
    draw_border!(renderer::SimpleTextRenderer, x::Int, y::Int, w::Int, h::Int) -> Nothing

Draw a rectangle border using box drawing characters.
"""
function draw_border!(renderer::SimpleTextRenderer, x::Int, y::Int, w::Int, h::Int)
    if w < 2 || h < 2
        return  # Cannot draw border for rectangles smaller than 2x2
    end
    
    # Clamp to valid bounds
    start_x = max(1, x)
    start_y = max(1, y)
    end_x = min(renderer.width, x + w - 1)
    end_y = min(renderer.height, y + h - 1)
    
    if start_x > end_x || start_y > end_y
        return  # Invalid bounds
    end
    
    # Corners
    if start_x == x && start_y == y
        set_char!(renderer, start_x, start_y, '┌')
    end
    if end_x == x + w - 1 && start_y == y
        set_char!(renderer, end_x, start_y, '┐')
    end
    if start_x == x && end_y == y + h - 1
        set_char!(renderer, start_x, end_y, '└')
    end
    if end_x == x + w - 1 && end_y == y + h - 1
        set_char!(renderer, end_x, end_y, '┘')
    end
    
    # Horizontal lines
    for col in (start_x + 1):(end_x - 1)
        if start_y == y
            set_char!(renderer, col, start_y, '─')  # Top
        end
        if end_y == y + h - 1
            set_char!(renderer, col, end_y, '─')    # Bottom
        end
    end
    
    # Vertical lines  
    for row in (start_y + 1):(end_y - 1)
        if start_x == x
            set_char!(renderer, start_x, row, '│')  # Left
        end
        if end_x == x + w - 1
            set_char!(renderer, end_x, row, '│')    # Right
        end
    end
end

"""
    display!(renderer::SimpleTextRenderer) -> Nothing

Render the buffer to console output.
"""
function display!(renderer::SimpleTextRenderer)
    for y in 1:renderer.height
        for x in 1:renderer.width
            print(renderer.buffer[y, x])
        end
        println()
    end
end

"""
    is_color_visible(color::Color) -> Bool

Check if a color is visible enough to render (not too dark or transparent).
"""
function is_color_visible(color::Color)
    # Check if color is not fully transparent and has enough brightness
    return color.a > 50 && (Int(color.r) + Int(color.g) + Int(color.b)) > 100
end

"""
    choose_rect_char(color::Color) -> Char

Choose appropriate character for rectangle based on color intensity.
"""
function choose_rect_char(color::Color)
    if !is_color_visible(color)
        return ' '  # Invisible/transparent
    end
    
    # Calculate brightness (0-765)
    brightness = Int(color.r) + Int(color.g) + Int(color.b)
    
    if brightness > 600
        return '█'  # Very bright
    elseif brightness > 400
        return '▓'  # Medium-bright
    elseif brightness > 200
        return '▒'  # Medium
    else
        return '░'  # Dark but visible
    end
end

# ===== MICROUI COMMAND PROCESSOR (FULLY CORRECTED) =====

"""
    render_context!(renderer::SimpleTextRenderer, ctx::Context) -> Nothing

Process MicroUI commands with all positioning and rendering corrections.
"""
function render_context!(renderer::SimpleTextRenderer, ctx::Context)
    clear!(renderer)
    
    # Create command iterator
    iter = CommandIterator(ctx.command_list)
    
    current_clip = Rect(0, 0, Int32(renderer.width * renderer.char_width), 
                       Int32(renderer.height * renderer.char_height))
    
    while true
        has_command, cmd_type, offset = next_command!(iter)
        
        if !has_command
            break
        end
        
        if cmd_type == MicroUI.COMMAND_CLIP
            cmd = read_command(ctx.command_list, offset, ClipCommand)
            current_clip = cmd.rect
            
        elseif cmd_type == MicroUI.COMMAND_RECT
            cmd = read_command(ctx.command_list, offset, RectCommand)
            
            # Skip invisible rectangles
            if !is_color_visible(cmd.color)
                continue
            end
            
            # Convert pixel coordinates to character coordinates
            char_x = pixel_to_char_x(renderer, Int(cmd.rect.x))
            char_y = pixel_to_char_y(renderer, Int(cmd.rect.y))
            char_w = pixel_to_char_w(renderer, Int(cmd.rect.w))
            char_h = pixel_to_char_h(renderer, Int(cmd.rect.h))
            
            # Choose appropriate character
            rect_char = choose_rect_char(cmd.color)
            
            draw_rect!(renderer, char_x, char_y, char_w, char_h, rect_char)
            
        elseif cmd_type == MicroUI.COMMAND_TEXT
            cmd = read_command(ctx.command_list, offset, TextCommand)
            text = get_string(ctx.command_list, cmd.str_index)
            
            # Skip invisible text
            if !is_color_visible(cmd.color)
                continue
            end
            
            # Skip empty text
            if isempty(text)
                continue
            end
            
            # Convert coordinates
            char_x = pixel_to_char_x(renderer, Int(cmd.pos.x))
            char_y = pixel_to_char_y(renderer, Int(cmd.pos.y))
            
            draw_string!(renderer, char_x, char_y, text)
            
        elseif cmd_type == MicroUI.COMMAND_ICON
            cmd = read_command(ctx.command_list, offset, IconCommand)
            
            # Skip invisible icons
            if !is_color_visible(cmd.color)
                continue
            end
            
            # Map MicroUI icons to Unicode characters
            icon_char = if cmd.id == MicroUI.ICON_CLOSE
                '✕'
            elseif cmd.id == MicroUI.ICON_CHECK
                '✓'
            elseif cmd.id == MicroUI.ICON_COLLAPSED
                '▶'
            elseif cmd.id == MicroUI.ICON_EXPANDED
                '▼'
            else
                '?'
            end
            
            # For close icons, position at the right edge of the rectangle
            if cmd.id == MicroUI.ICON_CLOSE
                # Position close icon at right edge of its rectangle
                char_x = pixel_to_char_x(renderer, Int(cmd.rect.x + cmd.rect.w - renderer.char_width))
                char_y = pixel_to_char_y(renderer, Int(cmd.rect.y))
            else
                # Other icons at left edge
                char_x = pixel_to_char_x(renderer, Int(cmd.rect.x))
                char_y = pixel_to_char_y(renderer, Int(cmd.rect.y))
            end
            
            set_char!(renderer, char_x, char_y, icon_char)
        end
    end
end

# ===== DEBUGGING AND TESTING FUNCTIONS =====

"""
    debug_render_info(renderer::SimpleTextRenderer, ctx::Context) -> Nothing

Display detailed debugging information about the rendering process.
"""
function debug_render_info(renderer::SimpleTextRenderer, ctx::Context)
    println("🔍 Detailed Render Debug Info")
    println("=" ^ 50)
    
    println("Renderer Configuration:")
    println("  Size: $(renderer.width) × $(renderer.height) characters")
    println("  Char size: $(renderer.char_width) × $(renderer.char_height) pixels")
    println("  Pixel coverage: $(renderer.width * renderer.char_width) × $(renderer.height * renderer.char_height) pixels")
    
    # Analyze commands
    iter = CommandIterator(ctx.command_list)
    command_counts = Dict{String, Int}()
    
    println("\\n📊 Command Analysis:")
    while true
        has_command, cmd_type, offset = next_command!(iter)
        if !has_command
            break
        end
        
        cmd_name = if cmd_type == MicroUI.COMMAND_CLIP
            "CLIP"
        elseif cmd_type == MicroUI.COMMAND_RECT
            "RECT"
        elseif cmd_type == MicroUI.COMMAND_TEXT
            "TEXT"
        elseif cmd_type == MicroUI.COMMAND_ICON
            "ICON"
        else
            "UNKNOWN"
        end
        
        command_counts[cmd_name] = get(command_counts, cmd_name, 0) + 1
        
        # Debug specific commands
        if cmd_type == MicroUI.COMMAND_TEXT
            cmd = read_command(ctx.command_list, offset, TextCommand)
            text = get_string(ctx.command_list, cmd.str_index)
            char_x = pixel_to_char_x(renderer, Int(cmd.pos.x))
            char_y = pixel_to_char_y(renderer, Int(cmd.pos.y))
            visible = is_color_visible(cmd.color)
            println("  TEXT: '$text' at pixel($(cmd.pos.x), $(cmd.pos.y)) → char($char_x, $char_y), visible: $visible")
            
        elseif cmd_type == MicroUI.COMMAND_ICON
            cmd = read_command(ctx.command_list, offset, IconCommand)
            char_x = pixel_to_char_x(renderer, Int(cmd.rect.x))
            char_y = pixel_to_char_y(renderer, Int(cmd.rect.y))
            visible = is_color_visible(cmd.color)
            icon_name = if cmd.id == MicroUI.ICON_CLOSE
                "CLOSE"
            elseif cmd.id == MicroUI.ICON_CHECK
                "CHECK"
            else
                "OTHER"
            end
            println("  ICON: $icon_name at pixel($(cmd.rect.x), $(cmd.rect.y)) → char($char_x, $char_y), visible: $visible")
            
        elseif cmd_type == MicroUI.COMMAND_RECT
            cmd = read_command(ctx.command_list, offset, RectCommand)
            char_x = pixel_to_char_x(renderer, Int(cmd.rect.x))
            char_y = pixel_to_char_y(renderer, Int(cmd.rect.y))
            char_w = pixel_to_char_w(renderer, Int(cmd.rect.w))
            char_h = pixel_to_char_h(renderer, Int(cmd.rect.h))
            visible = is_color_visible(cmd.color)
            rect_char = choose_rect_char(cmd.color)
            println("  RECT: pixel($(cmd.rect.x), $(cmd.rect.y), $(cmd.rect.w), $(cmd.rect.h)) → char($char_x, $char_y, $char_w, $char_h) '$rect_char', visible: $visible")
        end
    end
    
    println("\\n📈 Command Summary:")
    for (cmd_type, count) in command_counts
        println("  $cmd_type: $count")
    end
end

"""
    test_coordinate_precision() -> Nothing

Test coordinate conversion precision and edge cases.
"""
function test_coordinate_precision()
    println("🎯 Testing Coordinate Conversion Precision")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(70, 25, char_width=8.0, char_height=16.0)
    
    # Test cases from actual UI scenarios
    test_cases = [
        (0, 0, "Origin (0,0)"),
        (40, 32, "Window top-left (typical)"),  
        (360, 192, "Window bottom-right"),
        (352, 32, "Close button position"),     # tr.x + tr.w - tr.h
        (50, 82, "First widget position"),
        (50, 98, "Second widget position"),
        (50, 114, "Third widget position"),
    ]
    
    println("Pixel → Character conversion test:")
    println("Format: pixel(x,y) → char(x,y)")
    println("-" ^ 40)
    
    for (px, py, desc) in test_cases
        char_x = pixel_to_char_x(renderer, px)
        char_y = pixel_to_char_y(renderer, py)
        
        # Calculate back to pixel to show precision
        back_px = (char_x - 1) * renderer.char_width
        back_py = (char_y - 1) * renderer.char_height
        
        println("$desc:")
        println("  pixel($px, $py) → char($char_x, $char_y)")
        println("  Reverse: char($char_x, $char_y) → pixel($back_px, $back_py)")
        println("  Error: ($(px - back_px), $(py - back_py)) pixels")
        println()
    end
end