# ===== WINDOW MANAGEMENT =====
# High-level window and popup management functions

"""
    begin_window_ex(ctx::Context, title::String, rect::Rect, opt::UInt16) -> Int

Begin window with full customization options.

Creates a moveable, resizable window with title bar and optional controls. This is the
most flexible window creation function, allowing fine control over window behavior
through option flags.

# Arguments
- `ctx::Context`: The MicroUI context
- `title::String`: Window title displayed in the title bar
- `rect::Rect`: Initial window rectangle (position and size)
- `opt::UInt16`: Combination of option flags controlling window behavior

# Returns
- `Int`: Window status flags, typically `RES_ACTIVE` if window is open and should receive content

# Window Features
The function provides comprehensive window management:
- **Title Bar**: Optional title bar with dragging support (unless `OPT_NOTITLE`)
- **Close Button**: Optional close button in title bar (unless `OPT_NOCLOSE`)
- **Resize Handle**: Optional resize handle in bottom-right corner (unless `OPT_NORESIZE`)
- **Frame**: Optional window border and background (unless `OPT_NOFRAME`)
- **Auto-sizing**: Automatic sizing to content (if `OPT_AUTOSIZE`)
- **Popup Behavior**: Auto-close when clicking outside (if `OPT_POPUP`)

# Window Interaction
- **Dragging**: Click and drag title bar to move window
- **Resizing**: Click and drag resize handle to change size
- **Closing**: Click close button to close window
- **Focus**: Windows automatically come to front when clicked

# Option Flags
Common option combinations:
- `UInt16(0)`: Standard window with all features
- `UInt16(OPT_NOTITLE)`: Window without title bar
- `UInt16(OPT_NOCLOSE)`: Window without close button
- `UInt16(OPT_NORESIZE)`: Fixed-size window
- `UInt16(OPT_AUTOSIZE)`: Auto-size to content
- `UInt16(OPT_POPUP)`: Popup window behavior

# Examples
```julia
ctx = Context()
begin_frame(ctx)

# Standard window
if begin_window_ex(ctx, "Settings", Rect(100, 100, 300, 200), UInt16(0)) != 0
    # Add window content here
    label(ctx, "Window content")
    end_window(ctx)
end

# Popup-style window
popup_opt = UInt16(OPT_POPUP) | UInt16(OPT_AUTOSIZE) | UInt16(OPT_NOTITLE)
if begin_window_ex(ctx, "Tooltip", Rect(200, 150, 0, 0), popup_opt) != 0
    text(ctx, "This is a popup")
    end_window(ctx)
end

# Fixed-size dialog
dialog_opt = UInt16(OPT_NORESIZE) | UInt16(OPT_NOCLOSE)
if begin_window_ex(ctx, "Dialog", Rect(150, 100, 250, 150), dialog_opt) != 0
    text(ctx, "Please confirm your action")
    end_window(ctx)
end

end_frame(ctx)
```

# State Management
Windows automatically maintain their state between frames:
- Position and size are remembered
- Open/close state persists
- Z-order (which window is on top) is maintained

# Performance Notes
- Window creation is efficient through container pooling
- Only visible windows consume rendering resources
- Window state is preserved between frames for smooth interaction

# See Also
- [`begin_window`](@ref): Simplified window creation
- [`end_window`](@ref): Required to close window scope
- [`Option`](@ref): Available option flags
- [`get_container`](@ref): Underlying container management
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

"""
    begin_window(ctx::Context, title::String, rect::Rect) -> Int

Simple window widget with default options.

This is a convenience function that creates a standard window with all default features
enabled: title bar, close button, resize handle, and frame. For more control over window
behavior, use [`begin_window_ex`](@ref).

# Arguments
- `ctx::Context`: The MicroUI context
- `title::String`: Window title displayed in the title bar
- `rect::Rect`: Initial window rectangle (position and size)

# Returns
- `Int`: Window status flags, typically `RES_ACTIVE` if window is open

# Default Features
- Title bar with dragging support
- Close button in top-right corner
- Resize handle in bottom-right corner
- Window frame and background
- Standard window behavior

# Examples
```julia
ctx = Context()
begin_frame(ctx)

# Create a simple window
if begin_window(ctx, "My Application", Rect(50, 50, 400, 300)) != 0
    # Add your UI content here
    label(ctx, "Welcome to my application!")
    
    layout_row!(ctx, 2, [100, 100], 0)
    button(ctx, "OK")
    button(ctx, "Cancel")
    
    end_window(ctx)
end

end_frame(ctx)
```

# Window Lifecycle
1. Call `begin_window` to start the window
2. Add UI content (labels, buttons, etc.)
3. Call `end_window` to finalize the window

# See Also
- [`begin_window_ex`](@ref): Window creation with custom options
- [`end_window`](@ref): Required to close window scope
- [`Rect`](@ref): Rectangle structure for window positioning
"""
begin_window(ctx::Context, title::String, rect::Rect) = begin_window_ex(ctx, title, rect, UInt16(0))

"""
    end_window(ctx::Context) -> Nothing

End window and clean up window context.

This function must be called after [`begin_window`](@ref) or [`begin_window_ex`](@ref)
to properly close the window scope and clean up the rendering context. It handles:
- Clipping rectangle cleanup
- Container stack management
- Layout finalization

# Arguments
- `ctx::Context`: The MicroUI context

# Usage Pattern
Always pair `begin_window` with `end_window`:

```julia
# Correct usage
if begin_window(ctx, "MyWindow", rect) != 0
    # Window content here
    label(ctx, "Content")
    end_window(ctx)  # Always call this
end

# Also correct - early return
if begin_window(ctx, "MyWindow", rect) == 0
    return  # Window not open, no need for end_window
end
# Window content here
end_window(ctx)  # Required after successful begin_window
```

# Error Handling
Failing to call `end_window` after a successful `begin_window` will result in:
- Assertion errors in debug builds
- Corrupted stack state
- Rendering issues in subsequent frames

# See Also
- [`begin_window`](@ref): Start window scope
- [`begin_window_ex`](@ref): Start window scope with options
- [`pop_clip_rect!`](@ref): Clipping management
- [`end_root_container!`](@ref): Container cleanup
"""
function end_window(ctx::Context)
    pop_clip_rect!(ctx)
    end_root_container!(ctx)
end

"""
    open_popup!(ctx::Context, name::String) -> Nothing

Open popup window at mouse position.

Sets up a popup to appear at the current mouse location and marks it for opening.
The popup will be positioned at the mouse cursor and brought to the front.
This function only marks the popup for opening; use [`begin_popup`](@ref) to
actually create the popup content.

# Arguments
- `ctx::Context`: The MicroUI context
- `name::String`: Unique name identifier for the popup

# Popup Behavior
- **Positioning**: Popup appears at current mouse position
- **Z-Order**: Automatically brought to front
- **Hover Root**: Set as hover target to prevent immediate closure
- **Size**: Initially minimal (1x1), typically auto-sized by content

# Usage Pattern
```julia
# In event handling code
if button(ctx, "Show Menu") != 0
    open_popup!(ctx, "context_menu")
end

# In main UI code
if begin_popup(ctx, "context_menu") != 0
    if button(ctx, "Cut") != 0
        # Handle cut action
    end
    if button(ctx, "Copy") != 0
        # Handle copy action
    end
    end_popup(ctx)
end
```

# Examples
```julia
ctx = Context()
begin_frame(ctx)

# Button that opens popup
if button(ctx, "Options") != 0
    open_popup!(ctx, "options_menu")
end

# Popup content (will appear at mouse position)
if begin_popup(ctx, "options_menu") != 0
    text(ctx, "Choose an option:")
    if button(ctx, "Option 1") != 0
        # Handle option 1
    end
    if button(ctx, "Option 2") != 0
        # Handle option 2
    end
    end_popup(ctx)
end

end_frame(ctx)
```

# Multiple Popups
Each popup needs a unique name. You can have multiple popups, but only one
can be open at a time per name:

```julia
# Different popups for different contexts
if right_click_on_file
    open_popup!(ctx, "file_menu")
end
if right_click_on_folder
    open_popup!(ctx, "folder_menu")
end
```

# See Also
- [`begin_popup`](@ref): Create popup content
- [`end_popup`](@ref): Close popup scope
- [`get_container`](@ref): Underlying container management
- [`bring_to_front!`](@ref): Z-order management
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
    begin_popup(ctx::Context, name::String) -> Int

Begin popup window with auto-sizing and popup behavior.

Creates an auto-sizing popup window with no title bar or resize controls.
The popup automatically closes when the user clicks outside of it.
Must be paired with [`end_popup`](@ref).

# Arguments
- `ctx::Context`: The MicroUI context
- `name::String`: Unique name identifier for the popup (must match [`open_popup!`](@ref))

# Returns
- `Int`: Popup status, non-zero if popup is open and should receive content

# Popup Characteristics
- **No Title Bar**: Clean appearance without window decorations
- **Auto-Size**: Automatically resizes to fit content
- **No Resize**: Users cannot manually resize
- **No Scroll**: Content that doesn't fit is clipped
- **Auto-Close**: Closes when clicking outside the popup area

# Usage Pattern
Popups are typically opened by user actions and closed automatically:

```julia
# Step 1: Open popup (usually in response to user action)
if button(ctx, "Show Menu") != 0
    open_popup!(ctx, "menu")
end

# Step 2: Create popup content
if begin_popup(ctx, "menu") != 0
    # Popup is open, add content
    text(ctx, "Menu Options")
    if button(ctx, "Item 1") != 0
        # Handle item 1
        # Popup will close automatically after this frame
    end
    if button(ctx, "Item 2") != 0
        # Handle item 2
    end
    end_popup(ctx)
end
```

# Examples
```julia
ctx = Context()
begin_frame(ctx)

# Context menu popup
if begin_popup(ctx, "context_menu") != 0
    if button(ctx, "New File") != 0
        create_new_file()
    end
    if button(ctx, "Open File") != 0
        open_file_dialog()
    end
    button(ctx, "---")  # Separator
    if button(ctx, "Exit") != 0
        exit_application()
    end
    end_popup(ctx)
end

# Tooltip popup
if begin_popup(ctx, "tooltip") != 0
    text(ctx, "This button creates a new document")
    text(ctx, "Shortcut: Ctrl+N")
    end_popup(ctx)
end

end_frame(ctx)
```

# Popup Lifecycle
1. User action triggers [`open_popup!`](@ref)
2. [`begin_popup`](@ref) creates popup if it's open
3. Add popup content
4. [`end_popup`](@ref) finalizes popup
5. Popup auto-closes when user clicks outside

# See Also
- [`open_popup!`](@ref): Open popup at mouse position
- [`end_popup`](@ref): Required to close popup scope
- [`begin_window_ex`](@ref): For more complex popup-like windows
"""
function begin_popup(ctx::Context, name::String)
    opt = UInt16(OPT_POPUP) | UInt16(OPT_AUTOSIZE) | UInt16(OPT_NORESIZE) |
          UInt16(OPT_NOSCROLL) | UInt16(OPT_NOTITLE) | UInt16(OPT_CLOSED)
    return begin_window_ex(ctx, name, Rect(0, 0, 0, 0), opt)
end

"""
    end_popup(ctx::Context) -> Nothing

End popup window and clean up popup context.

This function must be called after [`begin_popup`](@ref) to properly close the
popup scope. It performs the same cleanup as [`end_window`](@ref) since popups
are specialized windows.

# Arguments
- `ctx::Context`: The MicroUI context

# Usage Pattern
Always pair `begin_popup` with `end_popup`:

```julia
# Correct usage
if begin_popup(ctx, "my_popup") != 0
    # Popup content here
    text(ctx, "Popup content")
    end_popup(ctx)  # Always call this
end

# Also correct - early return
if begin_popup(ctx, "my_popup") == 0
    return  # Popup not open, no need for end_popup
end
# Popup content here
end_popup(ctx)  # Required after successful begin_popup
```

# See Also
- [`begin_popup`](@ref): Start popup scope
- [`end_window`](@ref): Equivalent function for windows
- [`open_popup!`](@ref): Open popup for display
"""
end_popup(ctx::Context) = end_window(ctx)

"""
    begin_panel_ex(ctx::Context, name::String, opt::UInt16) -> Nothing

Begin panel container with full customization options.

Creates a nested container within the current layout with optional frame and
custom behavior. Panels are useful for grouping related widgets and creating
visual sections within windows.

# Arguments
- `ctx::Context`: The MicroUI context
- `name::String`: Unique name for the panel (for ID generation)
- `opt::UInt16`: Option flags controlling panel behavior

# Panel Behavior
- **Layout Integration**: Takes space from current layout automatically
- **Nested Container**: Creates new layout context for contained widgets
- **Optional Frame**: Can draw background and border (unless `OPT_NOFRAME`)
- **Clipping**: Clips contained widgets to panel bounds
- **ID Scope**: Creates new ID scope for contained widgets

# Panel vs Window
- **Panels**: Embedded within existing containers, take layout space
- **Windows**: Independent containers with their own positioning

# Option Flags
- `UInt16(0)`: Standard panel with background frame
- `UInt16(OPT_NOFRAME)`: Invisible panel (no background/border)

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Settings", Rect(100, 100, 400, 300)) != 0
    # Standard panel with frame
    begin_panel_ex(ctx, "graphics_settings", UInt16(0))
    label(ctx, "Graphics Settings")
    # Add graphics-related controls
    end_panel(ctx)
    
    # Invisible grouping panel
    begin_panel_ex(ctx, "audio_group", UInt16(OPT_NOFRAME))
    label(ctx, "Audio Settings")
    # Add audio-related controls
    end_panel(ctx)
    
    end_window(ctx)
end

end_frame(ctx)
```

# Layout Usage
Panels automatically integrate with the current layout:

```julia
# Panel takes next layout slot
layout_row!(ctx, 2, [200, 200], 150)

begin_panel_ex(ctx, "left_panel", UInt16(0))
# Content in left 200px column
label(ctx, "Left side")
end_panel(ctx)

begin_panel_ex(ctx, "right_panel", UInt16(0))
# Content in right 200px column
label(ctx, "Right side")
end_panel(ctx)
```

# ID Scoping
Panels create isolated ID scopes, preventing name conflicts:

```julia
begin_panel_ex(ctx, "panel1", UInt16(0))
button(ctx, "Save")  # ID: panel1/Save
end_panel(ctx)

begin_panel_ex(ctx, "panel2", UInt16(0))
button(ctx, "Save")  # ID: panel2/Save (different from above)
end_panel(ctx)
```

# See Also
- [`begin_panel`](@ref): Simplified panel creation
- [`end_panel`](@ref): Required to close panel scope
- [`layout_next`](@ref): How panels get their rectangle
- [`push_container_body!`](@ref): Container setup
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

"""
    begin_panel(ctx::Context, name::String) -> Nothing

Simple panel widget with default options.

Creates a standard panel with background frame and default behavior.
This is a convenience function equivalent to calling [`begin_panel_ex`](@ref)
with no option flags.

# Arguments
- `ctx::Context`: The MicroUI context
- `name::String`: Unique name for the panel

# Default Features
- Background frame with panel color
- Automatic layout integration
- ID scoping for contained widgets
- Clipping to panel bounds

# Examples
```julia
ctx = Context()
begin_frame(ctx)

if begin_window(ctx, "Application", Rect(50, 50, 500, 400)) != 0
    # Create sections with panels
    begin_panel(ctx, "toolbar")
    layout_row!(ctx, 3, [80, 80, 80], 0)
    button(ctx, "New")
    button(ctx, "Open")
    button(ctx, "Save")
    end_panel(ctx)
    
    # Main content area
    begin_panel(ctx, "content")
    text(ctx, "This is the main content area")
    text(ctx, "Add your application content here")
    end_panel(ctx)
    
    # Status bar
    begin_panel(ctx, "status")
    label(ctx, "Ready")
    end_panel(ctx)
    
    end_window(ctx)
end

end_frame(ctx)
```

# Panel Styling
Panels use the `COLOR_PANELBG` color from the current style:

```julia
# Customize panel appearance through style
ctx.style.colors[Int(COLOR_PANELBG)] = Color(50, 50, 50, 255)  # Dark gray

begin_panel(ctx, "dark_panel")
# Panel will have dark gray background
end_panel(ctx)
```

# See Also
- [`begin_panel_ex`](@ref): Panel creation with custom options
- [`end_panel`](@ref): Required to close panel scope
- [`COLOR_PANELBG`](@ref): Panel background color in style
"""
begin_panel(ctx::Context, name::String) = begin_panel_ex(ctx, name, UInt16(0))

"""
    end_panel(ctx::Context) -> Nothing

End panel container and clean up panel context.

This function must be called after [`begin_panel`](@ref) or [`begin_panel_ex`](@ref)
to properly close the panel scope and clean up the rendering context. It handles:
- Clipping rectangle cleanup
- Container stack management
- Layout context restoration
- ID scope cleanup

# Arguments
- `ctx::Context`: The MicroUI context

# Usage Pattern
Always pair `begin_panel` with `end_panel`:

```julia
# Correct usage
begin_panel(ctx, "my_panel")
# Panel content here
label(ctx, "Content")
end_panel(ctx)  # Always call this

# Nested panels
begin_panel(ctx, "outer")
    label(ctx, "Outer panel")
    
    begin_panel(ctx, "inner")
    label(ctx, "Inner panel")
    end_panel(ctx)  # Close inner first
    
    label(ctx, "Back in outer panel")
end_panel(ctx)  # Close outer last
```

# Error Handling
Failing to call `end_panel` after `begin_panel` will result in:
- Stack imbalance errors
- ID scope corruption
- Clipping issues
- Layout problems

# Cleanup Order
The function performs cleanup in the correct order:
1. Remove clipping rectangle
2. Pop container from stack (updates content size)
3. Restore parent layout context
4. Pop ID scope

# See Also
- [`begin_panel`](@ref): Start panel scope
- [`begin_panel_ex`](@ref): Start panel scope with options
- [`pop_container!`](@ref): Container cleanup implementation
"""
function end_panel(ctx::Context)
    pop_clip_rect!(ctx)
    pop_container!(ctx)
end