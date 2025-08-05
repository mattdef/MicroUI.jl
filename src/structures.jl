"""
# MicroUI Core Structures

Fundamental data types and structures used throughout the MicroUI system.

This file defines the core data structures that form the foundation of MicroUI:

- **Basic geometric types**: Vectors, rectangles, colors for UI positioning and appearance
- **Command system**: Structures for backend-independent rendering command recording
- **Layout system**: Data structures for automatic widget positioning and sizing
- **Container system**: Structures for windows, panels, and UI organization
- **Context management**: The main state container that coordinates all UI operations

# Design Principles

- **Memory efficiency**: Structures use appropriate-sized integer types
- **Cache friendliness**: Related data is grouped together in structures
- **Immutability where possible**: Many structures are immutable for safety
- **Clear ownership**: Mutable structures have clear ownership semantics
- **Performance-oriented**: Structure layouts optimized for common access patterns

# Structure Categories

## Geometric Primitives
Basic building blocks for positioning and sizing UI elements.

## Command System
Backend-independent rendering through recorded commands that can be replayed
by any graphics system.

## Layout Management
Automatic positioning system that handles widget placement, sizing, and flow
within containers.

## Resource Management
Pooling and caching systems for efficient reuse of UI resources.

# See Also

- [Core Concepts](concepts.md): How these structures work together
- [Performance Guide](performance.md): Memory layout and optimization details
- [Backend Integration](backends.md): Using command structures for rendering
"""

# ===== BASIC STRUCTURES =====
# Fundamental data types used throughout the system

"""
    Vec2

2D integer vector for positions, sizes, and offsets in UI coordinate space.

Vec2 is used extensively throughout MicroUI for representing 2D quantities
like screen positions, widget sizes, scroll offsets, and mouse coordinates.
It uses 64-bit integers to handle large screen coordinates and prevent overflow.

# Fields

- `x::Int64`: X coordinate, width, or horizontal offset
- `y::Int64`: Y coordinate, height, or vertical offset

# Design Rationale

## Why Int64?
- **Large screens**: 4K, 8K, and future displays need large coordinate ranges
- **Virtual coordinates**: UI may use coordinate systems larger than screen
- **Overflow safety**: Math operations won't overflow unexpectedly
- **Future-proofing**: Ready for ultra-high resolution displays

## Performance Characteristics
- **Memory**: 16 bytes per Vec2 (2 × 8 bytes)
- **Alignment**: Natural 8-byte alignment on 64-bit systems
- **Arithmetic**: Native 64-bit integer operations, very fast

# Usage Patterns

## Screen Coordinates
```julia
# Mouse position
mouse_pos = Vec2(1920, 1080)  # Bottom-right of Full HD

# Widget position
button_pos = Vec2(100, 50)    # 100 pixels right, 50 pixels down

# Large virtual coordinates
virtual_pos = Vec2(10000, 5000)  # Large drawing canvas
```

## Size and Dimensions
```julia
# Widget size
button_size = Vec2(120, 30)   # 120 pixels wide, 30 pixels tall

# Content area size  
content_size = Vec2(800, 600) # Available space for widgets

# Minimum size constraints
min_size = Vec2(50, 20)       # Minimum button dimensions
```

## Offsets and Deltas
```julia
# Mouse movement
mouse_delta = Vec2(5, -3)     # Moved 5 right, 3 up

# Scroll offset
scroll_offset = Vec2(0, -100) # Scrolled up 100 pixels

# Animation displacement
anim_offset = Vec2(10, 0)     # Moving 10 pixels right per frame
```

# Arithmetic Operations

Vec2 supports standard vector arithmetic:

```julia
# Vector addition
pos1 = Vec2(100, 200)
offset = Vec2(10, 20)
new_pos = pos1 + offset       # Vec2(110, 220)

# Vector subtraction  
delta = new_pos - pos1        # Vec2(10, 20)

# Scalar multiplication
scaled = pos1 * 2             # Vec2(200, 400)

# Component-wise operations
a = Vec2(10, 20)
b = Vec2(3, 4)
# Individual components: a.x + b.x, a.y + b.y
```

# Layout Calculations

Vec2 is essential for layout computations:

```julia
# Calculate widget center
widget_rect = Rect(100, 100, 80, 40)
center = Vec2(widget_rect.x + widget_rect.w ÷ 2, 
              widget_rect.y + widget_rect.h ÷ 2)  # Vec2(140, 120)

# Text positioning within widget
text_size = Vec2(60, 16)
text_pos = center - text_size ÷ 2  # Center text in widget

# Scroll position clamping
max_scroll = content_size - viewport_size
scroll_pos = Vec2(min(scroll_pos.x, max_scroll.x), 
                  min(scroll_pos.y, max_scroll.y))
```

# Container and Layout Integration

Vec2 works seamlessly with the layout system:

```julia
# Layout context uses Vec2 for positioning
mutable struct Layout
    position::Vec2     # Current layout cursor
    size::Vec2        # Default widget size
    max::Vec2         # Maximum extents reached
    # ... other fields
end

# Container content tracking
mutable struct Container  
    content_size::Vec2  # Total size of all content
    scroll::Vec2       # Current scroll position
    # ... other fields
end
```

# Input Handling

Vec2 represents all input coordinates:

```julia
# Mouse input events
function input_mousemove!(ctx::Context, x::Int, y::Int)
    ctx.mouse_pos = Vec2(Int64(x), Int64(y))
    ctx.mouse_delta = ctx.mouse_pos - ctx.last_mouse_pos
end

# Touch/gesture input (future)
struct TouchPoint
    pos::Vec2          # Touch position
    prev_pos::Vec2     # Previous position for gesture calculation
end
```

# Coordinate System Notes

MicroUI uses a standard computer graphics coordinate system:
- **Origin (0,0)**: Top-left corner of the screen/window
- **X-axis**: Increases rightward (positive = right)
- **Y-axis**: Increases downward (positive = down)

```julia
# Screen layout:
# (0,0) -----> +X
#   |
#   |  UI content area  
#   |
#   v
#  +Y

# Widget at bottom-right of 1920×1080 screen:
bottom_right = Vec2(1820, 1040)  # Accounting for widget size
```

# Memory Layout and Performance

Vec2 has optimal memory characteristics:

```julia
# Packed layout (no padding):
# [8 bytes: x][8 bytes: y] = 16 bytes total

# Array of Vec2 is cache-friendly:
positions = Vec2[Vec2(0, 0), Vec2(10, 20), Vec2(30, 40)]
# Sequential memory access pattern

# SIMD potential (with appropriate libraries):
# Multiple Vec2 operations can be vectorized
```

# Conversion and Compatibility

Vec2 integrates with Julia's numeric ecosystem:

```julia
# From tuples
pos = Vec2(tuple_pos...)      # If tuple_pos = (100, 200)

# To tuples for external APIs
external_api(pos.x, pos.y)   # Extract components

# Float conversion when needed
float_pos = Vec2(Int64(round(float_x)), Int64(round(float_y)))
```

# Debugging and Display

Vec2 has convenient string representation:

```julia
pos = Vec2(123, 456)
println("Position: \$pos")  # "Position: Vec2(123, 456)"

# Custom formatting for logging
function format_vec2(v::Vec2)
    return "(\$(v.x), \$(v.y))"
end
```

# See Also

- [`Rect`](@ref): Uses Vec2 for position and size
- [`Context`](@ref): Stores mouse position as Vec2
- [`Layout`](@ref): Uses Vec2 for positioning calculations
- [Coordinate Systems](coordinates.md): Detailed coordinate system documentation
"""
struct Vec2
    x::Int64  # X coordinate/width
    y::Int64  # Y coordinate/height
end

"""
    Rect

Rectangle defined by position and size, forming the basis for all layout and clipping operations.

Rect represents rectangular areas in 2D space and is the fundamental building block
for UI layout, widget positioning, clipping regions, and hit testing. It uses
32-bit integers for efficient memory usage while supporting reasonable coordinate ranges.

# Fields

- `x::Int32`: Left edge position (screen coordinates)
- `y::Int32`: Top edge position (screen coordinates)  
- `w::Int32`: Width in pixels (must be ≥ 0)
- `h::Int32`: Height in pixels (must be ≥ 0)

# Design Rationale

## Why Int32 for Rectangles vs Int64 for Vec2?
- **Coordinate range**: ±2.1 billion pixels covers any realistic screen size
- **Memory efficiency**: 16 bytes vs 32 bytes per rectangle (50% savings)
- **Cache performance**: More rectangles fit in cache lines
- **GPU compatibility**: Most graphics APIs use 32-bit coordinates

## Rectangle Convention
```julia
# Standard computer graphics convention:
# (x,y) = top-left corner
# w,h = positive width and height extending right and down

#   (x,y)
#     ┌─────────┐ ← y
#     │         │
#     │  Rect   │ h
#     │         │
#     └─────────┘
#     ←   w   →
#         ↑
#        x+w,y+h (bottom-right, exclusive)
```

# Construction and Usage

## Basic Rectangle Creation
```julia
# Widget rectangle: position (100,50), size 200×30
widget_rect = Rect(100, 50, 200, 30)

# Full screen rectangle (1920×1080)
screen_rect = Rect(0, 0, 1920, 1080)

# Empty rectangle (useful for initialization)
empty_rect = Rect(0, 0, 0, 0)

# Square (equal width and height)
square = Rect(10, 10, 50, 50)
```

## Coordinate Calculations
```julia
rect = Rect(100, 50, 200, 30)

# Edge coordinates
left = rect.x           # 100
top = rect.y            # 50  
right = rect.x + rect.w # 300 (exclusive)
bottom = rect.y + rect.h # 80 (exclusive)

# Center point
center_x = rect.x + rect.w ÷ 2  # 200
center_y = rect.y + rect.h ÷ 2  # 65

# Corner points
top_left = (rect.x, rect.y)                    # (100, 50)
top_right = (rect.x + rect.w, rect.y)          # (300, 50)
bottom_left = (rect.x, rect.y + rect.h)       # (100, 80)
bottom_right = (rect.x + rect.w, rect.y + rect.h) # (300, 80)
```

# Widget Layout and Positioning

Rect is central to widget positioning:

```julia
# Window with title bar
window_rect = Rect(100, 100, 400, 300)
title_rect = Rect(window_rect.x, window_rect.y, window_rect.w, 24)
content_rect = Rect(window_rect.x, window_rect.y + 24, 
                   window_rect.w, window_rect.h - 24)

# Button layout within content area
button_width, button_height = 100, 30
button_rect = Rect(content_rect.x + 10,          # 10px from left
                  content_rect.y + 10,          # 10px from top
                  button_width, button_height)

# Grid layout (3×2 grid of buttons)
for row in 0:1, col in 0:2
    btn_x = content_rect.x + col * (button_width + 5)
    btn_y = content_rect.y + row * (button_height + 5)
    grid_button = Rect(btn_x, btn_y, button_width, button_height)
    # ... create button at grid_button position
end
```

# Clipping and Intersection

Rect is used extensively for clipping calculations:

```julia
# Clip region intersection
window_clip = Rect(0, 0, 800, 600)      # Window bounds
widget_area = Rect(700, 500, 200, 200)  # Widget extends beyond window

# Calculate visible area
visible_area = intersect_rects(window_clip, widget_area)
# Result: Rect(700, 500, 100, 100) - only the visible portion

# Check if rectangle is completely outside clip region
if visible_area.w <= 0 || visible_area.h <= 0
    # Rectangle is completely clipped - skip rendering
    return
end
```

# Hit Testing and Mouse Interaction

Rect enables efficient hit testing:

```julia
# Point-in-rectangle test
function point_in_rect(rect::Rect, point::Vec2)
    return point.x >= rect.x && 
           point.x < rect.x + rect.w &&
           point.y >= rect.y && 
           point.y < rect.y + rect.h
end

# Mouse interaction
mouse_pos = Vec2(150, 75)
button_rect = Rect(100, 50, 100, 50)

if point_in_rect(button_rect, mouse_pos)
    # Mouse is over button - handle hover state
    handle_button_hover()
end

# Rectangle overlap test (for widget collision detection)
function rects_overlap(a::Rect, b::Rect)
    return !(a.x >= b.x + b.w || b.x >= a.x + a.w ||
             a.y >= b.y + b.h || b.y >= a.y + a.h)
end
```

# Layout System Integration

Rect works with the layout system for automatic positioning:

```julia
# Layout calculates next widget rectangle
function layout_next(ctx::Context)
    layout = get_layout(ctx)
    
    # Calculate position and size
    x = layout.position.x
    y = layout.position.y  
    w = layout.size.x
    h = layout.size.y
    
    # Create widget rectangle
    widget_rect = Rect(x, y, w, h)
    
    # Update layout for next widget
    layout.position = Vec2(x + w + spacing, y)
    
    return widget_rect
end
```

# Container and Scrolling

Rect handles container areas and scrolling:

```julia
# Container with scrollable content
container_rect = Rect(0, 0, 300, 200)    # Visible area
content_size = Vec2(500, 400)            # Total content size
scroll_offset = Vec2(50, 30)             # Current scroll position

# Calculate content rectangle in screen space
content_rect = Rect(container_rect.x - scroll_offset.x,
                   container_rect.y - scroll_offset.y,
                   content_size.x, content_size.y)

# Widgets positioned relative to content rectangle
widget_in_content = Rect(content_rect.x + 100, content_rect.y + 150, 80, 25)
```

# Command System Integration

Rect appears in rendering commands:

```julia
# Rectangle drawing command
struct RectCommand
    base::BaseCommand
    rect::Rect        # Rectangle to draw
    color::Color      # Fill color
end

# Icon drawing command  
struct IconCommand
    base::BaseCommand
    rect::Rect        # Rectangle to draw icon within
    id::IconId        # Which icon to draw
    color::Color      # Icon color
end
```

# Performance Characteristics

Rect is optimized for performance:

```julia
# Memory layout: 16 bytes total
# [4 bytes: x][4 bytes: y][4 bytes: w][4 bytes: h]

# No padding on 64-bit systems (natural alignment)
# Array of Rect has excellent cache locality

# Arithmetic operations are fast (32-bit integer math)
intersection_test = rect1.x < rect2.x + rect2.w  # Single comparison
```

# Rectangle Utilities

Common rectangle operations:

```julia
# Expand rectangle (add border/padding)
function expand_rect(r::Rect, n::Int32)
    return Rect(r.x - n, r.y - n, r.w + n * 2, r.h + n * 2)
end

# Contract rectangle (remove border/padding)  
function contract_rect(r::Rect, n::Int32)
    return Rect(r.x + n, r.y + n, 
               max(0, r.w - n * 2), max(0, r.h - n * 2))
end

# Rectangle union (bounding box)
function union_rects(a::Rect, b::Rect)
    left = min(a.x, b.x)
    top = min(a.y, b.y) 
    right = max(a.x + a.w, b.x + b.w)
    bottom = max(a.y + a.h, b.y + b.h)
    return Rect(left, top, right - left, bottom - top)
end
```

# Validation and Debugging

Rectangle validation and debugging aids:

```julia
# Validate rectangle (non-negative dimensions)
function is_valid_rect(r::Rect)
    return r.w >= 0 && r.h >= 0
end

# Calculate rectangle area
function rect_area(r::Rect)
    return r.w * r.h
end

# Rectangle to string for debugging
function rect_string(r::Rect)
    return "Rect(\$(r.x), \$(r.y), \$(r.w), \$(r.h))"
end

# Check if rectangle is empty
function is_empty_rect(r::Rect)
    return r.w == 0 || r.h == 0
end
```

# See Also

- [`Vec2`](@ref): 2D vector type used with rectangles
- [`intersect_rects`](@ref): Rectangle intersection calculation
- [`expand_rect`](@ref): Rectangle expansion utility
- [`Layout`](@ref): Uses Rect for widget positioning
- [`ClipCommand`](@ref): Uses Rect for clipping regions
- [Layout Guide](layout.md): Rectangle usage in layout system
"""
struct Rect
    x::Int32  # Left edge position
    y::Int32  # Top edge position
    w::Int32  # Width
    h::Int32  # Height
end

"""
    Color

RGBA color representation with 8 bits per channel for UI rendering.

Color represents all color information in MicroUI using the standard RGBA format
with 8-bit components. This provides 16.7 million colors with transparency support
while maintaining compact memory usage and fast operations.

# Fields

- `r::UInt8`: Red component (0-255, where 0=none, 255=full intensity)
- `g::UInt8`: Green component (0-255, where 0=none, 255=full intensity)  
- `b::UInt8`: Blue component (0-255, where 0=none, 255=full intensity)
- `a::UInt8`: Alpha component (0-255, where 0=transparent, 255=opaque)

# Design Rationale

## Why 8-bit Components?
- **Standard format**: Compatible with most graphics APIs and image formats
- **Memory efficient**: 4 bytes per color vs 16 bytes for float RGBA
- **Perceptual adequacy**: 8 bits provides sufficient color gradations for UI
- **Hardware optimized**: GPUs and displays natively support 8-bit color

## Alpha Channel Usage
- **0 (transparent)**: Completely see-through, useful for invisible elements
- **128 (semi-transparent)**: 50% opacity for overlays and disabled states
- **255 (opaque)**: Fully solid, standard for most UI elements

# Color Construction

## Basic Colors
```julia
# Primary colors
red = Color(255, 0, 0, 255)      # Pure red
green = Color(0, 255, 0, 255)    # Pure green  
blue = Color(0, 0, 255, 255)     # Pure blue

# Grayscale
black = Color(0, 0, 0, 255)      # Pure black
white = Color(255, 255, 255, 255) # Pure white
gray = Color(128, 128, 128, 255)  # 50% gray

# Transparent
transparent = Color(0, 0, 0, 0)   # Fully transparent
semi_transparent = Color(255, 255, 255, 128)  # 50% white
```

## UI Color Palette
```julia
# Typical UI colors
text_color = Color(230, 230, 230, 255)      # Light gray text
background = Color(50, 50, 50, 255)         # Dark background
button_normal = Color(75, 75, 75, 255)      # Button base color
button_hover = Color(95, 95, 95, 255)       # Hover state (lighter)
button_pressed = Color(115, 115, 115, 255)  # Pressed state (even lighter)

# Accent colors
accent_blue = Color(64, 128, 255, 255)      # Bright blue accent
success_green = Color(64, 192, 64, 255)     # Success/OK color
warning_orange = Color(255, 128, 64, 255)   # Warning color
error_red = Color(255, 64, 64, 255)         # Error/danger color
```

# Color Usage in MicroUI

## Style System Integration
```julia
# Colors are stored in style arrays
style = DEFAULT_STYLE
text_color = style.colors[Int(COLOR_TEXT)]        # Get text color
border_color = style.colors[Int(COLOR_BORDER)]    # Get border color

# Drawing with style colors
draw_rect!(ctx, widget_rect, style.colors[Int(COLOR_BUTTON)])
draw_text!(ctx, font, "Hello", pos, style.colors[Int(COLOR_TEXT)])
```

## Rendering Commands
```julia
# Colors appear in various rendering commands
rect_cmd = RectCommand(
    BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
    Rect(10, 10, 100, 50),
    Color(128, 64, 192, 255)  # Purple rectangle
)

text_cmd = TextCommand(
    BaseCommand(COMMAND_TEXT, sizeof(TextCommand)),
    font, Vec2(20, 30), 
    Color(255, 255, 255, 255),  # White text
    str_index, str_length
)
```

## Dynamic Color Generation
```julia
# Interpolate between colors for smooth transitions
function lerp_color(a::Color, b::Color, t::Float64)
    t = clamp(t, 0.0, 1.0)
    return Color(
        UInt8(round(a.r + t * (b.r - a.r))),
        UInt8(round(a.g + t * (b.g - a.g))),
        UInt8(round(a.b + t * (b.b - a.b))),
        UInt8(round(a.a + t * (b.a - a.a)))
    )
end

# Fade animation
start_color = Color(255, 0, 0, 255)    # Red
end_color = Color(0, 255, 0, 255)      # Green
fade_progress = 0.3                    # 30% of the way
current_color = lerp_color(start_color, end_color, fade_progress)
```

# Color Manipulation

## Brightness and Contrast
```julia
# Darken color (multiply by factor < 1.0)
function darken_color(color::Color, factor::Float64)
    factor = clamp(factor, 0.0, 1.0)
    return Color(
        UInt8(round(color.r * factor)),
        UInt8(round(color.g * factor)),
        UInt8(round(color.b * factor)),
        color.a  # Preserve alpha
    )
end

# Lighten color (interpolate toward white)
function lighten_color(color::Color, factor::Float64)
    white = Color(255, 255, 255, color.a)
    return lerp_color(color, white, factor)
end

# Adjust alpha transparency
function set_alpha(color::Color, alpha::UInt8)
    return Color(color.r, color.g, color.b, alpha)
end
```

## Color Analysis
```julia
# Calculate luminance (perceived brightness)
function luminance(color::Color)
    # Standard RGB to luminance conversion
    r = color.r / 255.0
    g = color.g / 255.0  
    b = color.b / 255.0
    return 0.299 * r + 0.587 * g + 0.114 * b
end

# Check if color is "dark" (for contrast decisions)
function is_dark_color(color::Color)
    return luminance(color) < 0.5
end

# Calculate contrast ratio (for accessibility)
function contrast_ratio(color1::Color, color2::Color)
    l1 = luminance(color1) + 0.05
    l2 = luminance(color2) + 0.05
    return max(l1, l2) / min(l1, l2)
end
```

# Theme and Palette Creation

## Creating Cohesive Color Schemes
```julia
# Generate button state colors from base color
function generate_button_colors(base::Color)
    normal = base
    hover = lighten_color(base, 0.2)      # 20% lighter
    pressed = lighten_color(base, 0.4)    # 40% lighter
    disabled = set_alpha(darken_color(base, 0.5), 128)  # Darker + transparent
    
    return (normal, hover, pressed, disabled)
end

# Create complementary color scheme
function create_color_scheme(primary::Color)
    # Generate related colors
    secondary = Color(255 - primary.r, 255 - primary.g, 255 - primary.b, primary.a)
    accent = Color(primary.b, primary.r, primary.g, primary.a)  # Rotate components
    
    return (primary, secondary, accent)
end
```

## Accessibility Considerations
```julia
# Ensure sufficient contrast for readability
function ensure_contrast(text_color::Color, bg_color::Color, min_ratio::Float64 = 4.5)
    ratio = contrast_ratio(text_color, bg_color)
    if ratio < min_ratio
        # Adjust text color for better contrast
        if is_dark_color(bg_color)
            return Color(255, 255, 255, text_color.a)  # Use white text
        else
            return Color(0, 0, 0, text_color.a)        # Use black text
        end
    end
    return text_color
end
```

# Performance Characteristics

Color is highly optimized for performance:

```julia
# Memory layout: 4 bytes total (very compact)
# [1 byte: r][1 byte: g][1 byte: b][1 byte: a]

# Can be loaded as single 32-bit integer for fast operations
color_as_uint32 = unsafe_load(Ptr{UInt32}(pointer_from_objref(color)))

# Array of colors is extremely cache-friendly
palette = Color[Color(255,0,0,255), Color(0,255,0,255), Color(0,0,255,255)]
```

# Backend Integration

Color converts easily to different graphics APIs:

```julia
# OpenGL (normalized floats)
function color_to_opengl(color::Color)
    return (color.r/255.0, color.g/255.0, color.b/255.0, color.a/255.0)
end

# DirectX/Vulkan (packed RGBA)
function color_to_packed_rgba(color::Color)
    return UInt32(color.r) | (UInt32(color.g) << 8) | 
           (UInt32(color.b) << 16) | (UInt32(color.a) << 24)
end

# Web/CSS
function color_to_css(color::Color)
    if color.a == 255
        return "rgb(\$(color.r), \$(color.g), \$(color.b))"
    else
        alpha = color.a / 255.0
        return "rgba(\$(color.r), \$(color.g), \$(color.b), \$alpha)"
    end
end
```

# Color Constants and Presets

Common color constants for convenience:

```julia
# Standard colors
const COLOR_TRANSPARENT = Color(0, 0, 0, 0)
const COLOR_BLACK = Color(0, 0, 0, 255)
const COLOR_WHITE = Color(255, 255, 255, 255)
const COLOR_RED = Color(255, 0, 0, 255)
const COLOR_GREEN = Color(0, 255, 0, 255)
const COLOR_BLUE = Color(0, 0, 255, 255)

# UI-specific colors
const COLOR_DISABLED = Color(128, 128, 128, 128)  # Semi-transparent gray
const COLOR_HIGHLIGHT = Color(255, 255, 0, 64)    # Translucent yellow
const COLOR_SELECTION = Color(64, 128, 255, 128)  # Semi-transparent blue
```

# Debugging and Visualization

Color debugging utilities:

```julia
# Convert color to hex string
function color_to_hex(color::Color)
    return "#\$(string(color.r, base=16, pad=2))\$(string(color.g, base=16, pad=2))\$(string(color.b, base=16, pad=2))"
end

# Parse hex color string
function hex_to_color(hex::String)
    hex = replace(hex, "#" => "")
    @assert length(hex) == 6 "Invalid hex color format"
    
    r = parse(UInt8, hex[1:2], base=16)
    g = parse(UInt8, hex[3:4], base=16)
    b = parse(UInt8, hex[5:6], base=16)
    return Color(r, g, b, 255)
end

# Color information for debugging
function describe_color(color::Color)
    hex = color_to_hex(color)
    lum = round(luminance(color), digits=3)
    return "Color(r=\$(color.r), g=\$(color.g), b=\$(color.b), a=\$(color.a)) [\$hex, luminance=\$lum]"
end
```

# See Also

- [`ColorId`](@ref): Predefined color indices for UI elements
- [`Style`](@ref): Contains color palette for UI theming
- [`DEFAULT_STYLE`](@ref): Default color scheme
- [`RectCommand`](@ref), [`TextCommand`](@ref): Commands that use Color
- [Theming Guide](theming.md): Creating custom color schemes
- [Accessibility Guide](accessibility.md): Color contrast and accessibility
"""
struct Color
    r::UInt8  # Red component (0-255)
    g::UInt8  # Green component (0-255)
    b::UInt8  # Blue component (0-255)
    a::UInt8  # Alpha component (0-255, 255=opaque)
end

"""
    PoolItem

Resource pool item for efficient management of reusable UI objects.

PoolItem is used in resource pooling systems throughout MicroUI to track
when objects were last used. This enables automatic cleanup of unused
resources and efficient reuse of expensive-to-create objects like containers.

# Fields

- `id::Id`: Unique identifier of the pooled item (0 = unused slot)
- `last_update::Int32`: Frame number when item was last accessed

# Design Rationale

## Resource Pooling Benefits
- **Avoid allocations**: Reuse existing objects instead of creating new ones
- **Predictable performance**: No garbage collection spikes from frequent allocation/deallocation
- **Memory locality**: Pool objects are stored contiguously for better cache performance
- **Automatic cleanup**: Unused items are detected and reclaimed automatically

## LRU (Least Recently Used) Strategy
The pooling system uses frame numbers to implement LRU replacement:
- Active items have `last_update` = current frame
- Inactive items have older `last_update` values
- When pool is full, the oldest item is replaced

# Usage in Container Pool

Container pooling is the primary use case:

```julia
# Container pool stores PoolItem metadata
container_pool::Vector{PoolItem}  # Metadata for each pool slot
containers::Vector{Container}     # Actual container objects

# Getting a container from the pool
function get_container(ctx::Context, id::Id)
    # Try to find existing container
    idx = pool_get(ctx, ctx.container_pool, CONTAINERPOOL_SIZE, id)
    if idx >= 0
        # Found existing container - update access time
        pool_update!(ctx, ctx.container_pool, idx)
        return ctx.containers[idx]
    end
    
    # Need new container - find LRU slot
    idx = pool_init!(ctx, ctx.container_pool, CONTAINERPOOL_SIZE, id)
    container = ctx.containers[idx]
    # ... initialize container ...
    return container
end
```

# Pool Management Operations

## Finding Pool Items
```julia
function pool_get(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id)
    for i in 1:len
        if items[i].id == id
            return i  # Found matching item
        end
    end
    return -1  # Not found
end
```

## Initializing New Pool Items
```julia
function pool_init!(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id)
    # Find least recently used slot
    oldest_frame = ctx.frame
    oldest_idx = -1
    
    for i in 1:len
        if items[i].last_update < oldest_frame
            oldest_frame = items[i].last_update
            oldest_idx = i
        end
    end
    
    @assert oldest_idx > 0 "Pool exhausted"
    
    # Initialize the slot
    items[oldest_idx].id = id
    items[oldest_idx].last_update = ctx.frame
    
    return oldest_idx
end
```

## Updating Access Time
```julia
function pool_update!(ctx::Context, items::Vector{PoolItem}, idx::Int)
    items[idx].last_update = ctx.frame
end
```

# Treenode Pool Usage

Treenodes also use pooling for state persistence:

```julia
# Treenode expansion state persistence
treenode_pool::Vector{PoolItem}

function get_treenode_state(ctx::Context, id::Id)
    idx = pool_get(ctx, ctx.treenode_pool, TREENODEPOOL_SIZE, id)
    if idx >= 0
        # Treenode state exists - it was expanded before
        pool_update!(ctx, ctx.treenode_pool, idx)
        return true  # Expanded
    else
        return false  # Collapsed (default state)
    end
end

function set_treenode_expanded(ctx::Context, id::Id)
    idx = pool_get(ctx, ctx.treenode_pool, TREENODEPOOL_SIZE, id)
    if idx < 0
        # Create new pool entry for expanded state
        pool_init!(ctx, ctx.treenode_pool, TREENODEPOOL_SIZE, id)
    else
        # Update existing entry
        pool_update!(ctx, ctx.treenode_pool, idx)
    end
end
```

# Pool Lifecycle

Understanding the pool lifecycle:

```julia
# Frame 1: Create window "Settings"
begin_window(ctx, "Settings", rect)  
# → pool_init! creates PoolItem{id=hash("Settings"), last_update=1}

# Frame 2: Same window
begin_window(ctx, "Settings", rect)  
# → pool_get finds existing item, pool_update! sets last_update=2

# Frame 3: Window not created
# → PoolItem still exists but last_update remains 2

# Frame 100: Different window needs pool slot
begin_window(ctx, "NewWindow", rect)
# → pool_init! finds PoolItem with oldest last_update (2), replaces it
# → New PoolItem{id=hash("NewWindow"), last_update=100}
```

# Memory Management

PoolItem provides efficient memory usage:

```julia
# Minimal memory overhead per pool slot
# 4 bytes (Id) + 4 bytes (Int32) = 8 bytes per PoolItem

# Typical pool sizes:
# Container pool: 48 × 8 bytes = 384 bytes
# Treenode pool: 48 × 8 bytes = 384 bytes
# Total pooling overhead: < 1 KB

# Compare to dynamic allocation:
# Creating/destroying containers each frame would be much more expensive
```

# Pool Debugging

Debugging pool usage:

```julia
function debug_pool_usage(pool::Vector{PoolItem}, name::String, current_frame::Int32)
    active_count = 0
    old_count = 0
    
    for item in pool
        if item.id != 0
            age = current_frame - item.last_update
            if age == 0
                active_count += 1
            else
                old_count += 1
            end
        end
    end
    
    total_slots = length(pool)
    free_slots = total_slots - active_count - old_count
    
    println("\$name Pool Status:")
    println("  Active: \$active_count")
    println("  Old: \$old_count") 
    println("  Free: \$free_slots")
    println("  Total: \$total_slots")
end

# Usage
debug_pool_usage(ctx.container_pool, "Container", ctx.frame)
```

# Pool Exhaustion Handling

When pools are exhausted:

```julia
function safe_pool_init!(ctx::Context, items::Vector{PoolItem}, len::Int, id::Id)
    try
        return pool_init!(ctx, items, len, id)
    catch e
        if occursin("Pool exhausted", string(e))
            @warn "Pool exhausted - consider increasing pool size"
            # Could implement emergency cleanup or pool expansion here
            return -1  # Indicate failure
        else
            rethrow(e)
        end
    end
end
```

# Performance Characteristics

PoolItem enables high performance resource management:

- **Pool lookup**: O(n) linear search, but n is small (typically ≤ 48)
- **Access update**: O(1) direct array access
- **Memory overhead**: 8 bytes per pool slot
- **Cache efficiency**: Pool arrays are contiguous and frequently accessed
- **No allocations**: Eliminates malloc/free during normal operation

# Integration with Context

PoolItem integrates seamlessly with the main context:

```julia
mutable struct Context
    # Resource pools using PoolItem
    container_pool::Vector{PoolItem}
    containers::Vector{Container}
    treenode_pool::Vector{PoolItem}
    
    # Current frame for LRU tracking
    frame::Int32
    
    # ... other fields
end
```

# See Also

- [`Container`](@ref): Primary user of container pooling
- [`Context`](@ref): Contains pool arrays and frame counter
- [`get_container`](@ref): Function that uses container pooling
- [`begin_treenode`](@ref): Function that uses treenode pooling
- [Performance Guide](performance.md): Resource pooling strategies
"""
mutable struct PoolItem
    id::Id           # Unique identifier of the pooled item
    last_update::Int32  # Frame number when item was last accessed
end

# ===== COMMAND SYSTEM =====
# The command system allows backend-independent rendering by recording
# all drawing operations as commands that can be replayed later

"""
    BaseCommand

Common header structure present in all command types for efficient buffer traversal.

BaseCommand provides the essential metadata that every command in the command buffer
must have. It enables the command system to traverse the buffer, identify command
types, and handle commands generically without knowing their specific structure.

# Fields

- `type::CommandType`: Identifies which specific command type this is
- `size::Int32`: Total size of this command in bytes (including the BaseCommand header)

# Design Rationale

## Uniform Command Processing
All commands share the same header format, enabling generic processing:

```julia
# Read any command's header first
base = read_command(cmdlist, offset, BaseCommand)

# Use header to determine how to process the command
if base.type == COMMAND_RECT
    rect_cmd = read_command(cmdlist, offset, RectCommand)
    process_rectangle(rect_cmd)
elseif base.type == COMMAND_TEXT
    text_cmd = read_command(cmdlist, offset, TextCommand)  
    process_text(text_cmd)
end

# Use size to advance to next command
next_offset = offset + base.size
```

## Memory Layout Efficiency
BaseCommand provides consistent memory layout across all command types:

```julia
# All commands start with the same 8-byte header:
# [4 bytes: CommandType][4 bytes: Int32 size]

# Followed by command-specific data:
struct RectCommand
    base::BaseCommand     # Always first (8 bytes)
    rect::Rect           # Command-specific data (16 bytes)
    color::Color         # Command-specific data (4 bytes)
end
# Total: 28 bytes, with base at offset 0
```

# Command Buffer Traversal

BaseCommand enables efficient iteration through the command buffer:

```julia
function iterate_commands(cmdlist::CommandList)
    offset = 0
    while offset < cmdlist.idx
        # Read command header
        base = read_command(cmdlist, offset, BaseCommand)
        
        # Process command based on type
        process_command_by_type(base.type, offset, cmdlist)
        
        # Move to next command using size
        offset += base.size
    end
end
```

# Command Construction

All commands are constructed with a proper BaseCommand header:

```julia
# Creating a rectangle command
rect_cmd = RectCommand(
    BaseCommand(COMMAND_RECT, sizeof(RectCommand)),  # Header with type and size
    Rect(10, 20, 100, 50),                          # Command data
    Color(255, 128, 64, 255)                        # Command data
)

# Creating a text command
text_cmd = TextCommand(
    BaseCommand(COMMAND_TEXT, sizeof(TextCommand)),  # Header
    font, Vec2(30, 40), Color(255, 255, 255, 255), # Command data
    str_index, str_length                           # Command data
)
```

# Size Calculation and Validation

The size field enables validation and bounds checking:

```julia
function validate_command_size(cmdlist::CommandList, offset::Int)
    if offset + sizeof(BaseCommand) > cmdlist.idx
        error("Command header extends beyond buffer")
    end
    
    base = read_command(cmdlist, offset, BaseCommand)
    
    if offset + base.size > cmdlist.idx
        error("Command (type=\$(base.type), size=\$(base.size)) extends beyond buffer")
    end
    
    # Validate size matches expected size for command type
    expected_size = expected_command_size(base.type)
    if base.size != expected_size
        error("Command size mismatch: expected \$expected_size, got \$(base.size)")
    end
end

function expected_command_size(cmd_type::CommandType)
    if cmd_type == COMMAND_RECT
        return sizeof(RectCommand)
    elseif cmd_type == COMMAND_TEXT
        return sizeof(TextCommand)
    elseif cmd_type == COMMAND_ICON
        return sizeof(IconCommand)
    elseif cmd_type == COMMAND_JUMP
        return sizeof(JumpCommand)
    elseif cmd_type == COMMAND_CLIP
        return sizeof(ClipCommand)
    else
        error("Unknown command type: \$cmd_type")
    end
end
```

# Performance Characteristics

BaseCommand is designed for optimal performance:

- **Minimal overhead**: Only 8 bytes per command
- **Aligned access**: Natural alignment for fast memory access
- **Sequential traversal**: Enables cache-friendly command processing
- **Branch prediction**: Command type checks are highly predictable

# Command Buffer Packing

BaseCommand enables tight packing of commands in the buffer:

```julia
# Commands are packed with no padding:
# Buffer layout:
# [BaseCommand + RectCommand data][BaseCommand + TextCommand data][...]
#  ← 28 bytes total →              ← variable size →

# No alignment gaps between commands
# Maximum memory utilization
# Sequential access pattern for optimal cache performance
```

# Jump Command Integration

BaseCommand works seamlessly with jump commands for Z-ordering:

```julia
# Jump commands use BaseCommand for consistency
struct JumpCommand
    base::BaseCommand  # type=COMMAND_JUMP, size=sizeof(JumpCommand)
    dst::CommandPtr   # Jump destination
end

# Command iterator handles jumps automatically
function next_command!(iter::CommandIterator)
    base = read_command(iter.cmdlist, iter.current, BaseCommand)
    
    if base.type == COMMAND_JUMP
        # Follow jump instead of returning jump command
        jump_cmd = read_command(iter.cmdlist, iter.current, JumpCommand)
        iter.current = jump_cmd.dst
        return next_command!(iter)  # Recursive call
    else
        # Return normal command
        old_current = iter.current
        iter.current += base.size
        return (true, base.type, old_current)
    end
end
```

# Error Handling and Recovery

BaseCommand enables robust error handling:

```julia
function safe_command_iteration(cmdlist::CommandList)
    offset = 0
    commands_processed = 0
    
    while offset < cmdlist.idx
        try
            # Validate header can be read
            if offset + sizeof(BaseCommand) > cmdlist.idx
                @warn "Incomplete command header at offset \$offset"
                break
            end
            
            base = read_command(cmdlist, offset, BaseCommand)
            
            # Validate size is reasonable
            if base.size < sizeof(BaseCommand) || base.size > cmdlist.idx - offset
                @warn "Invalid command size \$(base.size) at offset \$offset"
                break
            end
            
            # Process command
            process_command_safely(base.type, offset, cmdlist)
            commands_processed += 1
            
            # Advance to next command
            offset += base.size
            
        catch e
            @warn "Error processing command at offset \$offset: \$e"
            # Try to recover by advancing past this command
            offset += sizeof(BaseCommand)
        end
    end
    
    return commands_processed
end
```

# Debug and Profiling Support

BaseCommand enables comprehensive debugging tools:

```julia
function debug_command_buffer(cmdlist::CommandList)
    println("Command Buffer Analysis:")
    println("  Total size: \$(cmdlist.idx) bytes")
    
    offset = 0
    command_count = 0
    type_counts = Dict{CommandType, Int}()
    
    while offset < cmdlist.idx
        base = read_command(cmdlist, offset, BaseCommand)
        command_count += 1
        type_counts[base.type] = get(type_counts, base.type, 0) + 1
        
        println("  \$command_count: type=\$(base.type), size=\$(base.size), offset=\$offset")
        offset += base.size
    end
    
    println("Command Type Summary:")
    for (cmd_type, count) in type_counts
        println("  \$cmd_type: \$count commands")
    end
end
```

# See Also

- [`CommandType`](@ref): Enumeration used in the type field
- [`RectCommand`](@ref), [`TextCommand`](@ref): Commands that include BaseCommand
- [`CommandList`](@ref): Buffer that stores commands with BaseCommand headers
- [`CommandIterator`](@ref): Uses BaseCommand for traversal
- [`read_command`](@ref): Function for reading commands from buffer
"""
struct BaseCommand
    type::CommandType  # What type of command this is
    size::Int32       # Size of this command in bytes
end

"""
    JumpCommand

Command for non-linear traversal of the command buffer, enabling proper Z-order rendering.

JumpCommand allows the command buffer to be traversed in non-sequential order,
which is essential for implementing container Z-ordering where higher Z-index
containers must be rendered after (on top of) lower Z-index containers.

# Fields

- `base::BaseCommand`: Common command header (type=COMMAND_JUMP, size=sizeof(JumpCommand))
- `dst::CommandPtr`: Destination byte offset in the command buffer to jump to

# Design Rationale

## Z-Order Rendering Problem
Without jumps, commands are processed in the order they were generated:

```julia
# Problem: Commands generated in Z-index order
Window A (z=1): [RECT][TEXT]
Window B (z=5): [RECT][ICON]  
Window C (z=3): [RECT][TEXT]

# Buffer order: [A commands][B commands][C commands]
# Rendering order: A → B → C (incorrect! B should be on top)
```

## Jump Solution
Jump commands enable reordering for correct rendering:

```julia
# Solution: Commands linked with jumps for proper Z-order
Buffer layout after sorting by Z-index:
[A commands][JUMP to C][C commands][JUMP to B][B commands][JUMP to end]

# Rendering order: A → C → B (correct! Higher Z-index on top)
```

# Z-Order Implementation

The jump system implements proper Z-ordering through a linked list structure:

```julia
# Container Z-index sorting in end_frame
containers = [container_a, container_c, container_b]  # Sorted by Z-index
sort!(containers, by = c -> c.zindex)  # [A(z=1), C(z=3), B(z=5)]

# Create jump chain
for i in 1:length(containers)
    if i < length(containers)
        # Link current container to next container
        current = containers[i]
        next = containers[i+1]
        
        # Update tail jump of current container
        jump_cmd = JumpCommand(
            BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
            next.head + sizeof(JumpCommand)  # Skip next container's head jump
        )
        write_jump_at_offset(cmdlist, current.tail, jump_cmd)
    else
        # Last container jumps to end of buffer
        last = containers[i]
        jump_cmd = JumpCommand(
            BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
            cmdlist.idx  # End of buffer
        )
        write_jump_at_offset(cmdlist, last.tail, jump_cmd)
    end
end
```

# Container Command Regions

Each container has head and tail jump commands that define its command region:

```julia
mutable struct Container
    head::CommandPtr  # Points to head jump command
    tail::CommandPtr  # Points to tail jump command
    # ... other fields
end

# Container command structure:
# [HEAD JUMP][container's actual commands...][TAIL JUMP]
#      ↑                                            ↑
#    head                                         tail
#   points here                               points here

# Head jump: skips to first actual command (head + sizeof(JumpCommand))
# Tail jump: initially points nowhere, updated during Z-order sorting
```

# Command Buffer Traversal with Jumps

The CommandIterator automatically follows jumps:

```julia
function next_command!(iter::CommandIterator)
    while iter.current < iter.cmdlist.idx
        base = read_command(iter.cmdlist, iter.current, BaseCommand)
        
        if base.type == COMMAND_JUMP
            # Follow jump transparently
            jump_cmd = read_command(iter.cmdlist, iter.current, JumpCommand)
            iter.current = jump_cmd.dst
            # Continue loop to get next real command
        else
            # Return actual rendering command
            old_current = iter.current
            iter.current += base.size
            return (true, base.type, old_current)
        end
    end
    return (false, COMMAND_JUMP, CommandPtr(0))  # End of buffer
end
```

# Jump Command Creation

Jump commands are created during container setup and Z-order sorting:

```julia
# Create placeholder jump during container initialization
function begin_root_container!(ctx::Context, cnt::Container)
    # Create head jump (initially points to next position)
    cnt.head = push_jump_command!(ctx, ctx.command_list.idx + sizeof(JumpCommand))
    
    # Container commands go here...
    
    # Create tail jump (initially points nowhere, updated later)
    cnt.tail = push_jump_command!(ctx, CommandPtr(0))
end

# Helper function to create jump commands
function push_jump_command!(ctx::Context, dst::CommandPtr)
    jump_cmd = JumpCommand(
        BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
        dst
    )
    return write_command!(ctx.command_list, jump_cmd)
end
```

# Jump Destination Validation

Jump destinations must be validated to prevent buffer corruption:

```julia
function validate_jump_command(cmdlist::CommandList, jump_cmd::JumpCommand)
    dst = jump_cmd.dst
    
    # Check bounds
    if dst < 0 || dst > cmdlist.idx
        error("Jump destination \$dst outside buffer bounds [0, \$(cmdlist.idx)]")
    end
    
    # Check destination points to valid command
    if dst < cmdlist.idx
        try
            target_base = read_command(cmdlist, dst, BaseCommand)
            # Destination should point to a valid command header
        catch e
            error("Jump destination \$dst does not point to valid command: \$e")
        end
    end
end
```

# Jump Performance Characteristics

Jump commands are designed for minimal performance impact:

- **Size**: 12 bytes total (8 bytes BaseCommand + 4 bytes destination)
- **Processing**: Simple pointer assignment, extremely fast
- **Memory access**: Sequential buffer access maintained for non-jump commands
- **Branch prediction**: Jump vs non-jump is highly predictable

# Advanced Jump Patterns

Beyond Z-ordering, jumps enable advanced rendering patterns:

```julia
# Conditional rendering with jumps
if should_render_expensive_content
    # Render expensive content
    render_complex_widgets()
else
    # Jump over expensive content
    skip_jump = JumpCommand(
        BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
        end_of_expensive_content_offset
    )
    write_command!(cmdlist, skip_jump)
end

# LOD (Level of Detail) rendering
function render_with_lod(distance::Real)
    if distance < near_threshold
        render_high_detail_commands()
    elseif distance < far_threshold
        # Jump to medium detail commands
        jump_to_medium_detail()
    else
        # Jump to low detail commands  
        jump_to_low_detail()
    end
end
```

# Debugging Jump Chains

Tools for debugging complex jump structures:

```julia
function trace_jump_chain(cmdlist::CommandList, start_offset::CommandPtr)
    println("Tracing jump chain from offset \$start_offset:")
    
    current = start_offset
    visited = Set{CommandPtr}()
    step = 1
    
    while current < cmdlist.idx && current ∉ visited
        push!(visited, current)
        
        base = read_command(cmdlist, current, BaseCommand)
        println("  Step \$step: offset=\$current, type=\$(base.type)")
        
        if base.type == COMMAND_JUMP
            jump_cmd = read_command(cmdlist, current, JumpCommand)
            println("    → Jumping to offset \$(jump_cmd.dst)")
            current = jump_cmd.dst
        else
            println("    → Normal command, ending trace")
            break
        end
        
        step += 1
        
        if step > 100  # Prevent infinite loops
            println("    → Too many jumps, possible cycle detected")
            break
        end
    end
end
```

# See Also

- [`BaseCommand`](@ref): Common header used by JumpCommand
- [`CommandPtr`](@ref): Type used for jump destinations
- [`Container`](@ref): Uses head/tail CommandPtr for command regions
- [`CommandIterator`](@ref): Automatically follows jumps during traversal
- [`end_frame`](@ref): Function that sets up Z-order jump chains
- [Z-Order Rendering](zorder.md): Detailed explanation of Z-order system
"""
struct JumpCommand
    base::BaseCommand  # Common command header
    dst::CommandPtr   # Destination offset in command buffer
end

"""
    ClipCommand

Command to set the active clipping rectangle for subsequent rendering operations.

ClipCommand establishes a clipping region that restricts all subsequent drawing
operations to a specific rectangular area. This is essential for implementing
container boundaries, scrollable regions, and preventing widgets from drawing
outside their allocated space.

# Fields

- `base::BaseCommand`: Common command header (type=COMMAND_CLIP, size=sizeof(ClipCommand))
- `rect::Rect`: Clipping rectangle in screen coordinates

# Design Rationale

## Why Clipping is Essential
- **Container boundaries**: Prevent widgets from drawing outside their container
- **Scrollable regions**: Only show the visible portion of scrolled content
- **Nested containers**: Each container level can further restrict the drawable area
- **Performance**: Skip drawing operations for completely clipped content

## Hardware vs Software Clipping
ClipCommand can be implemented using either hardware or software clipping:

```julia
# Hardware clipping (OpenGL/DirectX)
function apply_clip_hardware(rect::Rect)
    glScissor(rect.x, rect.y, rect.w, rect.h)
    glEnable(GL_SCISSOR_TEST)
end

# Software clipping (pixel-level)
function apply_clip_software(rect::Rect, framebuffer::FrameBuffer)
    framebuffer.clip_rect = rect
    # All subsequent drawing checks against clip_rect
end
```

# Clipping Hierarchy

Clipping regions are hierarchical - each new clip intersects with the current clip:

```julia
# Clipping stack example:
# 1. Window clip: Rect(0, 0, 800, 600)
apply_clip(Rect(0, 0, 800, 600))         # Full window

# 2. Panel clip: Rect(100, 100, 400, 300) 
apply_clip(Rect(100, 100, 400, 300))     # Panel within window
# Effective clip: intersect(window, panel) = Rect(100, 100, 400, 300)

# 3. Nested panel: Rect(150, 150, 200, 100)
apply_clip(Rect(150, 150, 200, 100))     # Nested panel
# Effective clip: intersect(previous, nested) = Rect(150, 150, 200, 100)
```

# Usage in Container Rendering

ClipCommand is automatically generated when entering containers:

```julia
function begin_window(ctx::Context, title::String, rect::Rect)
    # ... window setup ...
    
    # Set clipping to window content area
    content_area = calculate_content_area(rect)
    clip_cmd = ClipCommand(
        BaseCommand(COMMAND_CLIP, sizeof(ClipCommand)),
        content_area
    )
    push_command!(ctx, clip_cmd)
    
    # All subsequent commands are clipped to content_area
    return window_id
end
```

# Clipping Optimization

ClipCommand enables powerful rendering optimizations:

```julia
function draw_rect_with_clipping!(ctx::Context, rect::Rect, color::Color)
    # Check if rectangle is visible within current clip
    current_clip = get_clip_rect(ctx)
    clipped_rect = intersect_rects(rect, current_clip)
    
    if clipped_rect.w <= 0 || clipped_rect.h <= 0
        # Rectangle is completely clipped - skip rendering
        return
    end
    
    if rect == clipped_rect
        # Rectangle is fully visible - no clipping needed
        rect_cmd = RectCommand(
            BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
            rect, color
        )
        push_command!(ctx, rect_cmd)
    else
        # Rectangle is partially visible - set up clipping
        clip_cmd = ClipCommand(
            BaseCommand(COMMAND_CLIP, sizeof(ClipCommand)),
            current_clip
        )
        push_command!(ctx, clip_cmd)
        
        # Draw full rectangle (will be clipped by hardware/software)
        rect_cmd = RectCommand(
            BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
            rect, color
        )
        push_command!(ctx, rect_cmd)
        
        # Reset to unclipped state
        unclip_cmd = ClipCommand(
            BaseCommand(COMMAND_CLIP, sizeof(ClipCommand)),
            UNCLIPPED_RECT  # Special "no clipping" rectangle
        )
        push_command!(ctx, unclip_cmd)
    end
end
```

# Special Clipping Values

ClipCommand uses special rectangle values for common cases:

```julia
# No clipping (full screen/infinite)
const UNCLIPPED_RECT = Rect(0, 0, 0x1000000, 0x1000000)  # Very large rectangle

# Completely clipped (nothing visible)
const FULLY_CLIPPED_RECT = Rect(0, 0, 0, 0)  # Zero-size rectangle

# Usage examples:
reset_clipping = ClipCommand(
    BaseCommand(COMMAND_CLIP, sizeof(ClipCommand)),
    UNCLIPPED_RECT  # Remove all clipping restrictions
)

hide_everything = ClipCommand(
    BaseCommand(COMMAND_CLIP, sizeof(ClipCommand)),
    FULLY_CLIPPED_RECT  # Clip everything (nothing will be visible)
)
```

# Backend Implementation Examples

Different backends handle ClipCommand differently:

## OpenGL Implementation
```julia
function render_clip_command_opengl(cmd::ClipCommand)
    rect = cmd.rect
    
    if rect == UNCLIPPED_RECT
        # Disable clipping
        glDisable(GL_SCISSOR_TEST)
    else
        # Enable scissor test with rectangle
        # Note: OpenGL Y coordinate is bottom-up
        screen_height = get_screen_height()
        gl_y = screen_height - rect.y - rect.h
        glScissor(rect.x, gl_y, rect.w, rect.h)
        glEnable(GL_SCISSOR_TEST)
    end
end
```

## Software Rendering Implementation
```julia
function render_clip_command_software(cmd::ClipCommand, context::SoftwareContext)
    context.clip_rect = cmd.rect
    
    # All subsequent drawing operations check against clip_rect:
    # if pixel_position ∉ clip_rect then skip_pixel()
end
```

## Web Canvas Implementation
```julia
function render_clip_command_web(cmd::ClipCommand, canvas_context)
    rect = cmd.rect
    
    if rect == UNCLIPPED_RECT
        # Restore to no clipping
        canvas_context.restore()
        canvas_context.save()  # Start fresh clipping state
    else
        # Set up clipping path
        canvas_context.save()
        canvas_context.beginPath()
        canvas_context.rect(rect.x, rect.y, rect.w, rect.h)
        canvas_context.clip()
    end
end
```

# Performance Characteristics

ClipCommand is lightweight but can have performance implications:

- **Command size**: 20 bytes (8 bytes BaseCommand + 16 bytes Rect)
- **State change cost**: Varies by backend (hardware vs software)
- **Optimization potential**: Enables culling of invisible content
- **Memory impact**: Minimal command overhead

# Clipping State Management

Proper clipping state management is crucial for correctness:

```julia
# Stack-based clipping management
mutable struct ClipStack
    clips::Vector{Rect}
    current::Rect
end

function push_clip!(stack::ClipStack, new_clip::Rect)
    # Intersect with current clip
    intersected = intersect_rects(stack.current, new_clip)
    push!(stack.clips, stack.current)  # Save current
    stack.current = intersected         # Update current
    
    # Generate clip command
    return ClipCommand(
        BaseCommand(COMMAND_CLIP, sizeof(ClipCommand)),
        intersected
    )
end

function pop_clip!(stack::ClipStack)
    if !isempty(stack.clips)
        stack.current = pop!(stack.clips)  # Restore previous
        
        # Generate clip command
        return ClipCommand(
            BaseCommand(COMMAND_CLIP, sizeof(ClipCommand)),
            stack.current
        )
    else
        error("Clip stack underflow")
    end
end
```

# Debugging Clipping Issues

Tools for debugging clipping problems:

```julia
function debug_clipping_commands(cmdlist::CommandList)
    println("Clipping Command Analysis:")
    
    iter = CommandIterator(cmdlist)
    clip_count = 0
    
    while true
        (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
        if !has_cmd; break; end
        
        if cmd_type == COMMAND_CLIP
            clip_cmd = read_command(cmdlist, cmd_idx, ClipCommand)
            clip_count += 1
            
            rect = clip_cmd.rect
            if rect == UNCLIPPED_RECT
                println("  Clip \$clip_count: UNCLIPPED (no restrictions)")
            elseif rect.w == 0 || rect.h == 0
                println("  Clip \$clip_count: FULLY_CLIPPED (nothing visible)")
            else
                println("  Clip \$clip_count: Rect(\$(rect.x), \$(rect.y), \$(rect.w), \$(rect.h))")
            end
        end
    end
    
    println("Total clipping commands: \$clip_count")
end

# Visualize clipping regions (for debugging)
function visualize_clip_regions(cmdlist::CommandList)
    # Generate overlay showing all clipping rectangles
    # Different colors for different nesting levels
    # Helps identify clipping issues visually
end
```

# See Also

- [`BaseCommand`](@ref): Common header used by ClipCommand
- [`Rect`](@ref): Rectangle type used for clipping regions
- [`intersect_rects`](@ref): Function for calculating clip intersections
- [`push_clip_rect!`](@ref): High-level clipping management
- [`check_clip`](@ref): Function for testing clipping visibility
- [Clipping Guide](clipping.md): Detailed clipping system documentation
"""
struct ClipCommand
    base::BaseCommand  # Common command header
    rect::Rect        # Clipping rectangle in screen coordinates
end

"""
    RectCommand

Command for drawing filled rectangles, used for backgrounds, borders, and solid color areas.

RectCommand is one of the most fundamental rendering commands in MicroUI,
used to draw solid-color rectangular regions. It forms the basis for most
UI visual elements including button backgrounds, window frames, and borders.

# Fields

- `base::BaseCommand`: Common command header (type=COMMAND_RECT, size=sizeof(RectCommand))
- `rect::Rect`: Rectangle to draw in screen coordinates
- `color::Color`: Fill color with RGBA components

# Design Rationale

## Fundamental Building Block
Rectangles are the foundation of UI rendering:
- **Button backgrounds**: Solid color rectangles behind button text
- **Window frames**: Rectangle outlines and filled areas
- **Panel backgrounds**: Large rectangles for content areas
- **Borders**: Thin rectangles forming widget outlines
- **Highlights**: Semi-transparent rectangles for selection/hover states

## Simplicity and Performance
RectCommand is designed for maximum performance:
- **Minimal data**: Only essential information (position, size, color)
- **Hardware friendly**: Maps directly to GPU rectangle primitives
- **Cache efficient**: Small, fixed-size command structure

# Usage Patterns

## Basic Rectangle Drawing
```julia
# Draw button background
button_bg = RectCommand(
    BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
    Rect(100, 50, 120, 30),           # Button rectangle
    Color(75, 75, 75, 255)            # Gray background
)

# Draw window background
window_bg = RectCommand(
    BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
    Rect(0, 0, 800, 600),             # Full window
    Color(50, 50, 50, 255)            # Dark background
)
```

## Border and Frame Drawing
```julia
# Draw border using multiple rectangles
function draw_border_commands(rect::Rect, color::Color, thickness::Int32)
    commands = RectCommand[]
    
    # Top border
    push!(commands, RectCommand(
        BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
        Rect(rect.x, rect.y, rect.w, thickness),
        color
    ))
    
    # Bottom border
    push!(commands, RectCommand(
        BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
        Rect(rect.x, rect.y + rect.h - thickness, rect.w, thickness),
        color
    ))
    
    # Left border
    push!(commands, RectCommand(
        BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
        Rect(rect.x, rect.y, thickness, rect.h),
        color
    ))
    
    # Right border
    push!(commands, RectCommand(
        BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
        Rect(rect.x + rect.w - thickness, rect.y, thickness, rect.h),
        color
    ))
    
    return commands
end
```

# High-Level Drawing Functions

RectCommand is typically created through high-level drawing functions:

```julia
function draw_rect!(ctx::Context, rect::Rect, color::Color)
    # Apply clipping optimization
    clipped_rect = intersect_rects(rect, get_clip_rect(ctx))
    
    # Skip if completely clipped
    if clipped_rect.w <= 0 || clipped_rect.h <= 0
        return
    end
    
    # Create and add rectangle command
    rect_cmd = RectCommand(
        BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
        clipped_rect,  # Use clipped rectangle for efficiency
        color
    )
    push_command!(ctx, rect_cmd)
end

function draw_box!(ctx::Context, rect::Rect, color::Color)
    # Draw outline using four rectangles
    thickness = Int32(1)
    
    # Top edge
    draw_rect!(ctx, Rect(rect.x, rect.y, rect.w, thickness), color)
    # Bottom edge  
    draw_rect!(ctx, Rect(rect.x, rect.y + rect.h - thickness, rect.w, thickness), color)
    # Left edge
    draw_rect!(ctx, Rect(rect.x, rect.y, thickness, rect.h), color)
    # Right edge
    draw_rect!(ctx, Rect(rect.x + rect.w - thickness, rect.y, thickness, rect.h), color)
end
```

# Widget Integration

Widgets use RectCommand extensively for visual appearance:

```julia
function render_button(ctx::Context, rect::Rect, label::String, state::ButtonState)
    # Choose background color based on state
    bg_color = if state == BUTTON_PRESSED
        ctx.style.colors[Int(COLOR_BUTTONFOCUS)]
    elseif state == BUTTON_HOVER
        ctx.style.colors[Int(COLOR_BUTTONHOVER)]
    else
        ctx.style.colors[Int(COLOR_BUTTON)]
    end
    
    # Draw button background
    draw_rect!(ctx, rect, bg_color)
    
    # Draw button border (optional)
    if ctx.style.border_thickness > 0
        border_color = ctx.style.colors[Int(COLOR_BORDER)]
        draw_box!(ctx, rect, border_color)
    end
    
    # Text rendering would use TextCommand (separate)
end
```

# Backend Rendering Implementation

Different backends render RectCommand in various ways:

## OpenGL Implementation
```julia
function render_rect_command_opengl(cmd::RectCommand)
    rect = cmd.rect
    color = cmd.color
    
    # Set color
    glColor4ub(color.r, color.g, color.b, color.a)
    
    # Draw rectangle using immediate mode (simple but slow)
    glBegin(GL_QUADS)
        glVertex2i(rect.x, rect.y)
        glVertex2i(rect.x + rect.w, rect.y)
        glVertex2i(rect.x + rect.w, rect.y + rect.h)
        glVertex2i(rect.x, rect.y + rect.h)
    glEnd()
    
    # Or using modern OpenGL with VBOs (faster)
    upload_quad_to_vbo(rect, color)
    draw_quad_from_vbo()
end
```

## Software Rendering Implementation
```julia
function render_rect_command_software(cmd::RectCommand, framebuffer::Matrix{Color})
    rect = cmd.rect
    color = cmd.color
    
    # Clamp to framebuffer bounds
    fb_height, fb_width = size(framebuffer)
    x_start = max(1, rect.x + 1)  # Convert to 1-based indexing
    y_start = max(1, rect.y + 1)
    x_end = min(fb_width, rect.x + rect.w)
    y_end = min(fb_height, rect.y + rect.h)
    
    # Fill rectangle
    for y in y_start:y_end, x in x_start:x_end
        framebuffer[y, x] = blend_color(framebuffer[y, x], color)
    end
end
```

## Web Canvas Implementation
```julia
function render_rect_command_web(cmd::RectCommand, canvas_context)
    rect = cmd.rect
    color = cmd.color
    
    # Set fill style
    canvas_context.fillStyle = "rgba(\$(color.r), \$(color.g), \$(color.b), \$(color.a/255))"
    
    # Draw filled rectangle
    canvas_context.fillRect(rect.x, rect.y, rect.w, rect.h)
end
```

# Performance Optimization

RectCommand can be optimized in various ways:

## Batching
```julia
# Batch multiple rectangles of the same color
struct BatchedRectCommand
    base::BaseCommand
    color::Color
    rect_count::Int32
    rects::Vector{Rect}  # Variable-length array
end

# Benefits: Fewer draw calls, better GPU utilization
```

## Culling
```julia
function cull_rectangles(commands::Vector{RectCommand}, clip_rect::Rect)
    visible_commands = RectCommand[]
    
    for cmd in commands
        # Only keep rectangles that intersect with clip region
        if intersects(cmd.rect, clip_rect)
            push!(visible_commands, cmd)
        end
    end
    
    return visible_commands
end
```

# Memory Layout and Size

RectCommand has an efficient memory layout:

```julia
# Memory layout (28 bytes total):
# [BaseCommand: 8 bytes][Rect: 16 bytes][Color: 4 bytes]
# 
# Alignment (on 64-bit systems):
# BaseCommand: 8-byte aligned
# Rect: 4-byte aligned (Int32 fields)
# Color: 1-byte aligned (UInt8 fields)
# 
# Total size: 28 bytes (no padding needed)
```

# Validation and Error Handling

RectCommand validation ensures robust rendering:

```julia
function validate_rect_command(cmd::RectCommand)
    # Validate rectangle
    if cmd.rect.w < 0 || cmd.rect.h < 0
        error("Rectangle has negative dimensions: \$(cmd.rect)")
    end
    
    # Validate base command
    if cmd.base.type != COMMAND_RECT
        error("Invalid command type: expected COMMAND_RECT, got \$(cmd.base.type)")
    end
    
    if cmd.base.size != sizeof(RectCommand)
        error("Invalid command size: expected \$(sizeof(RectCommand)), got \$(cmd.base.size)")
    end
    
    # Color validation (usually not needed, but can check for special cases)
    if cmd.color.a == 0
        @warn "Drawing rectangle with fully transparent color (invisible)"
    end
end
```

# Debugging and Visualization

Tools for debugging rectangle rendering:

```julia
function debug_rectangle_commands(cmdlist::CommandList)
    println("Rectangle Command Analysis:")
    
    iter = CommandIterator(cmdlist)
    rect_count = 0
    total_area = 0
    
    while true
        (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
        if !has_cmd; break; end
        
        if cmd_type == COMMAND_RECT
            rect_cmd = read_command(cmdlist, cmd_idx, RectCommand)
            rect_count += 1
            area = rect_cmd.rect.w * rect_cmd.rect.h
            total_area += area
            
            println("  Rect \$rect_count: \$(rect_cmd.rect), color=\$(rect_cmd.color), area=\$area")
        end
    end
    
    println("Total rectangles: \$rect_count")
    println("Total area covered: \$total_area pixels")
end
```

# See Also

- [`BaseCommand`](@ref): Common header used by RectCommand
- [`Rect`](@ref): Rectangle type used for positioning and sizing
- [`Color`](@ref): Color type used for fill color
- [`draw_rect!`](@ref): High-level function that creates RectCommand
- [`draw_box!`](@ref): Function that creates border using multiple RectCommands
- [Widget Rendering](widgets.md): How widgets use RectCommand
"""
struct RectCommand
    base::BaseCommand  # Common command header
    rect::Rect        # Rectangle to draw
    color::Color      # Fill color
end

"""
    TextCommand

Command for rendering text strings with specified font, position, and color.

TextCommand handles all text rendering in MicroUI, from button labels to
large text blocks. It includes support for different fonts, positioning,
colors, and integrates with the string storage system for efficient memory usage.

# Fields

- `base::BaseCommand`: Common command header (type=COMMAND_TEXT, size=sizeof(TextCommand))
- `font::Font`: Font to use for rendering (backend-specific font handle)
- `pos::Vec2`: Text baseline position in screen coordinates
- `color::Color`: Text color with RGBA components
- `str_index::Int32`: Index into the command list's string table
- `str_length::Int32`: Length of the string in characters (for validation)

# Design Rationale

## Separation of Text Data and Commands
Text strings are stored separately from commands for efficiency:

```julia
# String storage in CommandList
mutable struct CommandList
    buffer::Vector{UInt8}     # Command buffer
    strings::Vector{String}   # Separate string storage
    string_idx::Int32        # Current string count
    # ...
end

# TextCommand references strings by index
struct TextCommand
    str_index::Int32    # Points into strings array
    str_length::Int32   # For validation and optimization
    # ...
end
```

This design provides several benefits:
- **Memory efficiency**: Strings aren't duplicated in the command buffer
- **Variable length**: Strings can be any length without affecting command size
- **Shared strings**: Multiple commands can reference the same string
- **Cache locality**: Commands remain fixed-size for efficient traversal

## Font Abstraction
The `Font` field uses the generic `Font` type to support different backends:

```julia
# Different backends store fonts differently:
# OpenGL: texture ID + glyph metrics
# DirectWrite: font object + render parameters  
# Web: CSS font string
# Software: bitmap font data

# TextCommand works with all backends through Font abstraction
```

# Usage in Text Rendering

## High-Level Text Drawing
```julia
function draw_text!(ctx::Context, font::Font, str::String, pos::Vec2, color::Color)
    # Store string in command list
    str_idx = write_string!(ctx.command_list, str)
    
    # Create text command
    text_cmd = TextCommand(
        BaseCommand(COMMAND_TEXT, sizeof(TextCommand)),
        font,
        pos,
        color,
        str_idx,
        length(str)
    )
    
    # Add to command buffer
    push_command!(ctx, text_cmd)
end

# Convenience function for widgets
function draw_control_text!(ctx::Context, str::String, rect::Rect, colorid::ColorId, opt::UInt16)
    font = ctx.style.font
    color = ctx.style.colors[Int(colorid)]
    
    # Calculate text position within rectangle
    text_width = ctx.text_width(font, str)
    text_height = ctx.text_height(font)
    
    # Handle text alignment
    pos_x = if (opt & UInt16(OPT_ALIGNCENTER)) != 0
        rect.x + (rect.w - text_width) ÷ 2
    elseif (opt & UInt16(OPT_ALIGNRIGHT)) != 0
        rect.x + rect.w - text_width - ctx.style.padding
    else
        rect.x + ctx.style.padding
    end
    
    pos_y = rect.y + (rect.h - text_height) ÷ 2
    
    draw_text!(ctx, font, str, Vec2(pos_x, pos_y), color)
end
```

## String Management Integration
```julia
function push_text_command!(ctx::Context, font::Font, str::String, pos::Vec2, color::Color)
    # Store string and get index
    str_idx = write_string!(ctx.command_list, str)
    
    # Create command with string reference
    text_cmd = TextCommand(
        BaseCommand(COMMAND_TEXT, sizeof(TextCommand)),
        font, pos, color, str_idx, length(str)
    )
    
    return write_command!(ctx.command_list, text_cmd)
end

# String retrieval during rendering
function get_text_command_string(cmdlist::CommandList, cmd::TextCommand)
    return get_string(cmdlist, cmd.str_index)
end
```

# Backend Rendering Implementation

Different backends handle TextCommand in various ways:

## OpenGL with Texture Atlas
```julia
function render_text_command_opengl(cmd::TextCommand, cmdlist::CommandList)
    # Get string data
    text_str = get_string(cmdlist, cmd.str_index)
    font = cmd.font  # Contains texture atlas and glyph data
    
    # Set text color
    glColor4ub(cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a)
    
    # Bind font texture
    glBindTexture(GL_TEXTURE_2D, font.texture_id)
    
    # Render each character
    x = cmd.pos.x
    y = cmd.pos.y
    
    for char in text_str
        if haskey(font.glyph_data, char)
            glyph = font.glyph_data[char]
            
            # Draw character quad with texture coordinates
            draw_glyph_quad(x + glyph.offset_x, y + glyph.offset_y, 
                          glyph.width, glyph.height,
                          glyph.texture_coords)
            
            x += glyph.advance_x
        end
    end
end
```

## Software Rendering with Bitmap Font
```julia
function render_text_command_software(cmd::TextCommand, cmdlist::CommandList, framebuffer::Matrix{Color})
    text_str = get_string(cmdlist, cmd.str_index)
    font = cmd.font  # Contains bitmap font data
    
    x = cmd.pos.x
    y = cmd.pos.y
    
    for char in text_str
        if haskey(font.char_bitmaps, char)
            bitmap = font.char_bitmaps[char]
            
            # Blit character bitmap to framebuffer
            for dy in 1:bitmap.height, dx in 1:bitmap.width
                if bitmap.data[dy, dx] > 0  # Non-zero pixel
                    fb_x = x + dx - 1
                    fb_y = y + dy - 1
                    
                    if 1 <= fb_x <= size(framebuffer, 2) && 1 <= fb_y <= size(framebuffer, 1)
                        # Alpha blend text color with background
                        alpha = bitmap.data[dy, dx] / 255.0
                        framebuffer[fb_y, fb_x] = blend_colors(framebuffer[fb_y, fb_x], cmd.color, alpha)
                    end
                end
            end
            
            x += font.char_widths[char]
        end
    end
end
```

## Web Canvas Implementation
```julia
function render_text_command_web(cmd::TextCommand, cmdlist::CommandList, canvas_context)
    text_str = get_string(cmdlist, cmd.str_index)
    font = cmd.font  # CSS font string like "16px Arial"
    
    # Set font and color
    canvas_context.font = font
    canvas_context.fillStyle = color_to_css(cmd.color)
    
    # Draw text at baseline position
    canvas_context.fillText(text_str, cmd.pos.x, cmd.pos.y)
end
```

# Text Measurement Integration

TextCommand works with text measurement callbacks:

```julia
# Text measurement callbacks (set by application)
ctx.text_width = function(font::Font, str::String)
    # Backend-specific text width calculation
    return calculate_text_width(font, str)
end

ctx.text_height = function(font::Font)
    # Backend-specific line height
    return get_font_line_height(font)
end

# Usage in layout calculations
function layout_text_widget(ctx::Context, text::String)
    font = ctx.style.font
    text_w = ctx.text_width(font, text)
    text_h = ctx.text_height(font)
    
    # Calculate widget size including padding
    widget_w = text_w + ctx.style.padding * 2
    widget_h = text_h + ctx.style.padding * 2
    
    return Vec2(widget_w, widget_h)
end
```

# Multi-Line Text Handling

TextCommand handles single lines of text. Multi-line text is broken into multiple TextCommands:

```julia
function draw_multiline_text!(ctx::Context, font::Font, text::String, rect::Rect, color::Color)
    lines = split(text, '\n')
    line_height = ctx.text_height(font)
    
    y = rect.y
    for line in lines
        # Skip lines that would be outside the rectangle
        if y + line_height > rect.y + rect.h
            break
        end
        
        # Create TextCommand for each line
        draw_text!(ctx, font, line, Vec2(rect.x, y), color)
        y += line_height
    end
end

# Word wrapping (more complex)
function draw_wrapped_text!(ctx::Context, font::Font, text::String, rect::Rect, color::Color)
    words = split(text, ' ')
    line_height = ctx.text_height(font)
    
    y = rect.y
    current_line = ""
    
    for word in words
        test_line = isempty(current_line) ? word : current_line * " " * word
        test_width = ctx.text_width(font, test_line)
        
        if test_width <= rect.w
            current_line = test_line
        else
            # Line is full, draw it and start new line
            if !isempty(current_line)
                draw_text!(ctx, font, current_line, Vec2(rect.x, y), color)
                y += line_height
                current_line = word
            end
        end
    end
    
    # Draw remaining text
    if !isempty(current_line) && y + line_height <= rect.y + rect.h
        draw_text!(ctx, font, current_line, Vec2(rect.x, y), color)
    end
end
```

# Performance Characteristics

TextCommand is optimized for efficient text rendering:

- **Command size**: 32 bytes fixed size (8 + 8 + 8 + 4 + 4 + 4 bytes)
- **String storage**: Separate from commands for memory efficiency
- **Font abstraction**: Minimal overhead for different font systems
- **Baseline positioning**: Standard typography positioning for accurate layout

# Typography and Positioning

TextCommand uses baseline positioning for professional typography:

```julia
# Text positioning concepts:
#
# Top line (ascender height)
#     ┌─ Ascender height
#     │
# Baseline ──────────────────── ← pos.y points here
#     │
#     └─ Descender height  
# Bottom line

# Calculate text rectangle from baseline position
function text_command_to_rect(cmd::TextCommand, cmdlist::CommandList, text_width_func::Function, text_height_func::Function)
    text_str = get_string(cmdlist, cmd.str_index)
    width = text_width_func(cmd.font, text_str)
    height = text_height_func(cmd.font)
    
    # Baseline is typically 80% down from top of text rectangle
    baseline_offset = Int32(height * 0.8)
    
    return Rect(
        cmd.pos.x,
        cmd.pos.y - baseline_offset,  # Move up from baseline to top
        width,
        height
    )
end
```

# String Encoding and Unicode

TextCommand supports Unicode text through Julia's native string handling:

```julia
# Unicode text examples
unicode_text = "Hello 世界! 🎉 Ñoël"

# Julia strings are UTF-8 by default
# TextCommand.str_length is character count, not byte count
char_count = length(unicode_text)  # Number of Unicode codepoints
byte_count = sizeof(unicode_text)  # Number of UTF-8 bytes

# Backend rendering must handle UTF-8 properly
function render_unicode_text(font::Font, text::String)
    for char in text  # Iterates over Unicode codepoints
        render_single_character(font, char)
    end
end
```

# Validation and Error Handling

TextCommand validation ensures robust text rendering:

```julia
function validate_text_command(cmd::TextCommand, cmdlist::CommandList)
    # Validate base command
    if cmd.base.type != COMMAND_TEXT
        error("Invalid command type: expected COMMAND_TEXT, got \$(cmd.base.type)")
    end
    
    if cmd.base.size != sizeof(TextCommand)
        error("Invalid command size: expected \$(sizeof(TextCommand)), got \$(cmd.base.size)")
    end
    
    # Validate string index
    if cmd.str_index < 1 || cmd.str_index > cmdlist.string_idx
        error("Invalid string index: \$(cmd.str_index) (valid range: 1-\$(cmdlist.string_idx))")
    end
    
    # Validate string length
    actual_string = get_string(cmdlist, cmd.str_index)
    actual_length = length(actual_string)
    
    if cmd.str_length != actual_length
        @warn "String length mismatch: command says \$(cmd.str_length), actual is \$actual_length"
    end
    
    # Font validation (backend-specific)
    if cmd.font === nothing
        @warn "Text command has null font"
    end
end
```

# Debugging Text Rendering

Tools for debugging text-related issues:

```julia
function debug_text_commands(cmdlist::CommandList)
    println("Text Command Analysis:")
    
    iter = CommandIterator(cmdlist)
    text_count = 0
    total_chars = 0
    
    while true
        (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
        if !has_cmd; break; end
        
        if cmd_type == COMMAND_TEXT
            text_cmd = read_command(cmdlist, cmd_idx, TextCommand)
            text_str = get_string(cmdlist, text_cmd.str_index)
            text_count += 1
            total_chars += length(text_str)
            
            println("  Text \$text_count: '\$text_str' at \$(text_cmd.pos)")
            println("    Font: \$(text_cmd.font), Color: \$(text_cmd.color)")
            println("    Length: \$(text_cmd.str_length) chars")
        end
    end
    
    println("Total text commands: \$text_count")
    println("Total characters rendered: \$total_chars")
end

# Check for common text rendering issues
function diagnose_text_issues(cmdlist::CommandList)
    issues = String[]
    
    iter = CommandIterator(cmdlist)
    while true
        (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
        if !has_cmd; break; end
        
        if cmd_type == COMMAND_TEXT
            text_cmd = read_command(cmdlist, cmd_idx, TextCommand)
            text_str = get_string(cmdlist, text_cmd.str_index)
            
            # Check for empty strings
            if isempty(text_str)
                push!(issues, "Empty text command at \$(text_cmd.pos)")
            end
            
            # Check for transparent text
            if text_cmd.color.a == 0
                push!(issues, "Fully transparent text: '\$text_str'")
            end
            
            # Check for very small text (might be invisible)
            if text_cmd.pos.x < -1000 || text_cmd.pos.y < -1000
                push!(issues, "Text far off-screen: '\$text_str' at \$(text_cmd.pos)")
            end
        end
    end
    
    if isempty(issues)
        println("No text rendering issues detected")
    else
        println("Text rendering issues found:")
        for issue in issues
            println("  - \$issue")
        end
    end
end
```

# See Also

- [`BaseCommand`](@ref): Common header used by TextCommand
- [`Font`](@ref): Font type used for text rendering
- [`Vec2`](@ref): Position type for text placement  
- [`Color`](@ref): Color type for text appearance
- [`draw_text!`](@ref): High-level function that creates TextCommand
- [`write_string!`](@ref): Function for storing strings in CommandList
- [`get_string`](@ref): Function for retrieving strings during rendering
- [Text Rendering Guide](text.md): Detailed text system documentation
- [Typography Guide](typography.md): Advanced text layout and styling
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
    IconCommand

Command for drawing built-in icons and symbols as simple geometric shapes.

IconCommand renders predefined icons that are drawn as basic geometric shapes
rather than bitmap images. This provides scalable, crisp icons that work at
any size and integrate seamlessly with the vector-based UI rendering system.

# Fields

- `base::BaseCommand`: Common command header (type=COMMAND_ICON, size=sizeof(IconCommand))
- `rect::Rect`: Rectangle to draw the icon within (icon scales to fit)
- `id::IconId`: Which icon to draw (ICON_CLOSE, ICON_CHECK, etc.)
- `color::Color`: Icon color with RGBA components

# Design Rationale

## Vector Icons vs Bitmap Icons
IconCommand uses geometric shapes instead of bitmap images:

**Advantages of Geometric Icons:**
- **Scalable**: Look crisp at any size from 8×8 to 128×128 pixels
- **Small memory footprint**: No texture storage required
- **Color flexibility**: Can be rendered in any color
- **Backend independent**: Work with any rendering system
- **Fast rendering**: Simple geometry renders quickly

**Trade-offs:**
- **Limited complexity**: Only simple shapes (lines, triangles, circles)
- **Predefined set**: Cannot add arbitrary icons without code changes
- **Geometric style**: All icons must fit the simple geometric aesthetic

## Icon Scaling and Positioning
Icons automatically scale to fit the provided rectangle:

```julia
# Icon adapts to any rectangle size
small_icon = IconCommand(base, Rect(10, 10, 16, 16), ICON_CHECK, color)    # 16×16
large_icon = IconCommand(base, Rect(50, 50, 64, 64), ICON_CHECK, color)    # 64×64

# Both render the same checkmark shape, scaled appropriately
```

# Available Icons

MicroUI includes essential UI icons:

```julia
# Window controls
ICON_CLOSE = 1      # ✕ symbol for close buttons
ICON_CHECK = 2      # ✓ checkmark for checkboxes and confirmation

# Tree/list controls  
ICON_COLLAPSED = 3  # ► triangle pointing right (collapsed state)
ICON_EXPANDED = 4   # ▼ triangle pointing down (expanded state)
```

# Usage in Widgets

## Checkbox Icons
```julia
function render_checkbox(ctx::Context, rect::Rect, checked::Bool, color::Color)
    # Draw checkbox background
    draw_rect!(ctx, rect, ctx.style.colors[Int(COLOR_BASE)])
    
    # Draw checkmark if checked
    if checked
        icon_cmd = IconCommand(
            BaseCommand(COMMAND_ICON, sizeof(IconCommand)),
            rect,           # Checkmark fills entire checkbox
            ICON_CHECK,
            color
        )
        push_command!(ctx, icon_cmd)
    end
end
```

## Window Close Button
```julia
function render_window_close_button(ctx::Context, window_rect::Rect)
    # Calculate close button position (top-right corner)
    button_size = ctx.style.title_height
    close_rect = Rect(
        window_rect.x + window_rect.w - button_size,
        window_rect.y,
        button_size,
        button_size
    )
    
    # Draw close button background
    if ctx.hover == close_button_id
        draw_rect!(ctx, close_rect, ctx.style.colors[Int(COLOR_BUTTONHOVER)])
    end
    
    # Draw close icon
    icon_cmd = IconCommand(
        BaseCommand(COMMAND_ICON, sizeof(IconCommand)),
        close_rect,
        ICON_CLOSE,
        ctx.style.colors[Int(COLOR_TITLETEXT)]
    )
    push_command!(ctx, icon_cmd)
end
```

## Treenode Expansion Indicator
```julia
function render_treenode_icon(ctx::Context, rect::Rect, expanded::Bool)
    icon_id = expanded ? ICON_EXPANDED : ICON_COLLAPSED
    
    # Create square icon area at left edge of rect
    icon_size = min(rect.w, rect.h)
    icon_rect = Rect(rect.x, rect.y, icon_size, icon_size)
    
    icon_cmd = IconCommand(
        BaseCommand(COMMAND_ICON, sizeof(IconCommand)),
        icon_rect,
        icon_id,
        ctx.style.colors[Int(COLOR_TEXT)]
    )
    push_command!(ctx, icon_cmd)
end
```

# Backend Rendering Implementation

Different backends render IconCommand using their native drawing primitives:

## OpenGL Implementation
```julia
function render_icon_command_opengl(cmd::IconCommand)
    rect = cmd.rect
    color = cmd.color
    icon_id = cmd.id
    
    # Set icon color
    glColor4ub(color.r, color.g, color.b, color.a)
    
    if icon_id == ICON_CLOSE
        # Draw X using two diagonal lines
        glBegin(GL_LINES)
            # Diagonal from top-left to bottom-right
            glVertex2i(rect.x, rect.y)
            glVertex2i(rect.x + rect.w, rect.y + rect.h)
            # Diagonal from top-right to bottom-left  
            glVertex2i(rect.x + rect.w, rect.y)
            glVertex2i(rect.x, rect.y + rect.h)
        glEnd()
        
    elseif icon_id == ICON_CHECK
        # Draw checkmark using connected lines
        mid_x = rect.x + rect.w ÷ 3
        mid_y = rect.y + rect.h ÷ 2
        
        glBegin(GL_LINE_STRIP)
            glVertex2i(rect.x, mid_y)                    # Left point
            glVertex2i(mid_x, rect.y + rect.h)          # Bottom point
            glVertex2i(rect.x + rect.w, rect.y)         # Top-right point
        glEnd()
        
    elseif icon_id == ICON_COLLAPSED
        # Draw right-pointing triangle
        glBegin(GL_TRIANGLES)
            glVertex2i(rect.x, rect.y)                  # Top-left
            glVertex2i(rect.x, rect.y + rect.h)         # Bottom-left
            glVertex2i(rect.x + rect.w, rect.y + rect.h ÷ 2)  # Right point
        glEnd()
        
    elseif icon_id == ICON_EXPANDED
        # Draw down-pointing triangle
        glBegin(GL_TRIANGLES)
            glVertex2i(rect.x, rect.y)                  # Top-left
            glVertex2i(rect.x + rect.w, rect.y)         # Top-right
            glVertex2i(rect.x + rect.w ÷ 2, rect.y + rect.h)  # Bottom point
        glEnd()
    end
end
```

## Software Rendering Implementation
```julia
function render_icon_command_software(cmd::IconCommand, framebuffer::Matrix{Color})
    rect = cmd.rect
    color = cmd.color
    icon_id = cmd.id
    
    if icon_id == ICON_CLOSE
        # Draw X using Bresenham line algorithm
        draw_line!(framebuffer, rect.x, rect.y, rect.x + rect.w, rect.y + rect.h, color)
        draw_line!(framebuffer, rect.x + rect.w, rect.y, rect.x, rect.y + rect.h, color)
        
    elseif icon_id == ICON_CHECK
        # Draw checkmark
        mid_x = rect.x + rect.w ÷ 3
        mid_y = rect.y + rect.h ÷ 2
        draw_line!(framebuffer, rect.x, mid_y, mid_x, rect.y + rect.h, color)
        draw_line!(framebuffer, mid_x, rect.y + rect.h, rect.x + rect.w, rect.y, color)
        
    elseif icon_id == ICON_COLLAPSED
        # Draw filled triangle
        triangle_points = [
            (rect.x, rect.y),
            (rect.x, rect.y + rect.h),
            (rect.x + rect.w, rect.y + rect.h ÷ 2)
        ]
        fill_triangle!(framebuffer, triangle_points, color)
        
    elseif icon_id == ICON_EXPANDED
        # Draw filled triangle
        triangle_points = [
            (rect.x, rect.y),
            (rect.x + rect.w, rect.y),
            (rect.x + rect.w ÷ 2, rect.y + rect.h)
        ]
        fill_triangle!(framebuffer, triangle_points, color)
    end
end
```

## Web Canvas Implementation
```julia
function render_icon_command_web(cmd::IconCommand, canvas_context)
    rect = cmd.rect
    color = cmd.color
    icon_id = cmd.id
    
    # Set drawing style
    canvas_context.strokeStyle = color_to_css(color)
    canvas_context.fillStyle = color_to_css(color)
    canvas_context.lineWidth = 2
    
    if icon_id == ICON_CLOSE
        # Draw X
        canvas_context.beginPath()
        canvas_context.moveTo(rect.x, rect.y)
        canvas_context.lineTo(rect.x + rect.w, rect.y + rect.h)
        canvas_context.moveTo(rect.x + rect.w, rect.y)
        canvas_context.lineTo(rect.x, rect.y + rect.h)
        canvas_context.stroke()
        
    elseif icon_id == ICON_CHECK
        # Draw checkmark
        mid_x = rect.x + rect.w / 3
        mid_y = rect.y + rect.h / 2
        canvas_context.beginPath()
        canvas_context.moveTo(rect.x, mid_y)
        canvas_context.lineTo(mid_x, rect.y + rect.h)
        canvas_context.lineTo(rect.x + rect.w, rect.y)
        canvas_context.stroke()
        
    elseif icon_id == ICON_COLLAPSED || icon_id == ICON_EXPANDED
        # Draw triangles
        canvas_context.beginPath()
        if icon_id == ICON_COLLAPSED
            # Right-pointing triangle
            canvas_context.moveTo(rect.x, rect.y)
            canvas_context.lineTo(rect.x, rect.y + rect.h)
            canvas_context.lineTo(rect.x + rect.w, rect.y + rect.h / 2)
        else
            # Down-pointing triangle
            canvas_context.moveTo(rect.x, rect.y)
            canvas_context.lineTo(rect.x + rect.w, rect.y)
            canvas_context.lineTo(rect.x + rect.w / 2, rect.y + rect.h)
        end
        canvas_context.closePath()
        canvas_context.fill()
    end
end
```

# Icon Customization and Extensions

While the built-in icon set is limited, it can be extended:

## Custom Icon IDs
```julia
# Extend IconId enum (requires recompilation)
@enum IconId::UInt8 begin
    ICON_CLOSE = 1
    ICON_CHECK = 2  
    ICON_COLLAPSED = 3
    ICON_EXPANDED = 4
    # Custom icons
    ICON_SETTINGS = 5
    ICON_HELP = 6
    ICON_SEARCH = 7
end
```

## Alternative Approaches for Complex Icons
```julia
# Use text rendering for Unicode symbols
function draw_unicode_icon(ctx::Context, rect::Rect, symbol::String, color::Color)
    # Examples: "⚙" (settings), "❓" (help), "🔍" (search)
    draw_text!(ctx, ctx.style.font, symbol, Vec2(rect.x, rect.y), color)
end

# Use custom drawing functions
function draw_custom_icon(ctx::Context, rect::Rect, icon_name::String, color::Color)
    if icon_name == "gear"
        draw_gear_shape(ctx, rect, color)
    elseif icon_name == "arrow"
        draw_arrow_shape(ctx, rect, color)
    end
end
```

# Performance Characteristics

IconCommand is highly optimized:

- **Command size**: 24 bytes (8 + 16 + 1 + 4 bytes)
- **Rendering speed**: Very fast geometric shapes
- **Memory usage**: No texture storage required
- **Scaling**: No quality loss at any size
- **Cache efficiency**: Fixed-size commands, predictable access patterns

# Validation and Error Handling

IconCommand validation ensures robust icon rendering:

```julia
function validate_icon_command(cmd::IconCommand)
    # Validate base command
    if cmd.base.type != COMMAND_ICON
        error("Invalid command type: expected COMMAND_ICON, got \$(cmd.base.type)")
    end
    
    if cmd.base.size != sizeof(IconCommand)
        error("Invalid command size: expected \$(sizeof(IconCommand)), got \$(cmd.base.size)")
    end
    
    # Validate icon ID
    valid_icons = [ICON_CLOSE, ICON_CHECK, ICON_COLLAPSED, ICON_EXPANDED]
    if cmd.id ∉ valid_icons
        error("Unknown icon ID: \$(cmd.id)")
    end
    
    # Validate rectangle
    if cmd.rect.w <= 0 || cmd.rect.h <= 0
        @warn "Icon rectangle has zero or negative size: \$(cmd.rect)"
    end
    
    # Check for invisible icons
    if cmd.color.a == 0
        @warn "Icon has fully transparent color (invisible)"
    end
end
```

# Debugging Icon Rendering

Tools for debugging icon-related issues:

```julia
function debug_icon_commands(cmdlist::CommandList)
    println("Icon Command Analysis:")
    
    iter = CommandIterator(cmdlist)
    icon_count = 0
    icon_types = Dict{IconId, Int}()
    
    while true
        (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
        if !has_cmd; break; end
        
        if cmd_type == COMMAND_ICON
            icon_cmd = read_command(cmdlist, cmd_idx, IconCommand)
            icon_count += 1
            
            # Count icon types
            icon_types[icon_cmd.id] = get(icon_types, icon_cmd.id, 0) + 1
            
            println("  Icon \$icon_count: \$(icon_cmd.id) at \$(icon_cmd.rect)")
            println("    Color: \$(icon_cmd.color)")
        end
    end
    
    println("Total icons: \$icon_count")
    println("Icon type distribution:")
    for (icon_id, count) in icon_types
        println("  \$icon_id: \$count instances")
    end
end
```

# See Also

- [`BaseCommand`](@ref): Common header used by IconCommand
- [`IconId`](@ref): Enumeration of available icon types
- [`Rect`](@ref): Rectangle type for icon positioning and sizing
- [`Color`](@ref): Color type for icon appearance
- [`draw_icon!`](@ref): High-level function that creates IconCommand
- [Icon System Guide](icons.md): Detailed icon system documentation
- [Custom Icons Guide](custom_icons.md): Adding custom icon support
"""
struct IconCommand
    base::BaseCommand  # Common command header
    rect::Rect        # Rectangle to draw icon within
    id::IconId        # Which icon to draw
    color::Color      # Icon color
end

"""
    CommandList

Container for all rendering commands and string data generated during a frame.

CommandList serves as the central repository for all drawing operations in MicroUI.
It manages both the binary command buffer containing rendering commands and
a separate string storage system for text data, providing efficient memory
usage and fast command processing.

# Fields

- `buffer::Vector{UInt8}`: Binary buffer storing packed command data
- `idx::Int32`: Current write position in the command buffer (bytes)
- `strings::Vector{String}`: Separate storage for text strings  
- `string_idx::Int32`: Current write position in string array (count)

# Design Rationale

## Dual Storage System
CommandList uses two separate storage systems for optimal efficiency:

### Binary Command Buffer
```julia
# Commands stored as packed binary data:
# [RectCommand: 28 bytes][TextCommand: 32 bytes][IconCommand: 24 bytes]...
#  ↑ offset 0            ↑ offset 28           ↑ offset 60

# Benefits:
# - Fixed-size commands enable fast traversal
# - Packed format maximizes cache efficiency  
# - Direct memory access for high performance
```

### Separate String Storage
```julia
# Strings stored separately from commands:
strings = ["Button", "Hello World", "Settings", ...]
           ↑ index 1  ↑ index 2      ↑ index 3

# Benefits:
# - Variable-length strings don't complicate command buffer
# - Strings can be shared between multiple commands
# - Command buffer remains fixed-size and cache-friendly
```

## Memory Management
CommandList uses pre-allocated buffers to avoid runtime allocations:

```julia
# Pre-allocated buffer prevents malloc/free during UI rendering
buffer = Vector{UInt8}(undef, COMMANDLIST_SIZE)  # 256KB default

# String array grows dynamically but typically stabilizes
strings = String[]  # Starts empty, grows as needed
```

# Frame Lifecycle

CommandList follows a clear lifecycle each frame:

```julia
# Frame beginning: Reset for new commands
function begin_frame(ctx::Context)
    ctx.command_list.idx = 0         # Reset command buffer
    ctx.command_list.string_idx = 0  # Reset string counter
    # Note: string array is reused for memory efficiency
end

# During frame: Commands and strings are added
draw_rect!(ctx, rect, color)     # → Adds RectCommand to buffer
draw_text!(ctx, font, "Hi", pos, color)  # → Adds TextCommand + string

# Frame end: Commands are ready for rendering
function end_frame(ctx::Context)
    # Command buffer contains all rendering operations
    # Ready for backend processing
end
```

# Command Buffer Operations

## Writing Commands
```julia
function write_command!(cmdlist::CommandList, cmd::T) where T
    size = sizeof(T)
    
    # Check buffer capacity
    if cmdlist.idx + size > length(cmdlist.buffer)
        error("Command buffer overflow")
    end
    
    # Write command as binary data
    ptr = pointer(cmdlist.buffer, cmdlist.idx + 1)
    unsafe_store!(Ptr{T}(ptr), cmd)
    
    # Update write position
    old_idx = cmdlist.idx
    cmdlist.idx += size
    return old_idx  # Return offset for references
end

# Usage example
rect_cmd = RectCommand(base, rect, color)
offset = write_command!(cmdlist, rect_cmd)
```

## Reading Commands
```julia
function read_command(cmdlist::CommandList, idx::CommandPtr, ::Type{T}) where T
    # Validate bounds
    if idx < 0 || idx + sizeof(T) > cmdlist.idx
        error("Invalid command index or buffer overflow")
    end
    
    # Read command as binary data
    ptr = pointer(cmdlist.buffer, idx + 1)
    return unsafe_load(Ptr{T}(ptr))
end

# Usage example
base = read_command(cmdlist, offset, BaseCommand)
if base.type == COMMAND_RECT
    rect_cmd = read_command(cmdlist, offset, RectCommand)
end
```

# String Storage Operations

## Storing Strings
```julia
function write_string!(cmdlist::CommandList, str::String)
    cmdlist.string_idx += 1
    
    # Expand string array if needed
    if cmdlist.string_idx > length(cmdlist.strings)
        resize!(cmdlist.strings, cmdlist.string_idx * 2)
    end
    
    # Store string
    cmdlist.strings[cmdlist.string_idx] = str
    return cmdlist.string_idx
end

# Usage in text commands
text_str = "Hello World"
str_idx = write_string!(cmdlist, text_str)
text_cmd = TextCommand(base, font, pos, color, str_idx, length(text_str))
```

## Retrieving Strings
```julia
function get_string(cmdlist::CommandList, str_index::Int32)
    if str_index < 1 || str_index > cmdlist.string_idx
        error("Invalid string index: \$str_index")
    end
    return cmdlist.strings[str_index]
end

# Usage during rendering
text_cmd = read_command(cmdlist, offset, TextCommand)
text_str = get_string(cmdlist, text_cmd.str_index)
```

# Buffer Management and Optimization

## Buffer Size Planning
```julia
# Calculate buffer requirements for different UI complexities:

# Simple UI (few buttons, minimal text)
# ~50 commands × 30 bytes average = 1.5 KB

# Typical application UI  
# ~500 commands × 30 bytes average = 15 KB

# Complex dashboard
# ~2000 commands × 30 bytes average = 60 KB

# Buffer size recommendations:
const COMMANDLIST_SIZE = 256 * 1024  # 256 KB (generous for most apps)
```

## Memory Usage Analysis
```julia
function analyze_command_buffer_usage(cmdlist::CommandList)
    used_bytes = cmdlist.idx
    total_bytes = length(cmdlist.buffer)
    usage_percent = (used_bytes / total_bytes) * 100
    
    # Count commands by type
    type_counts = Dict{CommandType, Int}()
    type_sizes = Dict{CommandType, Int}()
    
    offset = 0
    while offset < cmdlist.idx
        base = read_command(cmdlist, offset, BaseCommand)
        type_counts[base.type] = get(type_counts, base.type, 0) + 1
        type_sizes[base.type] = get(type_sizes, base.type, 0) + base.size
        offset += base.size
    end
    
    println("Command Buffer Analysis:")
    println("  Used: \$used_bytes / \$total_bytes bytes (\$(round(usage_percent, digits=1))%)")
    println("  String storage: \$(cmdlist.string_idx) strings")
    
    for (cmd_type, count) in type_counts
        size_bytes = type_sizes[cmd_type]
        avg_size = size_bytes ÷ count
        println("  \$cmd_type: \$count commands, \$size_bytes bytes (avg \$avg_size bytes)")
    end
end
```

# Performance Characteristics

CommandList is optimized for high-performance UI rendering:

## Memory Access Patterns
- **Sequential writes**: Commands written in order for cache efficiency
- **Sequential reads**: Command processing follows cache-friendly access pattern
- **Packed data**: No padding or gaps between commands
- **Locality**: Related commands are stored near each other

## Allocation Strategy
- **Pre-allocation**: Buffer allocated once at startup
- **No runtime malloc**: No dynamic allocation during UI rendering
- **String reuse**: String array reused between frames
- **Predictable memory**: Fixed buffer size enables memory planning

## Performance Metrics
```julia
# Typical performance characteristics:
# Command writing: ~10-50 ns per command
# Command reading: ~5-20 ns per command  
# String storage: ~100-500 ns per string (includes string copy)
# String retrieval: ~5-10 ns per string (array access)
# Buffer reset: ~1-5 ns (just reset indices)
```

# Error Handling and Validation

## Buffer Overflow Protection
```julia
function safe_write_command!(cmdlist::CommandList, cmd::T) where T
    required_size = sizeof(T)
    available_space = length(cmdlist.buffer) - cmdlist.idx
    
    if required_size > available_space
        @warn "Command buffer overflow: need \$required_size bytes, have \$available_space"
        return -1  # Indicate failure
    end
    
    return write_command!(cmdlist, cmd)
end
```

## Command Validation
```julia
function validate_command_buffer(cmdlist::CommandList)
    offset = 0
    command_count = 0
    
    while offset < cmdlist.idx
        try
            # Validate command header
            if offset + sizeof(BaseCommand) > cmdlist.idx
                error("Incomplete command header at offset \$offset")
            end
            
            base = read_command(cmdlist, offset, BaseCommand)
            
            # Validate command size
            if base.size < sizeof(BaseCommand)
                error("Command size too small: \$(base.size) at offset \$offset")
            end
            
            if offset + base.size > cmdlist.idx
                error("Command extends beyond buffer: size \$(base.size) at offset \$offset")
            end
            
            # Validate command type
            if base.type ∉ [COMMAND_RECT, COMMAND_TEXT, COMMAND_ICON, COMMAND_JUMP, COMMAND_CLIP]
                error("Invalid command type: \$(base.type) at offset \$offset")
            end
            
            offset += base.size
            command_count += 1
            
        catch e
            @error "Command validation failed: \$e"
            break
        end
    end
    
    println("Validated \$command_count commands in buffer")
end
```

# Integration with Rendering Pipeline

CommandList integrates seamlessly with the rendering pipeline:

```julia
# Complete rendering workflow
function render_frame(ctx::Context)
    # 1. Generate commands
    begin_frame(ctx)
    build_ui(ctx)           # Application UI code
    end_frame(ctx)
    
    # 2. Process commands  
    cmdlist = ctx.command_list
    iter = CommandIterator(cmdlist)
    
    while true
        (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
        if !has_cmd; break; end
        
        # Dispatch to appropriate renderer
        if cmd_type == COMMAND_RECT
            rect_cmd = read_command(cmdlist, cmd_idx, RectCommand)
            backend_draw_rect(rect_cmd.rect, rect_cmd.color)
        elseif cmd_type == COMMAND_TEXT
            text_cmd = read_command(cmdlist, cmd_idx, TextCommand)
            text_str = get_string(cmdlist, text_cmd.str_index)
            backend_draw_text(text_cmd.font, text_str, text_cmd.pos, text_cmd.color)
        # ... handle other command types
        end
    end
end
```

# See Also

- [`BaseCommand`](@ref): Common header for all commands
- [`CommandIterator`](@ref): Tool for processing CommandList contents
- [`write_command!`](@ref): Function for adding commands
- [`read_command`](@ref): Function for reading commands
- [`write_string!`](@ref), [`get_string`](@ref): String storage functions
- [Command System Guide](commands.md): Detailed command system documentation
- [Performance Optimization](performance.md): CommandList optimization techniques
"""
mutable struct CommandList
    buffer::Vector{UInt8}    # Binary command buffer
    idx::Int32              # Current write position in buffer
    strings::Vector{String}  # String storage for text commands
    string_idx::Int32       # Current write position in string array
    
    CommandList() = new(Vector{UInt8}(undef, COMMANDLIST_SIZE), 0, String[], 0)
end

"""
    CommandIterator

Iterator for traversing the MicroUI command buffer in proper rendering order.

The `CommandIterator` automatically handles jump commands to maintain correct Z-order 
rendering of UI containers. When a jump command is encountered, the iterator follows 
the jump destination seamlessly, allowing backend renderers to process commands in 
the correct visual layering order.

# Fields
- `cmdlist::CommandList`: The command list containing the binary command buffer to iterate over
- `current::CommandPtr`: Current byte position within the command buffer (0-based indexing)

# Constructor
    CommandIterator(cmdlist::CommandList)

Creates a new iterator starting at the beginning of the command buffer (position 0).

# Usage

The iterator is designed to be used with `next_command!` in a loop pattern:

    # Create iterator for a command list
    iter = CommandIterator(ctx.command_list)

    # Process all commands in proper Z-order
    while true
        (has_command, command_type, command_offset) = next_command!(iter)
        if !has_command
            break  # No more commands
        end
        
        # Process command based on type
        if command_type == COMMAND_RECT
            rect_cmd = read_command(ctx.command_list, command_offset, RectCommand)
            # Render rectangle...
        elseif command_type == COMMAND_TEXT
            text_cmd = read_command(ctx.command_list, command_offset, TextCommand)
            # Render text...
        end
    end

# Jump Command Handling

Jump commands (COMMAND_JUMP) are used internally by MicroUI to implement container 
Z-ordering. When containers are sorted by Z-index at the end of a frame, jump commands 
are inserted to link container command sequences in the correct rendering order.

The iterator automatically follows these jumps, so backend code doesn't need to handle 
Z-ordering logic - it simply processes commands in the order the iterator provides them.

# Performance Notes

- The iterator uses unsafe pointer operations for maximum performance
- Jump following is done inline without function call overhead
- Memory access is bounds-checked against the command buffer size

# See Also
- `next_command!`: Advance the iterator to the next command
- `CommandList`: The command buffer structure being iterated
- `read_command`: Read typed command data at a given offset
"""
mutable struct CommandIterator
    cmdlist::CommandList  # Command list to iterate over
    current::CommandPtr  # Current position in buffer
    
    CommandIterator(cmdlist::CommandList) = new(cmdlist, 0)
end

# ===== LAYOUT SYSTEM =====
# The layout system handles automatic positioning of widgets

"""
    Layout

Layout state for managing automatic widget positioning and sizing within containers.

The `Layout` structure maintains the current layout context for a container or layout region.
It handles automatic positioning, sizing, and flow of widgets within a defined area, supporting
both automatic flow layouts and manual positioning.

# Fields
- `body::Rect`: Available area for content placement (excludes padding/margins)
- `next::Rect`: Manually set position/size for the next widget (when using `layout_set_next!`)
- `position::Vec2`: Current layout cursor position for automatic placement
- `size::Vec2`: Default widget size when not explicitly specified
- `max::Vec2`: Maximum extent reached by any widget (used for content size calculation)
- `widths::Vector{Int32}`: Column widths for the current row layout
- `items::Int32`: Number of items configured for the current row
- `item_index::Int32`: Current item index within the row (0-based)
- `next_row::Int32`: Y position where the next row will be placed
- `next_type::Int32`: Type of next layout positioning (RELATIVE or ABSOLUTE)
- `indent::Int32`: Current indentation level (used by treenodes and nested layouts)

# Constructor
    Layout()

Creates a new layout with default values. All rectangles and vectors are initialized to zero,
and the maximum extent is set to the minimum possible values.

# Usage

Layouts are managed automatically by the MicroUI system and typically don't need manual creation:

    # Automatic layout with default spacing
    layout_row!(ctx, 2, [100, 200], 30)  # 2 items: 100px, 200px wide, 30px tall
    widget_rect1 = layout_next(ctx)       # Gets first position
    widget_rect2 = layout_next(ctx)       # Gets second position
    
    # Manual positioning
    layout_set_next!(ctx, Rect(50, 60, 100, 30), false)  # Absolute positioning
    widget_rect3 = layout_next(ctx)       # Uses the manually set rectangle
    
    # Column layouts
    layout_begin_column!(ctx)
    # Widgets placed vertically...
    layout_end_column!(ctx)

# Layout Flow

The layout system works in several modes:

1. **Row Layout**: Widgets are placed horizontally with specified widths
2. **Column Layout**: Widgets are placed vertically in a single column
3. **Manual Layout**: Explicit positioning using `layout_set_next!`
4. **Default Layout**: Single column with automatic sizing

# Width Specification

Row widths can be specified as:
- Positive values: Fixed pixel width
- Zero: Use default widget size
- Negative values: Fill remaining space proportionally

# Performance Notes

- Layout calculations are done incrementally as widgets are placed
- Maximum extent tracking enables automatic container sizing
- Column layouts create nested layout contexts for isolation

# See Also
- `layout_next`: Get the next widget rectangle
- `layout_row!`: Set up horizontal row layout
- `layout_begin_column!`: Start vertical column layout
- `layout_set_next!`: Manually position the next widget
- `push_layout!`: Create nested layout context
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
    Container

Represents a UI container such as a window, panel, or other widget grouping.

Containers are the fundamental building blocks for organizing UI elements in MicroUI.
Each container maintains its own command buffer region, layout state, and visual properties.
Containers can be nested and are rendered in Z-order with automatic clipping and scrolling.

# Fields
- `head::CommandPtr`: Start offset of this container's command sequence in the command buffer
- `tail::CommandPtr`: End offset of this container's command sequence in the command buffer  
- `rect::Rect`: Complete container rectangle in screen coordinates (includes title bar, borders)
- `body::Rect`: Content area rectangle (excludes title bar, scrollbars, borders)
- `content_size::Vec2`: Total size of all content within the container
- `scroll::Vec2`: Current scroll offset (positive values scroll content up/left)
- `zindex::Int32`: Z-order index for rendering (higher values render on top)
- `open::Bool`: Whether the container is currently open and should be rendered

# Constructor
    Container()

Creates a new container with default values. All rectangles are zero-sized, 
scroll offset is zero, Z-index is zero, and the container starts closed.

# Usage

Containers are typically managed through high-level functions rather than direct manipulation:

    # Window container
    if begin_window(ctx, "My Window", Rect(100, 100, 400, 300)) != 0
        # Window content goes here
        label(ctx, "Hello World")
        end_window(ctx)
    end
    
    # Panel container  
    if begin_panel(ctx, "Settings Panel") != 0
        # Panel content goes here
        checkbox!(ctx, "Enable feature", state_ref)
        end_panel(ctx)
    end
    
    # Popup container
    open_popup!(ctx, "Error Dialog")
    if begin_popup(ctx, "Error Dialog") != 0
        text(ctx, "An error occurred!")
        end_popup(ctx)
    end

# Command Buffer Regions

Each container owns a region of the global command buffer, defined by `head` and `tail` offsets.
This allows the rendering system to:

1. Sort containers by Z-index at frame end
2. Link container command sequences with jump commands
3. Render containers in proper visual layering order

# Z-Order Management

Containers are automatically sorted by `zindex` before rendering:
- Higher Z-index values render on top of lower values
- Containers gain focus and move to front when clicked
- Root containers (windows, popups) participate in Z-ordering
- Nested containers inherit Z-order from their parents

# Scrolling System

Scrolling is handled automatically when content exceeds container size:
- `content_size` tracks the total size of all content
- `scroll` offset is applied during layout calculations  
- Scrollbars are drawn when content overflows the body area
- Mouse wheel input automatically targets the hovered container

# Content vs Body Area

- `rect`: Full container including decorations (title bar, borders, scrollbars)
- `body`: Available area for content placement
- `content_size`: Actual size needed by all content (before scrolling)

# Performance Notes

- Containers use object pooling for efficient memory reuse
- Command buffer regions avoid memory copying during Z-order sorting
- Scroll calculations are done incrementally during layout

# See Also
- `begin_window`: Create and manage window containers
- `begin_panel`: Create nested panel containers  
- `begin_popup`: Create popup containers
- `get_container`: Retrieve container by ID from pool
- `bring_to_front!`: Manually adjust container Z-order
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
    Style

Visual style configuration defining the appearance of all UI elements.

The `Style` structure contains all visual parameters used by MicroUI widgets including
colors, sizes, spacing, and layout metrics. It provides a centralized way to customize
the entire UI appearance while maintaining visual consistency across all components.

# Fields
- `font::Font`: Default font used for all text rendering (can be any type depending on backend)
- `size::Vec2`: Default size for widgets when not explicitly specified (width, height in pixels)
- `padding::Int32`: Inner padding inside widgets (space between widget border and content)
- `spacing::Int32`: Spacing between adjacent widgets in layouts
- `indent::Int32`: Indentation amount for nested elements like tree nodes
- `title_height::Int32`: Height of window title bars in pixels
- `scrollbar_size::Int32`: Width of vertical scrollbars and height of horizontal scrollbars
- `thumb_size::Int32`: Minimum size of scrollbar thumb handles
- `colors::Vector{Color}`: Color palette array indexed by ColorId enum values

# Constructor
    Style(font, size, padding, spacing, indent, title_height, scrollbar_size, thumb_size, colors)

Creates a new style with all parameters explicitly specified.

# Usage

Styles are typically used through the context's style field:

    # Use default style
    ctx.style = DEFAULT_STYLE
    
    # Customize colors while keeping other settings
    custom_style = DEFAULT_STYLE
    custom_style.colors[Int(COLOR_BUTTON)] = Color(100, 150, 200, 255)
    ctx.style = custom_style
    
    # Access style properties in widgets
    widget_width = ctx.style.size.x + ctx.style.padding * 2
    title_area = Rect(x, y, width, ctx.style.title_height)

# Color System

The color array is indexed using ColorId enum values:

    COLOR_TEXT         = 1   # Main text color
    COLOR_BORDER       = 2   # Border color for frames  
    COLOR_WINDOWBG     = 3   # Window background
    COLOR_TITLEBG      = 4   # Title bar background
    COLOR_TITLETEXT    = 5   # Title bar text
    COLOR_PANELBG      = 6   # Panel background
    COLOR_BUTTON       = 7   # Button normal state
    COLOR_BUTTONHOVER  = 8   # Button hover state
    COLOR_BUTTONFOCUS  = 9   # Button focused state
    COLOR_BASE         = 10  # Base input control color
    COLOR_BASEHOVER    = 11  # Base input control hover
    COLOR_BASEFOCUS    = 12  # Base input control focused
    COLOR_SCROLLBASE   = 13  # Scrollbar track color
    COLOR_SCROLLTHUMB  = 14  # Scrollbar thumb color

# Default Values

The DEFAULT_STYLE constant provides sensible defaults:
- Font: Backend-dependent (typically set by application)
- Size: 68×10 pixels for standard widgets
- Padding: 5 pixels inner spacing
- Spacing: 4 pixels between widgets
- Indent: 24 pixels for tree nodes
- Title height: 24 pixels
- Scrollbar size: 12 pixels
- Thumb size: 8 pixels minimum
- Colors: Dark theme with high contrast

# Customization Examples

    # Light theme colors
    light_colors = copy(DEFAULT_STYLE.colors)
    light_colors[Int(COLOR_WINDOWBG)] = Color(240, 240, 240, 255)
    light_colors[Int(COLOR_TEXT)] = Color(20, 20, 20, 255)
    
    # Larger widgets for touch interfaces
    touch_style = Style(
        DEFAULT_STYLE.font,
        Vec2(80, 40),  # Larger default size
        8,             # More padding
        6,             # More spacing
        DEFAULT_STYLE.indent,
        32,            # Taller title bars
        16,            # Wider scrollbars
        12,            # Larger thumbs
        DEFAULT_STYLE.colors
    )

# Performance Notes

- Style access is frequent during rendering, so fields are kept as primitive types
- Color lookups use direct array indexing for maximum speed
- Style modifications should be done before frame rendering for consistency

# See Also
- `DEFAULT_STYLE`: Predefined dark theme style
- `ColorId`: Enum values for color array indexing
- `Context`: Structure containing the current style
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
    Stack{T}

Generic stack data structure with overflow protection for managing nested UI contexts.

The `Stack{T}` provides a type-safe stack implementation used throughout MicroUI to manage
nested contexts such as containers, clipping rectangles, layouts, and ID scopes. It includes
built-in overflow protection to prevent stack corruption and provides clear error messages
for debugging.

# Type Parameters
- `T`: The element type stored in the stack

# Fields
- `items::Vector{T}`: Preallocated storage for stack elements
- `idx::Int32`: Current stack depth (0 = empty, 1-based indexing for occupied elements)

# Constructor
    Stack{T}(size::Int)

Creates a new stack with preallocated storage for `size` elements. The stack starts empty
(idx = 0) but has memory already allocated for maximum performance.

# Usage

Stacks are used internally by MicroUI for various nested contexts:

    # Container stack for nested widgets
    container_stack = Stack{Container}(32)
    
    # Clipping rectangle stack
    clip_stack = Stack{Rect}(32)
    
    # ID scope stack for hierarchical naming
    id_stack = Stack{Id}(32)
    
    # Basic operations
    push!(stack, item)      # Add item to top
    item = pop!(stack)      # Remove and return top item  
    item = top(stack)       # Peek at top item without removing
    is_empty = isempty(stack)  # Check if stack is empty

# Stack Operations

The stack supports standard stack operations with safety checks:

    # Push operation with overflow protection
    push!(ctx.clip_stack, new_clip_rect)
    
    # Pop operation with underflow protection  
    old_clip_rect = pop!(ctx.clip_stack)
    
    # Peek at current value
    current_clip = top(ctx.clip_stack)
    
    # Check state
    if !isempty(ctx.id_stack)
        # Process current ID context
    end

# Error Handling

All operations include safety checks:
- `push!`: Throws "Stack overflow" if capacity exceeded
- `pop!`: Throws "Stack underflow" if stack is empty
- `top`: Throws "Stack is empty" if no elements present

# Memory Management

- Storage is preallocated at construction time
- No allocations occur during push/pop operations
- Memory layout is contiguous for cache efficiency
- Stack size is fixed at creation time

# Common Usage Patterns in MicroUI

    # Clipping stack for nested drawing regions
    push_clip_rect!(ctx, widget_bounds)
    # ... draw clipped content ...
    pop_clip_rect!(ctx)
    
    # Container stack for nested layouts
    push!(ctx.container_stack, new_container)
    # ... process container contents ...
    pop!(ctx.container_stack)
    
    # ID stack for hierarchical widget naming
    push_id!(ctx, "panel_name")
    widget_id = get_id(ctx, "button")  # Creates "panel_name/button"
    pop_id!(ctx)

# Performance Notes

- Zero-allocation operations after initial construction
- Direct array access for maximum speed
- Bounds checking adds minimal overhead
- Stack depth is tracked with simple integer arithmetic

# See Also
- `push!`: Add element to stack top
- `pop!`: Remove element from stack top  
- `top`: Access top element without removal
- `isempty`: Check if stack contains elements
"""
mutable struct Stack{T}
    items::Vector{T}  # Stack storage
    idx::Int32       # Current stack depth (0 = empty)
    
    Stack{T}(size::Int) where T = new{T}(Vector{T}(undef, size), 0)
end

"""
    Context

Main context structure containing all UI state and configuration for a MicroUI instance.

The `Context` is the central hub that manages the entire immediate mode GUI system state.
It contains rendering callbacks, visual styling, interaction state, command buffers, 
nested context stacks, resource pools, and input handling. Every MicroUI operation
requires a context instance.

# Rendering Callbacks
- `text_width::Function`: Callback to measure text width: `(font, str) -> width_pixels`
- `text_height::Function`: Callback to get text height: `(font) -> height_pixels`  
- `draw_frame::Function`: Callback to draw widget frames: `(ctx, rect, colorid) -> nothing`

# Visual Configuration
- `style::Style`: Current visual style containing colors, sizes, and spacing

# Core Interaction State
- `hover::Id`: Widget ID currently under the mouse cursor (0 if none)
- `focus::Id`: Widget ID that has keyboard focus (0 if none)
- `last_id::Id`: Most recently generated widget ID
- `last_rect::Rect`: Rectangle of the most recently positioned widget
- `last_zindex::Int32`: Highest Z-index assigned this frame
- `updated_focus::Bool`: Whether focus was explicitly set this frame
- `frame::Int32`: Current frame number (increments each frame)

# Container Management
- `hover_root::Union{Nothing, Container}`: Root container currently under mouse
- `next_hover_root::Union{Nothing, Container}`: Root container under mouse next frame
- `scroll_target::Union{Nothing, Container}`: Container that should receive scroll events

# Text Input State
- `number_edit_buf::String`: Buffer for number widget text editing mode
- `number_edit::Id`: ID of number widget currently in text edit mode

# Command System
- `command_list::CommandList`: Buffer containing all rendering commands for current frame

# Context Stacks (for nested UI elements)
- `root_list::Stack{Container}`: All root containers (windows, popups) this frame
- `container_stack::Stack{Container}`: Stack of nested containers being processed
- `clip_stack::Stack{Rect}`: Stack of nested clipping rectangles
- `id_stack::Stack{Id}`: Stack of nested ID scopes for hierarchical naming
- `layout_stack::Stack{Layout}`: Stack of nested layout contexts

# Resource Pools (for efficient memory reuse)
- `container_pool::Vector{PoolItem}`: Pool metadata for container reuse
- `containers::Vector{Container}`: Actual container storage
- `treenode_pool::Vector{PoolItem}`: Pool metadata for treenode state

# Input State
- `mouse_pos::Vec2`: Current mouse position in screen coordinates
- `last_mouse_pos::Vec2`: Mouse position from previous frame
- `mouse_delta::Vec2`: Mouse movement since last frame
- `scroll_delta::Vec2`: Mouse wheel scroll input this frame
- `mouse_down::UInt8`: Bitmask of currently pressed mouse buttons
- `mouse_pressed::UInt8`: Bitmask of mouse buttons pressed this frame
- `key_down::UInt8`: Bitmask of currently pressed modifier/special keys
- `key_pressed::UInt8`: Bitmask of keys pressed this frame
- `input_text::String`: Text input received this frame

# Constructor
    Context()

Creates a new context with default placeholder callbacks. Applications must call `init!()`
and set proper rendering callbacks before use.

# Initialization

    # Create and initialize context
    ctx = Context()
    init!(ctx)
    
    # Set required rendering callbacks
    ctx.text_width = (font, str) -> backend_measure_text_width(font, str)
    ctx.text_height = font -> backend_get_text_height(font)
    ctx.draw_frame = (ctx, rect, colorid) -> backend_draw_frame(rect, colorid)

# Frame Lifecycle

Every frame must follow this pattern:

    begin_frame(ctx)
    
    # Create UI elements
    if begin_window(ctx, "My Window", Rect(10, 10, 300, 200)) != 0
        if button(ctx, "Click me") != 0
            println("Button clicked!")
        end
        end_window(ctx)
    end
    
    end_frame(ctx)
    
    # Process rendering commands
    render_commands(ctx.command_list)

# Input Handling

Input must be fed to the context each frame:

    # Mouse input
    input_mousemove!(ctx, mouse_x, mouse_y)
    input_mousedown!(ctx, mouse_x, mouse_y, MOUSE_LEFT)
    input_mouseup!(ctx, mouse_x, mouse_y, MOUSE_LEFT)
    input_scroll!(ctx, scroll_x, scroll_y)
    
    # Keyboard input
    input_keydown!(ctx, KEY_CTRL)
    input_keyup!(ctx, KEY_CTRL)
    input_text!(ctx, "typed text")

# Stack Management

The context automatically manages nested contexts:

    # ID scoping for unique widget names
    push_id!(ctx, "panel1")
    widget_id = get_id(ctx, "button")  # Creates unique "panel1/button" ID
    pop_id!(ctx)
    
    # Clipping for constrained drawing
    push_clip_rect!(ctx, widget_bounds)
    # ... draw clipped content ...
    pop_clip_rect!(ctx)

# Resource Pooling

Containers and treenodes use efficient pooling:
- Automatically reuses memory for frequently created/destroyed elements
- Pool items track last usage for automatic cleanup
- Prevents memory fragmentation in long-running applications

# Performance Considerations

- The context is designed for zero allocations during normal operation
- Command buffer is preallocated and reused each frame
- Stack operations use array indexing for maximum speed
- Resource pools eliminate garbage collection pressure

# Error Handling

The context includes assertions for debugging:
- Stack balance verification at frame end
- Buffer overflow detection
- Focus and hover state validation

# See Also
- `init!`: Initialize context to default state
- `begin_frame`: Start a new frame of UI processing
- `end_frame`: Finalize frame and prepare for rendering
- `Style`: Visual styling configuration
- `CommandList`: Rendering command buffer
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