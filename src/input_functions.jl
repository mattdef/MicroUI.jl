# ===== INPUT FUNCTIONS =====
# Functions for handling mouse, keyboard, and text input

"""
    input_mousemove!(ctx::Context, x::Int, y::Int)

Update the mouse cursor position in the UI context.

This function records the current mouse position for use in hit testing,
hover detection, and mouse-based interactions. The position should be
provided in screen coordinates relative to the UI rendering area.

# Arguments
- `ctx::Context`: The UI context to update
- `x::Int`: The X coordinate of the mouse cursor
- `y::Int`: The Y coordinate of the mouse cursor

# Effects
- Updates `ctx.mouse_pos` with the new position
- Mouse delta will be calculated automatically in the next [`begin_frame`](@ref) call
- Triggers hover state updates for widgets under the new position

# Examples
```julia
# Basic mouse movement handling
function on_mouse_move(ctx, x, y)
    input_mousemove!(ctx, x, y)
end

# Integration with a window system
function handle_window_events(ctx, window)
    while has_event(window)
        event = get_event(window)
        if event.type == MOUSE_MOVE
            input_mousemove!(ctx, event.x, event.y)
        end
    end
end
```

# Coordinate system
The coordinate system used should match your rendering backend:
- **Origin**: Typically top-left corner (0, 0)
- **X-axis**: Increases to the right
- **Y-axis**: Typically increases downward (computer graphics convention)
- **Units**: Pixels in most cases

# Performance considerations
This function is typically called frequently (on every mouse movement),
so it's optimized to only update the position without performing
expensive calculations. The actual hover detection is deferred until
the next frame processing.

# Frame synchronization
Mouse position updates are processed during the next UI frame. For
best results, call this function before [`begin_frame`](@ref):

```julia
# Recommended order
input_mousemove!(ctx, new_x, new_y)  # Update input state
begin_frame(ctx)                      # Process input and build UI
# ... build UI ...
end_frame(ctx)                        # Finalize frame
```

# See also
[`input_mousedown!`](@ref), [`input_mouseup!`](@ref), [`Vec2`](@ref), [`begin_frame`](@ref)
"""
function input_mousemove!(ctx::Context, x::Int, y::Int)
    ctx.mouse_pos = Vec2(Int32(x), Int32(y))
end

"""
    input_mousedown!(ctx::Context, x::Int, y::Int, btn::MouseButton)

Handle a mouse button press event.

This function records a mouse button press at the specified coordinates,
updating both the mouse position and the button state. The press will be
detected by widgets during the next frame processing.

# Arguments
- `ctx::Context`: The UI context to update
- `x::Int`: The X coordinate where the press occurred
- `y::Int`: The Y coordinate where the press occurred  
- `btn::MouseButton`: The mouse button that was pressed

# Effects
- Updates mouse position to `(x, y)`
- Sets the button as currently down in `ctx.mouse_down`
- Sets the button as pressed this frame in `ctx.mouse_pressed`
- Enables focus acquisition for widgets under the cursor

# Mouse button flags
The `btn` parameter should be one of:
- `MOUSE_LEFT`: Left mouse button (primary button)
- `MOUSE_RIGHT`: Right mouse button (context menu)
- `MOUSE_MIDDLE`: Middle mouse button (wheel click)

Multiple buttons can be down simultaneously as the system uses bitwise flags.

# Examples
```julia
# Handle left mouse button press
input_mousedown!(ctx, 150, 100, MOUSE_LEFT)

# Handle right mouse button press (context menu)
input_mousedown!(ctx, 200, 150, MOUSE_RIGHT)

# Integration with window events
function handle_mouse_press(ctx, event)
    button = case event.button
        1 => MOUSE_LEFT
        2 => MOUSE_MIDDLE  
        3 => MOUSE_RIGHT
        _ => return  # Unknown button
    end
    input_mousedown!(ctx, event.x, event.y, button)
end
```

# Widget interaction behavior
When a mouse button is pressed:
1. **Position update**: Mouse position is updated immediately
2. **Hover detection**: Widgets under the cursor can detect the press
3. **Focus acquisition**: Clicked widgets can acquire keyboard focus
4. **Button state**: The button is marked as both "down" and "pressed"

# State persistence
- `mouse_down`: Remains set until the button is released
- `mouse_pressed`: Only set for the frame when the press occurs
- `mouse_pos`: Updated to the press coordinates

# Frame timing
For optimal responsiveness, call this function immediately when the
mouse press occurs, before the next frame processing:

```julia
# Immediate response pattern
on_mouse_press(x, y, button) = begin
    input_mousedown!(ctx, x, y, button)
    # Optionally trigger immediate frame update for responsiveness
    update_ui_frame(ctx)
end
```

# See also
[`input_mouseup!`](@ref), [`input_mousemove!`](@ref), [`MouseButton`](@ref), [`set_focus!`](@ref)
"""
function input_mousedown!(ctx::Context, x::Int, y::Int, btn::MouseButton)
    input_mousemove!(ctx, x, y)
    ctx.mouse_down |= UInt8(btn)
    ctx.mouse_pressed |= UInt8(btn)
end

"""
    input_mousedown!(ctx::Context, x::Int32, y::Int32, btn::MouseButton)

Convenience overload for `input_mousedown!` accepting `Int32` coordinates.

This overload provides compatibility with code that uses `Int32` coordinates,
automatically converting them to `Int` for internal processing.

# Arguments
- `ctx::Context`: The UI context to update
- `x::Int32`: The X coordinate where the press occurred
- `y::Int32`: The Y coordinate where the press occurred
- `btn::MouseButton`: The mouse button that was pressed

# Examples
```julia
# Using Int32 coordinates (e.g., from Vec2)
mouse_pos = Vec2(Int32(150), Int32(100))
input_mousedown!(ctx, mouse_pos.x, mouse_pos.y, MOUSE_LEFT)
```

# See also
[`input_mousedown!`](@ref), [`Vec2`](@ref)
"""
input_mousedown!(ctx::Context, x::Int32, y::Int32, btn::MouseButton) = input_mousedown!(ctx, Int64(x), Int64(y), btn)

"""
    input_mouseup!(ctx::Context, x::Int, y::Int, btn::MouseButton)

Handle a mouse button release event.

This function records a mouse button release at the specified coordinates,
updating the mouse position and clearing the button from the "down" state.
The release can trigger widget actions like button clicks.

# Arguments
- `ctx::Context`: The UI context to update
- `x::Int`: The X coordinate where the release occurred
- `y::Int`: The Y coordinate where the release occurred
- `btn::MouseButton`: The mouse button that was released

# Effects
- Updates mouse position to `(x, y)`
- Clears the button from `ctx.mouse_down` (no longer held down)
- May trigger widget actions (e.g., button click completion)

# Click detection
A complete "click" typically requires:
1. `input_mousedown!` on a widget
2. Mouse remains over the widget (optional, depending on widget)
3. `input_mouseup!` completes the click

Many widgets only trigger their action on mouse release, not press,
following standard GUI conventions.

# Examples
```julia
# Handle mouse button release
input_mouseup!(ctx, 150, 100, MOUSE_LEFT)

# Complete click sequence
input_mousedown!(ctx, 100, 50, MOUSE_LEFT)  # Press
# ... user moves mouse slightly ...
input_mousemove!(ctx, 102, 51)              # Small movement
input_mouseup!(ctx, 102, 51, MOUSE_LEFT)    # Release -> click!

# Integration with event systems
function handle_mouse_release(ctx, event)
    button = map_platform_button(event.button)
    input_mouseup!(ctx, event.x, event.y, button)
end
```

# Button state after release
- `mouse_down`: The released button flag is cleared
- `mouse_pressed`: Cleared automatically at frame end
- Other buttons remain unaffected if multiple buttons were down

# Drag operations
For drag operations, the sequence is typically:
1. `input_mousedown!` - Start drag
2. Multiple `input_mousemove!` calls - Continue drag
3. `input_mouseup!` - End drag

Widgets can detect drag by checking `mouse_down` state during movement.

# Widget focus behavior
Mouse release typically does not change focus (unlike press), but may
trigger focus-related actions like text input completion or menu dismissal.

# See also
[`input_mousedown!`](@ref), [`input_mousemove!`](@ref), [`MouseButton`](@ref)
"""
function input_mouseup!(ctx::Context, x::Int, y::Int, btn::MouseButton)
    input_mousemove!(ctx, x, y)
    ctx.mouse_down &= ~UInt8(btn)
end

"""
    input_mouseup!(ctx::Context, x::Int32, y::Int32, btn::MouseButton)

Convenience overload for `input_mouseup!` accepting `Int32` coordinates.

This overload provides compatibility with code that uses `Int32` coordinates,
automatically converting them to `Int` for internal processing.

# Arguments
- `ctx::Context`: The UI context to update
- `x::Int32`: The X coordinate where the release occurred
- `y::Int32`: The Y coordinate where the release occurred
- `btn::MouseButton`: The mouse button that was released

# Examples
```julia
# Using Int32 coordinates
release_pos = Vec2(Int32(200), Int32(150))
input_mouseup!(ctx, release_pos.x, release_pos.y, MOUSE_LEFT)
```

# See also
[`input_mouseup!`](@ref), [`Vec2`](@ref)
"""
input_mouseup!(ctx::Context, x::Int32, y::Int32, btn::MouseButton) = input_mouseup!(ctx, Int64(x), Int64(y), btn)

"""
    input_scroll!(ctx::Context, x::Int, y::Int)

Handle mouse scroll wheel input.

This function records scroll wheel movement for processing by scrollable
containers. The scroll input is accumulated and applied to the appropriate
container during frame processing.

# Arguments
- `ctx::Context`: The UI context to update
- `x::Int`: Horizontal scroll amount (positive = scroll right)
- `y::Int`: Vertical scroll amount (positive = scroll down)

# Effects
- Accumulates scroll delta in `ctx.scroll_delta`
- Scroll is applied to the container under the mouse cursor
- Multiple scroll events in one frame are accumulated

# Scroll conventions
The scroll direction follows these conventions:
- **Vertical (`y`)**: Positive values scroll content down (scroll bar moves up)
- **Horizontal (`x`)**: Positive values scroll content right (scroll bar moves left)
- **Units**: Typically pixels or "notches" depending on the input device

# Examples
```julia
# Vertical scroll (mouse wheel)
input_scroll!(ctx, 0, -120)  # Scroll up (content moves up)
input_scroll!(ctx, 0, 120)   # Scroll down (content moves down)

# Horizontal scroll (trackpad, horizontal wheel)
input_scroll!(ctx, -50, 0)   # Scroll left
input_scroll!(ctx, 50, 0)    # Scroll right

# Diagonal scroll (trackpad)
input_scroll!(ctx, 30, -60)  # Scroll right and up

# Integration with platform events
function handle_scroll_event(ctx, event)
    # Convert platform units to pixels
    scroll_x = event.delta_x * SCROLL_SCALE
    scroll_y = event.delta_y * SCROLL_SCALE
    input_scroll!(ctx, scroll_x, scroll_y)
end
```

# Target selection
The scroll target is determined automatically:
1. **Mouse position**: The container under the current mouse cursor
2. **Scrollable check**: Only containers with scrollable content receive scroll
3. **Priority**: Innermost scrollable container takes priority

# Accumulation behavior
Multiple scroll events within one frame are accumulated:

```julia
input_scroll!(ctx, 0, 10)   # First scroll
input_scroll!(ctx, 0, 20)   # Second scroll
# Total scroll this frame: (0, 30)
```

# Frame processing
Scroll delta is applied during [`end_frame`](@ref) and then reset:
1. Scroll accumulates during the frame
2. Applied to target container at frame end
3. `ctx.scroll_delta` is reset to (0, 0)

# Smooth scrolling
For smooth scrolling effects, send smaller incremental values:

```julia
# Instead of one large scroll
input_scroll!(ctx, 0, 240)  # Jerky

# Use multiple smaller scrolls over time
for frame in animation_frames
    input_scroll!(ctx, 0, 20)  # Smooth
    update_frame(ctx)
end
```

# Container compatibility
Not all containers respond to scroll:
- **Windows**: Scroll content if it overflows
- **Panels**: Scroll content if it overflows  
- **Text areas**: Scroll text content
- **Buttons/labels**: Typically do not scroll

# See also
[`end_frame`](@ref), [`push_container_body!`](@ref), [`Vec2`](@ref)
"""
function input_scroll!(ctx::Context, x::Int, y::Int)
    ctx.scroll_delta = Vec2(ctx.scroll_delta.x + Int32(x), ctx.scroll_delta.y + Int32(y))
end

"""
    input_keydown!(ctx::Context, key::Key)

Handle a keyboard key press event.

This function records that a key has been pressed, making it available
for both immediate detection (this frame) and continuous detection
(while held). Keys can trigger widget actions or modify behavior.

# Arguments
- `ctx::Context`: The UI context to update
- `key::Key`: The key that was pressed

# Effects
- Sets the key as pressed this frame in `ctx.key_pressed`
- Sets the key as currently down in `ctx.key_down`
- Focused widgets can respond to the key press

# Key flags
The `key` parameter should be one of the predefined key constants:
- `KEY_SHIFT`: Shift modifier key
- `KEY_CTRL`: Control modifier key  
- `KEY_ALT`: Alt modifier key
- `KEY_BACKSPACE`: Backspace key (text deletion)
- `KEY_RETURN`: Enter/Return key (text confirmation)

Multiple keys can be down simultaneously using bitwise flags.

# Examples
```julia
# Handle basic key presses
input_keydown!(ctx, KEY_RETURN)     # Enter key
input_keydown!(ctx, KEY_BACKSPACE)  # Backspace key

# Handle modifier keys
input_keydown!(ctx, KEY_CTRL)       # Control key
input_keydown!(ctx, KEY_SHIFT)      # Shift key

# Integration with keyboard events
function handle_key_press(ctx, event)
    key = case event.keycode
        VK_RETURN    => KEY_RETURN
        VK_BACKSPACE => KEY_BACKSPACE
        VK_SHIFT     => KEY_SHIFT
        VK_CONTROL   => KEY_CTRL
        VK_ALT       => KEY_ALT
        _            => return  # Unhandled key
    end
    input_keydown!(ctx, key)
end
```

# Widget behavior
Different widgets respond to keys differently:
- **Text input**: `KEY_BACKSPACE` deletes, `KEY_RETURN` may confirm
- **Buttons**: `KEY_RETURN` may trigger activation
- **Sliders**: Arrow keys may adjust values
- **Lists**: Arrow keys may change selection

# State tracking
- `key_pressed`: Only true for the frame when initially pressed
- `key_down`: Remains true while the key is held down
- Both are cleared when the key is released

# Key repeat
For key repeat functionality, call this function for each repeat event:

```julia
# Handle key repeat from platform
function on_key_repeat(ctx, key)
    # Treat repeat as new press for widgets that support it
    input_keydown!(ctx, key)
end
```

# Focus requirement
Most key input only affects the currently focused widget. Ensure
appropriate widgets have focus for key handling:

```julia
# Set focus before expecting key input
widget_id = get_id(ctx, "text_input")
set_focus!(ctx, widget_id)

# Now key presses will affect this widget
input_keydown!(ctx, KEY_BACKSPACE)
```

# See also
[`input_keyup!`](@ref), [`input_text!`](@ref), [`set_focus!`](@ref), [`Key`](@ref)
"""
function input_keydown!(ctx::Context, key::Key)
    ctx.key_pressed |= UInt8(key)
    ctx.key_down |= UInt8(key)
end

"""
    input_keyup!(ctx::Context, key::Key)

Handle a keyboard key release event.

This function records that a key has been released, clearing it from
the "down" state while leaving other keys unaffected.

# Arguments
- `ctx::Context`: The UI context to update
- `key::Key`: The key that was released

# Effects
- Clears the key from `ctx.key_down` (no longer held)
- `key_pressed` state is cleared automatically at frame end
- Widgets may trigger actions on key release

# Examples
```julia
# Handle key release
input_keyup!(ctx, KEY_SHIFT)  # Release shift key
input_keyup!(ctx, KEY_CTRL)   # Release control key

# Complete key press sequence
input_keydown!(ctx, KEY_RETURN)  # Press
# ... key held for some time ...
input_keyup!(ctx, KEY_RETURN)    # Release

# Platform integration
function handle_key_release(ctx, event)
    key = map_platform_key(event.keycode)
    if key != nothing
        input_keyup!(ctx, key)
    end
end
```

# Modifier key handling
Modifier keys (Shift, Ctrl, Alt) are commonly released independently:

```julia
# User presses Ctrl+Shift+S
input_keydown!(ctx, KEY_CTRL)
input_keydown!(ctx, KEY_SHIFT)
input_keydown!(ctx, KEY_S)  # Hypothetical if we tracked letter keys

# User releases keys in different order
input_keyup!(ctx, KEY_S)      # Release S first
input_keyup!(ctx, KEY_CTRL)   # Release Ctrl next
input_keyup!(ctx, KEY_SHIFT)  # Release Shift last
```

# State after release
- The released key flag is cleared from `key_down`
- Other keys remain unaffected
- `key_pressed` flags are managed automatically by the frame system

# Widget interactions
Some widgets respond to key release rather than press:
- Avoiding accidental triggers from key repeat
- Allowing cancellation by moving focus before release
- Implementing "press and hold" behaviors

# See also
[`input_keydown!`](@ref), [`input_text!`](@ref), [`Key`](@ref)
"""
function input_keyup!(ctx::Context, key::Key)
    ctx.key_down &= ~UInt8(key)
end

"""
    input_text!(ctx::Context, text::String)

Add text input for the current frame.

This function provides text input to the UI system, typically from
keyboard character events. The text is accumulated during the frame
and processed by text input widgets like textboxes.

# Arguments
- `ctx::Context`: The UI context to update
- `text::String`: The text to add (typically single characters, but can be longer)

# Effects
- Appends text to `ctx.input_text` for this frame
- Text input widgets can read and process the accumulated text
- Text is cleared automatically at frame end

# Text input vs. key events
This function handles printable character input, complementing key events:
- **`input_text!`**: Printable characters (a-z, A-Z, 0-9, symbols, Unicode)
- **`input_keydown!`**: Special keys (Enter, Backspace, modifiers)

# Examples
```julia
# Single character input
input_text!(ctx, "a")      # Letter 'a'
input_text!(ctx, "5")      # Digit '5'
input_text!(ctx, "@")      # Symbol '@'

# Unicode characters
input_text!(ctx, "é")      # Accented character
input_text!(ctx, "🎯")     # Emoji
input_text!(ctx, "中")     # Chinese character

# Multiple characters (less common)
input_text!(ctx, "hello")  # Multiple characters at once

# Platform integration
function handle_text_input(ctx, event)
    # Platform provides the character(s) as string
    input_text!(ctx, event.text)
end
```

# Accumulation behavior
Text input accumulates during the frame:

```julia
input_text!(ctx, "H")
input_text!(ctx, "e")
input_text!(ctx, "l")
input_text!(ctx, "l")
input_text!(ctx, "o")
# ctx.input_text now contains "Hello"
```

# Character encoding
The function accepts any valid UTF-8 string, supporting:
- **ASCII**: Basic Latin characters (a-z, A-Z, 0-9)
- **Extended Latin**: Accented characters (é, ñ, ü)
- **Unicode**: Any valid Unicode character including emojis
- **Multi-byte**: Properly handles character boundaries

# Widget processing
Text input widgets typically process the accumulated text:

```julia
# In a textbox widget implementation
if has_focus(ctx, textbox_id)
    if !isempty(ctx.input_text)
        # Add input text to textbox content
        textbox_content *= ctx.input_text
        mark_changed()
    end
end
```

# Platform considerations
Different platforms handle text input differently:
- **Windows**: WM_CHAR messages provide characters
- **Linux**: KeyPress events with XLookupString
- **macOS**: NSTextInput protocol
- **Web**: 'input' events on focused elements

The application layer should convert platform-specific text events
into calls to this function.

# Input Method Editor (IME) support
For complex text input (Asian languages, etc.), the platform typically
provides composed characters through the same text input mechanism:

```julia
# IME composition example (handled automatically)
input_text!(ctx, "こ")      # Partial composition
input_text!(ctx, "ん")      # Continued composition  
input_text!(ctx, "にちは")   # Final composition result
```

# Frame lifecycle
Text input follows this lifecycle:
1. **Accumulation**: `input_text!` calls add to `ctx.input_text`
2. **Processing**: Widgets read `ctx.input_text` during frame
3. **Reset**: `ctx.input_text` is cleared at [`end_frame`](@ref)

# See also
[`input_keydown!`](@ref), [`input_keyup!`](@ref), [`textbox!`](@ref), [`end_frame`](@ref)
"""
function input_text!(ctx::Context, text::String)
    ctx.input_text *= text
end