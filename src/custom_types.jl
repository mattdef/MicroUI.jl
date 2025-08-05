"""
# MicroUI Custom Types

Convenient type aliases for commonly used types throughout the MicroUI library.

These type aliases provide semantic meaning, improve code readability, and allow
for easy changes to underlying types if needed. They also help with performance
by using consistent, optimized types throughout the system.

# Design Philosophy

- **Semantic clarity**: `Id` is more meaningful than `UInt32`
- **Performance consistency**: All numeric values use the same `Real` type
- **Backend flexibility**: `Font` can adapt to different rendering systems
- **Memory efficiency**: Types chosen for optimal size and alignment

# Type Categories

- **Identification**: Unique identifiers for UI elements
- **Numeric values**: Floating-point calculations and measurements
- **Resource handles**: References to external resources like fonts
- **Internal pointers**: Efficient navigation within data structures

# Usage Throughout MicroUI

These types appear in function signatures, struct fields, and return values
throughout the library. Understanding their purpose helps with both using
MicroUI effectively and extending it with custom functionality.

# Performance Characteristics

All types are chosen for optimal performance:
- **32-bit alignment**: All types fit efficiently in memory
- **Register-friendly**: Types that fit in CPU registers for fast operations
- **Cache-efficient**: Compact representation improves cache locality

# See Also

- [`Context`](@ref): Uses all these types extensively
- [`get_id`](@ref): Returns `Id` values
- [`slider!`](@ref): Uses `Real` for numeric values
- [Performance Guide](performance.md): Type choice impact on performance
"""

# ===== IDENTIFICATION TYPES =====

"""
    Id

Unique identifier type for widgets and containers, generated from strings.

Widget IDs are used throughout MicroUI to track widget state, handle focus,
and manage interactions. Each widget gets a unique ID based on its name
and the current ID context (from nested containers).

# Type Definition

```julia
const Id = UInt32
```

Uses 32-bit unsigned integers providing 4.3 billion unique IDs, which is
more than sufficient for any realistic UI application.

# ID Generation

IDs are generated using the FNV-1a hashing algorithm from widget names:

```julia
# Basic ID generation
button_id = get_id(ctx, "save_button")
# Returns: UInt32 value like 0x8c4f2a91

# IDs are deterministic - same name gives same ID
id1 = get_id(ctx, "button")  # → 0x12345678
id2 = get_id(ctx, "button")  # → 0x12345678 (same)
```

# Hierarchical ID Context

IDs incorporate their container context to avoid collisions:

```julia
# Same widget name in different contexts = different IDs
begin_window(ctx, "Window1")
    button_id_1 = get_id(ctx, "OK")  # → 0xaabbccdd
end_window(ctx)

begin_window(ctx, "Window2")  
    button_id_2 = get_id(ctx, "OK")  # → 0x11223344 (different!)
end_window(ctx)

# Manual ID scoping
push_id!(ctx, "section1")
    widget_id = get_id(ctx, "item")   # ID includes "section1" context
pop_id!(ctx)
```

# Usage in Widget Functions

Most widget functions automatically generate IDs:

```julia
# These functions call get_id() internally:
button(ctx, "Save")           # ID from "Save"
checkbox!(ctx, "Enable", ref) # ID from "Enable"  
slider!(ctx, value, 0, 100)   # ID from object reference or name

# Manual ID management for advanced cases:
my_id = get_id(ctx, "custom_widget")
if mouse_over(ctx, widget_rect) && ctx.hover != my_id
    ctx.hover = my_id
end
```

# ID Storage and Comparison

IDs are stored and compared as simple integers:

```julia
# Store current widget state
current_focus = ctx.focus      # Type: Id (UInt32)
current_hover = ctx.hover      # Type: Id (UInt32)

# Fast comparison (single CPU instruction)
if widget_id == ctx.focus
    draw_focus_highlight()
end

# IDs in data structures
widget_states = Dict{Id, WidgetState}()
widget_states[button_id] = current_state
```

# ID Collision Handling

While extremely rare, ID collisions can theoretically occur:

```julia
# Collision probability: ~1 in 4.3 billion for random strings
# For typical widget names, collisions are practically impossible

# Best practices to avoid collisions:
# 1. Use descriptive, unique widget names
push_id!(ctx, "settings_dialog")
    push_id!(ctx, "audio_section")
        volume_slider_id = get_id(ctx, "volume")  # Fully qualified context
    pop_id!(ctx)
pop_id!(ctx)

# 2. Include object references for dynamic widgets
for (i, item) in enumerate(items)
    item_id = get_id(ctx, "item_\$(objectid(item))")  # Guaranteed unique
    button(ctx, "Delete \$i")
end
```

# Performance Characteristics

- **Generation**: ~10-20 nanoseconds per ID (FNV-1a hash)
- **Storage**: 4 bytes per ID
- **Comparison**: Single CPU instruction
- **Hash quality**: Good distribution, low collision rate

# Debugging IDs

When debugging widget ID issues:

```julia
# Print widget IDs for inspection
widget_id = get_id(ctx, "problematic_widget")
println("Widget ID: 0x\$(string(widget_id, base=16, pad=8))")

# Trace ID context stack
println("Current ID stack depth: \$(ctx.id_stack.idx)")
for i in 1:ctx.id_stack.idx
    println("  Level \$i: 0x\$(string(ctx.id_stack.items[i], base=16, pad=8))")
end
```

# Integration with External Systems

IDs can be used to integrate with external state management:

```julia
# Map MicroUI widget IDs to application state
widget_to_model = Dict{Id, ModelObject}()

function register_widget(name::String, model::ModelObject)
    widget_id = get_id(ctx, name)
    widget_to_model[widget_id] = model
end

# Use during UI updates
if button(ctx, "save") & Int(RES_SUBMIT) != 0
    button_id = get_id(ctx, "save")
    model = widget_to_model[button_id]
    save_model(model)
end
```

# Macro System Integration

The macro system uses IDs for automatic state management:

```julia
# Macro-generated code uses IDs internally
@button save_btn = "Save"
# Generates: button_id = get_id(ctx, "save_btn")

# Window-specific ID scoping in macros
@window "MyApp" begin
    # All widget IDs automatically scoped to this window
    @button ok = "OK"  # ID includes window context
end
```

# See Also

- [`get_id`](@ref): Generate IDs from strings
- [`push_id!`](@ref), [`pop_id!`](@ref): Manage ID context
- [`Context`](@ref): Stores current focus and hover IDs
- [`HASH_INITIAL`](@ref): Hash algorithm constant
- [Widget ID System](concepts.md#widget-ids): Conceptual overview
"""
const Id = UInt32

# ===== NUMERIC TYPES =====

"""
    Real

Floating point type used for numeric values throughout the MicroUI library.

All numeric computations, widget values, and measurements use this consistent
floating-point type. This ensures predictable behavior, optimal performance,
and consistent precision across the entire UI system.

# Type Definition

```julia
const Real = Float32
```

Uses 32-bit floating-point numbers (IEEE 754 single precision) which provide:
- **Range**: ±3.4 × 10³⁸ (more than sufficient for UI coordinates and values)
- **Precision**: ~7 decimal digits (adequate for UI measurements)
- **Performance**: Native CPU support, fast arithmetic operations

# Why Float32 Instead of Float64?

Float32 was chosen over Float64 for several reasons:

## Memory Efficiency
```julia
# Memory usage comparison:
Float32: 4 bytes per value
Float64: 8 bytes per value

# For a slider with 100 history values:
Float32: 400 bytes
Float64: 800 bytes (100% overhead)
```

## Performance Benefits
- **SIMD operations**: More values fit in vector registers
- **Cache efficiency**: 2× more values per cache line
- **GPU compatibility**: Graphics hardware optimized for 32-bit floats
- **Memory bandwidth**: 50% less data movement

## Precision Requirements
```julia
# Float32 precision is more than adequate for UI:
pixel_position = Real(123.456)    # ±0.001 pixel accuracy
slider_value = Real(0.123456)     # ±0.000001 value precision
angle_degrees = Real(45.67)       # ±0.01 degree accuracy

# Screen coordinates rarely exceed ±32,768 pixels
# Widget values typically range from 0.0 to 1000.0
# Float32 handles these ranges with excellent precision
```

# Usage Throughout MicroUI

All numeric widget values use `Real`:

```julia
# Slider values
volume = Ref(Real(0.8))
slider!(ctx, volume, Real(0.0), Real(1.0))

# Number inputs
temperature = Ref(Real(23.5))
number!(ctx, temperature, Real(0.1))

# Coordinates and measurements
rect = Rect(Real(10), Real(20), Real(100), Real(50))
pos = Vec2(Real(x), Real(y))

# Color components (though stored as UInt8, calculations use Real)
alpha = Real(color.a) / Real(255)  # Normalize to 0.0-1.0
```

# Type Conversions

MicroUI provides automatic conversions for convenience:

```julia
# These conversions happen automatically:
slider!(ctx, value_ref, 0.0, 1.0)      # Float64 → Real
slider!(ctx, value_ref, 0, 100)        # Int → Real

# Manual conversion when needed:
user_input = 42.7                      # Float64
widget_value = Real(user_input)        # Explicit conversion

# Ref handling with automatic conversion:
volume = Ref(0.5)                      # Creates Ref{Float64}
# MicroUI widgets automatically convert to/from Real
```

# Precision Considerations

Float32 provides excellent precision for UI applications:

```julia
# Precision examples:
Real(1.0) + Real(1e-7)    # Still distinguishable
Real(1000.0) + Real(0.01) # Still accurate

# When precision matters:
accumulated_error = Real(0.0)
for i in 1:1000000
    accumulated_error += Real(0.1)  # Some rounding error
end
# Result: ~99999.99 instead of 100000.0 (tiny error)

# For UI applications, this level of error is negligible
```

# Performance Characteristics

Real (Float32) operations are highly optimized:

```julia
# Arithmetic operations: 1-2 CPU cycles
result = Real(a) + Real(b)
result = Real(a) * Real(b)

# SIMD operations: 4-8 values per instruction
values = [Real(1.0), Real(2.0), Real(3.0), Real(4.0)]
# Can be processed in parallel with single SIMD instruction

# Memory layout efficiency:
struct Point
    x::Real  # 4 bytes
    y::Real  # 4 bytes
end
# Total: 8 bytes (fits in single cache line easily)
```

# Integration with Julia Ecosystem

Real works seamlessly with Julia's numeric system:

```julia
# Mathematical functions work directly:
angle = Real(π/4)
sin_val = sin(angle)              # Returns Float32
cos_val = cos(angle)              # Returns Float32

# Broadcasting and array operations:
values = Real[1.0, 2.0, 3.0, 4.0]
scaled = values .* Real(2.0)      # Efficient SIMD operations

# Integration with LinearAlgebra:
using LinearAlgebra
matrix = Matrix{Real}(undef, 3, 3)
vector = Vector{Real}([1.0, 2.0, 3.0])
```

# Common Patterns

## Range Normalization
```julia
# Convert values between different ranges
function normalize_range(value::Real, old_min::Real, old_max::Real, 
                        new_min::Real, new_max::Real)
    old_range = old_max - old_min
    new_range = new_max - new_min
    return ((value - old_min) * new_range / old_range) + new_min
end

# Usage in sliders:
screen_pos = normalize_range(slider_value, Real(0.0), Real(1.0), 
                           Real(rect.x), Real(rect.x + rect.w))
```

## Smooth Interpolation
```julia
# Linear interpolation for animations
function lerp(a::Real, b::Real, t::Real)
    return a + t * (b - a)
end

# Usage:
current_value = lerp(old_value, target_value, Real(0.1))  # 10% per frame
```

## Value Clamping
```julia
# Ensure values stay within bounds
function clamp_real(value::Real, min_val::Real, max_val::Real)
    return max(min_val, min(max_val, value))
end

# Usage in widgets:
slider_value[] = clamp_real(new_value, Real(0.0), Real(1.0))
```

# Debugging and Inspection

When debugging numeric issues:

```julia
# Check for common floating-point issues:
value = Real(0.1) + Real(0.2)
println("Value: \$value")  # Might show 0.30000001 due to rounding

# Use appropriate comparisons:
function approximately_equal(a::Real, b::Real, epsilon::Real = Real(1e-6))
    return abs(a - b) < epsilon
end

# Format for display:
formatted = @sprintf("%.3f", value)  # Show 3 decimal places
```

# See Also

- [`slider!`](@ref), [`number!`](@ref): Widgets using Real values
- [`Vec2`](@ref), [`Rect`](@ref): Structures using Real coordinates
- [`format_real`](@ref): Number formatting function
- [Julia Float32 Documentation](https://docs.julialang.org/en/v1/manual/integers-and-floating-point-numbers/)
"""
const Real = Float32

# ===== RESOURCE HANDLE TYPES =====

"""
    Font

Font handle type that can represent any font resource depending on the rendering backend.

The `Font` type is intentionally generic to allow MicroUI to work with different
rendering systems, each of which may represent fonts differently. This flexibility
is essential for the backend-independent design of MicroUI.

# Type Definition

```julia
const Font = Any
```

Uses Julia's `Any` type to accommodate different font representations across
various rendering backends and platforms.

# Backend-Specific Representations

Different rendering backends use different font representations:

## OpenGL/Graphics Libraries
```julia
# OpenGL with text rendering library:
font_handle = load_opengl_font("Arial.ttf", 16)  # → TextureID + metadata
ctx.text_width = (font, str) -> measure_opengl_text(font, str)

# GLFW + freetype:
struct GLFont
    texture_id::UInt32
    char_data::Dict{Char, CharInfo}
    size::Int
end
font = GLFont(texture, char_map, 16)
```

## Native GUI Frameworks
```julia
# Windows GDI:
font = CreateFont(16, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, ...)  # HFONT

# macOS Core Text:
font = CTFontCreateWithName("Arial", 16.0, C_NULL)  # CTFontRef

# X11/Xft:
font = XftFontOpen(display, screen, XFT_FAMILY, XftTypeString, "Arial", ...)
```

## Web/JavaScript Backends
```julia
# HTML5 Canvas:
font = "16px Arial"  # CSS font string

# WebGL with text textures:
struct WebFont
    font_atlas::WebGLTexture
    glyph_data::Dict{Char, GlyphInfo}
    css_name::String
end
```

## Software Rendering
```julia
# Pure Julia software rendering:
struct SoftwareFont
    bitmap_data::Matrix{UInt8}
    glyph_metrics::Dict{Char, Rect}
    baseline::Int
    line_height::Int
end
```

# Usage in MicroUI

Font handles are primarily used in text measurement and drawing:

```julia
# Text measurement callback (set by application):
ctx.text_width = function(font::Font, str::String)
    # Backend-specific text measurement
    return backend_measure_text(font, str)
end

ctx.text_height = function(font::Font)
    # Backend-specific line height
    return backend_get_line_height(font)
end

# Text drawing (in command processing):
function process_text_command(cmd::TextCommand)
    # cmd.font is of type Font
    backend_draw_text(cmd.font, text_string, cmd.pos, cmd.color)
end
```

# Default Font Handling

Most applications use a single default font:

```julia
# Simple approach: single default font
default_font = load_application_font()
ctx.style.font = default_font

# All text uses the default font:
ctx.text_width = (font, str) -> measure_text(default_font, str)
ctx.text_height = font -> get_line_height(default_font)
```

# Multi-Font Support

Advanced applications can support multiple fonts:

```julia
# Font registry approach:
struct FontRegistry
    fonts::Dict{String, Any}  # Font name → backend-specific handle
    default::String
end

registry = FontRegistry(Dict(
    "ui" => load_ui_font(),
    "mono" => load_monospace_font(),
    "heading" => load_heading_font()
), "ui")

# Font-aware text measurement:
function measure_text_with_registry(font_name::String, text::String)
    font_handle = registry.fonts[font_name]
    return backend_measure_text(font_handle, text)
end

# Usage in widgets:
ctx.text_width = (font, str) -> begin
    font_name = font isa String ? font : "ui"  # Default to UI font
    return measure_text_with_registry(font_name, str)
end
```

# Font Loading Examples

## SDL2 + SDL_ttf
```julia
using SDL2

function load_sdl_font(path::String, size::Int)
    font_ptr = TTF_OpenFont(path, Cint(size))
    if font_ptr == C_NULL
        error("Failed to load font: \$path")
    end
    return font_ptr  # TTF_Font pointer
end

# Text measurement with SDL:
function sdl_text_width(font, text::String)
    w_ref = Ref{Cint}(0)
    h_ref = Ref{Cint}(0)
    TTF_SizeUTF8(font, text, w_ref, h_ref)
    return Int(w_ref[])
end
```

## Cairo Graphics
```julia
using Cairo

function setup_cairo_font(cr::CairoContext, family::String, size::Real)
    Cairo.select_font_face(cr, family, Cairo.FONT_SLANT_NORMAL, Cairo.FONT_WEIGHT_NORMAL)
    Cairo.set_font_size(cr, size)
    return cr  # Context itself acts as font handle
end

function cairo_text_width(cr::CairoContext, text::String)
    text_extents = Cairo.text_extents(cr, text)
    return text_extents.width
end
```

## Pure Julia/Images.jl
```julia
using Images, ImageDraw, FileIO

struct JuliaFont
    image_data::Matrix{RGB{N0f8}}
    char_positions::Dict{Char, Rect}
    line_height::Int
end

function load_bitmap_font(path::String)
    font_image = load(path)
    char_map = parse_font_metadata(path * ".meta")
    return JuliaFont(font_image, char_map, 16)
end
```

# Performance Considerations

Since Font is `Any`, there's a small performance cost:

```julia
# Type-unstable (but necessary for flexibility):
function measure_text(font::Font, text::String)
    # Julia can't optimize this call site
    return backend_specific_measure(font, text)
end

# Optimization: use function barriers
function measure_text_optimized(font::Font, text::String)
    return _measure_text_impl(font, text)  # Separate function for type stability
end

function _measure_text_impl(font::T, text::String) where T
    # This function is type-stable for each font type T
    return backend_specific_measure(font, text)
end
```

# Font Caching and Management

Efficient font management for performance:

```julia
# Font cache to avoid repeated loading:
const FONT_CACHE = Dict{String, Any}()

function get_cached_font(name::String, size::Int)
    key = "\$name_\$size"
    if !haskey(FONT_CACHE, key)
        FONT_CACHE[key] = load_font_from_disk(name, size)
    end
    return FONT_CACHE[key]
end

# Cleanup when needed:
function cleanup_fonts()
    for font in values(FONT_CACHE)
        backend_free_font(font)
    end
    empty!(FONT_CACHE)
end
```

# Error Handling

Robust font handling with fallbacks:

```julia
function safe_font_loader(preferred::String, fallback::String = "default")
    try
        return load_font(preferred)
    catch e
        @warn "Failed to load preferred font \$preferred: \$e"
        try
            return load_font(fallback)
        catch e2
            @warn "Failed to load fallback font \$fallback: \$e2"
            return create_minimal_font()  # Last resort
        end
    end
end
```

# See Also

- [`TextCommand`](@ref): Structure that stores Font handles
- [`Style`](@ref): Contains default font for the UI
- [`draw_text!`](@ref): Function that uses Font for rendering
- [Backend Integration Guide](backends.md): Implementing font support
- [Text Rendering Guide](text.md): Advanced text handling techniques
"""
const Font = Any

# ===== INTERNAL POINTER TYPES =====

"""
    CommandPtr

Pointer/index type for navigating within the command buffer.

Command pointers are used to create links and jumps within the command buffer,
enabling efficient traversal and non-linear command execution for features
like Z-ordering and container rendering.

# Type Definition

```julia
const CommandPtr = Int32
```

Uses 32-bit signed integers to represent byte offsets within the command buffer.
The signed type allows for relative addressing and error checking with negative
values indicating invalid states.

# Usage in Command System

CommandPtr values represent byte offsets into the command buffer:

```julia
# Command buffer layout:
# [BaseCommand][RectCommand][BaseCommand][TextCommand][...]
#  offset=0     offset=16    offset=80     offset=96

# CommandPtr points to the start of any command:
rect_cmd_ptr = CommandPtr(0)   # Points to first command
text_cmd_ptr = CommandPtr(80)  # Points to text command
```

# Container Command Linking

Containers use CommandPtr to manage their command buffer regions:

```julia
# Container structure includes command pointers:
mutable struct Container
    head::CommandPtr  # Start of container's commands
    tail::CommandPtr  # End of container's commands (jump command location)
    # ... other fields
end

# Container command sequence:
# [JUMP to next container][container commands...][JUMP to end]
#  ↑ head points here                           ↑ tail points here
```

# Jump Command Implementation

Jump commands use CommandPtr for non-linear buffer traversal:

```julia
struct JumpCommand
    base::BaseCommand
    dst::CommandPtr    # Destination offset in command buffer
end

# Creating a jump:
destination = CommandPtr(1024)  # Jump to offset 1024
jump_cmd = JumpCommand(
    BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
    destination
)
```

# Command Buffer Traversal

CommandPtr enables efficient command iteration:

```julia
# Manual command iteration:
current_ptr = CommandPtr(0)
while current_ptr < ctx.command_list.idx
    # Read command at current position
    base_cmd = read_command(ctx.command_list, current_ptr, BaseCommand)
    
    if base_cmd.type == COMMAND_JUMP
        # Follow jump to new location
        jump_cmd = read_command(ctx.command_list, current_ptr, JumpCommand)
        current_ptr = jump_cmd.dst
    else
        # Process normal command
        process_command(base_cmd.type, current_ptr)
        current_ptr += base_cmd.size  # Advance by command size
    end
end
```

# Z-Order Rendering

CommandPtr enables proper Z-order rendering through jump chains:

```julia
# Z-order example: Window1 (z=1), Window2 (z=5), Window3 (z=3)
# Command buffer layout after sorting:

# Window1 commands: [RECT][TEXT][JUMP to Window3]
# Window3 commands: [RECT][ICON][JUMP to Window2]  
# Window2 commands: [RECT][JUMP to end]

# Rendering order: Window1 → Window3 → Window2 (back to front)
```

# CommandIterator Integration

The CommandIterator uses CommandPtr internally:

```julia
mutable struct CommandIterator
    cmdlist::CommandList
    current::CommandPtr    # Current position in buffer
end

function next_command!(iter::CommandIterator)
    if iter.current >= iter.cmdlist.idx
        return (false, COMMAND_JUMP, CommandPtr(0))  # End of buffer
    end
    
    # Read command at current position
    cmd_ptr = iter.current
    base_cmd = read_command(iter.cmdlist, cmd_ptr, BaseCommand)
    
    if base_cmd.type == COMMAND_JUMP
        # Follow jump, don't return jump command to caller
        jump_cmd = read_command(iter.cmdlist, cmd_ptr, JumpCommand)
        iter.current = jump_cmd.dst
        return next_command!(iter)  # Recursive call to get next real command
    else
        # Advance to next command and return current
        iter.current += base_cmd.size
        return (true, base_cmd.type, cmd_ptr)
    end
end
```

# Memory and Buffer Management

CommandPtr values must stay within valid buffer bounds:

```julia
# Bounds checking:
function validate_command_ptr(cmdlist::CommandList, ptr::CommandPtr)
    if ptr < 0
        error("Invalid command pointer: \$ptr (negative)")
    end
    if ptr >= cmdlist.idx
        error("Command pointer \$ptr exceeds buffer size \$(cmdlist.idx)")
    end
    return true
end

# Safe command reading:
function safe_read_command(cmdlist::CommandList, ptr::CommandPtr, ::Type{T}) where T
    validate_command_ptr(cmdlist, ptr)
    if ptr + sizeof(T) > cmdlist.idx
        error("Command at \$ptr extends beyond buffer")
    end
    return read_command(cmdlist, ptr, T)
end
```

# Performance Characteristics

CommandPtr operations are highly efficient:

- **Storage**: 4 bytes per pointer
- **Arithmetic**: Simple integer addition/subtraction
- **Dereferencing**: Direct memory access with offset
- **Comparison**: Single CPU instruction

# Command Buffer Fragmentation

CommandPtr allows efficient buffer usage without fragmentation:

```julia
# Commands are packed sequentially:
# [CMD1: 32 bytes][CMD2: 48 bytes][CMD3: 16 bytes][...]
#  ptr=0           ptr=32          ptr=80

# No gaps or alignment padding needed
# CommandPtr directly indexes into packed data
```

# Debugging Command Buffers

CommandPtr values help with debugging:

```julia
function debug_command_buffer(cmdlist::CommandList)
    println("Command buffer contents:")
    ptr = CommandPtr(0)
    
    while ptr < cmdlist.idx
        base_cmd = read_command(cmdlist, ptr, BaseCommand)
        println("  Offset \$ptr: \$(base_cmd.type) (size: \$(base_cmd.size))")
        
        if base_cmd.type == COMMAND_JUMP
            jump_cmd = read_command(cmdlist, ptr, JumpCommand)
            println("    → Jump to offset \$(jump_cmd.dst)")
        end
        
        ptr += base_cmd.size
    end
end
```

# Error Conditions

CommandPtr can represent error states:

```julia
const INVALID_COMMAND_PTR = CommandPtr(-1)

function find_command_by_type(cmdlist::CommandList, cmd_type::CommandType)
    ptr = CommandPtr(0)
    while ptr < cmdlist.idx
        base_cmd = read_command(cmdlist, ptr, BaseCommand)
        if base_cmd.type == cmd_type
            return ptr  # Found it
        end
        ptr += base_cmd.size
    end
    return INVALID_COMMAND_PTR  # Not found
end

# Usage:
text_cmd_ptr = find_command_by_type(cmdlist, COMMAND_TEXT)
if text_cmd_ptr != INVALID_COMMAND_PTR
    # Process text command
    text_cmd = read_command(cmdlist, text_cmd_ptr, TextCommand)
end
```

# See Also

- [`CommandList`](@ref): Buffer that CommandPtr indexes into
- [`JumpCommand`](@ref): Command type that uses CommandPtr
- [`CommandIterator`](@ref): Uses CommandPtr for traversal
- [`Container`](@ref): Stores head/tail CommandPtr values
- [Command System Guide](commands.md): Detailed command buffer documentation
"""
const CommandPtr = Int32

"""
    Command

Abstract base type for all rendering commands in the MicroUI command system.

Command serves as the parent type for all specific command types used in
MicroUI's backend-independent rendering system. All concrete command types
inherit from this abstract type to ensure type safety and enable polymorphic
handling of different command types.

# Design Rationale

## Command Pattern Benefits
- **Backend independence**: Commands can be interpreted by any graphics system
- **Deferred rendering**: UI logic runs separately from actual drawing
- **Optimization opportunities**: Commands can be batched, culled, or reordered
- **Debugging and recording**: Commands can be logged, saved, or replayed

## Type Hierarchy
```julia
abstract type Command end

# Concrete command types:
struct RectCommand <: Command
struct TextCommand <: Command  
struct IconCommand <: Command
struct JumpCommand <: Command
struct ClipCommand <: Command
```

# Command Buffer Architecture

Commands are stored in a binary buffer for efficient processing:

```julia
# Command buffer contains a sequence of heterogeneous commands:
# [RectCommand][TextCommand][ClipCommand][JumpCommand][...]

# Each command starts with BaseCommand header:
struct BaseCommand
    type::CommandType  # Identifies the specific command type
    size::Int32       # Size in bytes for buffer traversal
end
```

# Usage in Rendering Pipeline

The command system enables a clean separation between UI logic and rendering:

```julia
# UI Phase: Generate commands
begin_frame(ctx)
draw_rect!(ctx, rect, color)           # → Creates RectCommand
draw_text!(ctx, font, "Hello", pos, color)  # → Creates TextCommand
end_frame(ctx)

# Rendering Phase: Process commands  
iter = CommandIterator(ctx.command_list)
while true
    (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
    if !has_cmd; break; end
    
    # Dispatch based on command type
    if cmd_type == COMMAND_RECT
        cmd = read_command(ctx.command_list, cmd_idx, RectCommand)
        backend_draw_rect(cmd.rect, cmd.color)
    elseif cmd_type == COMMAND_TEXT
        cmd = read_command(ctx.command_list, cmd_idx, TextCommand)
        text_str = get_string(ctx.command_list, cmd.str_index)
        backend_draw_text(cmd.font, text_str, cmd.pos, cmd.color)
    # ... handle other command types
    end
end
```

# Type Safety and Polymorphism

The Command abstract type provides type safety while allowing flexibility:

```julia
# Type-safe command processing
function process_command(cmd::Command)
    if cmd isa RectCommand
        process_rect_command(cmd)
    elseif cmd isa TextCommand
        process_text_command(cmd)
    # ... handle other types
    else
        error("Unknown command type: \$(typeof(cmd))")
    end
end

# Generic command handling
function get_command_bounds(cmd::Command)
    if cmd isa RectCommand
        return cmd.rect
    elseif cmd isa TextCommand
        return Rect(cmd.pos.x, cmd.pos.y, text_width(cmd), text_height(cmd))
    elseif cmd isa IconCommand
        return cmd.rect
    else
        return Rect(0, 0, 0, 0)  # Unknown bounds
    end
end
```

# Command Validation and Debugging

The abstract type enables generic validation and debugging tools:

```julia
# Generic command validation
function validate_command(cmd::Command)
    if cmd isa RectCommand
        return is_valid_rect(cmd.rect) && is_valid_color(cmd.color)
    elseif cmd isa TextCommand
        return cmd.str_index > 0 && cmd.str_length > 0
    # ... validate other types
    end
end

# Command statistics and profiling
function analyze_commands(commands::Vector{Command})
    stats = Dict{Type, Int}()
    for cmd in commands
        cmd_type = typeof(cmd)
        stats[cmd_type] = get(stats, cmd_type, 0) + 1
    end
    return stats
end
```

# Performance Considerations

While Command is an abstract type, the command system is designed for performance:

- **Minimal abstraction overhead**: Commands are stored as binary data, not objects
- **Type-stable dispatch**: Command type is known at processing time
- **Cache-friendly access**: Commands are processed sequentially from a buffer
- **No dynamic dispatch**: Command type is determined from `CommandType` enum

# Integration with Backend Systems

The Command abstract type facilitates integration with various rendering backends:

```julia
# OpenGL backend
function render_command_opengl(cmd::Command)
    if cmd isa RectCommand
        glColor4ub(cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a)
        glRecti(cmd.rect.x, cmd.rect.y, cmd.rect.x + cmd.rect.w, cmd.rect.y + cmd.rect.h)
    # ... other OpenGL rendering
    end
end

# Software rendering backend
function render_command_software(cmd::Command, framebuffer::Matrix{Color})
    if cmd isa RectCommand
        fill_rect!(framebuffer, cmd.rect, cmd.color)
    # ... other software rendering
    end
end

# Web/Canvas backend  
function render_command_web(cmd::Command, canvas_context)
    if cmd isa RectCommand
        canvas_context.fillStyle = color_to_css(cmd.color)
        canvas_context.fillRect(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h)
    # ... other web rendering
    end
end
```

# Future Extensibility

The Command abstract type makes it easy to add new command types:

```julia
# Custom command for advanced graphics
struct GradientCommand <: Command
    base::BaseCommand
    rect::Rect
    start_color::Color
    end_color::Color
    direction::Vec2
end

# Custom command for vector graphics
struct BezierCommand <: Command
    base::BaseCommand
    control_points::Vector{Vec2}
    color::Color
    thickness::Real
end
```

# See Also

- [`BaseCommand`](@ref): Common header for all commands
- [`RectCommand`](@ref), [`TextCommand`](@ref): Concrete command types
- [`CommandType`](@ref): Enumeration of command types
- [`CommandList`](@ref): Storage for command sequences
- [`CommandIterator`](@ref): Tool for processing command sequences
- [Command System Guide](commands.md): Detailed command system documentation
"""
abstract type Command end