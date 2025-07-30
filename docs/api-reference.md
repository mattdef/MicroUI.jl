# MicroUI.jl API Reference

This document provides a comprehensive reference for all functions, types, and constants in MicroUI.jl.

## Table of Contents

- [Core Types](#core-types)
- [Enumerations](#enumerations)
- [Context Management](#context-management)
- [Input Handling](#input-handling)
- [Layout System](#layout-system)
- [Drawing Functions](#drawing-functions)
- [Widgets](#widgets)
- [Containers](#containers)
- [Command System](#command-system)
- [Utility Functions](#utility-functions)
- [Constants](#constants)

---

## Core Types

### `Context`

The main context structure containing all UI state.

```julia
mutable struct Context
    # Rendering callbacks
    text_width::Function
    text_height::Function
    draw_frame::Function
    
    # State and configuration
    style::Style
    hover::Id
    focus::Id
    # ... other fields
end
```

**Required callbacks:**
- `text_width(font, text::String) -> Int` - Measure text width
- `text_height(font) -> Int` - Get font height
- `draw_frame(ctx, rect, colorid) -> Nothing` - Draw widget frame

### `Vec2`

2D integer vector for positions and sizes.

```julia
struct Vec2
    x::Int64
    y::Int64
end
```

**Operations:**
- `Vec2(x, y)` - Constructor
- `a + b` - Vector addition
- `a - b` - Vector subtraction
- `a * scalar` - Scalar multiplication

### `Rect`

Rectangle defined by position and size.

```julia
struct Rect
    x::Int32  # Left edge
    y::Int32  # Top edge
    w::Int32  # Width
    h::Int32  # Height
end
```

### `Color`

RGBA color with 8-bit channels.

```julia
struct Color
    r::UInt8  # Red (0-255)
    g::UInt8  # Green (0-255)
    b::UInt8  # Blue (0-255)
    a::UInt8  # Alpha (0-255, 255=opaque)
end
```

### `Container`

Represents a window, panel, or widget group.

```julia
mutable struct Container
    head::CommandPtr      # Command buffer start
    tail::CommandPtr      # Command buffer end
    rect::Rect           # Screen rectangle
    body::Rect           # Content area
    content_size::Vec2   # Total content size
    scroll::Vec2         # Scroll offset
    zindex::Int32        # Z-order
    open::Bool           # Visibility state
end
```

---

## Enumerations

### `ClipResult`

Result of clipping tests.

- `CLIP_NONE` - Rectangle fully visible
- `CLIP_PART` - Rectangle partially visible
- `CLIP_ALL` - Rectangle completely clipped

### `CommandType`

Types of rendering commands.

- `COMMAND_JUMP` - Jump to different buffer position
- `COMMAND_CLIP` - Set clipping rectangle
- `COMMAND_RECT` - Draw filled rectangle
- `COMMAND_TEXT` - Draw text string
- `COMMAND_ICON` - Draw icon

### `ColorId`

Predefined color indices for UI elements.

- `COLOR_TEXT` - Main text color
- `COLOR_BORDER` - Border color
- `COLOR_WINDOWBG` - Window background
- `COLOR_TITLEBG` - Title bar background
- `COLOR_TITLETEXT` - Title bar text
- `COLOR_PANELBG` - Panel background
- `COLOR_BUTTON` - Button normal state
- `COLOR_BUTTONHOVER` - Button hover state
- `COLOR_BUTTONFOCUS` - Button focused state
- `COLOR_BASE` - Base input control color
- `COLOR_BASEHOVER` - Base input hover
- `COLOR_BASEFOCUS` - Base input focused
- `COLOR_SCROLLBASE` - Scrollbar track
- `COLOR_SCROLLTHUMB` - Scrollbar thumb

### `IconId`

Built-in icon identifiers.

- `ICON_CLOSE` - Close button (X)
- `ICON_CHECK` - Checkmark
- `ICON_COLLAPSED` - Right-pointing triangle
- `ICON_EXPANDED` - Down-pointing triangle

### `MouseButton`

Mouse button flags (can be combined).

- `MOUSE_LEFT` - Left mouse button
- `MOUSE_RIGHT` - Right mouse button
- `MOUSE_MIDDLE` - Middle mouse button

### `Key`

Keyboard key flags (can be combined).

- `KEY_SHIFT` - Shift modifier
- `KEY_CTRL` - Control modifier
- `KEY_ALT` - Alt modifier
- `KEY_BACKSPACE` - Backspace key
- `KEY_RETURN` - Enter/Return key

### `Option`

Widget and container option flags (can be combined).

- `OPT_ALIGNCENTER` - Center-align text
- `OPT_ALIGNRIGHT` - Right-align text
- `OPT_NOINTERACT` - Disable interaction
- `OPT_NOFRAME` - Don't draw frame
- `OPT_NORESIZE` - Disable resizing
- `OPT_NOSCROLL` - Disable scrollbars
- `OPT_NOCLOSE` - Hide close button
- `OPT_NOTITLE` - Hide title bar
- `OPT_HOLDFOCUS` - Keep focus when mouse leaves
- `OPT_AUTOSIZE` - Auto-size to content
- `OPT_POPUP` - Behave as popup
- `OPT_CLOSED` - Start closed
- `OPT_EXPANDED` - Start expanded

### `Result`

Widget result flags.

- `RES_ACTIVE` - Widget is currently active
- `RES_SUBMIT` - Widget was activated (clicked)
- `RES_CHANGE` - Widget value changed

---

## Context Management

### `Context()`

Create a new context with default settings.

```julia
ctx = Context()
```

**Returns:** New `Context` instance

**Note:** You must set the rendering callbacks and call `init!()` before use.

### `init!(ctx::Context)`

Initialize or reset context to default state.

```julia
init!(ctx)
```

**Parameters:**
- `ctx` - Context to initialize

### `begin_frame(ctx::Context)`

Begin a new frame of UI processing.

```julia
begin_frame(ctx)
```

**Parameters:**
- `ctx` - UI context

**Note:** Must be called before any widgets or containers.

### `end_frame(ctx::Context)`

End current frame and prepare for rendering.

```julia
end_frame(ctx)
```

**Parameters:**
- `ctx` - UI context

**Note:** Handles container sorting and command buffer finalization.

### `set_focus!(ctx::Context, id::Id)`

Set keyboard focus to specific widget.

```julia
set_focus!(ctx, id)
```

**Parameters:**
- `ctx` - UI context
- `id` - Widget ID to focus

---

## Input Handling

### `input_mousemove!(ctx::Context, x::Int, y::Int)`

Update mouse position.

```julia
input_mousemove!(ctx, 100, 200)
```

**Parameters:**
- `ctx` - UI context
- `x` - Mouse X coordinate
- `y` - Mouse Y coordinate

### `input_mousedown!(ctx::Context, x::Int, y::Int, btn::MouseButton)`

Handle mouse button press.

```julia
input_mousedown!(ctx, x, y, MOUSE_LEFT)
```

**Parameters:**
- `ctx` - UI context
- `x` - Mouse X coordinate
- `y` - Mouse Y coordinate
- `btn` - Mouse button pressed

### `input_mouseup!(ctx::Context, x::Int, y::Int, btn::MouseButton)`

Handle mouse button release.

```julia
input_mouseup!(ctx, x, y, MOUSE_LEFT)
```

**Parameters:**
- `ctx` - UI context
- `x` - Mouse X coordinate
- `y` - Mouse Y coordinate
- `btn` - Mouse button released

### `input_scroll!(ctx::Context, x::Int, y::Int)`

Handle mouse scroll wheel input.

```julia
input_scroll!(ctx, 0, -3)  # Scroll up
```

**Parameters:**
- `ctx` - UI context
- `x` - Horizontal scroll delta
- `y` - Vertical scroll delta

### `input_keydown!(ctx::Context, key::Key)`

Handle key press event.

```julia
input_keydown!(ctx, KEY_CTRL)
```

**Parameters:**
- `ctx` - UI context
- `key` - Key pressed

### `input_keyup!(ctx::Context, key::Key)`

Handle key release event.

```julia
input_keyup!(ctx, KEY_CTRL)
```

**Parameters:**
- `ctx` - UI context
- `key` - Key released

### `input_text!(ctx::Context, text::String)`

Add text input for current frame.

```julia
input_text!(ctx, "Hello")
```

**Parameters:**
- `ctx` - UI context
- `text` - Text string to add

---

## Layout System

### `layout_row!(ctx::Context, items::Int, widths::Vector{Int}, height::Int)`

Set up new layout row.

```julia
layout_row!(ctx, 3, [100, 200, -1], 30)
```

**Parameters:**
- `ctx` - UI context
- `items` - Number of items in row
- `widths` - Array of column widths (-1 = fill remaining)
- `height` - Row height (0 = auto)

### `layout_width!(ctx::Context, width::Int)`

Set default width for next widget.

```julia
layout_width!(ctx, 150)
```

**Parameters:**
- `ctx` - UI context
- `width` - Default widget width

### `layout_height!(ctx::Context, height::Int)`

Set default height for next widget.

```julia
layout_height!(ctx, 25)
```

**Parameters:**
- `ctx` - UI context
- `height` - Default widget height

### `layout_set_next!(ctx::Context, r::Rect, relative::Bool)`

Manually set rectangle for next widget.

```julia
layout_set_next!(ctx, Rect(10, 10, 100, 30), false)
```

**Parameters:**
- `ctx` - UI context
- `r` - Rectangle for next widget
- `relative` - If true, relative to current position

### `layout_begin_column!(ctx::Context)`

Start column layout context.

```julia
layout_begin_column!(ctx)
# Widgets stack vertically
layout_end_column!(ctx)
```

**Parameters:**
- `ctx` - UI context

### `layout_end_column!(ctx::Context)`

End column layout context.

```julia
layout_end_column!(ctx)
```

**Parameters:**
- `ctx` - UI context

---

## Drawing Functions

### `draw_rect!(ctx::Context, rect::Rect, color::Color)`

Draw filled rectangle.

```julia
draw_rect!(ctx, Rect(10, 10, 100, 50), Color(255, 0, 0, 255))
```

**Parameters:**
- `ctx` - UI context
- `rect` - Rectangle to draw
- `color` - Fill color

### `draw_box!(ctx::Context, rect::Rect, color::Color)`

Draw rectangle outline.

```julia
draw_box!(ctx, Rect(10, 10, 100, 50), Color(0, 0, 0, 255))
```

**Parameters:**
- `ctx` - UI context
- `rect` - Rectangle outline
- `color` - Border color

### `draw_text!(ctx::Context, font::Font, str::String, len::Int, pos::Vec2, color::Color)`

Draw text string.

```julia
draw_text!(ctx, font, "Hello", -1, Vec2(10, 10), Color(0, 0, 0, 255))
```

**Parameters:**
- `ctx` - UI context
- `font` - Font to use
- `str` - Text string
- `len` - String length (-1 = full string)
- `pos` - Text position
- `color` - Text color

### `draw_icon!(ctx::Context, id::IconId, rect::Rect, color::Color)`

Draw built-in icon.

```julia
draw_icon!(ctx, ICON_CHECK, Rect(10, 10, 16, 16), Color(0, 255, 0, 255))
```

**Parameters:**
- `ctx` - UI context
- `id` - Icon identifier
- `rect` - Icon rectangle
- `color` - Icon color

---

## Widgets

### Text Widgets

#### `text(ctx::Context, text::String)`

Multi-line text display with word wrapping.

```julia
text(ctx, "This is a long text\nthat wraps automatically")
```

**Parameters:**
- `ctx` - UI context
- `text` - Text to display

#### `label(ctx::Context, text::String)`

Single-line text label.

```julia
label(ctx, "Username:")
```

**Parameters:**
- `ctx` - UI context
- `text` - Label text

### Button Widgets

#### `button(ctx::Context, label::String) -> Int`

Simple button with centered text.

```julia
if button(ctx, "Click Me") != 0
    println("Button clicked!")
end
```

**Parameters:**
- `ctx` - UI context
- `label` - Button text

**Returns:** Result flags (`RES_SUBMIT` when clicked)

#### `button_ex(ctx::Context, label::String, icon::Union{Nothing, IconId}, opt::UInt16) -> Int`

Button with full customization options.

```julia
if button_ex(ctx, "Save", ICON_CHECK, OPT_ALIGNCENTER) != 0
    save_file()
end
```

**Parameters:**
- `ctx` - UI context
- `label` - Button text
- `icon` - Optional icon
- `opt` - Option flags

**Returns:** Result flags

### Input Widgets

#### `checkbox!(ctx::Context, label::String, state::Ref{Bool}) -> Int`

Checkbox for boolean values.

```julia
enabled = Ref(true)
if checkbox!(ctx, "Enable feature", enabled) != 0
    println("Checkbox toggled: $(enabled[])")
end
```

**Parameters:**
- `ctx` - UI context
- `label` - Checkbox label
- `state` - Boolean state reference

**Returns:** Result flags (`RES_CHANGE` when toggled)

#### `textbox!(ctx::Context, buf::Ref{String}, bufsz::Int) -> Int`

Text input widget.

```julia
text_buffer = Ref("Initial text")
if textbox!(ctx, text_buffer, 256) != 0
    println("Text changed: $(text_buffer[])")
end
```

**Parameters:**
- `ctx` - UI context
- `buf` - String buffer reference
- `bufsz` - Maximum buffer size

**Returns:** Result flags (`RES_CHANGE` when text changes)

#### `textbox_ex!(ctx::Context, buf::Ref{String}, bufsz::Int, opt::UInt16) -> Int`

Textbox with options.

```julia
textbox_ex!(ctx, buf, 256, OPT_ALIGNCENTER)
```

**Parameters:**
- `ctx` - UI context
- `buf` - String buffer reference
- `bufsz` - Maximum buffer size
- `opt` - Option flags

**Returns:** Result flags

#### `slider!(ctx::Context, value::Ref{Real}, low::Real, high::Real) -> Int`

Slider for numeric values.

```julia
volume = Ref(0.5)
if slider!(ctx, volume, 0.0, 1.0) != 0
    println("Volume: $(volume[])")
end
```

**Parameters:**
- `ctx` - UI context
- `value` - Numeric value reference
- `low` - Minimum value
- `high` - Maximum value

**Returns:** Result flags (`RES_CHANGE` when value changes)

#### `slider_ex!(ctx::Context, value::Ref{Real}, low::Real, high::Real, step::Real, fmt::String, opt::UInt16) -> Int`

Slider with step and formatting options.

```julia
slider_ex!(ctx, value, 0.0, 100.0, 1.0, "%.1f", OPT_ALIGNCENTER)
```

**Parameters:**
- `ctx` - UI context
- `value` - Numeric value reference
- `low` - Minimum value
- `high` - Maximum value
- `step` - Step size (0 = continuous)
- `fmt` - Number format string
- `opt` - Option flags

**Returns:** Result flags

#### `number!(ctx::Context, value::Ref{Real}, step::Real) -> Int`

Number input with drag adjustment.

```julia
count = Ref(10.0)
if number!(ctx, count, 1.0) != 0
    println("Count: $(count[])")
end
```

**Parameters:**
- `ctx` - UI context
- `value` - Numeric value reference
- `step` - Drag step size

**Returns:** Result flags

#### `number_ex!(ctx::Context, value::Ref{Real}, step::Real, fmt::String, opt::UInt16) -> Int`

Number input with formatting options.

```julia
number_ex!(ctx, value, 0.1, "%.2f", OPT_ALIGNRIGHT)
```

**Parameters:**
- `ctx` - UI context
- `value` - Numeric value reference
- `step` - Drag step size
- `fmt` - Number format string
- `opt` - Option flags

**Returns:** Result flags

### Header Widgets

#### `header(ctx::Context, label::String) -> Int`

Collapsible header section.

```julia
if header(ctx, "Settings") != 0
    # Header content when expanded
end
```

**Parameters:**
- `ctx` - UI context
- `label` - Header text

**Returns:** Result flags (`RES_ACTIVE` when expanded)

#### `header_ex(ctx::Context, label::String, opt::UInt16) -> Int`

Header with options.

```julia
header_ex(ctx, "Advanced", OPT_EXPANDED)
```

**Parameters:**
- `ctx` - UI context
- `label` - Header text
- `opt` - Option flags

**Returns:** Result flags

### Tree Widgets

#### `begin_treenode(ctx::Context, label::String) -> Int`

Begin collapsible tree node.

```julia
if begin_treenode(ctx, "Folder") != 0
    # Tree node content
    end_treenode(ctx)
end
```

**Parameters:**
- `ctx` - UI context
- `label` - Node label

**Returns:** Result flags (`RES_ACTIVE` when expanded)

#### `begin_treenode_ex(ctx::Context, label::String, opt::UInt16) -> Int`

Tree node with options.

```julia
begin_treenode_ex(ctx, "Root", OPT_EXPANDED)
```

**Parameters:**
- `ctx` - UI context
- `label` - Node label
- `opt` - Option flags

**Returns:** Result flags

#### `end_treenode(ctx::Context)`

End tree node section.

```julia
end_treenode(ctx)
```

**Parameters:**
- `ctx` - UI context

---

## Containers

### Window Management

#### `begin_window(ctx::Context, title::String, rect::Rect) -> Int`

Begin window container.

```julia
if begin_window(ctx, "My Window", Rect(100, 100, 300, 200)) != 0
    # Window content
    end_window(ctx)
end
```

**Parameters:**
- `ctx` - UI context
- `title` - Window title
- `rect` - Initial window rectangle

**Returns:** Result flags (`RES_ACTIVE` if window is open)

#### `begin_window_ex(ctx::Context, title::String, rect::Rect, opt::UInt16) -> Int`

Window with full customization.

```julia
opt = UInt16(OPT_NORESIZE) | UInt16(OPT_NOCLOSE)
begin_window_ex(ctx, "Fixed Window", rect, opt)
```

**Parameters:**
- `ctx` - UI context
- `title` - Window title
- `rect` - Initial window rectangle
- `opt` - Option flags

**Returns:** Result flags

#### `end_window(ctx::Context)`

End window container.

```julia
end_window(ctx)
```

**Parameters:**
- `ctx` - UI context

### Panel Management

#### `begin_panel(ctx::Context, name::String)`

Begin panel container.

```julia
begin_panel(ctx, "sidebar")
    # Panel content
end_panel(ctx)
```

**Parameters:**
- `ctx` - UI context
- `name` - Panel identifier

#### `begin_panel_ex(ctx::Context, name::String, opt::UInt16)`

Panel with options.

```julia
begin_panel_ex(ctx, "panel1", OPT_NOFRAME)
```

**Parameters:**
- `ctx` - UI context
- `name` - Panel identifier
- `opt` - Option flags

#### `end_panel(ctx::Context)`

End panel container.

```julia
end_panel(ctx)
```

**Parameters:**
- `ctx` - UI context

### Popup Management

#### `open_popup!(ctx::Context, name::String)`

Open popup at mouse position.

```julia
if button(ctx, "Menu") != 0
    open_popup!(ctx, "context_menu")
end
```

**Parameters:**
- `ctx` - UI context
- `name` - Popup identifier

#### `begin_popup(ctx::Context, name::String) -> Int`

Begin popup container.

```julia
if begin_popup(ctx, "context_menu") != 0
    if button(ctx, "Copy") != 0
        copy_action()
    end
    if button(ctx, "Paste") != 0
        paste_action()
    end
    end_popup(ctx)
end
```

**Parameters:**
- `ctx` - UI context
- `name` - Popup identifier

**Returns:** Result flags (`RES_ACTIVE` if popup is open)

#### `end_popup(ctx::Context)`

End popup container.

```julia
end_popup(ctx)
```

**Parameters:**
- `ctx` - UI context

---

## Command System

### Command Iteration

#### `CommandIterator(cmdlist::CommandList)`

Create command iterator.

```julia
iter = CommandIterator(ctx.command_list)
```

**Parameters:**
- `cmdlist` - Command list to iterate

**Returns:** Command iterator

#### `next_command!(iter::CommandIterator) -> (Bool, CommandType, CommandPtr)`

Get next command from iterator.

```julia
has_cmd, cmd_type, offset = next_command!(iter)
```

**Parameters:**
- `iter` - Command iterator

**Returns:** Tuple of (has_command, command_type, command_offset)

### Command Reading

#### `read_command(cmdlist::CommandList, idx::CommandPtr, ::Type{T}) -> T`

Read command from buffer.

```julia
rect_cmd = read_command(cmdlist, offset, RectCommand)
```

**Parameters:**
- `cmdlist` - Command list
- `idx` - Command offset
- `T` - Command type

**Returns:** Command structure

#### `get_string(cmdlist::CommandList, str_index::Int32) -> String`

Get string from command list.

```julia
text = get_string(cmdlist, text_cmd.str_index)
```

**Parameters:**
- `cmdlist` - Command list
- `str_index` - String index

**Returns:** String data

---

## Utility Functions

### Geometric Operations

#### `expand_rect(r::Rect, n::Int) -> Rect`

Expand rectangle by n pixels in all directions.

```julia
expanded = expand_rect(rect, 5)
```

**Parameters:**
- `r` - Rectangle to expand
- `n` - Expansion amount

**Returns:** Expanded rectangle

#### `intersect_rects(r1::Rect, r2::Rect) -> Rect`

Calculate intersection of two rectangles.

```julia
overlap = intersect_rects(rect1, rect2)
```

**Parameters:**
- `r1` - First rectangle
- `r2` - Second rectangle

**Returns:** Intersection rectangle

### Clipping Functions

#### `push_clip_rect!(ctx::Context, rect::Rect)`

Push clipping rectangle onto stack.

```julia
push_clip_rect!(ctx, content_area)
```

**Parameters:**
- `ctx` - UI context
- `rect` - Clipping rectangle

#### `pop_clip_rect!(ctx::Context)`

Remove current clipping rectangle.

```julia
pop_clip_rect!(ctx)
```

**Parameters:**
- `ctx` - UI context

#### `get_clip_rect(ctx::Context) -> Rect`

Get current clipping rectangle.

```julia
clip = get_clip_rect(ctx)
```

**Parameters:**
- `ctx` - UI context

**Returns:** Current clipping rectangle

#### `check_clip(ctx::Context, r::Rect) -> ClipResult`

Test rectangle visibility against clip region.

```julia
clip_result = check_clip(ctx, widget_rect)
```

**Parameters:**
- `ctx` - UI context
- `r` - Rectangle to test

**Returns:** Clipping result

### ID Management

#### `get_id(ctx::Context, data::AbstractString) -> Id`

Generate unique ID from string.

```julia
id = get_id(ctx, "my_widget")
```

**Parameters:**
- `ctx` - UI context
- `data` - String data for ID generation

**Returns:** Unique widget ID

#### `push_id!(ctx::Context, data::AbstractString)`

Push ID scope onto stack.

```julia
push_id!(ctx, "panel1")
# Widgets use hierarchical IDs
pop_id!(ctx)
```

**Parameters:**
- `ctx` - UI context
- `data` - Scope identifier

#### `pop_id!(ctx::Context)`

Pop ID scope from stack.

```julia
pop_id!(ctx)
```

**Parameters:**
- `ctx` - UI context

---

## Constants

### Buffer Sizes

- `COMMANDLIST_SIZE = 256 * 1024` - Command buffer size in bytes
- `ROOTLIST_SIZE = 32` - Maximum root containers
- `CONTAINERSTACK_SIZE = 32` - Container stack depth
- `CLIPSTACK_SIZE = 32` - Clipping stack depth
- `IDSTACK_SIZE = 32` - ID stack depth
- `LAYOUTSTACK_SIZE = 16` - Layout stack depth
- `CONTAINERPOOL_SIZE = 48` - Container pool size
- `TREENODEPOOL_SIZE = 48` - Tree node pool size
- `MAX_WIDTHS = 16` - Maximum layout columns

### Format Strings

- `REAL_FMT = "%.3g"` - Default real number format
- `SLIDER_FMT = "%.2f"` - Default slider format
- `MAX_FMT = 127` - Maximum format string length

### Special Values

- `HASH_INITIAL = 0x811c9dc5` - ID hash seed
- `UNCLIPPED_RECT` - Rectangle representing no clipping

---

## Type Aliases

- `Id = UInt32` - Widget identifier type
- `Real = Float32` - Floating point type
- `Font = Any` - Font handle type
- `CommandPtr = Int32` - Command buffer pointer

---

## Style Configuration

The default style provides a dark theme with the following color scheme:

- **Text**: Light gray (230, 230, 230)
- **Background**: Dark gray (50, 50, 50)
- **Buttons**: Medium gray with hover states
- **Borders**: Dark gray (25, 25, 25)
- **Title bars**: Dark background with light text

You can customize colors by modifying `ctx.style.colors[ColorId]` or create your own style structure.