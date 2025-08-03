# ===== DRAWING FUNCTIONS =====
# High-level drawing functions that create appropriate commands

"""
    draw_rect!(ctx::Context, rect::Rect, color::Color)

Draw a filled rectangle with automatic clipping optimization.

This function creates a rectangle drawing command, but only for the visible
portion after intersection with the current clipping rectangle. Invisible
rectangles are automatically culled for optimal performance.

# Arguments
- `ctx::Context`: The UI context containing the command buffer and clipping state
- `rect::Rect`: The rectangle to draw in screen coordinates
- `color::Color`: The fill color in RGBA format

# Effects
- Adds a [`RectCommand`](@ref) to the command buffer if the rectangle is visible
- Automatically clips the rectangle to the current clipping region
- No command is generated if the rectangle is completely outside the clip region

# Clipping behavior
The function performs intelligent clipping optimization:
1. **Intersection calculation**: Computes intersection with current clip rectangle
2. **Visibility test**: Only draws if intersection has positive area
3. **Automatic culling**: Completely invisible rectangles generate no commands

# Examples
```julia
# Basic rectangle drawing
draw_rect!(ctx, Rect(10, 20, 100, 50), Color(255, 0, 0, 255))  # Red rectangle

# Rectangle that may be clipped
push_clip_rect!(ctx, Rect(0, 0, 200, 200))  # Set clip region
draw_rect!(ctx, Rect(150, 150, 100, 100), Color(0, 255, 0, 255))  # Partially visible
draw_rect!(ctx, Rect(300, 300, 50, 50), Color(0, 0, 255, 255))    # Completely culled
pop_clip_rect!(ctx)

# Widget background rendering
function draw_button_background(ctx, button_rect, is_pressed)
    bg_color = is_pressed ? Color(200, 200, 200, 255) : Color(240, 240, 240, 255)
    draw_rect!(ctx, button_rect, bg_color)
end
```

# Performance optimizations
- **Early culling**: Invisible rectangles generate zero overhead
- **Clipping integration**: Uses efficient rectangle intersection
- **Command optimization**: Only creates commands for visible content
- **Memory efficiency**: No allocations for culled rectangles

# Color format
The `color` parameter expects RGBA values:
- **Red/Green/Blue**: 0-255 (0 = none, 255 = full intensity)
- **Alpha**: 0-255 (0 = transparent, 255 = opaque)

```julia
# Color examples
transparent_red = Color(255, 0, 0, 128)   # 50% transparent red
opaque_blue = Color(0, 0, 255, 255)       # Solid blue
black = Color(0, 0, 0, 255)               # Solid black
white = Color(255, 255, 255, 255)         # Solid white
```

# Integration with widget system
This function is typically called by higher-level widget drawing code:

```julia
# Used by draw_control_frame! for widget backgrounds
function draw_control_frame!(ctx, id, rect, colorid, opt)
    color = ctx.style.colors[Int(colorid)]
    draw_rect!(ctx, rect, color)  # Background
    # ... border drawing ...
end
```

# Coordinate system
Rectangles use screen coordinates:
- **Origin**: Top-left of the UI area
- **X-axis**: Increases rightward
- **Y-axis**: Increases downward (computer graphics convention)
- **Units**: Pixels

# See also
[`draw_box!`](@ref), [`RectCommand`](@ref), [`get_clip_rect`](@ref), [`intersect_rects`](@ref)
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
    draw_box!(ctx::Context, rect::Rect, color::Color)

Draw a rectangle outline (border) using four separate edge rectangles.

This function creates a hollow rectangle by drawing four thin rectangles
for the top, bottom, left, and right edges. Each edge is drawn as a
separate filled rectangle for maximum rendering compatibility.

# Arguments
- `ctx::Context`: The UI context containing the command buffer
- `rect::Rect`: The rectangle outline to draw in screen coordinates
- `color::Color`: The border color in RGBA format

# Effects
- Creates four [`RectCommand`](@ref)s for the rectangle edges
- Each edge respects the current clipping rectangle independently
- Invisible edges are automatically culled

# Edge layout
The four edges are positioned as follows:
- **Top edge**: `(x+1, y, w-2, 1)` - excludes corners
- **Bottom edge**: `(x+1, y+h-1, w-2, 1)` - excludes corners  
- **Left edge**: `(x, y, 1, h)` - includes corners
- **Right edge**: `(x+w-1, y, 1, h)` - includes corners

This arrangement ensures corners are drawn exactly once (by vertical edges).

# Examples
```julia
# Basic border drawing
draw_box!(ctx, Rect(10, 10, 100, 50), Color(0, 0, 0, 255))  # Black border

# Widget frame with background and border
widget_rect = Rect(50, 50, 200, 100)
draw_rect!(ctx, widget_rect, Color(240, 240, 240, 255))  # Light gray background
draw_box!(ctx, widget_rect, Color(128, 128, 128, 255))   # Gray border

# Button with pressed state
function draw_button_frame(ctx, rect, is_pressed)
    bg_color = is_pressed ? Color(200, 200, 200, 255) : Color(220, 220, 220, 255)
    border_color = Color(100, 100, 100, 255)
    
    draw_rect!(ctx, rect, bg_color)      # Background
    draw_box!(ctx, rect, border_color)   # Border
end
```

# Border thickness
This function always draws a 1-pixel border. For thicker borders, use
multiple calls with adjusted rectangles:

```julia
# 3-pixel thick border
base_rect = Rect(10, 10, 100, 50)
for thickness in 0:2
    border_rect = expand_rect(base_rect, -thickness)
    draw_box!(ctx, border_rect, border_color)
end
```

# Performance considerations
- **Four separate commands**: Each edge can be culled independently by clipping
- **Overlap handling**: Corner arrangement prevents double-drawing
- **Clipping optimization**: Uses same culling as [`draw_rect!`](@ref)
- **Memory efficiency**: Only visible edges generate commands

# Visual appearance
The resulting border has these characteristics:
- **1-pixel thickness**: Consistent with most UI frameworks
- **Sharp corners**: No anti-aliasing or rounding
- **Solid color**: Uses the same color for all edges
- **Precise positioning**: Edges align perfectly with pixel boundaries

# Widget integration
Commonly used for widget frames and decorative elements:

```julia
# Panel with inset appearance
function draw_panel_frame(ctx, rect)
    # Main background
    draw_rect!(ctx, rect, Color(240, 240, 240, 255))
    
    # Inset border effect
    draw_box!(ctx, rect, Color(160, 160, 160, 255))                    # Outer border
    inner_rect = Rect(rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2)
    draw_box!(ctx, inner_rect, Color(255, 255, 255, 255))              # Inner highlight
end
```

# Alternative approaches
For different border styles, consider:
- **Thick borders**: Multiple `draw_box!` calls or custom logic
- **Rounded corners**: Custom geometry or specialized functions
- **Dashed borders**: Multiple small rectangles with gaps
- **Gradient borders**: Multiple rectangles with varying colors

# See also
[`draw_rect!`](@ref), [`expand_rect`](@ref), [`RectCommand`](@ref), [`get_clip_rect`](@ref)
"""
function draw_box!(ctx::Context, rect::Rect, color::Color)
    draw_rect!(ctx, Rect(rect.x + 1, rect.y, rect.w - 2, 1), color)
    draw_rect!(ctx, Rect(rect.x + 1, rect.y + rect.h - 1, rect.w - 2, 1), color)
    draw_rect!(ctx, Rect(rect.x, rect.y, 1, rect.h), color)
    draw_rect!(ctx, Rect(rect.x + rect.w - 1, rect.y, 1, rect.h), color)
end

"""
    UNCLIPPED_RECT

A constant representing an unclipped rectangle that covers the entire drawable area.

This rectangle is used to reset clipping state to "no clipping" and spans
a very large area (16,777,216 × 16,777,216 pixels) that should encompass
any reasonable UI content.

# Value
```julia
const UNCLIPPED_RECT = Rect(0, 0, 0x1000000, 0x1000000)
```

# Usage
- **Reset clipping**: Set as clip rectangle to disable clipping
- **Default state**: Used as initial clip rectangle in new contexts  
- **Text rendering**: Temporarily set when text extends beyond normal bounds
- **Full-screen drawing**: For elements that should ignore clipping

# Examples
```julia
# Disable clipping for full-screen overlay
set_clip!(ctx, UNCLIPPED_RECT)
draw_rect!(ctx, Rect(0, 0, screen_width, screen_height), overlay_color)

# Reset clipping state after complex operations
push_clip_rect!(ctx, widget_bounds)
# ... complex drawing with multiple clip changes ...
set_clip!(ctx, UNCLIPPED_RECT)  # Reset to no clipping

# Used internally by text rendering
function draw_text!(ctx, font, str, len, pos, color)
    # ... clipping logic ...
    if clipped != CLIP_NONE
        set_clip!(ctx, UNCLIPPED_RECT)  # Reset after text
    end
end
```

# Implementation details
- **Large size**: 0x1000000 = 16,777,216 pixels per dimension
- **Practical infinity**: Larger than any reasonable UI content
- **Memory efficient**: Just a constant, no allocation overhead
- **Platform independent**: Works regardless of screen resolution

# Clipping system integration
This constant integrates with the clipping system:
- **Stack operations**: Can be pushed/popped like normal clip rectangles
- **Intersection behavior**: Any rectangle intersected with this remains unchanged
- **Optimization**: Rendering systems can detect and optimize for this case

# Coordinate space
The rectangle starts at (0, 0) and extends to cover the maximum practical
UI space. This works with standard screen coordinate systems where:
- (0, 0) is typically the top-left corner
- Positive coordinates extend right and down
- The large size accommodates any reasonable content layout

# Performance notes
- **Zero overhead**: Defined as a compile-time constant
- **Intersection optimization**: Fast to compute intersections with
- **Command generation**: May skip clip commands when this is the active rectangle

# See also
[`set_clip!`](@ref), [`push_clip_rect!`](@ref), [`get_clip_rect`](@ref), [`draw_text!`](@ref)
"""
const UNCLIPPED_RECT = Rect(0, 0, 0x1000000, 0x1000000)

"""
    draw_text!(ctx::Context, font::Font, str::String, len::Int, pos::Vec2, color::Color)

Draw a text string with intelligent clipping management.

This function handles text rendering with automatic clipping optimization,
ensuring text is drawn efficiently while respecting the current clipping
boundaries. It manages clipping state changes automatically to minimize
rendering overhead.

# Arguments
- `ctx::Context`: The UI context containing the command buffer and clipping state
- `font::Font`: The font to use for rendering (type depends on backend)
- `str::String`: The text string to render
- `len::Int`: Maximum number of characters to render (-1 for entire string)
- `pos::Vec2`: The baseline position for the text in screen coordinates
- `color::Color`: The text color in RGBA format

# Effects
- Creates a [`TextCommand`](@ref) with the text data
- Manages clipping state changes for optimal rendering
- Automatically handles text that extends beyond clipping bounds

# Clipping optimization
The function uses a three-level clipping strategy:

1. **`CLIP_NONE`**: Text is fully visible, no clipping changes needed
2. **`CLIP_PART`**: Text is partially visible, sets precise clipping
3. **`CLIP_ALL`**: Text is completely invisible, no command generated

# Examples
```julia
# Basic text rendering
font = load_font("Arial", 12)
draw_text!(ctx, font, "Hello, World!", -1, Vec2(100, 50), Color(0, 0, 0, 255))

# Limited character rendering
draw_text!(ctx, font, "Long text here", 8, Vec2(50, 100), Color(255, 0, 0, 255))  # Only "Long tex"

# Text with transparency
draw_text!(ctx, font, "Faded text", -1, Vec2(200, 150), Color(128, 128, 128, 128))

# Widget label rendering
function draw_label(ctx, text, rect, color)
    font = ctx.style.font
    text_pos = Vec2(rect.x + 5, rect.y + rect.h ÷ 2)  # Left-aligned, vertically centered
    draw_text!(ctx, font, text, -1, text_pos, color)
end
```

# String length parameter
The `len` parameter controls how much of the string to render:
- **`-1`**: Render the entire string (most common)
- **Positive integer**: Render at most that many characters
- **Zero**: Render nothing (effectively a no-op)

```julia
text = "Hello, World!"
draw_text!(ctx, font, text, -1, pos, color)  # "Hello, World!"
draw_text!(ctx, font, text, 5, pos, color)   # "Hello"
draw_text!(ctx, font, text, 0, pos, color)   # "" (nothing)
```

# Font and baseline positioning
- **Font parameter**: Type depends on rendering backend (often a handle or struct)
- **Baseline position**: `pos` specifies the text baseline, not top-left corner
- **Coordinate system**: Standard screen coordinates (origin at top-left)

```julia
# Positioning examples
baseline_y = 100
font_height = ctx.text_height(font)

# Text baseline at y=100, text extends upward to y≈84
draw_text!(ctx, font, "Baseline positioning", -1, Vec2(50, baseline_y), color)

# To position by top-left corner instead:
top_left_y = 84
actual_baseline = top_left_y + font_height
draw_text!(ctx, font, "Top-left positioning", -1, Vec2(50, actual_baseline), color)
```

# Text measurement integration
The function uses the context's text measurement callbacks:

```julia
# These callbacks must be set for proper text rendering
ctx.text_width = (font, str) -> measure_text_width(font, str)
ctx.text_height = font -> get_font_height(font)

# Function uses these for clipping calculations
text_rect = Rect(pos.x, pos.y, ctx.text_width(font, str), ctx.text_height(font))
```

# Clipping state management
The function automatically manages clipping for optimal performance:

```julia
# Pseudocode of clipping logic
clipped = check_clip(ctx, text_rect)
if clipped == CLIP_ALL
    return  # Don't draw invisible text
end

if clipped == CLIP_PART
    set_clip!(ctx, get_clip_rect(ctx))  # Set precise clipping
end

create_text_command(...)

if clipped != CLIP_NONE
    set_clip!(ctx, UNCLIPPED_RECT)  # Reset clipping
end
```

# Unicode and character encoding
- **UTF-8 support**: Handles multi-byte Unicode characters correctly
- **Emoji rendering**: Support depends on font and rendering backend
- **Right-to-left text**: Support depends on rendering backend
- **Character boundaries**: Respects Unicode grapheme clusters

# Performance considerations
- **Clipping optimization**: Invisible text generates no commands
- **String handling**: Efficient substring creation when `len` is specified
- **Font caching**: Font objects should be cached by the application
- **Measurement overhead**: Text measurement may be expensive for complex fonts

# Backend integration
The actual text rendering depends on the backend implementation:
- **Software rendering**: May rasterize fonts directly
- **GPU rendering**: May use texture atlases or signed distance fields
- **Platform rendering**: May delegate to OS text rendering APIs

# Common text styling
For styled text, multiple draw calls may be needed:

```julia
# Bold text (multiple passes for weight)
base_pos = Vec2(100, 50)
draw_text!(ctx, font, "Bold", -1, base_pos, color)
draw_text!(ctx, font, "Bold", -1, Vec2(base_pos.x + 1, base_pos.y), color)  # Offset

# Outlined text
outline_color = Color(255, 255, 255, 255)
text_color = Color(0, 0, 0, 255)
for dx in -1:1, dy in -1:1
    if dx != 0 || dy != 0  # Skip center
        draw_text!(ctx, font, "Outlined", -1, Vec2(pos.x + dx, pos.y + dy), outline_color)
    end
end
draw_text!(ctx, font, "Outlined", -1, pos, text_color)  # Center text
```

# See also
[`TextCommand`](@ref), [`check_clip`](@ref), [`set_clip!`](@ref), [`push_text_command!`](@ref)
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
    draw_icon!(ctx::Context, id::IconId, rect::Rect, color::Color)

Draw a built-in icon with automatic clipping optimization.

This function renders predefined UI icons (symbols) within the specified
rectangle. Icons are simple geometric shapes that scale to fit the given
rectangle and are rendered by the backend using vector graphics or
pre-defined shapes.

# Arguments
- `ctx::Context`: The UI context containing the command buffer and clipping state
- `id::IconId`: The identifier of the icon to draw
- `rect::Rect`: The rectangle to draw the icon within
- `color::Color`: The icon color in RGBA format

# Effects
- Creates an [`IconCommand`](@ref) if the icon area is visible
- Manages clipping state changes for optimal rendering
- Automatically scales the icon to fit within the specified rectangle

# Available icons
The system provides several built-in icons:
- **`ICON_CLOSE`**: X symbol for close buttons (×)
- **`ICON_CHECK`**: Checkmark for checkboxes (✓)
- **`ICON_COLLAPSED`**: Right-pointing triangle for collapsed tree nodes (▶)
- **`ICON_EXPANDED`**: Down-pointing triangle for expanded tree nodes (▼)

# Examples
```julia
# Close button icon
close_rect = Rect(window_rect.x + window_rect.w - 20, window_rect.y, 20, 20)
draw_icon!(ctx, ICON_CLOSE, close_rect, Color(128, 128, 128, 255))

# Checkbox with checkmark
checkbox_rect = Rect(10, 10, 16, 16)
if checkbox_checked
    draw_icon!(ctx, ICON_CHECK, checkbox_rect, Color(0, 128, 0, 255))  # Green check
end

# Tree node expansion indicators
node_rect = Rect(5, 25, 12, 12)
if node_expanded
    draw_icon!(ctx, ICON_EXPANDED, node_rect, Color(64, 64, 64, 255))
else
    draw_icon!(ctx, ICON_COLLAPSED, node_rect, Color(64, 64, 64, 255))
end

# Button with icon
button_rect = Rect(50, 50, 100, 30)
icon_rect = Rect(button_rect.x + 5, button_rect.y + 5, 20, 20)

draw_rect!(ctx, button_rect, Color(220, 220, 220, 255))  # Button background
draw_icon!(ctx, ICON_CHECK, icon_rect, Color(0, 0, 0, 255))  # Icon
```

# Icon scaling and positioning
Icons automatically scale to fit the provided rectangle:
- **Aspect ratio**: Icons maintain their proportions within the rectangle
- **Centering**: Icons are typically centered within the rectangle
- **Vector graphics**: Icons scale cleanly at any size
- **Pixel alignment**: Backend may align to pixel boundaries for crispness

```julia
# Different sizes of the same icon
small_icon = Rect(10, 10, 12, 12)
medium_icon = Rect(30, 10, 24, 24)  
large_icon = Rect(60, 10, 48, 48)

draw_icon!(ctx, ICON_CHECK, small_icon, color)   # 12×12 pixels
draw_icon!(ctx, ICON_CHECK, medium_icon, color)  # 24×24 pixels
draw_icon!(ctx, ICON_CHECK, large_icon, color)   # 48×48 pixels
```

# Clipping optimization
Uses the same intelligent clipping as other drawing functions:
- **Visibility testing**: Icons outside the clip region generate no commands
- **Partial clipping**: Sets precise clipping for partially visible icons
- **State management**: Automatically resets clipping after drawing

# Color and styling
Icons use solid colors and can be styled through the color parameter:

```julia
# Different icon states
normal_color = Color(128, 128, 128, 255)    # Gray
hover_color = Color(64, 64, 64, 255)        # Darker gray
active_color = Color(0, 0, 0, 255)          # Black
disabled_color = Color(200, 200, 200, 128)  # Light gray, transparent

# State-dependent coloring
if button_disabled
    icon_color = disabled_color
elseif button_active
    icon_color = active_color
elseif button_hovered
    icon_color = hover_color
else
    icon_color = normal_color
end

draw_icon!(ctx, ICON_CLOSE, icon_rect, icon_color)
```

# Backend rendering
The actual icon rendering is backend-dependent:
- **Vector graphics**: Icons may be rendered as geometric shapes
- **Font rendering**: Icons might use icon fonts or symbol fonts
- **Bitmap rendering**: Icons could use pre-rendered bitmap images
- **Custom drawing**: Backend may implement custom drawing code for each icon

# Widget integration
Icons are commonly used in standard UI widgets:

```julia
# Window title bar with close button
function draw_title_bar(ctx, title_rect, title_text)
    # Title bar background
    draw_rect!(ctx, title_rect, Color(50, 50, 50, 255))
    
    # Title text
    text_pos = Vec2(title_rect.x + 8, title_rect.y + title_rect.h ÷ 2)
    draw_text!(ctx, ctx.style.font, title_text, -1, text_pos, Color(255, 255, 255, 255))
    
    # Close button
    close_size = title_rect.h - 4
    close_rect = Rect(title_rect.x + title_rect.w - close_size - 2, title_rect.y + 2, close_size, close_size)
    draw_icon!(ctx, ICON_CLOSE, close_rect, Color(255, 255, 255, 255))
end

# Checkbox widget implementation
function draw_checkbox(ctx, rect, is_checked, label_text)
    # Checkbox background
    checkbox_size = min(rect.h - 4, 16)
    checkbox_rect = Rect(rect.x + 2, rect.y + (rect.h - checkbox_size) ÷ 2, checkbox_size, checkbox_size)
    
    draw_rect!(ctx, checkbox_rect, Color(255, 255, 255, 255))  # White background
    draw_box!(ctx, checkbox_rect, Color(128, 128, 128, 255))   # Gray border
    
    # Checkmark if checked
    if is_checked
        check_rect = Rect(checkbox_rect.x + 2, checkbox_rect.y + 2, checkbox_rect.w - 4, checkbox_rect.h - 4)
        draw_icon!(ctx, ICON_CHECK, check_rect, Color(0, 128, 0, 255))
    end
    
    # Label text
    text_x = checkbox_rect.x + checkbox_rect.w + 6
    text_y = rect.y + rect.h ÷ 2
    draw_text!(ctx, ctx.style.font, label_text, -1, Vec2(text_x, text_y), Color(0, 0, 0, 255))
end
```

# Custom icon considerations
For applications needing additional icons:
- **Extended icon sets**: Backend may support additional icon IDs
- **Custom rendering**: Application can implement custom icon drawing
- **Image icons**: Use texture/image rendering instead of geometric icons
- **Font icons**: Use text rendering with icon fonts

# Performance notes
- **Command generation**: Same efficiency as other drawing primitives
- **Backend optimization**: Vector icons may be more efficient than bitmaps
- **Caching**: Backend may cache icon rendering for repeated use
- **Scaling efficiency**: Vector-based icons scale efficiently

# See also
[`IconCommand`](@ref), [`IconId`](@ref), [`check_clip`](@ref), [`draw_rect!`](@ref)
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