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
Iterator for traversing the command buffer
Handles jump commands automatically for proper Z-order rendering
"""
mutable struct CommandIterator
    cmdlist::CommandList  # Command list to iterate over
    current::CommandPtr  # Current position in buffer
    
    CommandIterator(cmdlist::CommandList) = new(cmdlist, 0)
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

"""
Generic stack data structure with overflow protection
Used for managing nested contexts (containers, clips, layouts, etc.)
"""
mutable struct Stack{T}
    items::Vector{T}  # Stack storage
    idx::Int32       # Current stack depth (0 = empty)
    
    Stack{T}(size::Int) where T = new{T}(Vector{T}(undef, size), 0)
end

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