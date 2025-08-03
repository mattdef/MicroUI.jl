# ===== CONTROL HELPERS =====
# Helper functions for implementing interactive widgets

"""
    in_hover_root(ctx::Context) -> Bool

Check if current container stack contains the hover root.

This function determines whether widgets in the current container should respond
to mouse input by checking if the container hierarchy contains the hover root.
Only widgets in the hover root hierarchy should process mouse interactions.

# Arguments
- `ctx::Context`: The MicroUI context

# Returns
- `Bool`: `true` if widgets should respond to mouse input, `false` otherwise

# Hover Root Concept
The hover root is the top-level container (window) that the mouse is currently over.
This system ensures that:
- Only widgets in the active window respond to mouse
- Overlapping windows don't interfere with each other
- Modal dialogs can block input to background windows

# Algorithm
The function traverses the container stack from top to bottom, looking for:
1. A container that matches the current hover root
2. A root container (has `head` field set)

If the hover root is found in the stack, widgets should respond to input.

# Examples
```julia
# Internal usage in widget functions
function button(ctx::Context, label::String)
    # Only process if in hover root
    if !in_hover_root(ctx)
        return 0  # No interaction
    end
    
    # Process button interaction
    # ...
end
```

# Use Cases
- **Input filtering**: Prevent background windows from responding
- **Modal dialogs**: Block input to parent windows
- **Popup menus**: Ensure only popup receives input
- **Window focus**: Maintain proper focus behavior

# See Also
- [`update_control!`](@ref): Uses this for input validation
- [`mouse_over`](@ref): Mouse hit testing
- [`begin_root_container!`](@ref): Sets up hover root detection
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
    draw_control_frame!(ctx::Context, id::Id, rect::Rect, colorid::ColorId, opt::UInt16) -> Nothing

Draw control frame with state-dependent styling.

Automatically selects the appropriate color variant based on the widget's current
interaction state (normal, hover, focus). This provides consistent visual feedback
across all widgets.

# Arguments
- `ctx::Context`: The MicroUI context
- `id::Id`: Widget identifier for state checking
- `rect::Rect`: Rectangle to draw the frame in
- `colorid::ColorId`: Base color identifier from the style palette
- `opt::UInt16`: Option flags, including `OPT_NOFRAME` to skip drawing

# Color State Logic
The function automatically selects colors based on widget state:
- **Normal**: Uses base color (e.g., `COLOR_BUTTON`)
- **Hover**: Uses hover variant (base + 1, e.g., `COLOR_BUTTONHOVER`)
- **Focus**: Uses focus variant (base + 2, e.g., `COLOR_BUTTONFOCUS`)

# Frame Skipping
If `OPT_NOFRAME` is set in options, no frame is drawn. This is useful for:
- Invisible buttons (text-only)
- Custom-styled widgets
- Flat UI designs

# Examples
```julia
# Button widget implementation
function button(ctx::Context, label::String)
    id = get_id(ctx, label)
    rect = layout_next(ctx)
    update_control!(ctx, id, rect, UInt16(0))
    
    # Draw frame with automatic state colors
    draw_control_frame!(ctx, id, rect, COLOR_BUTTON, UInt16(0))
    
    # Draw label text
    draw_control_text!(ctx, label, rect, COLOR_TEXT, UInt16(OPT_ALIGNCENTER))
end

# Invisible button (no frame)
function invisible_button(ctx::Context, label::String)
    id = get_id(ctx, label)
    rect = layout_next(ctx)
    update_control!(ctx, id, rect, UInt16(OPT_NOFRAME))
    
    # No frame drawn due to OPT_NOFRAME
    draw_control_frame!(ctx, id, rect, COLOR_BUTTON, UInt16(OPT_NOFRAME))
end
```

# Color Palette Requirements
The style must define color triplets for proper state rendering:
```julia
# Example color setup
style.colors[Int(COLOR_BUTTON)]      = Color(75, 75, 75, 255)   # Normal
style.colors[Int(COLOR_BUTTONHOVER)] = Color(95, 95, 95, 255)   # Hover
style.colors[Int(COLOR_BUTTONFOCUS)] = Color(115, 115, 115, 255) # Focus
```

# See Also
- [`draw_control_text!`](@ref): Companion function for text rendering
- [`update_control!`](@ref): Widget state management
- [`ColorId`](@ref): Available color identifiers
- [`Option`](@ref): Available option flags
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
    draw_control_text!(ctx::Context, str::String, rect::Rect, colorid::ColorId, opt::UInt16) -> Nothing

Draw control text with proper alignment and clipping.

Handles text positioning within widget rectangles with support for different
alignment modes and automatic clipping to widget bounds.

# Arguments
- `ctx::Context`: The MicroUI context
- `str::String`: Text string to render
- `rect::Rect`: Widget rectangle for text positioning
- `colorid::ColorId`: Text color from the style palette
- `opt::UInt16`: Option flags controlling alignment

# Text Alignment
The function supports three alignment modes:
- **Left** (default): Text aligned to left edge + padding
- **Center** (`OPT_ALIGNCENTER`): Text centered horizontally
- **Right** (`OPT_ALIGNRIGHT`): Text aligned to right edge - padding

# Clipping Behavior
- Automatically clips text to widget rectangle
- Uses push/pop clipping stack for proper nesting
- Ensures text doesn't overflow widget bounds

# Vertical Positioning
Text is always vertically centered within the widget rectangle using:
```julia
pos_y = rect.y + (rect.h - text_height) ÷ 2
```

# Examples
```julia
# Left-aligned text (default)
draw_control_text!(ctx, "Left Text", rect, COLOR_TEXT, UInt16(0))

# Centered text (common for buttons)
draw_control_text!(ctx, "Centered", rect, COLOR_TEXT, UInt16(OPT_ALIGNCENTER))

# Right-aligned text
draw_control_text!(ctx, "Right", rect, COLOR_TEXT, UInt16(OPT_ALIGNRIGHT))
```

# Widget Integration
Typically used in widget implementations:
```julia
function label(ctx::Context, text::String)
    rect = layout_next(ctx)
    draw_control_text!(ctx, text, rect, COLOR_TEXT, UInt16(0))
end

function button(ctx::Context, label::String)
    # ... button frame drawing ...
    draw_control_text!(ctx, label, rect, COLOR_TEXT, UInt16(OPT_ALIGNCENTER))
end
```

# Font and Measurement
Uses the current style font and text measurement callbacks:
- `ctx.text_width(font, str)`: Measure text width
- `ctx.text_height(font)`: Get text line height
- `ctx.style.font`: Current font reference

# See Also
- [`draw_control_frame!`](@ref): Companion function for widget frames
- [`draw_text!`](@ref): Low-level text rendering
- [`Option`](@ref): Alignment option flags
- [`push_clip_rect!`](@ref): Clipping management
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
    mouse_over(ctx::Context, rect::Rect) -> Bool

Test if mouse is over widget rectangle.

Performs comprehensive hit testing that considers mouse position, clipping
regions, and hover root status to determine if a widget should respond to
mouse interaction.

# Arguments
- `ctx::Context`: The MicroUI context
- `rect::Rect`: Widget rectangle to test

# Returns
- `Bool`: `true` if mouse is over the widget and widget should respond, `false` otherwise

# Hit Testing Logic
The function performs three checks:
1. **Rectangle overlap**: Mouse position intersects widget rectangle
2. **Clipping visibility**: Mouse position is within current clipping region
3. **Hover root**: Current container is in the hover root hierarchy

All three conditions must be true for the function to return `true`.

# Examples
```julia
function button(ctx::Context, label::String)
    rect = layout_next(ctx)
    
    if mouse_over(ctx, rect)
        # Mouse is over button - can show hover effects
        ctx.hover = get_id(ctx, label)
    end
    
    # ... rest of button implementation
end
```

# Use Cases
- **Hover detection**: Determine when to show hover effects
- **Tooltip triggers**: Show tooltips when mouse hovers
- **Interactive feedback**: Change cursor or highlight widgets
- **Click validation**: Ensure clicks are within widget bounds

# Clipping Integration
The function respects the current clipping rectangle, ensuring that:
- Widgets outside scrollable areas don't respond
- Overlapped widgets behave correctly
- Modal dialogs properly block input

# Performance Notes
This is a lightweight function suitable for calling every frame:
- Simple rectangle intersection tests
- No allocations
- Fast boolean operations

# See Also
- [`rect_overlaps_vec2`](@ref): Rectangle-point intersection test
- [`get_clip_rect`](@ref): Current clipping rectangle
- [`in_hover_root`](@ref): Hover root validation
- [`update_control!`](@ref): Uses this for mouse interaction
"""
function mouse_over(ctx::Context, rect::Rect)
    return rect_overlaps_vec2(rect, ctx.mouse_pos) &&
           rect_overlaps_vec2(get_clip_rect(ctx), ctx.mouse_pos) &&
           in_hover_root(ctx)
end

"""
    update_control!(ctx::Context, id::Id, rect::Rect, opt::UInt16) -> Nothing

Update widget interaction state.

Handles the complete interaction lifecycle for widgets including hover detection,
focus management, and click processing. This is the core function that makes
widgets interactive.

# Arguments
- `ctx::Context`: The MicroUI context
- `id::Id`: Unique widget identifier
- `rect::Rect`: Widget rectangle for hit testing
- `opt::UInt16`: Option flags controlling interaction behavior

# Interaction States
The function manages three key interaction states:
- **Hover**: Mouse is over the widget
- **Focus**: Widget has keyboard focus and receives input
- **Active**: Widget is being clicked/dragged

# Hover Management
- Sets `ctx.hover = id` when mouse is over widget and no buttons pressed
- Clears hover when mouse moves away from widget
- Respects `OPT_NOINTERACT` flag to disable interaction

# Focus Management
- Grants focus when widget is clicked
- Removes focus when clicking outside widget (unless `OPT_HOLDFOCUS`)
- Removes focus when mouse is released (unless `OPT_HOLDFOCUS`)
- Updates `ctx.updated_focus` flag for frame tracking

# Option Flags
- **`OPT_NOINTERACT`**: Disables all interaction (display-only widget)
- **`OPT_HOLDFOCUS`**: Keeps focus even after mouse release (textboxes, sliders)

# Examples
```julia
# Standard button interaction
function button(ctx::Context, label::String)
    id = get_id(ctx, label)
    rect = layout_next(ctx)
    
    # Handle all interaction states
    update_control!(ctx, id, rect, UInt16(0))
    
    # Check for button press
    if (ctx.mouse_pressed & UInt8(MOUSE_LEFT)) != 0 && ctx.focus == id
        return Int(RES_SUBMIT)  # Button was clicked
    end
    
    return 0
end

# Textbox with focus holding
function textbox(ctx::Context, text::String)
    id = get_id(ctx, text)
    rect = layout_next(ctx)
    
    # Hold focus for text input
    update_control!(ctx, id, rect, UInt16(OPT_HOLDFOCUS))
    
    if ctx.focus == id
        # Process keyboard input
        # ...
    end
end

# Display-only widget (no interaction)
function label(ctx::Context, text::String)
    id = get_id(ctx, text)
    rect = layout_next(ctx)
    
    # No interaction processing
    update_control!(ctx, id, rect, UInt16(OPT_NOINTERACT))
end
```

# Focus Lifecycle
1. **Unfocused**: Widget responds to hover only
2. **Hover**: Mouse over widget, ready for click
3. **Focus**: Widget clicked, receives keyboard input
4. **Active**: Widget being interacted with (drag, type, etc.)
5. **Release**: Return to unfocused or maintain focus

# Performance Notes
- Should be called once per widget per frame
- Efficient boolean operations and state updates
- No allocations in normal operation

# See Also
- [`mouse_over`](@ref): Hit testing implementation
- [`set_focus!`](@ref): Focus management
- [`Option`](@ref): Available option flags
- [`Result`](@ref): Widget result flags
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
    text(ctx::Context, text::String) -> Nothing

Multi-line text display widget with automatic word wrapping.

Displays text with intelligent word wrapping and line breaking. Handles long
text gracefully by breaking it into multiple lines that fit within the current
container width.

# Arguments
- `ctx::Context`: The MicroUI context
- `text::String`: Text content to display (supports newlines and Unicode)

# Text Processing Features
- **Word Wrapping**: Automatically wraps text to fit container width
- **Line Breaks**: Respects explicit newlines (`\\n`) in text
- **Unicode Support**: Handles multi-byte characters correctly
- **Efficient Rendering**: Minimizes allocations during text processing

# Layout Integration
The widget uses the current container's available width:
- Gets width from `container.body.w - (padding * 2)`
- Positions text starting at container origin + padding
- Advances vertically for each line

# Word Wrapping Algorithm
1. Process text character by character
2. Build lines word by word
3. Check if adding next word exceeds available width
4. Break line before word if it doesn't fit
5. Handle explicit newlines immediately

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Text Demo", Rect(50, 50, 300, 200)) != 0
    # Simple text display
    text(ctx, "This is a simple text widget.")
    
    # Multi-line text with manual breaks
    text(ctx, "Line 1\\nLine 2\\nLine 3")
    
    # Long text with automatic wrapping
    text(ctx, "This is a very long text that will automatically wrap to multiple lines when it exceeds the available width of the container.")
    
    # Mixed content
    text(ctx, "Short line\\nThis is a longer line that might wrap\\nShort again")
    
    end_window(ctx)
end

end_frame(ctx)
```

# Performance Characteristics
- **Zero allocations** for single-line text that fits
- **One allocation per line** for wrapped text (unavoidable with current API)
- **Character-based processing** for accurate word boundary detection
- **Early termination** for text that fits on one line

# Styling
Uses style properties for appearance:
- `ctx.style.font`: Font for text rendering
- `ctx.style.colors[COLOR_TEXT]`: Text color
- `ctx.style.padding`: Margin from container edges

# Unicode and Character Handling
- Properly handles UTF-8 multi-byte sequences
- Uses character count for width estimation
- Preserves character boundaries when breaking lines

# See Also
- [`label`](@ref): Single-line text widget
- [`draw_text!`](@ref): Low-level text rendering
- [`get_current_container`](@ref): Container width calculation
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
    label(ctx::Context, text::String) -> Nothing

Simple text label widget for single-line text display.

Displays a single line of text within the next layout slot. Unlike [`text`](@ref),
this widget integrates with the layout system and is intended for labels, captions,
and other single-line text elements.

# Arguments
- `ctx::Context`: The MicroUI context
- `text::String`: Text content to display

# Layout Integration
- Takes the next available layout slot via `layout_next(ctx)`
- Respects current layout row configuration
- Text is left-aligned with padding by default

# Differences from `text()`
- **Single line**: No word wrapping or line breaking
- **Layout aware**: Uses layout system positioning
- **Truncation**: Text may be clipped if too long for layout slot
- **Performance**: More efficient for simple labels

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Form", Rect(50, 50, 300, 200)) != 0
    # Form labels with layout
    layout_row!(ctx, 2, [100, 180], 25)
    
    label(ctx, "Name:")
    textbox!(ctx, name_ref, 50)
    
    label(ctx, "Email:")
    textbox!(ctx, email_ref, 50)
    
    label(ctx, "Age:")
    number!(ctx, age_ref, 1.0)
    
    end_window(ctx)
end

end_frame(ctx)
```

# Layout Patterns
```julia
# Single column labels
layout_row!(ctx, 1, [-1], 0)
label(ctx, "Section Header")
label(ctx, "Description text")

# Multi-column with labels
layout_row!(ctx, 3, [80, 100, -1], 0)
label(ctx, "Field 1:")
label(ctx, "Field 2:")
label(ctx, "Field 3:")
```

# Styling
Uses the same styling as other text:
- `COLOR_TEXT` for text color
- Current style font
- Left alignment with padding

# Performance
Ideal for:
- Form labels
- Button text
- Status indicators
- Simple captions

# See Also
- [`text`](@ref): Multi-line text with word wrapping
- [`draw_control_text!`](@ref): Underlying text rendering
- [`layout_next`](@ref): Layout system integration
"""
function label(ctx::Context, text::String)
    draw_control_text!(ctx, text, layout_next(ctx), COLOR_TEXT, UInt16(0))
end

"""
    button_ex(ctx::Context, label::String, icon::Union{Nothing, IconId}, opt::UInt16) -> Int

Button widget with full customization options.

Creates an interactive button with optional icon, custom styling, and configurable
behavior. This is the most flexible button creation function.

# Arguments
- `ctx::Context`: The MicroUI context
- `label::String`: Button text (can be empty if using icon only)
- `icon::Union{Nothing, IconId}`: Optional icon to display
- `opt::UInt16`: Option flags controlling button behavior and appearance

# Returns
- `Int`: Button result flags (see [`Result`](@ref))
  - `RES_SUBMIT`: Button was clicked this frame
  - `RES_ACTIVE`: Button is currently pressed (rare)

# Button Features
- **Text and Icon**: Can display text, icon, or both
- **State Feedback**: Visual feedback for hover, focus, and active states
- **Alignment Control**: Text alignment via option flags
- **Interaction**: Full mouse interaction with click detection

# Icon Support
When an icon is provided:
- Icon is drawn within the button rectangle
- Text and icon can coexist
- Icon uses text color for consistency

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Buttons", Rect(50, 50, 300, 200)) != 0
    # Standard text button
    if button_ex(ctx, "Save", nothing, UInt16(0)) != 0
        save_document()
    end
    
    # Centered text button
    if button_ex(ctx, "OK", nothing, UInt16(OPT_ALIGNCENTER)) != 0
        confirm_action()
    end
    
    # Icon-only button
    if button_ex(ctx, "", ICON_CLOSE, UInt16(0)) != 0
        close_window()
    end
    
    # Icon + text button
    if button_ex(ctx, "Save", ICON_CHECK, UInt16(OPT_ALIGNCENTER)) != 0
        save_and_confirm()
    end
    
    # Right-aligned button
    if button_ex(ctx, "Cancel", nothing, UInt16(OPT_ALIGNRIGHT)) != 0
        cancel_operation()
    end
    
    end_window(ctx)
end

end_frame(ctx)
```

# Button States and Colors
The button automatically uses appropriate colors based on interaction:
- **Normal**: `COLOR_BUTTON`
- **Hover**: `COLOR_BUTTONHOVER`
- **Focus/Active**: `COLOR_BUTTONFOCUS`

# Event Handling Pattern
```julia
# Store result for multiple checks
result = button_ex(ctx, "Multi-Action", nothing, UInt16(0))

if (result & Int(RES_SUBMIT)) != 0
    # Primary action on click
    perform_action()
end

if (result & Int(RES_ACTIVE)) != 0
    # Continuous action while pressed (rare)
    show_pressed_feedback()
end
```

# Accessibility
- Buttons provide clear visual feedback
- Support both mouse and keyboard interaction
- Consistent behavior across the UI

# See Also
- [`button`](@ref): Simplified button creation
- [`IconId`](@ref): Available icon types
- [`Option`](@ref): Alignment and behavior flags
- [`Result`](@ref): Button result flags
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
    button(ctx::Context, label::String) -> Int

Simple button widget with center-aligned text.

Creates a standard button with the given label text, center-aligned within the button.
This is the most commonly used button function for typical UI needs.

# Arguments
- `ctx::Context`: The MicroUI context
- `label::String`: Button text to display

# Returns
- `Int`: Button result flags, non-zero if button was clicked

# Default Behavior
- Center-aligned text
- Standard button colors and frame
- Full mouse interaction
- No icon

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Dialog", Rect(100, 100, 250, 150)) != 0
    text(ctx, "Are you sure you want to delete this file?")
    
    layout_row!(ctx, 2, [100, 100], 0)
    
    if button(ctx, "Yes") != 0
        delete_file()
        close_dialog()
    end
    
    if button(ctx, "No") != 0
        close_dialog()
    end
    
    end_window(ctx)
end

end_frame(ctx)
```

# Common Patterns
```julia
# Simple action button
if button(ctx, "Save") != 0
    save_document()
end

# Navigation buttons
layout_row!(ctx, 3, [80, 80, 80], 0)
if button(ctx, "Back") != 0
    go_back()
end
if button(ctx, "Forward") != 0
    go_forward()
end
if button(ctx, "Home") != 0
    go_home()
end

# OK/Cancel pattern
layout_row!(ctx, 2, [-1, -1], 0)
if button(ctx, "OK") != 0
    confirm_action()
end
if button(ctx, "Cancel") != 0
    cancel_action()
end
```

# Button Sizing
- Takes next layout slot automatically
- Respects current layout row configuration
- Minimum size defined by style settings

# See Also
- [`button_ex`](@ref): Button with full customization options
- [`layout_row!`](@ref): Control button layout and sizing
- [`draw_control_frame!`](@ref): Button frame rendering
"""
button(ctx::Context, label::String) = button_ex(ctx, label, nothing, UInt16(OPT_ALIGNCENTER))

"""
    checkbox!(ctx::Context, label::String, state::Ref{Bool}) -> Int

Checkbox widget for boolean values with persistent state.

Creates an interactive checkbox that toggles between checked and unchecked states.
The state is stored in a `Ref{Bool}` that persists between frames, making it suitable
for application settings, options, and boolean flags.

# Arguments
- `ctx::Context`: The MicroUI context
- `label::String`: Text label displayed next to the checkbox
- `state::Ref{Bool}`: Reference to boolean value (modified by widget)

# Returns
- `Int`: Widget result flags
  - `RES_CHANGE`: Checkbox state was toggled this frame
  - Other result flags as applicable

# State Management
The checkbox modifies the `state[]` value when clicked:
- `true`: Checkbox is checked (shows checkmark)
- `false`: Checkbox is unchecked (empty box)

# Visual Design
- **Checkbox box**: Square box using `COLOR_BASE` colors
- **Checkmark**: `ICON_CHECK` displayed when state is `true`
- **Label**: Text displayed to the right of the checkbox
- **State colors**: Different colors for normal, hover, and focus states

# Examples
```julia
# Application settings
settings_auto_save = Ref(true)
settings_dark_mode = Ref(false)
settings_notifications = Ref(true)

ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Settings", Rect(50, 50, 300, 200)) != 0
    text(ctx, "Application Settings:")
    
    # Auto-save option
    if checkbox!(ctx, "Enable auto-save", settings_auto_save) & Int(RES_CHANGE) != 0
        println("Auto-save toggled to: ", settings_auto_save[])
        update_auto_save_setting(settings_auto_save[])
    end
    
    # Dark mode option
    if checkbox!(ctx, "Dark mode", settings_dark_mode) & Int(RES_CHANGE) != 0
        println("Dark mode toggled to: ", settings_dark_mode[])
        apply_theme(settings_dark_mode[] ? "dark" : "light")
    end
    
    # Notifications option
    checkbox!(ctx, "Enable notifications", settings_notifications)
    
    end_window(ctx)
end

end_frame(ctx)
```

# Form Integration
```julia
# Form with multiple checkboxes
struct UserPreferences
    email_notifications::Ref{Bool}
    sms_notifications::Ref{Bool}
    newsletter::Ref{Bool}
    marketing::Ref{Bool}
end

prefs = UserPreferences(Ref(true), Ref(false), Ref(true), Ref(false))

# In UI code
text(ctx, "Notification Preferences:")
checkbox!(ctx, "Email notifications", prefs.email_notifications)
checkbox!(ctx, "SMS notifications", prefs.sms_notifications)
checkbox!(ctx, "Newsletter subscription", prefs.newsletter)
checkbox!(ctx, "Marketing emails", prefs.marketing)
```

# State Persistence
The checkbox state persists automatically between frames:
```julia
# State persists across multiple frames
enabled = Ref(false)

# Frame 1
checkbox!(ctx, "Feature enabled", enabled)  # User clicks, enabled[] becomes true

# Frame 2
checkbox!(ctx, "Feature enabled", enabled)  # Still shows as checked

# Frame 3
checkbox!(ctx, "Feature enabled", enabled)  # User clicks again, enabled[] becomes false
```

# Layout Integration
- Checkbox box is square, sized to row height
- Label takes remaining width in layout slot
- Integrates with standard layout system

# See Also
- [`Ref{Bool}`](https://docs.julialang.org/en/v1/base/c/#Base.Ref): Reference type for state storage
- [`Result`](@ref): Widget result flags
- [`COLOR_BASE`](@ref): Base widget colors
- [`ICON_CHECK`](@ref): Checkmark icon
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
    textbox_raw!(ctx::Context, buf::Ref{String}, bufsz::Int, id::Id, r::Rect, opt::UInt16) -> Int

Raw textbox implementation with full control over positioning and behavior.

This is the low-level textbox implementation that provides complete control over
text input behavior. It handles text editing, cursor display, and keyboard input
processing. Higher-level textbox functions build on this implementation.

# Arguments
- `ctx::Context`: The MicroUI context
- `buf::Ref{String}`: Reference to string buffer (modified by widget)
- `bufsz::Int`: Maximum buffer size in characters
- `id::Id`: Unique widget identifier
- `r::Rect`: Widget rectangle for positioning
- `opt::UInt16`: Option flags controlling behavior

# Returns
- `Int`: Widget result flags
  - `RES_CHANGE`: Text content was modified
  - `RES_SUBMIT`: Enter key was pressed (text submitted)

# Text Editing Features
- **Text Input**: Processes characters from `ctx.input_text`
- **Backspace**: Handles character deletion with UTF-8 awareness
- **Enter Key**: Submits text and removes focus
- **Focus Management**: Uses `OPT_HOLDFOCUS` for proper text editing
- **Visual Cursor**: Shows text cursor when focused

# Keyboard Handling
The textbox responds to several keyboard inputs:
- **Character Input**: Appends new characters to buffer
- **Backspace**: Removes last character (UTF-8 safe)
- **Enter/Return**: Submits text and removes focus

# Visual States
- **Unfocused**: Shows current text content
- **Focused**: Shows text with blinking cursor at end
- **Overflow**: Scrolls text horizontally when too long

# Buffer Management
- Respects `bufsz` limit to prevent overflow
- Handles UTF-8 character boundaries correctly
- Modifies `buf[]` content in-place

# Examples
```julia
# Custom textbox with specific positioning
text_buffer = Ref("Initial text")
custom_id = get_id(ctx, "custom_input")
custom_rect = Rect(100, 50, 200, 25)

result = textbox_raw!(ctx, text_buffer, 100, custom_id, custom_rect, UInt16(0))

if (result & Int(RES_CHANGE)) != 0
    println("Text changed to: ", text_buffer[])
end

if (result & Int(RES_SUBMIT)) != 0
    println("Text submitted: ", text_buffer[])
    process_input(text_buffer[])
end
```

# UTF-8 Safety
The textbox properly handles UTF-8 multi-byte characters:
- Backspace removes complete characters, not bytes
- Character counting respects Unicode boundaries
- Text rendering handles all Unicode characters

# Focus Behavior
- Gains focus when clicked
- Retains focus during text editing (`OPT_HOLDFOCUS`)
- Loses focus when Enter is pressed or clicked outside

# See Also
- [`textbox!`](@ref): High-level textbox widget
- [`textbox_ex!`](@ref): Textbox with options
- [`Result`](@ref): Widget result flags
- [`update_control!`](@ref): Interaction management
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
    textbox_ex!(ctx::Context, buf::Ref{String}, bufsz::Int, opt::UInt16) -> Int

Textbox widget with custom options and buffer size.

Creates a text input widget with configurable maximum length and behavior options.
This provides more control than the basic [`textbox!`](@ref) function while still
handling automatic positioning through the layout system.

# Arguments
- `ctx::Context`: The MicroUI context
- `buf::Ref{String}`: Reference to string buffer (modified by widget)
- `bufsz::Int`: Maximum buffer size in characters
- `opt::UInt16`: Option flags controlling appearance and behavior

# Returns
- `Int`: Widget result flags
  - `RES_CHANGE`: Text content was modified
  - `RES_SUBMIT`: Enter key was pressed

# Buffer Size Control
The `bufsz` parameter limits the maximum text length:
```julia
short_text = Ref("Hi")
long_text = Ref("This is a longer piece of text")

# Short textbox (max 10 characters)
textbox_ex!(ctx, short_text, 10, UInt16(0))

# Long textbox (max 200 characters)
textbox_ex!(ctx, long_text, 200, UInt16(0))
```

# Examples
```julia
# Form with different textbox types
username = Ref("user")
password = Ref("")
description = Ref("")

ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "User Form", Rect(50, 50, 350, 250)) != 0
    layout_row!(ctx, 2, [100, 200], 25)
    
    # Username (limited to 20 characters)
    label(ctx, "Username:")
    if textbox_ex!(ctx, username, 20, UInt16(0)) & Int(RES_SUBMIT) != 0
        validate_username(username[])
    end
    
    # Password (limited to 50 characters, could add password styling)
    label(ctx, "Password:")
    textbox_ex!(ctx, password, 50, UInt16(0))
    
    # Description (longer text allowed)
    label(ctx, "Description:")
    textbox_ex!(ctx, description, 500, UInt16(0))
    
    end_window(ctx)
end

end_frame(ctx)
```

# Option Flags
Common options include:
- `UInt16(0)`: Standard textbox
- `UInt16(OPT_ALIGNCENTER)`: Center-aligned text
- `UInt16(OPT_ALIGNRIGHT)`: Right-aligned text

# Automatic ID Generation
The widget automatically generates a unique ID based on the buffer reference:
```julia
# Each textbox gets a unique ID
id = get_id(ctx, "textbox_" * string(objectid(buf)))
```

# Text Validation
```julia
email = Ref("user@example.com")

result = textbox_ex!(ctx, email, 100, UInt16(0))

if (result & Int(RES_CHANGE)) != 0
    # Validate email format as user types
    if !is_valid_email(email[])
        show_error("Invalid email format")
    end
end

if (result & Int(RES_SUBMIT)) != 0
    # Final validation on submit
    if is_valid_email(email[])
        save_email(email[])
    else
        focus_textbox()  # Keep focus for correction
    end
end
```

# See Also
- [`textbox!`](@ref): Simple textbox with default size
- [`textbox_raw!`](@ref): Low-level textbox implementation
- [`Ref{String}`](https://docs.julialang.org/en/v1/base/c/#Base.Ref): Reference type for text storage
"""
function textbox_ex!(ctx::Context, buf::Ref{String}, bufsz::Int, opt::UInt16)
    id = get_id(ctx, "textbox_" * string(objectid(buf)))
    r = layout_next(ctx)
    return textbox_raw!(ctx, buf, bufsz, id, r, opt)
end

"""
    textbox!(ctx::Context, buf::Ref{String}, bufsz::Int) -> Int

Simple textbox widget with default options.

Creates a standard text input widget with the specified maximum buffer size.
This is the most commonly used textbox function for typical text input needs.

# Arguments
- `ctx::Context`: The MicroUI context
- `buf::Ref{String}`: Reference to string buffer (modified by widget)
- `bufsz::Int`: Maximum buffer size in characters

# Returns
- `Int`: Widget result flags
  - `RES_CHANGE`: Text was modified
  - `RES_SUBMIT`: Enter key was pressed

# Default Behavior
- Left-aligned text with padding
- Standard textbox frame and colors
- Full keyboard interaction
- UTF-8 character support

# Examples
```julia
# Simple text input
user_input = Ref("Type here...")

ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Input Demo", Rect(50, 50, 300, 150)) != 0
    text(ctx, "Enter your name:")
    
    if textbox!(ctx, user_input, 50) & Int(RES_SUBMIT) != 0
        println("User entered: ", user_input[])
        process_name(user_input[])
    end
    
    end_window(ctx)
end

end_frame(ctx)
```

# Common Patterns
```julia
# Form fields
name_field = Ref("")
email_field = Ref("")
phone_field = Ref("")

layout_row!(ctx, 2, [80, 200], 0)

label(ctx, "Name:")
textbox!(ctx, name_field, 100)

label(ctx, "Email:")
textbox!(ctx, email_field, 200)

label(ctx, "Phone:")
textbox!(ctx, phone_field, 20)

# Search box
search_query = Ref("")
layout_row!(ctx, 2, [200, 80], 0)

if textbox!(ctx, search_query, 100) & Int(RES_SUBMIT) != 0
    perform_search(search_query[])
end

if button(ctx, "Search") != 0
    perform_search(search_query[])
end
```

# Buffer Size Guidelines
Choose appropriate buffer sizes based on expected content:
- **Names**: 50-100 characters
- **Email addresses**: 200 characters
- **Phone numbers**: 20-30 characters
- **Short descriptions**: 500 characters
- **Comments**: 1000+ characters

# See Also
- [`textbox_ex!`](@ref): Textbox with custom options
- [`textbox_raw!`](@ref): Low-level textbox implementation
- [`label`](@ref): Text labels for form fields
"""
textbox!(ctx::Context, buf::Ref{String}, bufsz::Int) = textbox_ex!(ctx, buf, bufsz, UInt16(0))

"""
    number_textbox!(ctx::Context, value::Ref{Real}, r::Rect, id::Id) -> Bool

Number editing textbox for slider and number widgets.

Handles special number editing mode activated by Shift+click on numeric widgets.
When active, it converts the numeric value to text for precise editing, then
converts back to numeric when editing is complete.

# Arguments
- `ctx::Context`: The MicroUI context
- `value::Ref{Real}`: Reference to numeric value being edited
- `r::Rect`: Widget rectangle for the textbox
- `id::Id`: Widget identifier (shared with parent numeric widget)

# Returns
- `Bool`: `true` if number editing mode is active, `false` otherwise

# Number Editing Workflow
1. **Activation**: Shift+click on numeric widget starts editing mode
2. **Text Conversion**: Current value is formatted as editable text
3. **Text Editing**: User can type exact numeric values
4. **Completion**: Enter key or losing focus converts back to number
5. **Error Handling**: Invalid input preserves original value

# Activation Conditions
Number editing mode is triggered when:
- Mouse is pressed with left button
- Shift key is held down
- Mouse is over the widget (hover state)
- Widget has the specified ID

# Text Formatting
Uses [`format_real`](@ref) for consistent number-to-string conversion:
```julia
ctx.number_edit_buf = format_real(value[], REAL_FMT)
```

# Examples
```julia
# Used internally by slider and number widgets
function slider!(ctx::Context, value::Ref{Real}, low::Real, high::Real)
    id = get_id(ctx, "slider_" * string(objectid(value)))
    rect = layout_next(ctx)
    
    # Check for number editing mode
    if number_textbox!(ctx, value, rect, id)
        return 0  # Skip normal slider behavior
    end
    
    # Normal slider interaction
    # ...
end
```

# Precision Input
Number editing allows users to input precise values:
```julia
# User can Shift+click slider to type exact value
slider!(ctx, volume, 0.0f0, 1.0f0)  # Normal: drag to ~0.7
# Shift+click opens textbox
# User types: "0.75"
# Enter confirms: volume[] = 0.75f0 exactly
```

# Error Handling
Invalid text input is handled gracefully:
- Parse errors preserve the original value
- Focus loss cancels editing mode
- Enter key attempts conversion and exits mode

# State Management
The function manages global editing state:
- `ctx.number_edit`: ID of widget being edited (0 = none)
- `ctx.number_edit_buf`: Current text buffer content

# See Also
- [`slider!`](@ref): Uses this for precise value input
- [`number!`](@ref): Uses this for direct number editing
- [`format_real`](@ref): Number-to-string formatting
- [`textbox_raw!`](@ref): Underlying text editing implementation
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
    slider_ex!(ctx::Context, value::Ref{Real}, low::Real, high::Real, step::Real, fmt::String, opt::UInt16) -> Int

Slider widget with full customization options.

Creates an interactive slider for selecting numeric values within a specified range.
Supports dragging, precise text input (Shift+click), step quantization, and custom
formatting. This is the most flexible slider implementation.

# Arguments
- `ctx::Context`: The MicroUI context
- `value::Ref{Real}`: Reference to numeric value (modified by widget)
- `low::Real`: Minimum slider value
- `high::Real`: Maximum slider value
- `step::Real`: Step size for quantization (0 for continuous)
- `fmt::String`: Format string for value display
- `opt::UInt16`: Option flags controlling appearance

# Returns
- `Int`: Widget result flags
  - `RES_CHANGE`: Slider value was changed this frame

# Interaction Methods
1. **Mouse Dragging**: Click and drag to adjust value
2. **Precise Input**: Shift+click to enter exact value via textbox
3. **Step Quantization**: Values snap to step boundaries when step > 0

# Value Mapping
The slider maps mouse position to value range:
```julia
# Mouse position to value calculation
relative_pos = (mouse_x - slider_x) / slider_width
value = low + relative_pos * (high - low)
```

# Step Quantization
When step > 0, values are quantized:
```julia
if step != 0
    value = round(value / step) * step
end
```

# Examples
```julia
volume = Ref(0.5f0)
brightness = Ref(75.0f0)
temperature = Ref(20.5f0)

ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Controls", Rect(50, 50, 300, 250)) != 0
    # Volume slider (0-1, continuous, percentage display)
    text(ctx, "Volume:")
    if slider_ex!(ctx, volume, 0.0f0, 1.0f0, 0.0f0, "%.1f%%", UInt16(OPT_ALIGNCENTER)) & Int(RES_CHANGE) != 0
        set_audio_volume(volume[])
    end
    
    # Brightness slider (0-100, step by 5, integer display)
    text(ctx, "Brightness:")
    slider_ex!(ctx, brightness, 0.0f0, 100.0f0, 5.0f0, "%.0f", UInt16(OPT_ALIGNCENTER))
    
    # Temperature slider (-10 to 50, step by 0.5, celsius display)
    text(ctx, "Temperature:")
    slider_ex!(ctx, temperature, -10.0f0, 50.0f0, 0.5f0, "%.1f°C", UInt16(OPT_ALIGNCENTER))
    
    end_window(ctx)
end

end_frame(ctx)
```

# Custom Formatting
The format string controls value display:
```julia
# Different format examples
slider_ex!(ctx, val, 0.0f0, 1.0f0, 0.0f0, "%.2f", opt)     # "0.75"
slider_ex!(ctx, val, 0.0f0, 100.0f0, 1.0f0, "%.0f%%", opt) # "75%"
slider_ex!(ctx, val, 0.0f0, 360.0f0, 1.0f0, "%.0f°", opt)  # "180°"
```

# Range Validation
Values are automatically clamped to the specified range:
```julia
# Value cannot go outside [low, high] bounds
value[] = clamp(value[], low, high)
```

# Visual Components
- **Base Track**: Background slider track using `COLOR_BASE`
- **Thumb**: Draggable thumb using `COLOR_BUTTON` with state colors
- **Value Text**: Formatted value display overlaid on slider

# Precise Input Mode
Shift+click activates text input for exact values:
```julia
# Normal interaction: drag to approximately 0.7
# Shift+click: textbox opens, type "0.73", press Enter
# Result: value[] = 0.73f0 exactly
```

# See Also
- [`slider!`](@ref): Simple slider with default formatting
- [`number_textbox!`](@ref): Precise input implementation
- [`format_real`](@ref): Value formatting function
- [`Real`](@ref): Numeric type used for values
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
    slider!(ctx::Context, value::Ref{Real}, low::Real, high::Real) -> Int

Simple slider widget with default formatting and center alignment.

Creates a standard slider with continuous values, percentage-style formatting,
and center-aligned text. This is the most commonly used slider function.

# Arguments
- `ctx::Context`: The MicroUI context
- `value::Ref{Real}`: Reference to numeric value (modified by widget)
- `low::Real`: Minimum slider value
- `high::Real`: Maximum slider value

# Returns
- `Int`: Widget result flags, non-zero if value changed

# Default Behavior
- **Continuous**: No step quantization (smooth movement)
- **Format**: Uses `SLIDER_FMT` ("%.2f") for display
- **Alignment**: Center-aligned text over slider
- **Interaction**: Full mouse dragging + Shift+click for precise input

# Examples
```julia
# Audio controls
volume = Ref(0.5f0)        # 50% volume
balance = Ref(0.0f0)       # Center balance
bass = Ref(0.0f0)          # Neutral bass

ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Audio Settings", Rect(50, 50, 300, 200)) != 0
    text(ctx, "Audio Controls:")
    
    # Volume slider (0-100%)
    layout_row!(ctx, 2, [80, 180], 0)
    label(ctx, "Volume:")
    if slider!(ctx, volume, 0.0f0, 1.0f0) & Int(RES_CHANGE) != 0
        set_audio_volume(volume[])
    end
    
    # Balance slider (-100% to +100%)
    label(ctx, "Balance:")
    slider!(ctx, balance, -1.0f0, 1.0f0)
    
    # Bass control (-20dB to +20dB)
    label(ctx, "Bass:")
    slider!(ctx, bass, -20.0f0, 20.0f0)
    
    end_window(ctx)
end

end_frame(ctx)
```

# Common Use Cases
```julia
# Settings sliders
ui_scale = Ref(1.0f0)      # UI scale factor
mouse_sensitivity = Ref(0.5f0)  # Mouse sensitivity
scroll_speed = Ref(1.0f0)  # Scroll wheel speed

# Graphics settings
gamma = Ref(2.2f0)         # Display gamma
contrast = Ref(1.0f0)      # Contrast level
saturation = Ref(1.0f0)    # Color saturation

# Game settings
difficulty = Ref(0.5f0)    # Difficulty level (0=easy, 1=hard)
music_volume = Ref(0.8f0)  # Background music volume
effects_volume = Ref(0.9f0) # Sound effects volume

# All use the same simple pattern:
if slider!(ctx, setting_value, min_val, max_val) & Int(RES_CHANGE) != 0
    apply_setting(setting_value[])
end
```

# Value Display
The slider displays the current value using the default format:
- `0.50` → "0.50" (for volume at 50%)
- `0.00` → "0.00" (for centered balance)
- `15.75` → "15.75" (for temperature in celsius)

# Range Guidelines
Choose ranges appropriate for the setting:
- **Percentages**: 0.0 to 1.0
- **Angles**: 0.0 to 360.0
- **Decibels**: -60.0 to 6.0
- **Temperatures**: -10.0 to 50.0

# See Also
- [`slider_ex!`](@ref): Slider with full customization options
- [`number!`](@ref): Alternative numeric input widget
- [`Real`](@ref): Numeric type for slider values
- [`format_real`](@ref): Value formatting
"""
slider!(ctx::Context, value::Ref{Real}, low::Real, high::Real) = 
    slider_ex!(ctx, value, low, high, Real(0.0), SLIDER_FMT, UInt16(OPT_ALIGNCENTER))

"""
    number_ex!(ctx::Context, value::Ref{Real}, step::Real, fmt::String, opt::UInt16) -> Int

Number input widget with drag adjustment and full customization.

Creates a numeric input widget that allows both precise text input and mouse
drag adjustment. This combines the precision of a textbox with the convenience
of slider-style interaction.

# Arguments
- `ctx::Context`: The MicroUI context
- `value::Ref{Real}`: Reference to numeric value (modified by widget)
- `step::Real`: Step size for mouse drag adjustment
- `fmt::String`: Format string for value display
- `opt::UInt16`: Option flags controlling appearance

# Returns
- `Int`: Widget result flags
  - `RES_CHANGE`: Value was modified this frame

# Interaction Methods
1. **Text Input**: Click to enter precise values via textbox
2. **Mouse Drag**: Click and drag horizontally to adjust value
3. **Keyboard**: Arrow keys and other input when focused

# Drag Adjustment
Mouse dragging adjusts the value incrementally:
```julia
# Each pixel of mouse movement = one step
value[] += Real(mouse_delta_x) * step
```

# Examples
```julia
position_x = Ref(100.0f0)
rotation = Ref(0.0f0)
scale = Ref(1.0f0)
count = Ref(10.0f0)

ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Transform", Rect(50, 50, 300, 200)) != 0
    layout_row!(ctx, 2, [80, 120], 0)
    
    # Position (step by 1 pixel, 1 decimal place)
    label(ctx, "X Position:")
    number_ex!(ctx, position_x, 1.0f0, "%.1f px", UInt16(OPT_ALIGNRIGHT))
    
    # Rotation (step by 1 degree, integer display)
    label(ctx, "Rotation:")
    number_ex!(ctx, rotation, 1.0f0, "%.0f°", UInt16(OPT_ALIGNRIGHT))
    
    # Scale (step by 0.1, 2 decimal places)
    label(ctx, "Scale:")
    number_ex!(ctx, scale, 0.1f0, "%.2fx", UInt16(OPT_ALIGNRIGHT))
    
    # Count (step by 1, integer display)
    label(ctx, "Count:")
    number_ex!(ctx, count, 1.0f0, "%.0f items", UInt16(OPT_ALIGNRIGHT))
    
    end_window(ctx)
end

end_frame(ctx)
```

# Step Size Guidelines
Choose step sizes appropriate for the value type:
- **Positions**: 1.0 (pixels) or 0.1 (units)
- **Angles**: 1.0 (degrees) or 0.1 (radians)
- **Scales**: 0.1 or 0.01
- **Counts**: 1.0 (integers)
- **Percentages**: 0.01 (1%)

# Custom Formatting
Format strings control the display:
```julia
number_ex!(ctx, val, 1.0f0, "%.0f", opt)        # "42"
number_ex!(ctx, val, 0.1f0, "%.1f%%", opt)      # "75.5%"
number_ex!(ctx, val, 1.0f0, "\$%.2f", opt)       # "\$19.99"
number_ex!(ctx, val, 0.5f0, "%.1f°C", opt)      # "23.5°C"
```

# Precise vs Approximate Input
- **Drag**: Good for approximate adjustments, live feedback
- **Text**: Good for precise values, exact requirements
- **Both**: Users can choose the most appropriate method

# Form Integration
```julia
# Object properties form
struct Transform
    x::Ref{Real}
    y::Ref{Real}
    rotation::Ref{Real}
    scale_x::Ref{Real}
    scale_y::Ref{Real}
end

transform = Transform(Ref(0.0f0), Ref(0.0f0), Ref(0.0f0), Ref(1.0f0), Ref(1.0f0))

layout_row!(ctx, 2, [60, 100], 0)
label(ctx, "X:"); number_ex!(ctx, transform.x, 1.0f0, "%.1f", UInt16(0))
label(ctx, "Y:"); number_ex!(ctx, transform.y, 1.0f0, "%.1f", UInt16(0))
label(ctx, "Rot:"); number_ex!(ctx, transform.rotation, 1.0f0, "%.0f°", UInt16(0))
label(ctx, "SX:"); number_ex!(ctx, transform.scale_x, 0.1f0, "%.2f", UInt16(0))
label(ctx, "SY:"); number_ex!(ctx, transform.scale_y, 0.1f0, "%.2f", UInt16(0))
```

# See Also
- [`number!`](@ref): Simple number widget with default formatting
- [`slider_ex!`](@ref): Alternative for bounded ranges
- [`number_textbox!`](@ref): Text input implementation
- [`format_real`](@ref): Value formatting function
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
    number!(ctx::Context, value::Ref{Real}, step::Real) -> Int

Simple number widget with default formatting and center alignment.

Creates a standard number input widget with slider-style formatting and
center-aligned text. This is the most commonly used number widget function.

# Arguments
- `ctx::Context`: The MicroUI context
- `value::Ref{Real}`: Reference to numeric value (modified by widget)
- `step::Real`: Step size for mouse drag adjustment

# Returns
- `Int`: Widget result flags, non-zero if value changed

# Default Behavior
- **Format**: Uses `SLIDER_FMT` ("%.2f") for display
- **Alignment**: Center-aligned text
- **Interaction**: Click for text input, drag for adjustment
- **Step**: Mouse drag moves by specified step size

# Examples
```julia
# Simple numeric controls
speed = Ref(5.0f0)
count = Ref(10.0f0)
factor = Ref(1.5f0)

ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Settings", Rect(50, 50, 250, 150)) != 0
    layout_row!(ctx, 2, [80, 120], 0)
    
    # Speed setting (step by 0.5)
    label(ctx, "Speed:")
    if number!(ctx, speed, 0.5f0) & Int(RES_CHANGE) != 0
        update_speed(speed[])
    end
    
    # Item count (step by 1)
    label(ctx, "Count:")
    number!(ctx, count, 1.0f0)
    
    # Scale factor (step by 0.1)
    label(ctx, "Factor:")
    number!(ctx, factor, 0.1f0)
    
    end_window(ctx)
end

end_frame(ctx)
```

# Common Step Sizes
- **Integers**: 1.0 (whole numbers)
- **Decimals**: 0.1 or 0.01 (precision control)
- **Large Values**: 10.0 or 100.0 (coarse adjustment)
- **Small Values**: 0.001 (fine precision)

# Use Cases
```julia
# Game settings
health = Ref(100.0f0)      # Step by 1 (integers)
damage = Ref(25.0f0)       # Step by 1 (integers)
critical_chance = Ref(0.15f0) # Step by 0.01 (percentages)

# Graphics settings
fov = Ref(90.0f0)          # Step by 1 (degrees)
gamma = Ref(2.2f0)         # Step by 0.1 (gamma correction)
resolution_scale = Ref(1.0f0) # Step by 0.1 (scale factor)

# Physics settings
gravity = Ref(-9.81f0)     # Step by 0.1 (acceleration)
friction = Ref(0.8f0)      # Step by 0.05 (coefficient)
time_scale = Ref(1.0f0)    # Step by 0.1 (time multiplier)
```

# Interaction Workflow
1. **Display**: Shows current value with 2 decimal places
2. **Click**: Opens text input for precise typing
3. **Drag**: Horizontal mouse movement adjusts value
4. **Type**: Enter exact values when text input is active
5. **Confirm**: Enter key or click away confirms changes

# Value Formatting
Default formatting shows 2 decimal places:
- `5.0` → "5.00"
- `10.75` → "10.75"
- `0.333` → "0.33"

# See Also
- [`number_ex!`](@ref): Number widget with custom formatting
- [`slider!`](@ref): Alternative for bounded ranges
- [`textbox!`](@ref): Text-only input alternative
- [`Real`](@ref): Numeric type for values
"""
number!(ctx::Context, value::Ref{Real}, step::Real) = 
    number_ex!(ctx, value, step, SLIDER_FMT, UInt16(OPT_ALIGNCENTER))

"""
    header_impl(ctx::Context, label::String, istreenode::Bool, opt::UInt16) -> Int

Implementation for header and treenode widgets.

This is the shared implementation that handles expand/collapse state and visual
styling for both header sections and collapsible tree nodes. It manages the
toggle state through a pool-based system for efficiency.

# Arguments
- `ctx::Context`: The MicroUI context
- `label::String`: Header/treenode text label
- `istreenode::Bool`: `true` for treenode styling, `false` for header styling
- `opt::UInt16`: Option flags, including `OPT_EXPANDED` for initial state

# Returns
- `Int`: Widget result flags
  - `RES_ACTIVE`: Header/treenode is expanded (content should be shown)

# State Management
Uses the treenode pool for efficient state tracking:
- **Expanded State**: Tracked in `ctx.treenode_pool` by widget ID
- **Toggle Logic**: Pool presence indicates expanded state
- **Initial State**: `OPT_EXPANDED` flag controls default state

# Visual Differences
- **Header**: Uses button-style background and frame
- **Treenode**: Uses hover-only highlighting (subtle)
- **Both**: Show expand/collapse icon and handle clicks

# Pool-Based Toggle Logic
```julia
# If in pool AND OPT_EXPANDED: starts collapsed, now expanded
# If in pool AND NOT OPT_EXPANDED: starts expanded, now collapsed
# If NOT in pool AND OPT_EXPANDED: starts expanded, now collapsed
# If NOT in pool AND NOT OPT_EXPANDED: starts collapsed, now expanded
expanded = (opt & UInt16(OPT_EXPANDED)) != 0 ? !active : active
```

# Examples
```julia
# Used internally by header() and begin_treenode()
function header(ctx::Context, label::String)
    return header_impl(ctx, label, false, UInt16(0))
end

function begin_treenode(ctx::Context, label::String)
    return header_impl(ctx, label, true, UInt16(0))
end
```

# Icon Display
- **Collapsed**: Shows `ICON_COLLAPSED` (triangle pointing right)
- **Expanded**: Shows `ICON_EXPANDED` (triangle pointing down)
- **Position**: Icon appears on the left side of the header

# Click Handling
- Detects mouse clicks on the entire header area
- Toggles the expanded state in the pool
- Updates visual feedback immediately

# Layout Integration
- Takes full width of current layout (`width = -1`)
- Creates new layout row for header display
- Uses `layout_next()` for positioning

# See Also
- [`header`](@ref): Public header widget function
- [`begin_treenode`](@ref): Public treenode widget function
- [`pool_get`](@ref): Pool lookup implementation
- [`pool_init!`](@ref): Pool initialization
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

"""
    header_ex(ctx::Context, label::String, opt::UInt16) -> Int

Header widget for grouping content with custom options.

Creates a clickable header section that can be used to organize content into
collapsible groups. Headers provide visual separation and can optionally
start in an expanded state.

# Arguments
- `ctx::Context`: The MicroUI context
- `label::String`: Header text to display
- `opt::UInt16`: Option flags, primarily `OPT_EXPANDED` for initial state

# Returns
- `Int`: Header result flags
  - `RES_ACTIVE`: Header is expanded (show content below)

# Option Flags
- `UInt16(0)`: Header starts collapsed
- `UInt16(OPT_EXPANDED)`: Header starts expanded

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Settings", Rect(50, 50, 300, 400)) != 0
    # Graphics settings section
    if header_ex(ctx, "Graphics Settings", UInt16(0)) != 0
        # Content shown only when header is expanded
        layout_row!(ctx, 2, [100, 150], 0)
        label(ctx, "Resolution:")
        # ... resolution controls
        
        label(ctx, "Quality:")
        # ... quality controls
    end
    
    # Audio settings section (starts expanded)
    if header_ex(ctx, "Audio Settings", UInt16(OPT_EXPANDED)) != 0
        layout_row!(ctx, 2, [100, 150], 0)
        label(ctx, "Volume:")
        # ... volume controls
        
        label(ctx, "Effects:")
        # ... effects controls
    end
    
    # Controls section
    if header_ex(ctx, "Controls", UInt16(0)) != 0
        # ... control configuration
    end
    
    end_window(ctx)
end

end_frame(ctx)
```

# Visual Styling
- **Background**: Uses `COLOR_BUTTON` with full button styling
- **Icon**: Shows expand/collapse triangle on the left
- **Text**: Header label with appropriate spacing
- **Interaction**: Full button-style hover and click feedback

# Content Organization
```julia
# Organize complex interfaces with headers
if header_ex(ctx, "User Information", UInt16(0)) != 0
    # User fields only shown when expanded
    textbox!(ctx, username, 50)
    textbox!(ctx, email, 100)
    checkbox!(ctx, "Send notifications", notifications)
end

if header_ex(ctx, "Advanced Options", UInt16(0)) != 0
    # Advanced settings hidden by default
    number!(ctx, timeout, 1.0f0)
    checkbox!(ctx, "Debug mode", debug_mode)
    slider!(ctx, cache_size, 1.0f0, 100.0f0)
end
```

# State Persistence
Header expand/collapse state persists between frames automatically:
- First time: Uses option flag for initial state
- Subsequently: Remembers user's last toggle action
- Per-application session: State resets when application restarts

# See Also
- [`header`](@ref): Simple header with default options
- [`begin_treenode_ex`](@ref): Alternative with different styling
- [`header_impl`](@ref): Shared implementation details
"""
header_ex(ctx::Context, label::String, opt::UInt16) = header_impl(ctx, label, false, opt)

"""
    header(ctx::Context, label::String) -> Int

Simple header widget for grouping content.

Creates a clickable header section that starts in a collapsed state. This is
the most commonly used header function for organizing UI content into sections.

# Arguments
- `ctx::Context`: The MicroUI context
- `label::String`: Header text to display

# Returns
- `Int`: Header result flags, non-zero if expanded

# Default Behavior
- Starts collapsed (user must click to expand)
- Full button styling with frame and background
- Expand/collapse icon on the left
- Click anywhere on header to toggle

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Application Settings", Rect(50, 50, 350, 500)) != 0
    # File settings
    if header(ctx, "File Settings") != 0
        checkbox!(ctx, "Auto-save", auto_save)
        number!(ctx, "Save interval (minutes)", save_interval, 1.0f0)
        textbox!(ctx, "Default save location", save_path, 200)
    end
    
    # Display settings
    if header(ctx, "Display Settings") != 0
        slider!(ctx, "UI scale", ui_scale, 0.5f0, 2.0f0)
        checkbox!(ctx, "Dark theme", dark_theme)
        checkbox!(ctx, "Show tooltips", show_tooltips)
    end
    
    # Network settings
    if header(ctx, "Network Settings") != 0
        textbox!(ctx, "Server URL", server_url, 100)
        number!(ctx, "Timeout (seconds)", timeout, 1.0f0)
        checkbox!(ctx, "Use proxy", use_proxy)
    end
    
    end_window(ctx)
end

end_frame(ctx)
```

# Typical Usage Patterns
```julia
# Settings organization
if header(ctx, "Graphics") != 0
    # Graphics-related controls
end

if header(ctx, "Audio") != 0
    # Audio-related controls  
end

if header(ctx, "Controls") != 0
    # Input-related controls
end

# Feature grouping
if header(ctx, "Basic Features") != 0
    # Essential functionality
end

if header(ctx, "Advanced Features") != 0
    # Power-user functionality
end

# Status sections
if header(ctx, "System Status") != 0
    # System information display
end
```

# Content Visibility
Content inside the header block is only processed when expanded:
```julia
if header(ctx, "Expensive Operations") != 0
    # These widgets only created when header is open
    # Saves performance when collapsed
    complex_visualization(ctx)
    expensive_calculation(ctx)
end
```

# See Also
- [`header_ex`](@ref): Header with custom initial state
- [`begin_treenode`](@ref): Alternative with subtle styling
- [`text`](@ref): For non-interactive section labels
"""
header(ctx::Context, label::String) = header_ex(ctx, label, UInt16(0))

"""
    begin_treenode_ex(ctx::Context, label::String, opt::UInt16) -> Int

Begin collapsible treenode section with custom options.

Creates a subtly-styled collapsible section that's ideal for hierarchical content
like file trees, object hierarchies, or nested data structures. Unlike headers,
treenodes have minimal visual styling and support proper nesting.

# Arguments
- `ctx::Context`: The MicroUI context
- `label::String`: Treenode text label
- `opt::UInt16`: Option flags, primarily `OPT_EXPANDED` for initial state

# Returns
- `Int`: Treenode result flags
  - `RES_ACTIVE`: Treenode is expanded (content should be shown)

# Treenode vs Header
- **Treenode**: Minimal styling, hover-only highlight, supports nesting
- **Header**: Full button styling, bold visual separation, flat structure

# Nesting Support
When expanded, treenodes create a new ID scope and add indentation:
- **ID Scope**: Child widgets get unique IDs within treenode context
- **Indentation**: Content is visually indented using `ctx.style.indent`

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "File Browser", Rect(50, 50, 300, 400)) != 0
    # Root folder (starts expanded)
    if begin_treenode_ex(ctx, "📁 Project", UInt16(OPT_EXPANDED)) != 0
        # Nested folder
        if begin_treenode_ex(ctx, "📁 src", UInt16(0)) != 0
            label(ctx, "📄 main.jl")
            label(ctx, "📄 utils.jl")
            
            # Deeply nested folder
            if begin_treenode_ex(ctx, "📁 components", UInt16(0)) != 0
                label(ctx, "📄 button.jl")
                label(ctx, "📄 textbox.jl")
                end_treenode(ctx)
            end
            
            end_treenode(ctx)
        end
        
        # Another nested folder
        if begin_treenode_ex(ctx, "📁 docs", UInt16(0)) != 0
            label(ctx, "📄 README.md")
            label(ctx, "📄 API.md")
            end_treenode(ctx)
        end
        
        # Files in root
        label(ctx, "📄 Project.toml")
        label(ctx, "📄 Manifest.toml")
        
        end_treenode(ctx)
    end
    
    end_window(ctx)
end

end_frame(ctx)
```

# Object Hierarchy Example
```julia
# Scene graph or object hierarchy
if begin_treenode_ex(ctx, "Scene Root", UInt16(OPT_EXPANDED)) != 0
    if begin_treenode_ex(ctx, "🎯 Camera", UInt16(0)) != 0
        label(ctx, "Position: (0, 0, 10)")
        label(ctx, "Target: (0, 0, 0)")
        end_treenode(ctx)
    end
    
    if begin_treenode_ex(ctx, "💡 Lights", UInt16(0)) != 0
        if begin_treenode_ex(ctx, "☀️ Sun Light", UInt16(0)) != 0
            slider!(ctx, sun_intensity, 0.0f0, 2.0f0)
            # ... other sun properties
            end_treenode(ctx)
        end
        
        if begin_treenode_ex(ctx, "🔦 Spot Light", UInt16(0)) != 0
            slider!(ctx, spot_intensity, 0.0f0, 1.0f0)
            # ... other spot properties
            end_treenode(ctx)
        end
        
        end_treenode(ctx)
    end
    
    if begin_treenode_ex(ctx, "📦 Objects", UInt16(OPT_EXPANDED)) != 0
        # ... scene objects
        end_treenode(ctx)
    end
    
    end_treenode(ctx)
end
```

# Visual Styling
- **No background**: Transparent background by default
- **Hover highlight**: Subtle highlighting on mouse hover only
- **Icon**: Same expand/collapse triangles as headers
- **Indentation**: Child content is indented automatically

# Required Pairing
Always pair `begin_treenode_ex` with `end_treenode`:
```julia
if begin_treenode_ex(ctx, "My Node", opt) != 0
    # Node content here
    end_treenode(ctx)  # Required!
end
```

# See Also
- [`begin_treenode`](@ref): Simple treenode with default options
- [`end_treenode`](@ref): Required to close treenode scope
- [`header_ex`](@ref): Alternative with full button styling
- [`push_id!`](@ref): ID scoping implementation
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

"""
    begin_treenode(ctx::Context, label::String) -> Int

Simple treenode widget with default options.

Creates a collapsible treenode section that starts collapsed. This is the most
commonly used treenode function for hierarchical content display.

# Arguments
- `ctx::Context`: The MicroUI context
- `label::String`: Treenode text label

# Returns
- `Int`: Treenode result flags, non-zero if expanded

# Default Behavior
- Starts collapsed (user must click to expand)
- Minimal visual styling (hover-only highlight)
- Automatic indentation for nested content
- Supports arbitrary nesting depth

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Data Structure", Rect(50, 50, 300, 400)) != 0
    # Simple tree structure
    if begin_treenode(ctx, "Root Node") != 0
        label(ctx, "Root data: value1")
        
        if begin_treenode(ctx, "Child Node 1") != 0
            label(ctx, "Child 1 data: value2")
            
            if begin_treenode(ctx, "Grandchild") != 0
                label(ctx, "Grandchild data: value3")
                end_treenode(ctx)
            end
            
            end_treenode(ctx)
        end
        
        if begin_treenode(ctx, "Child Node 2") != 0
            label(ctx, "Child 2 data: value4")
            end_treenode(ctx)
        end
        
        end_treenode(ctx)
    end
    
    end_window(ctx)
end

end_frame(ctx)
```

# JSON-like Data Display
```julia
# Display complex data structures
struct Person
    name::String
    age::Int
    address::Dict{String, String}
    hobbies::Vector{String}
end

person = Person("Alice", 30, 
    Dict("street" => "123 Main St", "city" => "Springfield"),
    ["reading", "hiking", "coding"])

# Display person data as expandable tree
if begin_treenode(ctx, "Person: \$(person.name)") != 0
    label(ctx, "Age: \$(person.age)")
    
    if begin_treenode(ctx, "Address") != 0
        for (key, value) in person.address
            label(ctx, "\$key: \$value")
        end
        end_treenode(ctx)
    end
    
    if begin_treenode(ctx, "Hobbies") != 0
        for (i, hobby) in enumerate(person.hobbies)
            label(ctx, "\$i. \$hobby")
        end
        end_treenode(ctx)
    end
    
    end_treenode(ctx)
end
```

# Interactive Tree Navigation
```julia
# File system browser
function display_directory(ctx, path, depth=0)
    if begin_treenode(ctx, "📁 \$(basename(path))") != 0
        try
            for item in readdir(path, join=true)
                if isdir(item)
                    display_directory(ctx, item, depth + 1)
                else
                    label(ctx, "📄 \$(basename(item))")
                end
            end
        catch
            label(ctx, "❌ Access denied")
        end
        end_treenode(ctx)
    end
end

# Usage
display_directory(ctx, "/home/user/projects")
```

# State Persistence
Treenode expand/collapse state persists automatically:
- Each treenode remembers its state between frames
- State is tied to the treenode label/ID
- Nested treenodes have independent states

# Performance Benefits
Collapsed treenodes skip content processing:
```julia
if begin_treenode(ctx, "Expensive Content") != 0
    # This code only runs when treenode is expanded
    # Saves CPU when collapsed
    for i in 1:1000
        complex_computation(i)
        label(ctx, "Result \$i")
    end
    end_treenode(ctx)
end
```

# See Also
- [`begin_treenode_ex`](@ref): Treenode with custom initial state
- [`end_treenode`](@ref): Required to close treenode scope
- [`header`](@ref): Alternative with bold styling
- [`label`](@ref): For leaf nodes in tree structures
"""
begin_treenode(ctx::Context, label::String) = begin_treenode_ex(ctx, label, UInt16(0))

"""
    end_treenode(ctx::Context) -> Nothing

End treenode section and restore layout context.

This function must be called after [`begin_treenode`](@ref) or [`begin_treenode_ex`](@ref)
to properly close the treenode scope and restore the previous layout state.

# Arguments
- `ctx::Context`: The MicroUI context

# Cleanup Operations
The function performs several cleanup operations:
1. **Remove indentation**: Restores previous indentation level
2. **Pop ID scope**: Restores parent ID context
3. **Layout restoration**: Returns to parent layout state

# Usage Pattern
Always pair `begin_treenode` with `end_treenode`:

```julia
# Correct usage
if begin_treenode(ctx, "My Node") != 0
    # Node content here
    label(ctx, "Content")
    end_treenode(ctx)  # Always call this
end

# Nested treenodes (close in reverse order)
if begin_treenode(ctx, "Parent") != 0
    label(ctx, "Parent content")
    
    if begin_treenode(ctx, "Child") != 0
        label(ctx, "Child content")
        end_treenode(ctx)  # Close child first
    end
    
    label(ctx, "More parent content")
    end_treenode(ctx)  # Close parent last
end
```

# Error Handling
Failing to call `end_treenode` after a successful `begin_treenode` will result in:
- Incorrect indentation in subsequent widgets
- ID scope pollution
- Layout state corruption
- Assertion errors in debug builds

# Indentation Management
The function decreases the current layout indentation:
```julia
layout.indent -= ctx.style.indent
```

This ensures that widgets after the treenode return to the proper indentation level.

# See Also
- [`begin_treenode`](@ref): Start treenode scope
- [`begin_treenode_ex`](@ref): Start treenode scope with options
- [`pop_id!`](@ref): ID scope management
- [`get_layout`](@ref): Layout context access
"""
function end_treenode(ctx::Context)
    layout = get_layout(ctx)
    layout.indent -= ctx.style.indent
    pop_id!(ctx)
end

# ===== CONTAINER MANAGEMENT =====
# Functions for scrollbars and container body management

"""
    draw_scrollbar!(ctx::Context, cnt::Container, body::Rect, cs::Vec2, axis_name::String) -> Nothing

Draw scrollbar for given axis with full interaction support.

Handles scrollbar rendering and interaction for either horizontal ("x") or vertical ("y")
axis. Provides visual feedback, thumb positioning, and mouse interaction for scrolling
through container content that exceeds the visible area.

# Arguments
- `ctx::Context`: The MicroUI context
- `cnt::Container`: Container that owns the scrollbar
- `body::Rect`: Visible container body rectangle
- `cs::Vec2`: Content size (total size of all content)
- `axis_name::String`: Either "x" for horizontal or "y" for vertical scrollbar

# Scrollbar Components
Each scrollbar consists of:
- **Track**: Background area using `COLOR_SCROLLBASE`
- **Thumb**: Draggable element using `COLOR_SCROLLTHUMB`
- **Proportional sizing**: Thumb size reflects visible content ratio

# Interaction Features
- **Click and drag**: Click thumb to drag scroll position
- **Mouse wheel**: Sets scroll target for wheel input when mouse over body
- **Proportional movement**: Thumb movement maps to content scroll position
- **Bounds checking**: Prevents scrolling beyond content limits

# Axis-Specific Behavior
**Vertical Scrollbar ("y")**:
- Positioned at right edge of container body
- Height matches container body height
- Controls vertical scroll offset

**Horizontal Scrollbar ("x")**:
- Positioned at bottom edge of container body  
- Width matches container body width
- Controls horizontal scroll offset

# Examples
```julia
# Used internally by scrollbars! function
container = get_current_container(ctx)
content_size = Vec2(800, 1200)  # Content larger than container
body_rect = Rect(10, 10, 300, 400)  # Visible area

# Draw vertical scrollbar (content is taller than visible area)
draw_scrollbar!(ctx, container, body_rect, content_size, "y")

# Draw horizontal scrollbar (content is wider than visible area)  
draw_scrollbar!(ctx, container, body_rect, content_size, "x")
```

# Thumb Sizing Algorithm
Thumb size is proportional to visible content ratio:
```julia
# For vertical scrollbar
thumb_height = max(style.thumb_size, track_height * body_height / content_height)

# For horizontal scrollbar
thumb_width = max(style.thumb_size, track_width * body_width / content_width)
```

# Scroll Position Mapping
Mouse position maps to scroll offset:
```julia
# For vertical scrollbar
scroll_offset = mouse_delta_y * content_height / track_height

# For horizontal scrollbar
scroll_offset = mouse_delta_x * content_width / track_width
```

# Scroll Wheel Integration
When mouse is over the container body, sets the container as scroll target:
```julia
if mouse_over(ctx, body)
    ctx.scroll_target = container
end
```

This allows the scroll wheel to affect this container's scroll position.

# Performance Notes
- Only draws scrollbars when content exceeds container size
- Efficient hit testing and drag calculations
- Minimal allocations during scrolling

# See Also
- [`scrollbars!`](@ref): High-level scrollbar management
- [`mouse_over`](@ref): Hit testing for scroll wheel targeting
- [`update_control!`](@ref): Scrollbar interaction handling
- [`COLOR_SCROLLBASE`](@ref): Scrollbar track color
- [`COLOR_SCROLLTHUMB`](@ref): Scrollbar thumb color
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
    scrollbars!(ctx::Context, cnt::Container, body::Ref{Rect}) -> Nothing

Handle scrollbars for container and adjust body rectangle.

Manages both horizontal and vertical scrollbars for a container, automatically
showing them when content exceeds the container size. Adjusts the container
body rectangle to make room for scrollbars when needed.

# Arguments
- `ctx::Context`: The MicroUI context
- `cnt::Container`: Container to add scrollbars to
- `body::Ref{Rect}`: Container body rectangle (modified to make room for scrollbars)

# Scrollbar Logic
Scrollbars are shown when content exceeds container dimensions:
- **Vertical**: When `content_height > container_height`
- **Horizontal**: When `content_width > container_width`
- **Both**: When content exceeds container in both dimensions

# Body Rectangle Adjustment
The function modifies the body rectangle to reserve space for scrollbars:
```julia
# Reserve space for vertical scrollbar
if content_height > body_height
    body.w -= scrollbar_size
end

# Reserve space for horizontal scrollbar  
if content_width > body_width
    body.h -= scrollbar_size
end
```

# Content Size Calculation
Content size includes padding for accurate scrollbar sizing:
```julia
content_size = Vec2(
    container.content_size.x + padding * 2,
    container.content_size.y + padding * 2
)
```

# Examples
```julia
# Used internally by push_container_body!
function setup_container_scrolling(ctx, container)
    body_rect = Ref(container.rect)
    
    # Set up scrollbars and adjust body rectangle
    scrollbars!(ctx, container, body_rect)
    
    # body_rect now accounts for scrollbar space
    container.body = body_rect[]
end
```

# Scrollbar Interaction
Both scrollbars support full interaction:
- **Dragging**: Click and drag thumb to scroll
- **Proportional movement**: Thumb position reflects scroll offset
- **Wheel support**: Mouse wheel affects appropriate scrollbar
- **Bounds checking**: Prevents scrolling beyond content

# Corner Case Handling
When both scrollbars are present:
- Vertical scrollbar is shortened to avoid horizontal scrollbar
- Horizontal scrollbar is shortened to avoid vertical scrollbar
- Corner area is left empty (no special corner widget)

# Performance Considerations
- Only processes scrollbars when content overflows
- Efficient clipping setup prevents rendering outside container
- Scroll calculations are lightweight and real-time

# Clipping Integration
Sets up proper clipping for scrollbar rendering:
```julia
push_clip_rect!(ctx, body[])
# Draw scrollbars within clipped region
pop_clip_rect!(ctx)
```

# See Also
- [`draw_scrollbar!`](@ref): Individual scrollbar rendering
- [`push_container_body!`](@ref): Container setup that calls this
- [`get_current_container`](@ref): Container access
- [`push_clip_rect!`](@ref): Clipping management
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
    push_container_body!(ctx::Context, cnt::Container, body::Rect, opt::UInt16) -> Nothing

Set up container body with scrollbars and layout context.

Prepares a container for content rendering by setting up scrollbars (if needed),
creating the layout context, and establishing the content area. This function
is called during container initialization to create a properly configured
rendering environment.

# Arguments
- `ctx::Context`: The MicroUI context
- `cnt::Container`: Container being set up
- `body::Rect`: Initial body rectangle (before scrollbar adjustment)
- `opt::UInt16`: Option flags, including `OPT_NOSCROLL` to disable scrollbars

# Setup Process
1. **Scrollbar setup**: Adds scrollbars if content overflows (unless `OPT_NOSCROLL`)
2. **Layout creation**: Creates layout context with proper scroll offset
3. **Body assignment**: Stores final body rectangle in container

# Scrolling Behavior
When `OPT_NOSCROLL` is **not** set:
- Automatically adds scrollbars when content exceeds container size
- Adjusts body rectangle to make room for scrollbars
- Sets up scroll offset for layout positioning

When `OPT_NOSCROLL` **is** set:
- No scrollbars are shown regardless of content size
- Content that doesn't fit is clipped
- Layout uses full body rectangle

# Layout Integration
Creates a layout context with:
- **Body area**: Available space for content (after scrollbar adjustment)
- **Scroll offset**: Current container scroll position
- **Padding**: Inward padding from container edges

# Examples
```julia
# Used internally by begin_window_ex and begin_panel_ex
function setup_window_body(ctx, container, window_rect, options)
    # Calculate body rectangle (excluding title bar)
    body_rect = Rect(
        window_rect.x,
        window_rect.y + title_height,
        window_rect.w,
        window_rect.h - title_height
    )
    
    # Set up container body with scrollbars
    push_container_body!(ctx, container, body_rect, options)
    
    # Container is now ready for content
end
```

# Scrollbar Integration
The function handles scrollbar setup automatically:
```julia
# No scrollbars - use full body rectangle
if (opt & UInt16(OPT_NOSCROLL)) != 0
    # Skip scrollbar setup
    body_final = body
else
    # Add scrollbars and adjust body rectangle
    body_ref = Ref(body)
    scrollbars!(ctx, container, body_ref)
    body_final = body_ref[]
end
```

# Content Area Calculation
The final content area accounts for:
- Container padding (`ctx.style.padding`)
- Scrollbar space (if scrollbars are present)
- Scroll offset (for content positioning)

# Container State Update
Updates the container's body rectangle:
```julia
cnt.body = final_body_rectangle
```

This allows other functions to query the actual available content area.

# See Also
- [`scrollbars!`](@ref): Scrollbar setup implementation
- [`push_layout!`](@ref): Layout context creation
- [`expand_rect`](@ref): Rectangle expansion for padding
- [`begin_window_ex`](@ref): Uses this for window setup
- [`begin_panel_ex`](@ref): Uses this for panel setup
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
    begin_root_container!(ctx::Context, cnt::Container) -> Nothing

Initialize root container for rendering with proper setup.

Sets up a root-level container (window) for rendering by managing the container
stack, command buffer regions, hover detection, and clipping. This function
is called when starting a new window or top-level container.

# Arguments
- `ctx::Context`: The MicroUI context
- `cnt::Container`: Container to initialize as root container

# Root Container Setup
The function performs several critical setup operations:
1. **Stack management**: Pushes container onto both container and root stacks
2. **Command buffer**: Sets up command buffer region for this container
3. **Hover detection**: Updates hover root if mouse is over this container
4. **Clipping**: Initializes clipping state

# Container Stacks
- **Container stack**: For nested container tracking and current container access
- **Root stack**: For root containers only, used during frame finalization

# Command Buffer Management
Sets up command buffer region for Z-order rendering:
```julia
cnt.head = push_jump_command!(ctx, CommandPtr(0))  # Placeholder jump
```

The head command will later be updated to jump past this container's commands
or to link to other containers based on Z-order.

# Hover Root Detection
Updates the hover root if this container should receive mouse input:
```julia
if mouse_over_container && (no_current_hover || higher_z_index)
    ctx.next_hover_root = cnt
end
```

This ensures that only the topmost container under the mouse receives input.

# Examples
```julia
# Used internally by begin_window_ex
function start_window(ctx, container, window_rect)
    # Set up container as root
    begin_root_container!(ctx, container)
    
    # Container is now active and ready for content
    # Command buffer region is established
    # Hover detection is active
end
```

# Z-Order and Hover Logic
The hover root selection considers Z-order:
- Higher Z-index containers take priority
- Only containers under the mouse cursor are considered
- The topmost visible container becomes the hover root

# Clipping Initialization
Starts with unlimited clipping region:
```julia
push!(ctx.clip_stack, UNCLIPPED_RECT)
```

This allows the container to draw anywhere initially. Specific clipping
regions can be set up later as needed.

# Container Lifecycle
Root containers follow this lifecycle:
1. **Initialize**: `begin_root_container!` sets up the container
2. **Content**: Add widgets and child containers
3. **Finalize**: `end_root_container!` completes setup

# Command Buffer Regions
Each root container gets its own command buffer region:
- **Head**: Start of container's commands
- **Tail**: End of container's commands (set by `end_root_container!`)
- **Linking**: Containers are linked by Z-order during `end_frame`

# See Also
- [`end_root_container!`](@ref): Finalizes root container setup
- [`push_jump_command!`](@ref): Command buffer management
- [`bring_to_front!`](@ref): Z-order manipulation
- [`rect_overlaps_vec2`](@ref): Mouse overlap testing
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
    end_root_container!(ctx::Context) -> Nothing

Finalize root container and set up command buffer linking.

Completes the setup of a root container by finalizing the command buffer region,
updating jump commands, and cleaning up the container context. This function
is called when ending a window or top-level container.

# Arguments
- `ctx::Context`: The MicroUI context

# Finalization Process
1. **Command buffer tail**: Sets up tail jump command for this container
2. **Head jump update**: Updates head jump to skip past itself  
3. **Stack cleanup**: Removes container from stacks
4. **Clipping cleanup**: Restores clipping state

# Command Buffer Linking
The function sets up proper command buffer linking for Z-order rendering:
```julia
# Set tail jump (destination set during end_frame)
cnt.tail = push_jump_command!(ctx, CommandPtr(0))

# Update head jump to skip past itself
head_jump.dst = cnt.head + sizeof(JumpCommand)
```

# Z-Order Implementation
The command buffer structure enables Z-order rendering:
- Each container has head and tail jump commands
- Containers are sorted by Z-index during `end_frame`
- Jump commands link containers in proper rendering order

# Examples
```julia
# Used internally by end_window
function finish_window(ctx)
    # Complete container setup
    end_root_container!(ctx)
    
    # Container command region is now finalized
    # Ready for frame rendering
end
```

# Command Buffer Structure
After finalization, each container has this structure:
```
[HEAD_JUMP] -> [CONTAINER_COMMANDS...] -> [TAIL_JUMP] -> [NEXT_CONTAINER...]
```

The head jump initially points past itself, and the tail jump destination
is set during frame finalization to link to the next container.

# Stack Cleanup Order
The cleanup happens in the correct order:
1. **Pop clipping**: Restore previous clipping region
2. **Pop container**: Remove from container stack and update content size
3. **Context restoration**: Return to parent container context

# Content Size Update
The `pop_container!` call updates the container's content size based on
the maximum extents reached during layout:
```julia
# In pop_container!
cnt.content_size = Vec2(
    layout.max.x - layout.body.x,
    layout.max.y - layout.body.y
)
```

# Error Handling
The function assumes proper pairing with `begin_root_container!`:
- Container stack must not be empty
- Clipping stack must have at least one entry
- Layout stack must be properly balanced

# See Also
- [`begin_root_container!`](@ref): Initializes root container
- [`push_jump_command!`](@ref): Command buffer jump management
- [`pop_container!`](@ref): Container stack management
- [`end_frame`](@ref): Final command buffer linking
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