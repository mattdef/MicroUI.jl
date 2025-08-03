"""
# MicroUI Enumerations

All enumerations define the various states, types, and flags used throughout the MicroUI system.

These enums provide type-safe constants for different aspects of the UI system:

- **Rendering**: Command types, clipping results, color indices
- **Input**: Mouse buttons, keyboard keys
- **Widget behavior**: Options, results, icon types
- **State management**: Widget states and interaction flags

# Design Principles

- **Compact representation**: Most enums use `UInt8` for memory efficiency
- **Bitwise operations**: Flags can be combined using `|`, `&`, `~` operators
- **Type safety**: Prevents invalid combinations and improves debugging
- **Performance**: Enum operations compile to simple integer comparisons

# Usage Patterns

## Simple Values
```julia
# Direct enum usage
if cmd_type == COMMAND_RECT
    # Handle rectangle command
end

# Color selection
draw_rect!(ctx, rect, ctx.style.colors[Int(COLOR_BUTTON)])
```

## Flag Combinations
```julia
# Combine multiple options
window_opts = UInt16(OPT_NOCLOSE) | UInt16(OPT_NORESIZE)
begin_window_ex(ctx, "Fixed Window", rect, window_opts)

# Check for specific flags
if (result & Int(RES_SUBMIT)) != 0
    println("Widget was activated!")
end
```

# See Also

- [Core Concepts](concepts.md): How enums fit into MicroUI architecture
- [Widget Guide](widgets.md): Using result and option flags
- [Input Handling](input.md): Mouse and keyboard flag usage
"""

# ===== RENDERING ENUMERATIONS =====

"""
    ClipResult

Results returned when testing if a rectangle is visible within the current clipping region.

Clipping is used to restrict drawing to specific areas of the screen. When a widget
wants to draw something, it first checks if that drawing would be visible given
the current clipping constraints.

# Values

- `CLIP_NONE = 0`: Rectangle is fully visible, no clipping needed
- `CLIP_PART = 1`: Rectangle is partially visible, clipping required  
- `CLIP_ALL = 2`: Rectangle is completely outside clip region, skip rendering

# Performance Optimization

Clipping tests allow MicroUI to skip expensive drawing operations:

- **`CLIP_NONE`**: Draw normally, fastest path
- **`CLIP_PART`**: Set up clipping hardware/software, moderate cost
- **`CLIP_ALL`**: Skip drawing entirely, fastest path (no work)

# Usage Example

```julia
# Check if widget area needs clipping
widget_rect = Rect(x, y, width, height)
clip_result = check_clip(ctx, widget_rect)

if clip_result == CLIP_ALL
    return  # Don't draw anything
elseif clip_result == CLIP_PART
    # Set up clipping for this draw
    set_clip!(ctx, get_clip_rect(ctx))
    draw_widget_content(ctx, widget_rect)
    set_clip!(ctx, UNCLIPPED_RECT)  # Reset clipping
else  # CLIP_NONE
    # Draw normally without clipping overhead
    draw_widget_content(ctx, widget_rect)
end
```

# How Clipping Works

Clipping regions are maintained as a stack of nested rectangles:

```julia
begin_window(ctx, "Main", Rect(0, 0, 400, 300))    # Clip to window
    begin_panel(ctx, "Left", Rect(0, 0, 200, 300)) # Clip to left half
        # All drawing here is clipped to intersection: Rect(0, 0, 200, 300)
        draw_rect!(ctx, Rect(-50, -50, 300, 400), color)  # Partially visible
    end_panel(ctx)
end_window(ctx)
```

# Mathematical Details

For rectangles `r` (to draw) and `c` (clip region):

- **`CLIP_NONE`**: `r` entirely within `c`
- **`CLIP_PART`**: `r` overlaps `c` but extends outside  
- **`CLIP_ALL`**: `r` and `c` don't overlap at all

```julia
# Pseudocode for clipping test
function check_clip(r::Rect, c::Rect)
    if r.x >= c.x && r.y >= c.y && r.x+r.w <= c.x+c.w && r.y+r.h <= c.y+c.h
        return CLIP_NONE  # Fully inside
    elseif r.x >= c.x+c.w || r.y >= c.y+c.h || r.x+r.w <= c.x || r.y+r.h <= c.y
        return CLIP_ALL   # Completely outside  
    else
        return CLIP_PART  # Partially overlapping
    end
end
```

# Performance Tips

- **Organize UI hierarchically**: Smaller clip regions reject more content
- **Check clip early**: Test clipping before expensive calculations
- **Batch clipped draws**: Minimize clip state changes

# See Also

- [`check_clip`](@ref): Function that returns these values
- [`push_clip_rect!`](@ref), [`pop_clip_rect!`](@ref): Clipping stack management
- [`intersect_rects`](@ref): Rectangle intersection math
- [Clipping Guide](clipping.md): Detailed clipping documentation
"""
@enum ClipResult::UInt8 begin
    CLIP_NONE = 0
    CLIP_PART = 1
    CLIP_ALL = 2
end

"""
    CommandType

Types of rendering commands that can be stored in the command buffer.

MicroUI uses a command-based rendering system where all drawing operations
are recorded as commands in a buffer, then executed later by the rendering
backend. This decouples UI logic from rendering implementation.

# Values

- `COMMAND_JUMP = 1`: Jump to different position in command buffer
- `COMMAND_CLIP = 2`: Set clipping rectangle  
- `COMMAND_RECT = 3`: Draw filled rectangle
- `COMMAND_TEXT = 4`: Draw text string
- `COMMAND_ICON = 5`: Draw icon/symbol

# Command Buffer Architecture

```julia
# UI code generates commands
begin_frame(ctx)
draw_rect!(ctx, rect, color)     # → COMMAND_RECT
draw_text!(ctx, font, "Hi", pos, color)  # → COMMAND_TEXT  
end_frame(ctx)

# Rendering backend processes commands
iter = CommandIterator(ctx.command_list)
while true
    (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
    if !has_cmd; break; end
    
    if cmd_type == COMMAND_RECT
        rect_cmd = read_command(ctx.command_list, cmd_idx, RectCommand)
        backend_draw_rect(rect_cmd.rect, rect_cmd.color)
    elseif cmd_type == COMMAND_TEXT
        text_cmd = read_command(ctx.command_list, cmd_idx, TextCommand)
        text_str = get_string(ctx.command_list, text_cmd.str_index)
        backend_draw_text(text_cmd.font, text_str, text_cmd.pos, text_cmd.color)
    # ... handle other command types
    end
end
```

# Command Details

## COMMAND_JUMP (Z-ordering)
Allows non-linear traversal of the command buffer for proper Z-order rendering:

```julia
# Higher Z-index containers render on top
window1_commands... → JUMP to window2_start
window2_commands... → JUMP to end
# Window2 renders after (on top of) Window1
```

## COMMAND_CLIP (Clipping regions)
Sets the active clipping rectangle for subsequent commands:

```julia
# All drawing after this clip command is restricted to the rectangle
COMMAND_CLIP: Rect(10, 10, 200, 100)
COMMAND_RECT: Rect(0, 0, 300, 200)  # Only portion inside clip is drawn
```

## COMMAND_RECT (Filled rectangles)
Draws solid-color rectangles for backgrounds, borders, and UI elements:

```julia
# Button background
COMMAND_RECT: rect=Rect(10, 10, 100, 30), color=Color(128, 128, 128, 255)
```

## COMMAND_TEXT (Text rendering)
Renders text strings with specified font, position, and color:

```julia
# Button label
COMMAND_TEXT: font=default_font, pos=Vec2(15, 20), color=white, str="Click Me"
```

## COMMAND_ICON (Built-in symbols)
Draws simple geometric icons like checkmarks, arrows, close buttons:

```julia
# Checkbox checkmark
COMMAND_ICON: rect=Rect(10, 10, 16, 16), id=ICON_CHECK, color=black
```

# Command Structure

All commands share a common header:

```julia
struct BaseCommand
    type::CommandType  # Identifies which command this is
    size::Int32       # Size in bytes for buffer traversal
end
```

# Memory Layout

Commands are packed sequentially in the command buffer:

```
[RECT_CMD][TEXT_CMD][CLIP_CMD][JUMP_CMD][ICON_CMD]...
  64 bytes  48 bytes  32 bytes  16 bytes  40 bytes
```

# Backend Independence

The command system allows MicroUI to work with any rendering backend:

- **OpenGL**: Commands → OpenGL calls
- **Vulkan**: Commands → Vulkan command buffers  
- **Software**: Commands → pixel manipulation
- **Cairo**: Commands → Cairo drawing operations
- **Web Canvas**: Commands → HTML5 Canvas API

# Performance Characteristics

- **Command generation**: ~10-50 nanoseconds per command
- **Command processing**: Depends on backend, typically ~100ns-1μs per command
- **Memory usage**: ~30-80 bytes per command average
- **Cache efficiency**: Sequential buffer access, very cache-friendly

# Debugging Commands

```julia
# Iterate through all commands for debugging
iter = CommandIterator(ctx.command_list)
while true
    (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
    if !has_cmd; break; end
    
    println("Command at \$cmd_idx: \$cmd_type")
    if cmd_type == COMMAND_TEXT
        text_cmd = read_command(ctx.command_list, cmd_idx, TextCommand)
        text_str = get_string(ctx.command_list, text_cmd.str_index)
        println("  Text: '\$text_str' at \$(text_cmd.pos)")
    end
end
```

# See Also

- [`CommandList`](@ref): Command buffer implementation
- [`CommandIterator`](@ref): Command traversal
- [`RectCommand`](@ref), [`TextCommand`](@ref), [`IconCommand`](@ref): Specific command types
- [Rendering Backend Guide](backends.md): Implementing command processors
"""
@enum CommandType::UInt8 begin
    COMMAND_JUMP = 1  # Jump to different position in command buffer
    COMMAND_CLIP = 2  # Set clipping rectangle
    COMMAND_RECT = 3  # Draw filled rectangle
    COMMAND_TEXT = 4  # Draw text string
    COMMAND_ICON = 5  # Draw icon/symbol
end

"""
    ColorId

Predefined color identifiers for different UI elements in the style system.

Rather than hard-coding colors throughout the UI, MicroUI uses a color palette
system where each UI element type has a designated color ID. This allows easy
theming and consistent visual appearance.

# Color Categories

## Text Colors
- `COLOR_TEXT = 1`: Main text color for labels, content text
- `COLOR_TITLETEXT = 5`: Title bar text color

## Background Colors  
- `COLOR_WINDOWBG = 3`: Window background color
- `COLOR_TITLEBG = 4`: Title bar background color
- `COLOR_PANELBG = 6`: Panel background color

## Interactive Elements
- `COLOR_BUTTON = 7`: Button normal state
- `COLOR_BUTTONHOVER = 8`: Button hover state  
- `COLOR_BUTTONFOCUS = 9`: Button focused/pressed state

## Input Controls
- `COLOR_BASE = 10`: Base input control color (textboxes, sliders)
- `COLOR_BASEHOVER = 11`: Input control hover state
- `COLOR_BASEFOCUS = 12`: Input control focused state

## Scrollbars
- `COLOR_SCROLLBASE = 13`: Scrollbar track/background color
- `COLOR_SCROLLTHUMB = 14`: Scrollbar thumb/handle color

## Borders
- `COLOR_BORDER = 2`: Border color for frames and outlines

# Usage Examples

## Basic Color Usage
```julia
# Draw text in the standard text color
text_color = ctx.style.colors[Int(COLOR_TEXT)]
draw_text!(ctx, font, "Hello", pos, text_color)

# Draw button with appropriate state color
button_color = if ctx.focus == button_id
    ctx.style.colors[Int(COLOR_BUTTONFOCUS)]
elseif ctx.hover == button_id  
    ctx.style.colors[Int(COLOR_BUTTONHOVER)]
else
    ctx.style.colors[Int(COLOR_BUTTON)]
end
draw_rect!(ctx, button_rect, button_color)
```

## Widget State Colors
```julia
# Automatic state-based coloring
function draw_control_frame!(ctx, id, rect, base_colorid, opt)
    color_idx = Int(base_colorid)
    if ctx.focus == id
        color_idx += 2  # Use focused variant (+2 from base)
    elseif ctx.hover == id
        color_idx += 1  # Use hover variant (+1 from base)  
    end
    ctx.draw_frame(ctx, rect, ColorId(color_idx))
end

# Works with: BUTTON→BUTTONHOVER→BUTTONFOCUS (7→8→9)
#            BASE→BASEHOVER→BASEFOCUS (10→11→12)
```

## Theme Customization
```julia
# Create custom dark theme
dark_theme = copy(DEFAULT_STYLE)
dark_theme.colors[Int(COLOR_TEXT)] = Color(220, 220, 220, 255)      # Light gray text
dark_theme.colors[Int(COLOR_WINDOWBG)] = Color(40, 40, 40, 255)     # Dark gray background
dark_theme.colors[Int(COLOR_BUTTON)] = Color(60, 60, 60, 255)       # Dark button
dark_theme.colors[Int(COLOR_BUTTONHOVER)] = Color(80, 80, 80, 255)  # Lighter on hover

# Apply theme
ctx.style = dark_theme
```

# Color Array Access

Colors are stored in the style's color array:

```julia
# Access colors safely
function get_color(style::Style, color_id::ColorId)
    idx = Int(color_id)
    if 1 <= idx <= length(style.colors)
        return style.colors[idx]
    else
        return Color(255, 0, 255, 255)  # Magenta for missing colors
    end
end
```

# Widget Color Patterns

Most interactive widgets follow this pattern:

```julia
# Base ID + 0: Normal state  
# Base ID + 1: Hover state
# Base ID + 2: Focus/pressed state

# Examples:
COLOR_BUTTON = 7     # Normal button
COLOR_BUTTONHOVER = 8    # +1 = Hover
COLOR_BUTTONFOCUS = 9    # +2 = Focus

COLOR_BASE = 10      # Normal input
COLOR_BASEHOVER = 11     # +1 = Hover  
COLOR_BASEFOCUS = 12     # +2 = Focus
```

# Default Color Scheme

The [`DEFAULT_STYLE`](@ref) provides a dark theme:

- **Text**: Light gray on dark backgrounds
- **Backgrounds**: Dark grays and blacks
- **Buttons**: Medium gray with lighter hover/focus
- **Inputs**: Dark with subtle state changes
- **Accents**: Minimal, focused on usability

# Performance Notes

- **Array access**: Color lookups are O(1) and very fast
- **Memory usage**: 14 colors × 4 bytes = 56 bytes per style
- **Cache friendly**: Colors are accessed frequently and stay in cache

# Accessibility

When creating custom themes, consider:

- **Contrast ratios**: Ensure text is readable (4.5:1 minimum)
- **Color blindness**: Don't rely solely on color for information
- **State indication**: Make hover/focus states clearly visible
- **System integration**: Respect user's OS theme preferences

# See Also

- [`Color`](@ref): Color structure (RGBA values)
- [`Style`](@ref): Style system containing color arrays
- [`DEFAULT_STYLE`](@ref): Default color theme
- [`draw_control_frame!`](@ref): Automatic state-based coloring
- [Theming Guide](theming.md): Creating custom color schemes
"""
@enum ColorId::UInt8 begin
    COLOR_TEXT = 1         # Main text color
    COLOR_BORDER = 2       # Border color for frames
    COLOR_WINDOWBG = 3     # Window background
    COLOR_TITLEBG = 4      # Title bar background
    COLOR_TITLETEXT = 5    # Title bar text
    COLOR_PANELBG = 6      # Panel background
    COLOR_BUTTON = 7       # Button normal state
    COLOR_BUTTONHOVER = 8  # Button hover state
    COLOR_BUTTONFOCUS = 9  # Button focused state
    COLOR_BASE = 10        # Base input control color
    COLOR_BASEHOVER = 11   # Base input control hover
    COLOR_BASEFOCUS = 12   # Base input control focused
    COLOR_SCROLLBASE = 13  # Scrollbar track color
    COLOR_SCROLLTHUMB = 14 # Scrollbar thumb color
end

"""
    IconId

Built-in icon identifiers for common UI symbols and indicators.

MicroUI includes a small set of essential icons drawn as simple geometric shapes.
These icons are rendered by the drawing backend and provide consistent appearance
across different platforms and rendering systems.

# Available Icons

- `ICON_CLOSE = 1`: X symbol for close buttons and dismissal actions
- `ICON_CHECK = 2`: Checkmark for checkboxes and confirmation indicators
- `ICON_COLLAPSED = 3`: Triangle pointing right (►) for collapsed treenode state
- `ICON_EXPANDED = 4`: Triangle pointing down (▼) for expanded treenode state

# Design Philosophy

Icons are intentionally minimal and geometric:

- **Simple shapes**: Easy to render at any size
- **Backend independent**: Don't require image files or fonts
- **Scalable**: Look good at both small and large sizes
- **Fast rendering**: Simple geometry renders quickly
- **Consistent**: Same appearance across all platforms

# Usage Examples

## Checkbox Icons
```julia
# Draw checkbox with state-dependent icon
if checkbox_state[]
    draw_icon!(ctx, ICON_CHECK, checkbox_rect, text_color)
end
# Empty checkbox shows no icon
```

## Window Close Button
```julia
# Close button in title bar
close_rect = Rect(window_rect.x + window_rect.w - 20, window_rect.y, 20, 20)
draw_icon!(ctx, ICON_CLOSE, close_rect, title_color)

if button_clicked(ctx, close_rect)
    close_window()
end
```

## Treenode Expansion
```julia
# Show expansion state with appropriate triangle
icon_id = is_expanded ? ICON_EXPANDED : ICON_COLLAPSED
draw_icon!(ctx, icon_id, icon_rect, text_color)

if clicked
    is_expanded = !is_expanded  # Toggle state
end
```

## Custom Button Icons
```julia
# Use icon instead of text label
function icon_button(ctx, icon_id, rect)
    # Draw button background
    draw_control_frame!(ctx, id, rect, COLOR_BUTTON, options)
    
    # Draw icon centered in button  
    icon_color = ctx.style.colors[Int(COLOR_TEXT)]
    draw_icon!(ctx, icon_id, rect, icon_color)
    
    return check_button_clicked(ctx, rect)
end

# Usage
if icon_button(ctx, ICON_CLOSE, close_btn_rect)
    handle_close()
end
```

# Icon Rendering

Icons are rendered as filled shapes using the current color:

```julia
# Drawing an icon is similar to drawing text
draw_icon!(ctx, ICON_CHECK, target_rect, Color(0, 255, 0, 255))  # Green checkmark
```

The rendering backend interprets each icon ID and draws the appropriate shape:

- **ICON_CLOSE**: Two diagonal lines forming an X
- **ICON_CHECK**: Angled lines forming a checkmark (✓)  
- **ICON_COLLAPSED**: Right-pointing triangle (►)
- **ICON_EXPANDED**: Down-pointing triangle (▼)

# Size and Positioning

Icons automatically scale to fill the provided rectangle:

```julia
# Small icon (16×16)
draw_icon!(ctx, ICON_CHECK, Rect(10, 10, 16, 16), color)

# Large icon (64×64)  
draw_icon!(ctx, ICON_CHECK, Rect(100, 100, 64, 64), color)

# Non-square icons work too
draw_icon!(ctx, ICON_EXPANDED, Rect(0, 0, 20, 10), color)
```

# Backend Implementation

Rendering backends implement icon drawing based on the icon ID:

```julia
function render_icon(icon_id::IconId, rect::Rect, color::Color)
    if icon_id == ICON_CLOSE
        # Draw X: two diagonal lines
        draw_line(rect.x, rect.y, rect.x+rect.w, rect.y+rect.h, color)
        draw_line(rect.x+rect.w, rect.y, rect.x, rect.y+rect.h, color)
    elseif icon_id == ICON_CHECK
        # Draw checkmark: angled lines
        mid_x, mid_y = rect.x + rect.w÷3, rect.y + rect.h÷2
        draw_line(rect.x, mid_y, mid_x, rect.y+rect.h, color)
        draw_line(mid_x, rect.y+rect.h, rect.x+rect.w, rect.y, color)
    # ... other icons
    end
end
```

# Icon Commands

Icons generate [`COMMAND_ICON`](@ref) entries in the command buffer:

```julia
struct IconCommand
    base::BaseCommand  # type=COMMAND_ICON, size=sizeof(IconCommand)
    rect::Rect        # Where to draw the icon
    id::IconId        # Which icon to draw  
    color::Color      # Icon color
end
```

# Limitations and Extensions

## Current Limitations
- **Fixed set**: Only 4 built-in icons
- **Monochrome**: Single color per icon
- **Geometric**: No complex shapes or gradients

## Extension Options
```julia
# Custom icons via text rendering (if font supports it)
draw_text!(ctx, icon_font, "🔍", pos, color)  # Search icon

# Custom icons via small images
draw_custom_icon(ctx, "search.png", rect)

# Vector-based custom icons
draw_svg_icon(ctx, search_icon_svg, rect, color)
```

# Performance

- **Rendering speed**: Very fast, simple geometry
- **Memory usage**: 5 bytes per icon command
- **Scalability**: Resolution-independent
- **Cache efficiency**: No texture/image loading overhead

# See Also

- [`draw_icon!`](@ref): Icon drawing function
- [`IconCommand`](@ref): Icon command structure
- [`COMMAND_ICON`](@ref): Icon command type
- [Custom Icons Guide](custom_icons.md): Adding custom icon systems
"""
@enum IconId::UInt8 begin
    ICON_CLOSE = 1      # X symbol for close buttons
    ICON_CHECK = 2      # Checkmark for checkboxes
    ICON_COLLAPSED = 3  # Triangle pointing right (collapsed state)
    ICON_EXPANDED = 4   # Triangle pointing down (expanded state)
end

# ===== INPUT ENUMERATIONS =====

"""
    MouseButton

Mouse button flags that can be combined with bitwise operations.

These flags represent which mouse buttons are currently pressed or were pressed
during the current frame. Multiple buttons can be pressed simultaneously,
so the flags use bit positions that can be combined.

# Values

- `MOUSE_LEFT = 1 << 0`: Left mouse button (primary button, bit 0)
- `MOUSE_RIGHT = 1 << 1`: Right mouse button (context menu, bit 1)  
- `MOUSE_MIDDLE = 1 << 2`: Middle mouse button (wheel click, bit 2)

# Bitwise Operations

Since these are bit flags, you can combine and test them using bitwise operators:

```julia
# Check if left button is pressed
if (ctx.mouse_down & UInt8(MOUSE_LEFT)) != 0
    println("Left button is down")
end

# Check if right button was pressed this frame
if (ctx.mouse_pressed & UInt8(MOUSE_RIGHT)) != 0
    println("Right button was just pressed")
end

# Check for multiple buttons
if (ctx.mouse_down & UInt8(MOUSE_LEFT | MOUSE_MIDDLE)) != 0
    println("Left or middle button is down")
end

# Check for specific combination
if ctx.mouse_down == UInt8(MOUSE_LEFT | MOUSE_RIGHT)
    println("Both left and right buttons down (no middle)")
end
```

# Input Event Handling

Mouse button states are updated through input functions:

```julia
# Mouse button pressed
input_mousedown!(ctx, x, y, MOUSE_LEFT)
# ctx.mouse_down |= UInt8(MOUSE_LEFT)      # Add to current state
# ctx.mouse_pressed |= UInt8(MOUSE_LEFT)   # Mark as pressed this frame

# Mouse button released  
input_mouseup!(ctx, x, y, MOUSE_LEFT)
# ctx.mouse_down &= ~UInt8(MOUSE_LEFT)     # Remove from current state
# (mouse_pressed is cleared at end of frame)
```

# State Variables

The context tracks two mouse button states:

- **`mouse_down`**: Currently pressed buttons (persistent)
- **`mouse_pressed`**: Buttons pressed this frame only (cleared each frame)

```julia
# Example state progression:
# Frame 1: User presses left button
ctx.mouse_down = UInt8(MOUSE_LEFT)      # 0b001
ctx.mouse_pressed = UInt8(MOUSE_LEFT)   # 0b001

# Frame 2: User holds left, presses right  
ctx.mouse_down = UInt8(MOUSE_LEFT | MOUSE_RIGHT)  # 0b011
ctx.mouse_pressed = UInt8(MOUSE_RIGHT)  # 0b010 (only right is new)

# Frame 3: User releases left, holds right
ctx.mouse_down = UInt8(MOUSE_RIGHT)     # 0b010  
ctx.mouse_pressed = UInt8(0)            # 0b000 (no new presses)
```

# Widget Interaction Patterns

## Click Detection
```julia
# Basic click: press and release on same widget
function handle_button_click(ctx, button_id, button_rect)
    if mouse_over(ctx, button_rect)
        if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0
            ctx.focus = button_id  # Start interaction
        end
        
        if ctx.focus == button_id && (ctx.mouse_down & UInt8(MOUSE_LEFT)) == 0
            # Released on focused button = click!
            return true
        end
    end
    return false
end
```

## Drag Detection
```julia
# Drag: button down + mouse movement
function handle_slider_drag(ctx, slider_id, slider_rect)
    if ctx.focus == slider_id && (ctx.mouse_down & UInt8(MOUSE_LEFT)) != 0
        # Calculate slider value from mouse position
        relative_x = ctx.mouse_pos.x - slider_rect.x
        slider_value = relative_x / slider_rect.w
        return clamp(slider_value, 0.0, 1.0)
    end
    return current_value
end
```

## Context Menus
```julia
# Right-click for context menu
if (ctx.mouse_pressed & UInt8(MOUSE_RIGHT)) != 0 && mouse_over(ctx, widget_rect)
    open_context_menu(ctx, ctx.mouse_pos)
end
```

# Platform Differences

Different platforms may have different mouse button conventions:

- **Windows/Linux**: Left=primary, Right=context, Middle=wheel
- **macOS**: Single button (left), Right=Ctrl+click or two-finger click
- **Touch devices**: Left=tap, no right/middle buttons typically

MicroUI normalizes these to the standard three-button model.

# Accessibility

Mouse button handling should consider accessibility:

```julia
# Support keyboard activation as alternative to mouse
if (ctx.key_pressed & UInt8(KEY_RETURN)) != 0 && ctx.focus == widget_id
    # Treat Enter key as left click
    handle_activation(ctx, widget_id)
end
```

# Performance

- **Bitwise operations**: Extremely fast (single CPU instruction)
- **Memory usage**: 1 byte per button state variable
- **No allocations**: All operations work with primitive integers

# Advanced Usage

## Custom Button Handling
```julia
# Handle different buttons differently
if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0
    start_primary_action()
elseif (ctx.mouse_pressed & UInt8(MOUSE_RIGHT)) != 0
    show_context_menu()
elseif (ctx.mouse_pressed & UInt8(MOUSE_MIDDLE)) != 0
    start_pan_or_zoom()
end
```

## Multi-Button Combinations
```julia
# Special behavior for button combinations
buttons = ctx.mouse_down
if buttons == UInt8(MOUSE_LEFT | MOUSE_RIGHT)
    handle_special_mode()  # Both buttons together
elseif (buttons & UInt8(MOUSE_MIDDLE)) != 0
    handle_middle_button_mode()
end
```

# See Also

- [`input_mousedown!`](@ref), [`input_mouseup!`](@ref): Input functions
- [`Context`](@ref): Mouse state storage (`mouse_down`, `mouse_pressed`)
- [`Key`](@ref): Keyboard input flags
- [Input Handling Guide](input.md): Complete input system documentation
"""
@enum MouseButton::UInt8 begin
    MOUSE_LEFT = 1 << 0    # Left mouse button
    MOUSE_RIGHT = 1 << 1   # Right mouse button
    MOUSE_MIDDLE = 1 << 2  # Middle mouse button (wheel)
end

"""
    Key

Keyboard key flags for modifier keys and special keys used in UI interaction.

These flags represent keyboard keys that are important for UI operation.
Like mouse buttons, these can be combined to detect key combinations
like Ctrl+C or Shift+Tab.

# Values

## Modifier Keys
- `KEY_SHIFT = 1 << 0`: Shift modifier key (bit 0)
- `KEY_CTRL = 1 << 1`: Control modifier key (bit 1)
- `KEY_ALT = 1 << 2`: Alt modifier key (bit 2)

## Special Keys  
- `KEY_BACKSPACE = 1 << 3`: Backspace key for text deletion (bit 3)
- `KEY_RETURN = 1 << 4`: Enter/Return key for confirmation (bit 4)

# Bitwise Combinations

Test for key combinations using bitwise operations:

```julia
# Check for single keys
if (ctx.key_down & UInt8(KEY_CTRL)) != 0
    println("Control is held")
end

# Check for key combinations
if (ctx.key_down & UInt8(KEY_CTRL | KEY_SHIFT)) == UInt8(KEY_CTRL | KEY_SHIFT)
    println("Both Ctrl and Shift are held")
end

# Check for any modifier
if (ctx.key_down & UInt8(KEY_SHIFT | KEY_CTRL | KEY_ALT)) != 0
    println("At least one modifier is held")
end
```

# Input Event Handling

Keyboard states are updated through input functions:

```julia
# Key pressed down
input_keydown!(ctx, KEY_CTRL)
# ctx.key_down |= UInt8(KEY_CTRL)      # Add to current state
# ctx.key_pressed |= UInt8(KEY_CTRL)   # Mark as pressed this frame

# Key released
input_keyup!(ctx, KEY_CTRL)  
# ctx.key_down &= ~UInt8(KEY_CTRL)     # Remove from current state
# (key_pressed is cleared at end of frame)
```

# Text Input vs Key Events

MicroUI distinguishes between:

- **Key events**: Modifier keys, special keys (this enum)
- **Text input**: Printable characters for typing

```julia
# Handle special keys
if (ctx.key_pressed & UInt8(KEY_BACKSPACE)) != 0
    delete_character()
end

if (ctx.key_pressed & UInt8(KEY_RETURN)) != 0
    submit_form()
end

# Handle text input separately  
if !isempty(ctx.input_text)
    add_text_to_field(ctx.input_text)
end
```

# Common Usage Patterns

## Text Editing
```julia
# Textbox with backspace support
if ctx.focus == textbox_id
    # Handle special keys
    if (ctx.key_pressed & UInt8(KEY_BACKSPACE)) != 0 && !isempty(text_buffer)
        text_buffer = text_buffer[1:end-1]  # Delete last character
    end
    
    if (ctx.key_pressed & UInt8(KEY_RETURN)) != 0
        submit_text(text_buffer)
        ctx.focus = 0  # Remove focus
    end
    
    # Handle regular text input
    text_buffer *= ctx.input_text
end
```

## Keyboard Navigation
```julia
# Navigate between controls with Tab/Shift+Tab
if (ctx.key_pressed & UInt8(KEY_TAB)) != 0
    if (ctx.key_down & UInt8(KEY_SHIFT)) != 0
        focus_previous_control(ctx)  # Shift+Tab = backward
    else
        focus_next_control(ctx)      # Tab = forward
    end
end
```

## Keyboard Shortcuts
```julia
# Application shortcuts
if (ctx.key_down & UInt8(KEY_CTRL)) != 0
    if (ctx.key_pressed & UInt8(KEY_S)) != 0  # Ctrl+S
        save_file()
    elseif (ctx.key_pressed & UInt8(KEY_O)) != 0  # Ctrl+O
        open_file()
    elseif (ctx.key_pressed & UInt8(KEY_Z)) != 0  # Ctrl+Z
        if (ctx.key_down & UInt8(KEY_SHIFT)) != 0
            redo()  # Ctrl+Shift+Z
        else
            undo()  # Ctrl+Z
        end
    end
end
```

## Widget Activation
```julia
# Allow keyboard activation of focused widgets
if ctx.focus == button_id && (ctx.key_pressed & UInt8(KEY_RETURN)) != 0
    handle_button_click()  # Enter = click for accessibility
end

# Space bar for checkboxes/toggles
if ctx.focus == checkbox_id && (ctx.key_pressed & UInt8(KEY_SPACE)) != 0
    toggle_checkbox()
end
```

# Platform Considerations

Different platforms have different modifier key conventions:

- **Windows/Linux**: Ctrl for shortcuts, Alt for menus
- **macOS**: Cmd (mapped to Ctrl) for shortcuts, Option for Alt
- **Web**: Ctrl on PC, Cmd on Mac

MicroUI normalizes these to consistent KEY_CTRL, KEY_ALT flags.

# State Management

Like mouse buttons, keyboard state has two variables:

- **`key_down`**: Currently held keys (persistent)
- **`key_pressed`**: Keys pressed this frame (cleared each frame)

```julia
# Frame-by-frame example:
# Frame 1: User presses Ctrl
ctx.key_down = UInt8(KEY_CTRL)     # 0b00010
ctx.key_pressed = UInt8(KEY_CTRL)  # 0b00010

# Frame 2: User holds Ctrl, presses S
ctx.key_down = UInt8(KEY_CTRL)     # 0b00010 (still held)
ctx.key_pressed = UInt8(0)         # 0b00000 (no new presses)
# Note: 'S' would be in ctx.input_text, not key flags

# Frame 3: User releases Ctrl
ctx.key_down = UInt8(0)            # 0b00000
ctx.key_pressed = UInt8(0)         # 0b00000
```

# Accessibility Features

Keyboard support is essential for accessibility:

```julia
# Ensure all interactive elements are keyboard accessible
function make_widget_accessible(ctx, widget_id, widget_rect)
    # Visual focus indicator
    if ctx.focus == widget_id
        draw_focus_outline(ctx, widget_rect)
    end
    
    # Keyboard activation
    if ctx.focus == widget_id
        if (ctx.key_pressed & UInt8(KEY_RETURN)) != 0
            activate_widget(widget_id)
        end
    end
    
    # Tab navigation
    if widget_rect.contains(ctx.mouse_pos) && (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0
        ctx.focus = widget_id  # Focus follows mouse
    end
end
```

# Performance

- **Bitwise operations**: Single CPU instruction, extremely fast
- **Memory usage**: 1 byte per key state variable  
- **No allocations**: Pure integer operations

# Limitations

This enum only covers essential UI keys. For complete keyboard input:

- **Text input**: Use `ctx.input_text` for printable characters
- **Additional keys**: Arrow keys, function keys, etc. require custom handling
- **International**: Non-ASCII keys need Unicode text input system

# See Also

- [`input_keydown!`](@ref), [`input_keyup!`](@ref): Key input functions
- [`input_text!`](@ref): Text input for printable characters
- [`Context`](@ref): Key state storage (`key_down`, `key_pressed`)
- [`MouseButton`](@ref): Mouse input flags
- [Accessibility Guide](accessibility.md): Keyboard navigation best practices
"""
@enum Key::UInt8 begin
    KEY_SHIFT = 1 << 0      # Shift modifier key
    KEY_CTRL = 1 << 1       # Control modifier key
    KEY_ALT = 1 << 2        # Alt modifier key
    KEY_BACKSPACE = 1 << 3  # Backspace key
    KEY_RETURN = 1 << 4     # Enter/Return key
end

# ===== WIDGET BEHAVIOR ENUMERATIONS =====

"""
    Option

Option flags for controlling widget and container behavior and appearance.

These flags modify how widgets and containers behave and appear. They can be
combined using bitwise OR operations to apply multiple options simultaneously.
Most widgets accept an optional `opt` parameter for customization.

# Text Alignment
- `OPT_ALIGNCENTER = 1 << 0`: Center-align text content horizontally
- `OPT_ALIGNRIGHT = 1 << 1`: Right-align text content (default is left)

# Interaction Control
- `OPT_NOINTERACT = 1 << 2`: Disable interaction, make widget display-only
- `OPT_HOLDFOCUS = 1 << 8`: Keep focus even when mouse leaves widget area

# Visual Appearance
- `OPT_NOFRAME = 1 << 3`: Don't draw frame/border around widget

# Window Options
- `OPT_NORESIZE = 1 << 4`: Disable window resizing handles
- `OPT_NOSCROLL = 1 << 5`: Disable scrollbars in containers
- `OPT_NOCLOSE = 1 << 6`: Hide window close button
- `OPT_NOTITLE = 1 << 7`: Hide window title bar entirely

# Container Behavior
- `OPT_AUTOSIZE = 1 << 9`: Automatically size container to fit content
- `OPT_POPUP = 1 << 10`: Behave as popup window (auto-close when clicked outside)
- `OPT_CLOSED = 1 << 11`: Container starts in closed state
- `OPT_EXPANDED = 1 << 12`: Treenode starts in expanded state

# Usage Examples

## Basic Option Usage
```julia
# Center-aligned button
button_ex(ctx, "Centered", nothing, UInt16(OPT_ALIGNCENTER))

# Right-aligned text label
label_ex(ctx, "Right aligned", UInt16(OPT_ALIGNRIGHT))

# Button without frame/border
button_ex(ctx, "Borderless", nothing, UInt16(OPT_NOFRAME))

# Non-interactive display widget
textbox_ex!(ctx, readonly_text, 100, UInt16(OPT_NOINTERACT))
```

## Combining Multiple Options
```julia
# Centered, borderless button
opts = UInt16(OPT_ALIGNCENTER) | UInt16(OPT_NOFRAME)
button_ex(ctx, "Clean Button", nothing, opts)

# Fixed-size window (no resize, no close)
window_opts = UInt16(OPT_NORESIZE) | UInt16(OPT_NOCLOSE)
begin_window_ex(ctx, "Fixed Window", rect, window_opts)
```

## Window Customization
```julia
# Popup dialog
popup_opts = UInt16(OPT_POPUP) | UInt16(OPT_AUTOSIZE) | UInt16(OPT_NOCLOSE)
if begin_window_ex(ctx, "Alert", Rect(0, 0, 0, 0), popup_opts) != 0
    text(ctx, "This is a popup message!")
    if button(ctx, "OK") != 0
        # Popup closes automatically when clicked outside
    end
    end_window(ctx)
end

# Tool palette window
tool_opts = UInt16(OPT_NOTITLE) | UInt16(OPT_NORESIZE)
begin_window_ex(ctx, "Tools", tool_rect, tool_opts)
    # Tool buttons without title bar
    button(ctx, "Brush")
    button(ctx, "Eraser")
end_window(ctx)
```

## Treenode State Control
```julia
# Treenode that starts expanded
if begin_treenode_ex(ctx, "Documents", UInt16(OPT_EXPANDED)) & Int(RES_ACTIVE) != 0
    # Show expanded content
    begin_treenode(ctx, "Projects")
    end_treenode(ctx)
end_treenode(ctx)

# Treenode that starts collapsed (default behavior)
if begin_treenode_ex(ctx, "Settings", UInt16(0)) & Int(RES_ACTIVE) != 0
    # This content only shows when user expands the node
    checkbox!(ctx, "Enable feature", feature_flag)
end_treenode(ctx)
```

# Text Alignment Details

Text alignment affects how content is positioned within widget boundaries:

```julia
# Left-aligned (default)
button(ctx, "Left")     # Text at left edge + padding

# Center-aligned  
button_ex(ctx, "Center", nothing, UInt16(OPT_ALIGNCENTER))  # Text centered

# Right-aligned
button_ex(ctx, "Right", nothing, UInt16(OPT_ALIGNRIGHT))   # Text at right edge - padding
```

The alignment is implemented in [`draw_control_text!`](@ref):

```julia
if (opt & UInt16(OPT_ALIGNCENTER)) != 0
    pos_x = rect.x + (rect.w - text_width) ÷ 2
elseif (opt & UInt16(OPT_ALIGNRIGHT)) != 0
    pos_x = rect.x + rect.w - text_width - padding
else
    pos_x = rect.x + padding  # Left-aligned (default)
end
```

# Interaction Control

## OPT_NOINTERACT
Makes widgets display-only, ignoring mouse and keyboard input:

```julia
# Show current value without allowing changes
slider_ex!(ctx, readonly_value, 0.0f0, 1.0f0, 0.0f0, "%.2f", UInt16(OPT_NOINTERACT))

# Display-only textbox
textbox_ex!(ctx, display_text, 100, UInt16(OPT_NOINTERACT))
```

## OPT_HOLDFOCUS
Keeps focus even when mouse leaves widget area:

```julia
# Text input that stays focused until explicitly changed
textbox_ex!(ctx, text_ref, 256, UInt16(OPT_HOLDFOCUS))
# User can type even after moving mouse away
```

# Window and Container Options

## Size and Layout Control
```julia
# Auto-sizing popup that fits content
opts = UInt16(OPT_POPUP) | UInt16(OPT_AUTOSIZE)
begin_window_ex(ctx, "Auto Popup", Rect(mouse_x, mouse_y, 0, 0), opts)

# Fixed-size panel without scrollbars
panel_opts = UInt16(OPT_NOSCROLL)
begin_panel_ex(ctx, "Fixed Panel", panel_opts)
```

## Appearance Control
```julia
# Frameless panel (invisible background)
begin_panel_ex(ctx, "Invisible", UInt16(OPT_NOFRAME))

# Minimal window (no title, no close button)
minimal_opts = UInt16(OPT_NOTITLE) | UInt16(OPT_NOCLOSE)
begin_window_ex(ctx, "", rect, minimal_opts)
```

# Performance Considerations

- **Bitwise operations**: Flag checking is extremely fast
- **Branch prediction**: Common flags like OPT_ALIGNCENTER are well-predicted
- **Memory usage**: Options are typically passed as immediate values (no allocation)

# Default Behavior

When no options are specified (opt = 0), widgets use sensible defaults:

- **Text**: Left-aligned
- **Interaction**: Enabled  
- **Frames**: Drawn
- **Windows**: Resizable, with title bar and close button
- **Containers**: Scrollable if content overflows

# Advanced Usage

## Conditional Options
```julia
# Apply options based on state
opts = UInt16(0)
if is_readonly
    opts |= UInt16(OPT_NOINTERACT)
end
if center_text
    opts |= UInt16(OPT_ALIGNCENTER)
end

textbox_ex!(ctx, text_ref, 100, opts)
```

## Style Variations
```julia
# Create different button styles
function primary_button(ctx, label)
    opts = UInt16(OPT_ALIGNCENTER)
    return button_ex(ctx, label, nothing, opts)
end

function ghost_button(ctx, label)  
    opts = UInt16(OPT_ALIGNCENTER) | UInt16(OPT_NOFRAME)
    return button_ex(ctx, label, nothing, opts)
end
```

# See Also

- [`button_ex`](@ref), [`textbox_ex!`](@ref): Widgets accepting option flags
- [`begin_window_ex`](@ref): Window creation with options
- [`begin_panel_ex`](@ref): Panel creation with options
- [`Result`](@ref): Return values from interactive widgets
- [Widget Customization Guide](customization.md): Advanced option usage
"""
@enum Option::UInt16 begin
    OPT_ALIGNCENTER = 1 << 0  # Center-align text content
    OPT_ALIGNRIGHT = 1 << 1   # Right-align text content
    OPT_NOINTERACT = 1 << 2   # Disable interaction (display only)
    OPT_NOFRAME = 1 << 3      # Don't draw frame/border
    OPT_NORESIZE = 1 << 4     # Disable window resizing
    OPT_NOSCROLL = 1 << 5     # Disable scrollbars
    OPT_NOCLOSE = 1 << 6      # Hide close button
    OPT_NOTITLE = 1 << 7      # Hide title bar
    OPT_HOLDFOCUS = 1 << 8    # Keep focus even when mouse leaves
    OPT_AUTOSIZE = 1 << 9     # Automatically size to content
    OPT_POPUP = 1 << 10       # Behave as popup window
    OPT_CLOSED = 1 << 11      # Container starts closed
    OPT_EXPANDED = 1 << 12    # Treenode starts expanded
end

"""
    Result

Result flags returned by interactive widgets to indicate what actions occurred.

Interactive widgets return a bitmask of these flags to inform the application
about user interactions that happened during the current frame. Applications
check these flags to respond to user actions.

# Values

- `RES_ACTIVE = 1 << 0`: Widget is currently active/pressed (mouse down on widget)
- `RES_SUBMIT = 1 << 1`: Widget was activated/clicked (button click, enter pressed)
- `RES_CHANGE = 1 << 2`: Widget value changed this frame (slider moved, text edited)

# Usage Patterns

Most widget interaction follows this pattern:

```julia
result = widget_function(ctx, parameters...)

# Check for specific events
if (result & Int(RES_SUBMIT)) != 0
    # Widget was clicked/activated
    handle_widget_click()
end

if (result & Int(RES_CHANGE)) != 0
    # Widget value changed
    handle_value_change()
end

if (result & Int(RES_ACTIVE)) != 0
    # Widget is currently being interacted with
    show_active_feedback()
end
```

# Widget-Specific Behavior

## Buttons
```julia
# Buttons mainly use RES_SUBMIT for clicks
result = button(ctx, "Save File")

if (result & Int(RES_SUBMIT)) != 0
    save_current_file()  # Handle button click
end

if (result & Int(RES_ACTIVE)) != 0
    # Button is currently pressed (visual feedback)
    play_button_press_sound()
end
```

## Checkboxes
```julia
# Checkboxes use RES_CHANGE when toggled
checkbox_state = Ref(false)
result = checkbox!(ctx, "Enable feature", checkbox_state)

if (result & Int(RES_CHANGE)) != 0
    println("Checkbox is now: ", checkbox_state[])
    update_feature_state(checkbox_state[])
end
```

## Sliders
```julia
# Sliders use RES_CHANGE when value changes
slider_value = Ref(0.5f0)
result = slider!(ctx, slider_value, 0.0f0, 1.0f0)

if (result & Int(RES_CHANGE)) != 0
    println("New slider value: ", slider_value[])
    update_volume(slider_value[])
end

if (result & Int(RES_ACTIVE)) != 0
    # Slider is being dragged
    show_value_tooltip(slider_value[])
end
```

## Text Input
```julia
# Textboxes use both RES_CHANGE and RES_SUBMIT
text_buffer = Ref("Hello")
result = textbox!(ctx, text_buffer, 100)

if (result & Int(RES_CHANGE)) != 0
    # Text content changed (user typed/deleted)
    validate_input(text_buffer[])
end

if (result & Int(RES_SUBMIT)) != 0
    # User pressed Enter
    submit_text_input(text_buffer[])
    ctx.focus = 0  # Remove focus
end
```

## Number Input
```julia
# Number widgets combine slider and textbox behavior
number_value = Ref(42.0f0)
result = number!(ctx, number_value, 1.0f0)

if (result & Int(RES_CHANGE)) != 0
    # Value changed via drag or text edit
    apply_number_value(number_value[])
end

if (result & Int(RES_SUBMIT)) != 0
    # User finished text editing (pressed Enter)
    finalize_number_input(number_value[])
end
```

# Combining Results

Some widgets can return multiple flags simultaneously:

```julia
result = complex_widget(ctx, params...)

# Check for multiple conditions
if (result & Int(RES_CHANGE | RES_SUBMIT)) != 0
    # Either value changed OR widget was submitted
    handle_widget_event()
end

# Check for specific combination
if result == Int(RES_ACTIVE | RES_CHANGE)
    # Widget is active AND value changed (e.g., dragging slider)
    show_realtime_preview()
end
```

# Event Handling Patterns

## Immediate Response
```julia
# React immediately to any interaction
result = slider!(ctx, volume, 0.0f0, 1.0f0)
if (result & Int(RES_CHANGE)) != 0
    set_audio_volume(volume[])  # Update immediately
end
```

## Deferred Response
```julia
# Only react when interaction is complete
result = textbox!(ctx, filename, 256)
if (result & Int(RES_SUBMIT)) != 0
    load_file(filename[])  # Only load when user presses Enter
end
```

## State Tracking
```julia
# Track interaction state across frames
persistent_state = @static Dict{Symbol, Any}()

result = button(ctx, "Hold to confirm")
if (result & Int(RES_ACTIVE)) != 0
    # Button is being held
    if !haskey(persistent_state, :hold_start)
        persistent_state[:hold_start] = time()
    end
    
    hold_time = time() - persistent_state[:hold_start]
    if hold_time > 2.0  # Held for 2 seconds
        confirm_dangerous_action()
        delete!(persistent_state, :hold_start)
    end
else
    # Button released before confirmation
    delete!(persistent_state, :hold_start)
end
```

# Result Flag Timing

Understanding when flags are set:

## RES_ACTIVE
- **Set**: While mouse button is down over widget
- **Cleared**: When mouse button released or mouse leaves widget
- **Duration**: Can span multiple frames

## RES_SUBMIT  
- **Set**: On mouse button release over focused widget, or Enter key press
- **Cleared**: Automatically at end of frame
- **Duration**: Single frame only

## RES_CHANGE
- **Set**: When widget's value changes during this frame
- **Cleared**: Automatically at end of frame  
- **Duration**: Single frame only

```julia
# Frame-by-frame example:
# Frame 1: User clicks button (mouse down)
result = button(ctx, "Click me")
# result = RES_ACTIVE (1)

# Frame 2: User releases button (mouse up)  
result = button(ctx, "Click me")
# result = RES_ACTIVE | RES_SUBMIT (3)

# Frame 3: No interaction
result = button(ctx, "Click me")  
# result = 0 (no flags)
```

# Error Handling

Always check result values to avoid missing events:

```julia
# Good: Check return value
if button(ctx, "Delete") & Int(RES_SUBMIT) != 0
    delete_item()
end

# Bad: Ignore return value
button(ctx, "Delete")  # User clicks but nothing happens!
```

# Performance

- **Bitwise operations**: Extremely fast flag checking
- **Single integer**: Results are compact (1 byte per widget)
- **No allocations**: Pure integer operations

# Debugging

Print result flags to understand widget behavior:

```julia
result = widget_function(ctx, params...)
if result != 0
    flags = String[]
    (result & Int(RES_ACTIVE)) != 0 && push!(flags, "ACTIVE")
    (result & Int(RES_SUBMIT)) != 0 && push!(flags, "SUBMIT")  
    (result & Int(RES_CHANGE)) != 0 && push!(flags, "CHANGE")
    println("Widget result: ", join(flags, " | "))
end
```

# See Also

- [`button`](@ref), [`checkbox!`](@ref), [`slider!`](@ref): Functions returning Result flags
- [`Option`](@ref): Flags for controlling widget behavior
- [Event Handling Guide](events.md): Advanced event handling patterns
- [Widget Reference](widgets.md): Result flags for each widget type
"""
@enum Result::UInt8 begin
    RES_ACTIVE = 1 << 0   # Widget is currently active/pressed
    RES_SUBMIT = 1 << 1   # Widget was activated (clicked, enter pressed)
    RES_CHANGE = 1 << 2   # Widget value changed this frame
end