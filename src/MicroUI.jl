"""
MicroUI.jl - A Julia implementation of an immediate mode GUI library

This module provides a complete immediate mode GUI (IMGUI) implementation in Julia,
inspired by the microui C library. Immediate mode GUIs rebuild the entire interface
each frame, making them simpler to reason about and integrate into applications.

Key concepts:
- No persistent widget state - everything is recreated each frame
- Direct integration with rendering backends
- Minimal memory allocations during runtime
- Command-based rendering system for backend independence
"""
module MicroUI

# Export all public API functions and types
export Context, Container, Vec2, Rect, Color, Font
export init!, begin_frame, end_frame, set_focus!, get_id, push_id!, pop_id!
export push_clip_rect!, pop_clip_rect!, get_clip_rect, check_clip, expand_rect
export input_mousemove!, input_mousedown!, input_mouseup!, input_scroll!
export input_keydown!, input_keyup!, input_text!
export draw_rect!, draw_box!, draw_text!, draw_icon!, intersect_rects
export layout_row!, layout_width!, layout_height!, layout_begin_column!, layout_end_column!
export layout_set_next!, layout_next, get_current_container, get_container
export text, label, button, button_ex, checkbox!, textbox!, textbox_ex!, textbox_raw!
export slider!, slider_ex!, number!, number_ex!, header, header_ex
export begin_treenode, begin_treenode_ex, end_treenode
export begin_window, begin_window_ex, end_window
export open_popup!, begin_popup, end_popup
export begin_panel, begin_panel_ex, end_panel
export next_command!, push_command!, push_text_command!, bring_to_front!
export BaseCommand, read_command, TextCommand, RectCommand, CommandIterator, CommandPtr
export get_string, write_command!, write_string!, IconCommand, JumpCommand
export push_jump_command!

# ===== CONSTANTS =====
# Library version and buffer size constants for optimal performance

"""Current version of the MicroUI library"""
const VERSION = "1.0.0"

"""Size of the command buffer in bytes - stores all rendering commands for a frame"""
const COMMANDLIST_SIZE = 256 * 1024

"""Maximum number of root containers (windows) that can be active simultaneously"""
const ROOTLIST_SIZE = 32

"""Maximum depth of nested containers (windows, panels, etc.)"""
const CONTAINERSTACK_SIZE = 32

"""Maximum depth of clipping rectangle stack for nested clipping regions"""
const CLIPSTACK_SIZE = 32

"""Maximum depth of ID stack for hierarchical widget identification"""
const IDSTACK_SIZE = 32

"""Maximum depth of layout stack for nested layout contexts"""
const LAYOUTSTACK_SIZE = 16

"""Size of the container pool for efficient container reuse"""
const CONTAINERPOOL_SIZE = 48

"""Size of the treenode pool for efficient treenode state management"""
const TREENODEPOOL_SIZE = 48

"""Maximum number of columns in a layout row"""
const MAX_WIDTHS = 16

"""Maximum length for number format strings"""
const MAX_FMT = 127

"""Default format string for real number display"""
const REAL_FMT = "%.3g"

"""Default format string for slider values"""
const SLIDER_FMT = "%.2f"

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

# ===== TYPE ALIASES =====
# Convenient type aliases for commonly used types

"""Unique identifier for widgets and containers, generated from strings"""
const Id = UInt32

"""Floating point type used for numeric values throughout the library"""
const Real = Float32

"""Font handle - can be any type depending on rendering backend"""
const Font = Any

"""Pointer/index into the command buffer for command linking"""
const CommandPtr = Int32

# ===== BASIC STRUCTURES =====
# Fundamental data types used throughout the system

"""
2D integer vector for positions, sizes, and offsets
Used extensively for layout calculations and positioning
"""
struct Vec2
    x::Int64  # X coordinate/width
    y::Int64  # Y coordinate/height
end

"""
Rectangle defined by position and size
Forms the basis for all layout and clipping operations
"""
struct Rect
    x::Int32  # Left edge position
    y::Int32  # Top edge position
    w::Int32  # Width
    h::Int32  # Height
end

"""
RGBA color with 8 bits per channel
All color values in the library use this format
"""
struct Color
    r::UInt8  # Red component (0-255)
    g::UInt8  # Green component (0-255)
    b::UInt8  # Blue component (0-255)
    a::UInt8  # Alpha component (0-255, 255=opaque)
end

"""
Pool item for efficient resource management
Tracks when resources were last used for automatic cleanup
"""
mutable struct PoolItem
    id::Id           # Unique identifier of the pooled item
    last_update::Int32  # Frame number when item was last accessed
end

# ===== COMMAND SYSTEM =====
# The command system allows backend-independent rendering by recording
# all drawing operations as commands that can be replayed later

"""Abstract base type for all rendering commands"""
abstract type Command end

"""
Base header present in all command types
Contains type information and size for command buffer traversal
"""
struct BaseCommand
    type::CommandType  # What type of command this is
    size::Int32       # Size of this command in bytes
end

"""
Jump command for non-linear command buffer traversal
Used to implement container Z-ordering and command list linking
"""
struct JumpCommand
    base::BaseCommand  # Common command header
    dst::CommandPtr   # Destination offset in command buffer
end

"""
Clipping command to set the active clipping rectangle
All subsequent rendering will be clipped to this region
"""
struct ClipCommand
    base::BaseCommand  # Common command header
    rect::Rect        # Clipping rectangle in screen coordinates
end

"""
Rectangle drawing command for filled rectangles
Used for backgrounds, borders, and solid color areas
"""
struct RectCommand
    base::BaseCommand  # Common command header
    rect::Rect        # Rectangle to draw
    color::Color      # Fill color
end

"""
Text rendering command for drawing strings
Includes position, color, and string data
"""
struct TextCommand
    base::BaseCommand  # Common command header
    font::Font        # Font to use for rendering
    pos::Vec2         # Text baseline position
    color::Color      # Text color
    str_index::Int32  # Index into string table
    str_length::Int32 # Length of string in characters
end

"""
Icon drawing command for built-in symbols
Icons are simple geometric shapes drawn at specified rectangles
"""
struct IconCommand
    base::BaseCommand  # Common command header
    rect::Rect        # Rectangle to draw icon within
    id::IconId        # Which icon to draw
    color::Color      # Icon color
end

"""
Command buffer that stores all rendering commands for a frame
Manages both binary command data and string storage
"""
mutable struct CommandList
    buffer::Vector{UInt8}    # Binary command buffer
    idx::Int32              # Current write position in buffer
    strings::Vector{String}  # String storage for text commands
    string_idx::Int32       # Current write position in string array
    
    CommandList() = new(Vector{UInt8}(undef, COMMANDLIST_SIZE), 0, String[], 0)
end

"""
Write a command to the command buffer
Returns the offset where the command was written
"""
function write_command!(cmdlist::CommandList, cmd::T) where T
    size = sizeof(T)
    if cmdlist.idx + size > length(cmdlist.buffer)
        error("Command buffer overflow")
    end
    
    # Directly write binary data to buffer
    ptr = pointer(cmdlist.buffer, cmdlist.idx + 1)
    unsafe_store!(Ptr{T}(ptr), cmd)
    
    old_idx = cmdlist.idx
    cmdlist.idx += size
    return old_idx
end

"""
Store a string in the command list and return its index
Used by text commands to reference their string data
"""
function write_string!(cmdlist::CommandList, str::String)
    cmdlist.string_idx += 1
    if cmdlist.string_idx > length(cmdlist.strings)
        resize!(cmdlist.strings, cmdlist.string_idx * 2)
    end
    cmdlist.strings[cmdlist.string_idx] = str
    return cmdlist.string_idx
end

"""
Read a command from the buffer at the specified offset
Type parameter specifies which command type to read
"""
function read_command(cmdlist::CommandList, idx::CommandPtr, ::Type{T}) where T
    if idx < 0 || idx + sizeof(T) > cmdlist.idx
        error("Invalid command index")
    end
    ptr = pointer(cmdlist.buffer, idx + 1)
    return unsafe_load(Ptr{T}(ptr))
end

"""
Retrieve a string from the string table by index
Used when processing text commands during rendering
"""
function get_string(cmdlist::CommandList, str_index::Int32)
    return cmdlist.strings[str_index]
end

"""
Iterator for traversing the command buffer
Handles jump commands automatically for proper Z-order rendering
"""
mutable struct CommandIterator
    cmdlist::CommandList  # Command list to iterate over
    current::CommandPtr  # Current position in buffer
    
    CommandIterator(cmdlist::CommandList) = new(cmdlist, 0)
end

"""
Advance iterator to next command, handling jumps automatically
Returns (has_command, command_type, command_offset)
"""
@inline function next_command!(iter::CommandIterator)
    @inbounds begin
        while iter.current < iter.cmdlist.idx
            ptr = pointer(iter.cmdlist.buffer, iter.current + 1)
            base = unsafe_load(Ptr{BaseCommand}(ptr))
            
            if base.type != COMMAND_JUMP
                old_current = iter.current
                iter.current += base.size
                return (true, base.type, old_current)
            else
                # Follow jump to maintain Z-order
                jump = unsafe_load(Ptr{JumpCommand}(ptr))
                iter.current = jump.dst
            end
        end
    end
    return (false, COMMAND_JUMP, CommandPtr(0))
end

# ===== LAYOUT SYSTEM =====
# The layout system handles automatic positioning of widgets

"""
Layout state for a container or layout context
Manages positioning, sizing, and flow of widgets within a region
"""
mutable struct Layout
    body::Rect              # Available area for content
    next::Rect             # Next widget position/size
    position::Vec2         # Current layout position
    size::Vec2            # Default widget size
    max::Vec2             # Maximum extent reached
    widths::Vector{Int32} # Column widths for current row
    items::Int32          # Number of items in current row
    item_index::Int32     # Current item index in row
    next_row::Int32       # Y position of next row
    next_type::Int32      # Type of next layout (relative/absolute)
    indent::Int32         # Current indentation level
    
    Layout() = new(
        Rect(0,0,0,0), Rect(0,0,0,0), 
        Vec2(0,0), Vec2(0,0), Vec2(typemin(Int32), typemin(Int32)),
        zeros(Int32, MAX_WIDTHS), 0, 0, 0, 0, 0
    )
end

# ===== CONTAINER SYSTEM =====
# Containers represent windows, panels, and other grouping widgets

"""
Container represents a window, panel, or other widget grouping
Maintains its own command buffer region and layout state
"""
mutable struct Container
    head::CommandPtr      # Start of command buffer region
    tail::CommandPtr      # End of command buffer region
    rect::Rect           # Container screen rectangle
    body::Rect           # Content area (excludes title bar, scrollbars)
    content_size::Vec2   # Size of all content
    scroll::Vec2         # Current scroll offset
    zindex::Int32        # Z-order for rendering (higher = front)
    open::Bool           # Whether container is currently open
    
    Container() = new(0, 0, Rect(0,0,0,0), Rect(0,0,0,0), Vec2(0,0), Vec2(0,0), 0, false)
end

"""
Visual style configuration for the UI
Contains colors, sizes, and other visual parameters
"""
struct Style
    font::Font               # Default font for text rendering
    size::Vec2              # Default widget size
    padding::Int32          # Padding inside widgets
    spacing::Int32          # Spacing between widgets
    indent::Int32           # Indentation amount for tree nodes
    title_height::Int32     # Height of window title bars
    scrollbar_size::Int32   # Width/height of scrollbars
    thumb_size::Int32       # Minimum size of scrollbar thumbs
    colors::Vector{Color}   # Color palette for UI elements
end

"""
Generic stack data structure with overflow protection
Used for managing nested contexts (containers, clips, layouts, etc.)
"""
mutable struct Stack{T}
    items::Vector{T}  # Stack storage
    idx::Int32       # Current stack depth (0 = empty)
    
    Stack{T}(size::Int) where T = new{T}(Vector{T}(undef, size), 0)
end

"""Push item onto stack with overflow checking"""
@inline function push!(s::Stack{T}, val::T) where T
    s.idx >= length(s.items) && error("Stack overflow")
    s.idx += 1
    s.items[s.idx] = val
end

"""Pop item from stack with underflow checking"""
@inline function pop!(s::Stack)
    s.idx <= 0 && error("Stack underflow")
    s.idx -= 1
end

"""Get top item from stack without removing it"""
@inline function top(s::Stack)
    s.idx <= 0 && error("Stack is empty")
    return s.items[s.idx]
end

"""Check if stack is empty"""
@inline Base.isempty(s::Stack) = s.idx == 0

"""
Main context structure containing all UI state
This is the primary object that applications interact with
"""
mutable struct Context
    # Rendering callbacks - must be set by application
    text_width::Function    # Function to measure text width
    text_height::Function   # Function to get text height
    draw_frame::Function    # Function to draw widget frames
    
    # Visual style configuration
    style::Style           # Current visual style
    
    # Core interaction state
    hover::Id             # Widget currently under mouse
    focus::Id             # Widget with keyboard focus
    last_id::Id           # Last generated widget ID
    last_rect::Rect       # Last widget rectangle
    last_zindex::Int32    # Highest Z-index used this frame
    updated_focus::Bool   # Whether focus was updated this frame
    frame::Int32          # Current frame number
    
    # Container management
    hover_root::Union{Nothing, Container}      # Root container under mouse
    next_hover_root::Union{Nothing, Container} # Root container under mouse next frame
    scroll_target::Union{Nothing, Container}   # Container to receive scroll events
    
    # Number editing state
    number_edit_buf::String  # Buffer for number text editing
    number_edit::Id         # ID of number widget being edited
    
    # Command and layout stacks
    command_list::CommandList        # All rendering commands for this frame
    root_list::Stack{Container}      # All root containers this frame
    container_stack::Stack{Container} # Nested container stack
    clip_stack::Stack{Rect}         # Nested clipping rectangle stack
    id_stack::Stack{Id}             # Nested ID scope stack
    layout_stack::Stack{Layout}     # Nested layout context stack
    
    # Resource pools for efficient reuse
    container_pool::Vector{PoolItem}  # Pool of container resources
    containers::Vector{Container}     # Actual container storage
    treenode_pool::Vector{PoolItem}   # Pool of treenode state
    
    # Input state
    mouse_pos::Vec2       # Current mouse position
    last_mouse_pos::Vec2  # Mouse position last frame
    mouse_delta::Vec2     # Mouse movement this frame
    scroll_delta::Vec2    # Scroll wheel input this frame
    mouse_down::UInt8     # Currently pressed mouse buttons
    mouse_pressed::UInt8  # Mouse buttons pressed this frame
    key_down::UInt8       # Currently pressed keys
    key_pressed::UInt8    # Keys pressed this frame
    input_text::String    # Text input this frame
end

"""
Default visual style with dark theme colors
Provides sensible defaults for all UI elements
"""
const DEFAULT_STYLE = Style(
    nothing,
    Vec2(68, 10),
    5, 4, 24, 24, 12, 8,
    [
        Color(230, 230, 230, 255), # TEXT
        Color(25, 25, 25, 255),    # BORDER
        Color(50, 50, 50, 255),    # WINDOWBG
        Color(25, 25, 25, 255),    # TITLEBG
        Color(240, 240, 240, 255), # TITLETEXT
        Color(0, 0, 0, 0),         # PANELBG
        Color(75, 75, 75, 255),    # BUTTON
        Color(95, 95, 95, 255),    # BUTTONHOVER
        Color(115, 115, 115, 255), # BUTTONFOCUS
        Color(30, 30, 30, 255),    # BASE
        Color(35, 35, 35, 255),    # BASEHOVER
        Color(40, 40, 40, 255),    # BASEFOCUS
        Color(43, 43, 43, 255),    # SCROLLBASE
        Color(30, 30, 30, 255)     # SCROLLTHUMB
    ]
)

# ===== UTILITY FUNCTIONS =====
# Common mathematical and utility functions

"""Clamp value between minimum and maximum bounds"""
clamp(x, a, b) = max(a, min(b, x))

"""
Expand rectangle by given amount in all directions
Useful for creating borders and padding
"""
function expand_rect(r::Rect, n::Int32)
    Rect(r.x - n, r.y - n, r.w + n * 2, r.h + n * 2)
end

"""
Test if point is inside rectangle
Used for hit testing and mouse interaction
"""
function rect_overlaps_vec2(r::Rect, p::Vec2)
    p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h
end

"""
Format real numbers for display in widgets
Provides consistent number formatting throughout the UI
"""
function format_real(value::Real, fmt::String)
    val = Float64(value)
    
    if fmt == REAL_FMT || fmt == "%.3g"
        if abs(val) >= 1000
            return string(round(Int, val))
        elseif abs(val) >= 10
            return string(round(val, digits=1))
        else
            return string(round(val, digits=2))
        end
    elseif fmt == SLIDER_FMT || fmt == "%.2f"
        return string(round(val, digits=2))
    else
        return string(round(val, digits=2))
    end
end

"""
Default frame drawing function
Draws a filled rectangle with optional border
"""
function default_draw_frame(ctx::Context, rect::Rect, colorid::ColorId)
    draw_rect!(ctx, rect, ctx.style.colors[Int(colorid)])
    if colorid == COLOR_SCROLLBASE || colorid == COLOR_SCROLLTHUMB || colorid == COLOR_TITLEBG
        return
    end
    # Draw border for most elements
    if ctx.style.colors[Int(COLOR_BORDER)].a > 0
        draw_box!(ctx, expand_rect(rect, Int32(1)), ctx.style.colors[Int(COLOR_BORDER)])
    end
end

"""
Create new context with default settings
Applications should call init! after creation
"""
function Context()
    ctx = Context(
        (font, str) -> length(str) * 8,  # Default text_width function
        font -> 16,                      # Default text_height function
        default_draw_frame,              # Default draw_frame function
        DEFAULT_STYLE,
        0, 0, 0, Rect(0,0,0,0), 0, false, 0,
        nothing, nothing, nothing, "", 0,
        CommandList(),
        Stack{Container}(ROOTLIST_SIZE),
        Stack{Container}(CONTAINERSTACK_SIZE),
        Stack{Rect}(CLIPSTACK_SIZE),
        Stack{Id}(IDSTACK_SIZE),
        Stack{Layout}(LAYOUTSTACK_SIZE),
        [PoolItem(0, 0) for _ in 1:CONTAINERPOOL_SIZE],
        [Container() for _ in 1:CONTAINERPOOL_SIZE],
        [PoolItem(0, 0) for _ in 1:TREENODEPOOL_SIZE],
        Vec2(0,0), Vec2(0,0), Vec2(0,0), Vec2(0,0),
        0, 0, 0, 0, ""
    )
    return ctx
end

"""
Initialize or reset context to default state
Should be called before first use and when resetting UI state
"""
function init!(ctx::Context)
    ctx.command_list = CommandList()
    ctx.root_list.idx = 0
    ctx.container_stack.idx = 0
    ctx.clip_stack.idx = 0
    ctx.id_stack.idx = 0
    ctx.layout_stack.idx = 0
    
    ctx.hover = 0
    ctx.focus = 0
    ctx.frame = 0
    ctx.last_zindex = 0
    ctx.updated_focus = false
    ctx.hover_root = nothing
    ctx.next_hover_root = nothing
    ctx.scroll_target = nothing
    ctx.number_edit_buf = ""
    ctx.number_edit = 0
    
    ctx.mouse_pos = Vec2(0, 0)
    ctx.last_mouse_pos = Vec2(0, 0)
    ctx.mouse_delta = Vec2(0, 0)
    ctx.scroll_delta = Vec2(0, 0)
    ctx.mouse_down = 0
    ctx.mouse_pressed = 0
    ctx.key_down = 0
    ctx.key_pressed = 0
    ctx.input_text = ""
end

# ===== FRAME MANAGEMENT =====
# Functions to manage frame lifecycle and prepare for rendering

"""
Begin a new frame of UI processing
Must be called before any widgets or containers
"""
function begin_frame(ctx::Context)
    @assert !isnothing(ctx.text_width) && !isnothing(ctx.text_height) "text_width and text_height callbacks must be set"
    
    # Reset command buffer for new frame
    ctx.command_list.idx = 0
    ctx.command_list.string_idx = 0
    ctx.root_list.idx = 0
    ctx.scroll_target = nothing
    
    # Update hover state and mouse tracking
    ctx.hover_root = ctx.next_hover_root
    ctx.next_hover_root = nothing
    ctx.mouse_delta = Vec2(
        ctx.mouse_pos.x - ctx.last_mouse_pos.x,
        ctx.mouse_pos.y - ctx.last_mouse_pos.y
    )
    ctx.frame += 1
end

"""Compare containers by Z-index for sorting"""
function compare_zindex(a::Container, b::Container)
    return a.zindex - b.zindex
end

"""
End current frame and prepare command buffer for rendering
Handles container sorting, scrolling, and focus management
"""
function end_frame(ctx::Context)
    # Verify all stacks are properly balanced
    @assert ctx.container_stack.idx == 0 "Container stack not empty"
    @assert ctx.clip_stack.idx == 0 "Clip stack not empty"
    @assert ctx.id_stack.idx == 0 "ID stack not empty"  
    @assert ctx.layout_stack.idx == 0 "Layout stack not empty"

    # Apply scroll input to target container
    if ctx.scroll_target !== nothing
        ctx.scroll_target.scroll = Vec2(
            ctx.scroll_target.scroll.x + ctx.scroll_delta.x,
            ctx.scroll_target.scroll.y + ctx.scroll_delta.y
        )
    end

    # Clear focus if no widget claimed it this frame
    if !ctx.updated_focus
        ctx.focus = 0
    end
    ctx.updated_focus = false

    # Bring hover container to front on mouse press
    if ctx.mouse_pressed != 0 && ctx.next_hover_root !== nothing &&
       ctx.next_hover_root.zindex < ctx.last_zindex &&
       ctx.next_hover_root.zindex >= 0
        bring_to_front!(ctx, ctx.next_hover_root)
    end

    # Reset input state for next frame
    ctx.key_pressed = 0
    ctx.input_text = ""
    ctx.mouse_pressed = 0
    ctx.scroll_delta = Vec2(0, 0)
    ctx.last_mouse_pos = ctx.mouse_pos

    # Sort root containers by Z-index and set up command buffer jumps
    n = ctx.root_list.idx
    if n > 0
        containers = view(ctx.root_list.items, 1:n)
        sort!(containers, by = c -> c.zindex)
        
        # Create jump chain for proper Z-order rendering
        for i in 1:n
            cnt = containers[i]
            if i == 1
                # First container: set up initial jump
                if ctx.command_list.idx > 0
                    first_cmd_ptr = pointer(ctx.command_list.buffer, 1)
                    jump_cmd = JumpCommand(
                        BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
                        cnt.head + sizeof(JumpCommand)
                    )
                    unsafe_store!(Ptr{JumpCommand}(first_cmd_ptr), jump_cmd)
                end
            else
                # Link previous container to this one
                prev = containers[i-1]
                if prev.tail >= 0
                    ptr = pointer(ctx.command_list.buffer, prev.tail + 1)
                    jump_cmd = JumpCommand(
                        BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
                        cnt.head + sizeof(JumpCommand)
                    )
                    unsafe_store!(Ptr{JumpCommand}(ptr), jump_cmd)
                end
            end
            
            # Last container jumps to end of command list
            if i == n && cnt.tail >= 0
                ptr = pointer(ctx.command_list.buffer, cnt.tail + 1)
                jump_cmd = JumpCommand(
                    BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
                    ctx.command_list.idx
                )
                unsafe_store!(Ptr{JumpCommand}(ptr), jump_cmd)
            end
        end
    end
end

"""
Set keyboard focus to specific widget
Widget will receive keyboard input and be highlighted
"""
function set_focus!(ctx::Context, id::Id)
    ctx.focus = id
    ctx.updated_focus = true
end

# ===== ID MANAGEMENT =====
# System for generating unique widget identifiers

"""Hash constant for ID generation"""
const HASH_INITIAL = 0x811c9dc5

"""
Generate unique ID from string data
Uses FNV-1a hash algorithm for consistent ID generation
"""
function get_id(ctx::Context, data::AbstractString)
    h = ctx.id_stack.idx > 0 ? ctx.id_stack.items[ctx.id_stack.idx] : HASH_INITIAL
    for byte in codeunits(data)
        h = (h ⊻ UInt32(byte)) * 0x01000193
    end
    ctx.last_id = h
    return h
end

"""
Push new ID scope onto ID stack
Creates hierarchical namespace for widget IDs
"""
function push_id!(ctx::Context, data::AbstractString)
    push!(ctx.id_stack, get_id(ctx, data))
end

"""Pop ID scope from stack"""
function pop_id!(ctx::Context)
    pop!(ctx.id_stack)
end

# ===== INPUT FUNCTIONS =====
# Functions for handling mouse, keyboard, and text input

"""Update mouse position"""
function input_mousemove!(ctx::Context, x::Int, y::Int)
    ctx.mouse_pos = Vec2(Int32(x), Int32(y))
end

"""Handle mouse button press event"""
function input_mousedown!(ctx::Context, x::Int, y::Int, btn::MouseButton)
    input_mousemove!(ctx, x, y)
    ctx.mouse_down |= UInt8(btn)
    ctx.mouse_pressed |= UInt8(btn)
end

"""Convenience overload for Int32 coordinates"""
input_mousedown!(ctx::Context, x::Int32, y::Int32, btn::MouseButton) = input_mousedown!(ctx, Int64(x), Int64(y), btn)

"""Handle mouse button release event"""
function input_mouseup!(ctx::Context, x::Int, y::Int, btn::MouseButton)
    input_mousemove!(ctx, x, y)
    ctx.mouse_down &= ~UInt8(btn)
end

"""Convenience overload for Int32 coordinates"""
input_mouseup!(ctx::Context, x::Int32, y::Int32, btn::MouseButton) = input_mouseup!(ctx, Int64(x), Int64(y), btn)

"""Handle mouse scroll wheel input"""
function input_scroll!(ctx::Context, x::Int, y::Int)
    ctx.scroll_delta = Vec2(ctx.scroll_delta.x + Int32(x), ctx.scroll_delta.y + Int32(y))
end

"""Handle key press event"""
function input_keydown!(ctx::Context, key::Key)
    ctx.key_pressed |= UInt8(key)
    ctx.key_down |= UInt8(key)
end

"""Handle key release event"""
function input_keyup!(ctx::Context, key::Key)
    ctx.key_down &= ~UInt8(key)
end

"""Add text input for current frame"""
function input_text!(ctx::Context, text::String)
    ctx.input_text *= text
end

# ===== COMMAND FUNCTIONS =====
# Functions for building the command buffer

"""
Add command to command buffer
Returns offset where command was written
"""
function push_command!(ctx::Context, cmd::T) where T
    return write_command!(ctx.command_list, cmd)
end

"""
Add text rendering command with string data
Handles string storage and creates complete text command
"""
function push_text_command!(ctx::Context, font::Font, str::String, pos::Vec2, color::Color)
    str_idx = write_string!(ctx.command_list, str)
    text_cmd = TextCommand(
        BaseCommand(COMMAND_TEXT, sizeof(TextCommand)),
        font, pos, color, str_idx, length(str)
    )
    return write_command!(ctx.command_list, text_cmd)
end

"""
Add jump command for non-linear command buffer traversal
Used to implement container Z-ordering
"""
function push_jump_command!(ctx::Context, dst::CommandPtr)
    jump_cmd = JumpCommand(
        BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
        dst
    )
    return write_command!(ctx.command_list, jump_cmd)
end

"""Set clipping rectangle for subsequent rendering commands"""
function set_clip!(ctx::Context, rect::Rect)
    clip_cmd = ClipCommand(BaseCommand(COMMAND_CLIP, sizeof(ClipCommand)), rect)
    push_command!(ctx, clip_cmd)
end

# ===== DRAWING FUNCTIONS =====
# High-level drawing functions that create appropriate commands

"""
Draw filled rectangle with clipping
Only draws visible portions of the rectangle
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
Draw rectangle outline (border)
Draws four separate rectangles for top, bottom, left, and right edges
"""
function draw_box!(ctx::Context, rect::Rect, color::Color)
    draw_rect!(ctx, Rect(rect.x + 1, rect.y, rect.w - 2, 1), color)
    draw_rect!(ctx, Rect(rect.x + 1, rect.y + rect.h - 1, rect.w - 2, 1), color)
    draw_rect!(ctx, Rect(rect.x, rect.y, 1, rect.h), color)
    draw_rect!(ctx, Rect(rect.x + rect.w - 1, rect.y, 1, rect.h), color)
end

"""Unclipped rectangle for resetting clipping state"""
const UNCLIPPED_RECT = Rect(0, 0, 0x1000000, 0x1000000)

"""
Draw text string with automatic clipping handling
Sets up clipping if needed and creates text command
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
Draw built-in icon with automatic clipping
Icons are simple geometric shapes rendered by the backend
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

# ===== LAYOUT MANAGEMENT =====
# Functions for managing widget positioning and sizing

"""Layout positioning modes"""
const RELATIVE = 1
const ABSOLUTE = 2

"""
Create new layout context with given body rectangle and scroll offset
Used when entering containers or column layouts
"""
function push_layout!(ctx::Context, body::Rect, scroll::Vec2)
    layout = Layout()
    layout.body = Rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h)
    layout.max = Vec2(typemin(Int32), typemin(Int32))
    push!(ctx.layout_stack, layout)
    width = 0
    layout_row!(ctx, 1, [width], 0)
end

"""Get current layout context from stack"""
function get_layout(ctx::Context)
    @assert ctx.layout_stack.idx > 0 "No layout on stack"
    return ctx.layout_stack.items[ctx.layout_stack.idx]
end

"""
Pop container and update its content size
Called when exiting containers to finalize layout
"""
function pop_container!(ctx::Context)
    cnt = get_current_container(ctx)
    layout = get_layout(ctx)
    cnt.content_size = Vec2(
        layout.max.x - layout.body.x,
        layout.max.y - layout.body.y
    )
    pop!(ctx.container_stack)
    pop!(ctx.layout_stack)
    pop_id!(ctx)
end

"""Start column layout context within current layout"""
function layout_begin_column!(ctx::Context)
    push_layout!(ctx, layout_next(ctx), Vec2(0, 0))
end

"""
End column layout and merge extents with parent
Updates parent layout's position and maximum extents
"""
function layout_end_column!(ctx::Context)
    b = get_layout(ctx)
    pop!(ctx.layout_stack)
    # Inherit position/next_row/max from child layout
    a = get_layout(ctx)
    a.position = Vec2(
        max(a.position.x, b.position.x + b.body.x - a.body.x),
        a.position.y
    )
    a.next_row = max(a.next_row, b.next_row + b.body.y - a.body.y)
    a.max = Vec2(max(a.max.x, b.max.x), max(a.max.y, b.max.y))
end

"""
Set up new layout row with specified items and dimensions
Controls how widgets are positioned horizontally
"""
function layout_row!(ctx::Context, items::Int, widths::Union{Nothing, Vector{Int}}, height::Int)
    layout = get_layout(ctx)
    if widths !== nothing
        @assert items <= MAX_WIDTHS "Too many layout items"
        for i in 1:items
            layout.widths[i] = Int32(widths[i])
        end
    end
    layout.items = Int32(items)
    layout.position = Vec2(layout.indent, layout.next_row)
    layout.size = Vec2(layout.size.x, Int32(height))
    layout.item_index = 0
end

"""Set default width for next widget"""
function layout_width!(ctx::Context, width::Int)
    get_layout(ctx).size = Vec2(Int32(width), get_layout(ctx).size.y)
end

"""Set default height for next widget"""
function layout_height!(ctx::Context, height::Int)
    get_layout(ctx).size = Vec2(get_layout(ctx).size.x, Int32(height))
end

"""
Manually set rectangle for next widget
Can be relative to current position or absolute
"""
function layout_set_next!(ctx::Context, r::Rect, relative::Bool)
    layout = get_layout(ctx)
    layout.next = r
    layout.next_type = relative ? RELATIVE : ABSOLUTE
end

"""
Calculate and return rectangle for next widget
Handles both manual positioning and automatic layout flow
"""
function layout_next(ctx::Context)
    layout = get_layout(ctx)
    style = ctx.style
    
    if layout.next_type != 0
        # Use manually set rectangle
        type = layout.next_type
        layout.next_type = 0
        res = layout.next
        if type == ABSOLUTE
            ctx.last_rect = res
            return res
        end
    else
        # Automatic layout positioning
        if layout.item_index == layout.items
            layout_row!(ctx, Int(layout.items), nothing, Int(layout.size.y))
        end
        
        # Calculate position
        res = Rect(layout.position.x, layout.position.y, 0, 0)
        
        # Calculate size
        if layout.items > 0
            res = Rect(res.x, res.y, layout.widths[layout.item_index + 1], res.h)
        else
            res = Rect(res.x, res.y, layout.size.x, res.h)
        end
        
        res = Rect(res.x, res.y, res.w, layout.size.y)
        
        # Apply default sizes if zero
        if res.w == 0
            res = Rect(res.x, res.y, style.size.x + style.padding * 2, res.h)
        end
        if res.h == 0  
            res = Rect(res.x, res.y, res.w, style.size.y + style.padding * 2)
        end
        # Handle negative sizes (fill remaining space)
        if res.w < 0
            res = Rect(res.x, res.y, res.w + layout.body.w - res.x + 1, res.h)
        end
        if res.h < 0
            res = Rect(res.x, res.y, res.w, res.h + layout.body.h - res.y + 1)
        end
        
        layout.item_index += 1
    end
    
    # Update layout position for next widget
    layout.position = Vec2(layout.position.x + res.w + style.spacing, layout.position.y)
    layout.next_row = max(layout.next_row, res.y + res.h + style.spacing)
    
    # Convert to screen coordinates
    res = Rect(res.x + layout.body.x, res.y + layout.body.y, res.w, res.h)
    
    # Track maximum extents
    layout.max = Vec2(max(layout.max.x, res.x + res.w), max(layout.max.y, res.y + res.h))
    
    ctx.last_rect = res
    return res
end

# ===== CLIPPING FUNCTIONS =====
# Functions for managing clipping rectangles

"""Push new clipping rectangle onto stack"""
function push_clip_rect!(ctx::Context, rect::Rect)
    last = get_clip_rect(ctx)
    push!(ctx.clip_stack, intersect_rects(rect, last))
end

"""Remove current clipping rectangle from stack"""
function pop_clip_rect!(ctx::Context)
    pop!(ctx.clip_stack)
end

"""Get current clipping rectangle"""
function get_clip_rect(ctx::Context)
    @assert ctx.clip_stack.idx > 0 "No clip rect on stack"
    return ctx.clip_stack.items[ctx.clip_stack.idx]
end

"""
Test if rectangle is visible within current clipping region
Returns clipping result for optimization decisions
"""
function check_clip(ctx::Context, r::Rect)
    cr = get_clip_rect(ctx)
    if r.x > cr.x + cr.w || r.x + r.w < cr.x ||
       r.y > cr.y + cr.h || r.y + r.h < cr.y
        return CLIP_ALL
    end
    if r.x >= cr.x && r.x + r.w <= cr.x + cr.w &&
       r.y >= cr.y && r.y + r.h <= cr.y + cr.h
        return CLIP_NONE
    end
    return CLIP_PART
end

"""Expand rectangle by n pixels in all directions"""
function expand_rect(r::Rect, n::Int)
    return Rect(r.x - n, r.y - n, r.w + n * 2, r.h + n * 2)
end

"""
Calculate intersection of two rectangles
Returns rectangle representing overlapping area
"""
function intersect_rects(r1::Rect, r2::Rect)
    x1 = max(r1.x, r2.x)
    y1 = max(r1.y, r2.y)
    x2 = min(r1.x + r1.w, r2.x + r2.w)
    y2 = min(r1.y + r1.h, r2.y + r2.h)
    Rect(x1, y1, max(0, x2-x1), max(0, y2-y1))
end

# ===== POOL MANAGEMENT =====
# Resource pooling system for containers and treenodes

"""
Initialize pool item with given ID
Finds least recently used slot and assigns it to the ID
"""
function pool_init!(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id)
    n = -1
    f = ctx.frame
    for i in 1:len
        if items[i].last_update < f
            f = items[i].last_update
            n = i
        end
    end
    @assert n > 0 "Pool exhausted"
    items[n].id = id
    pool_update!(ctx, items, n)
    return n
end

"""
Find pool item by ID
Returns index if found, -1 if not found
"""
function pool_get(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id)
    for i in 1:len
        if items[i].id == id
            return i
        end
    end
    return -1
end

"""Update pool item's last access time to current frame"""
function pool_update!(ctx::Context, items::Vector{PoolItem}, idx::Int)
    items[idx].last_update = ctx.frame
end

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
            set_focus!(ctx, 0)
        end
        if ctx.mouse_down == 0 && (opt & UInt16(OPT_HOLDFOCUS)) == 0
            set_focus!(ctx, 0)
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

# ===== CONTAINER MANAGEMENT =====
# Functions for managing containers (windows, panels, etc.)

"""Get current container from container stack"""
function get_current_container(ctx::Context)
    @assert ctx.container_stack.idx > 0 "No container on stack"
    return ctx.container_stack.items[ctx.container_stack.idx]
end

"""
Get or create container with given ID
Uses pool for efficient container reuse
"""
function get_container(ctx::Context, id::Id, opt::UInt16)
    # Try to get existing container from pool
    idx = pool_get(ctx, ctx.container_pool, CONTAINERPOOL_SIZE, id)
    if idx >= 0
        if ctx.containers[idx].open || (opt & UInt16(OPT_CLOSED)) == 0
            pool_update!(ctx, ctx.container_pool, idx)
        end
        return ctx.containers[idx]
    end
    
    if (opt & UInt16(OPT_CLOSED)) != 0
        return nothing
    end
    
    # Container not found: initialize new one
    idx = pool_init!(ctx, ctx.container_pool, CONTAINERPOOL_SIZE, id)
    cnt = ctx.containers[idx]
    cnt.head = 0
    cnt.tail = 0
    cnt.rect = Rect(0, 0, 0, 0)
    cnt.body = Rect(0, 0, 0, 0)
    cnt.content_size = Vec2(0, 0)
    cnt.scroll = Vec2(0, 0)
    cnt.zindex = 0
    cnt.open = true
    bring_to_front!(ctx, cnt)
    return cnt
end

"""Convenience function to get container by name"""
function get_container(ctx::Context, name::String)
    id = get_id(ctx, name)
    return get_container(ctx, id, UInt16(0))
end

"""
Bring container to front by updating its Z-index
Higher Z-index containers are rendered on top
"""
function bring_to_front!(ctx::Context, cnt::Container)
    ctx.last_zindex += 1
    cnt.zindex = ctx.last_zindex
end

# ===== WIDGETS =====
# Implementation of all interactive UI widgets

"""
Multi-line text display widget
Automatically handles word wrapping and line breaks
"""
function text(ctx::Context, text::String)
    start_ptr = 1
    end_ptr = 1
    p = 1
    width = -1
    font = ctx.style.font
    color = ctx.style.colors[Int(COLOR_TEXT)]
    
    layout_begin_column!(ctx)
    layout_row!(ctx, 1, [width], ctx.text_height(font))
    
    text_bytes = text
    
    # Process text line by line with word wrapping
    while p <= length(text_bytes)
        r = layout_next(ctx)
        w = 0
        start_ptr = end_ptr = p
        
        while true
            word_start = p
            # Skip to end of current word
            while p <= length(text_bytes) && text_bytes[p] != ' ' && text_bytes[p] != '\n'
                p += 1
            end
            
            word = p > word_start ? text_bytes[word_start:p-1] : ""
            w += ctx.text_width(font, word)
            
            # Check if word fits on current line
            if w > r.w && end_ptr != start_ptr
                break
            end
            
            if p <= length(text_bytes)
                w += ctx.text_width(font, " ")
            end
            end_ptr = p
            p += 1
            
            # Break on newline or end of text
            if end_ptr >= length(text_bytes) || (p <= length(text_bytes) && text_bytes[end_ptr] == '\n')
                break
            end
        end
        
        line_text = end_ptr > start_ptr ? text_bytes[start_ptr:end_ptr] : ""
        draw_text!(ctx, font, line_text, -1, Vec2(r.x, r.y), color)
        p = end_ptr + 1
        
        if end_ptr >= length(text_bytes)
            break
        end
    end
    
    layout_end_column!(ctx)
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

# ===== UTILITY OPERATIONS =====
# Vector arithmetic operations for convenience

"""Add two vectors"""
Base.:+(a::Vec2, b::Vec2) = Vec2(a.x + b.x, a.y + b.y)

"""Subtract two vectors"""
Base.:-(a::Vec2, b::Vec2) = Vec2(a.x - b.x, a.y - b.y)

"""Scale vector by scalar"""
Base.:*(a::Vec2, s::Number) = Vec2(Int32(a.x * s), Int32(a.y * s))

end # module