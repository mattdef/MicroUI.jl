# ===== ENUMERATIONS =====
# All enums define the various states and types used throughout the system

"""
Clipping test results when checking if a rectangle is visible within the clip region
- CLIP_NONE: Rectangle is fully visible, no clipping needed
- CLIP_PART: Rectangle is partially visible, clipping required
- CLIP_ALL: Rectangle is completely outside clip region, skip rendering
"""
@enum ClipResult::UInt8 begin
    CLIP_NONE = 0
    CLIP_PART = 1
    CLIP_ALL = 2
end

"""
Types of rendering commands that can be stored in the command buffer
Each command type corresponds to a specific rendering operation
"""
@enum CommandType::UInt8 begin
    COMMAND_JUMP = 1  # Jump to different position in command buffer
    COMMAND_CLIP = 2  # Set clipping rectangle
    COMMAND_RECT = 3  # Draw filled rectangle
    COMMAND_TEXT = 4  # Draw text string
    COMMAND_ICON = 5  # Draw icon/symbol
end

"""
Predefined color IDs for different UI elements
These indices map to colors in the style's color array
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
Built-in icon identifiers for common UI symbols
Icons are drawn as simple geometric shapes
"""
@enum IconId::UInt8 begin
    ICON_CLOSE = 1      # X symbol for close buttons
    ICON_CHECK = 2      # Checkmark for checkboxes
    ICON_COLLAPSED = 3  # Triangle pointing right (collapsed state)
    ICON_EXPANDED = 4   # Triangle pointing down (expanded state)
end

"""
Mouse button flags that can be combined with bitwise operations
Multiple buttons can be pressed simultaneously
"""
@enum MouseButton::UInt8 begin
    MOUSE_LEFT = 1 << 0    # Left mouse button
    MOUSE_RIGHT = 1 << 1   # Right mouse button
    MOUSE_MIDDLE = 1 << 2  # Middle mouse button (wheel)
end

"""
Keyboard key flags for modifier keys and special keys
Can be combined to check for key combinations
"""
@enum Key::UInt8 begin
    KEY_SHIFT = 1 << 0      # Shift modifier key
    KEY_CTRL = 1 << 1       # Control modifier key
    KEY_ALT = 1 << 2        # Alt modifier key
    KEY_BACKSPACE = 1 << 3  # Backspace key
    KEY_RETURN = 1 << 4     # Enter/Return key
end

"""
Option flags for controlling widget and container behavior
These flags can be combined using bitwise OR operations
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
Result flags returned by interactive widgets
Indicate what actions occurred during the last frame
"""
@enum Result::UInt8 begin
    RES_ACTIVE = 1 << 0   # Widget is currently active/pressed
    RES_SUBMIT = 1 << 1   # Widget was activated (clicked, enter pressed)
    RES_CHANGE = 1 << 2   # Widget value changed this frame
end