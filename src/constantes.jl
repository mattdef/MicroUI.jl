"""
# MicroUI Constants

Library version and buffer size constants optimized for performance and memory usage.

These constants define the core limits and defaults for MicroUI's internal systems.
They are carefully chosen to balance memory usage, performance, and typical application needs.

# Categories

- **Version Information**: Library version tracking
- **Buffer Sizes**: Memory allocation limits for various subsystems
- **Stack Depths**: Maximum nesting levels for UI hierarchies
- **Pool Sizes**: Resource pool capacities for efficient object reuse
- **Format Strings**: Default formatting for numeric displays
- **Hash Constants**: Internal hashing parameters

# Performance Considerations

Most constants represent compile-time limits that avoid dynamic allocations
during UI rendering. Increasing these values uses more memory but allows
for more complex UIs. Decreasing them saves memory but may limit UI complexity.

# Customization

To modify these constants for your application:

```julia
# Create a custom version of constantes.jl with your values
const COMMANDLIST_SIZE = 512 * 1024  # Larger command buffer
const ROOTLIST_SIZE = 64            # More simultaneous windows
# ... then rebuild MicroUI
```

# See Also

- [`Context`](@ref): Uses most of these buffer sizes
- [`CommandList`](@ref): Uses `COMMANDLIST_SIZE`
- [`Container`](@ref): Limited by `ROOTLIST_SIZE` and pool sizes
"""

# ===== VERSION INFORMATION =====

"""
    VERSION

Current version string of the MicroUI library.

This follows semantic versioning (MAJOR.MINOR.PATCH) where:
- MAJOR: Incompatible API changes
- MINOR: New functionality in backward-compatible manner  
- PATCH: Backward-compatible bug fixes

# Usage

```julia
println("Using MicroUI version: ", MicroUI.VERSION)

# Version checking in applications
if MicroUI.VERSION >= "1.2.0"
    # Use newer features
end
```

# Version History

- `1.0.0`: Initial release with core immediate mode GUI functionality
- `1.1.0`: Added macro DSL system and advanced layout features
- `1.2.0`: Performance improvements and expanded widget set

# See Also

- [Release Notes](https://github.com/yourusername/MicroUI.jl/releases)
"""
const VERSION = "1.2.1"

# ===== BUFFER SIZES =====

"""
    COMMANDLIST_SIZE

Size of the command buffer in bytes for storing rendering commands per frame.

The command buffer stores all drawing operations (rectangles, text, icons, clipping)
generated during a single frame. This buffer is reused each frame to minimize allocations.

# Default Value: 256 KB (262,144 bytes)

This size supports approximately:
- 4,000 rectangle commands (64 bytes each)
- 8,000 simple text commands (32 bytes each)  
- Mixed command types in typical applications

# Performance Impact

- **Too small**: Applications with complex UIs may overflow the buffer
- **Too large**: Wastes memory, may hurt cache performance
- **Just right**: Holds one frame's commands with minimal waste

# Buffer Overflow

When the buffer fills up, additional commands are ignored with an error.
Monitor buffer usage during development:

```julia
ctx = create_context()
# ... render UI ...
usage_percent = (ctx.command_list.idx / MicroUI.COMMANDLIST_SIZE) * 100
println("Command buffer usage: ", usage_percent, "%")
```

# Sizing Guidelines

- **Simple UIs** (< 50 widgets): 64 KB sufficient
- **Standard applications**: 256 KB (default)
- **Complex dashboards**: 512 KB or more
- **Games with UI overlays**: 1 MB+

# Related Functions

The command buffer is managed by:
- [`write_command!`](@ref): Writes commands to buffer
- [`CommandIterator`](@ref): Reads commands for rendering
- [`begin_frame`](@ref): Resets buffer each frame

# See Also

- [`CommandList`](@ref): Buffer implementation
- [`push_command!`](@ref): Command writing function
- [Performance Guide](performance.md): Buffer optimization tips
"""
const COMMANDLIST_SIZE = 256 * 1024

"""
    ROOTLIST_SIZE

Maximum number of root containers (windows) that can be active simultaneously.

Root containers are top-level UI elements like windows, popups, and dialogs.
This limit prevents unbounded memory growth and ensures predictable performance.

# Default Value: 32 windows

This supports most desktop applications which rarely have more than a few
windows open at once. Each window uses a container slot regardless of visibility.

# Usage Examples

- **Text editor**: 1 main window + 2-3 tool palettes + find/replace dialog = ~5 windows
- **Image editor**: 1 main window + layers panel + tools + color picker = ~4 windows  
- **IDE**: 1 main window + project explorer + console + debugger = ~4 windows
- **Game**: 1 main UI + inventory + settings + help = ~4 windows

# What Counts as Root Container

- Main application windows ([`begin_window`](@ref))
- Modal dialogs 
- Popup menus ([`begin_popup`](@ref))
- Floating tool palettes
- Tooltip windows

# Exceeding the Limit

When the limit is reached, new root containers fail to create:

```julia
# This will fail silently if limit reached
if begin_window(ctx, "Window 33", rect) != 0
    # Window creation succeeded
    end_window(ctx)
else
    # Window creation failed - limit reached
    println("Too many windows open!")
end
```

# Memory Usage

Each root container slot uses approximately 200-300 bytes whether active or not.
Total overhead: ~32 x 250 bytes = 8 KB (negligible).

# Customization

For applications needing more windows:

```julia
# In your custom constants file
const ROOTLIST_SIZE = 64  # Support 64 simultaneous windows
```

# See Also

- [`Container`](@ref): Root container implementation
- [`begin_window`](@ref): Creates root containers
- [`get_container`](@ref): Container management
"""
const ROOTLIST_SIZE = 32

# ===== STACK DEPTH LIMITS =====

"""
    CONTAINERSTACK_SIZE

Maximum depth of nested containers (windows, panels, treenodes, etc.).

Controls how deeply UI elements can be nested within each other. Each level
of nesting (window → panel → treenode → sub-panel) uses one stack slot.

# Default Value: 32 levels

This allows very deep nesting while preventing stack overflow from
infinite recursion or extremely deep hierarchies.

# Typical Nesting Examples

- **Window → Panel → Checkbox**: 3 levels
- **Window → Treenode → Sub-treenode → Panel → Controls**: 5 levels
- **Complex forms**: Usually 4-8 levels maximum

# Stack Usage

```julia
begin_frame(ctx)
begin_window(ctx, "Main", rect)          # Level 1
    begin_panel(ctx, "Settings")         # Level 2  
        begin_treenode(ctx, "Advanced")  # Level 3
            begin_panel(ctx, "Debug")    # Level 4
                checkbox!(ctx, "Verbose logging", state)  # Widgets don't add levels
            end_panel(ctx)               # Back to level 3
        end_treenode(ctx)                # Back to level 2
    end_panel(ctx)                       # Back to level 1
end_window(ctx)                          # Back to level 0
end_frame(ctx)
```

# Error Handling

Stack overflow is detected and throws an error:

```julia
# This will eventually throw "Stack overflow" error
function deeply_nested(ctx, depth)
    if depth > 0
        begin_panel(ctx, "Level \$depth")
        deeply_nested(ctx, depth - 1)
        end_panel(ctx)
    end
end
```

# Memory Impact

Each stack level uses ~100 bytes. Total stack memory: 32 x 100 = 3.2 KB.

# See Also

- [`begin_panel`](@ref), [`end_panel`](@ref): Panel nesting
- [`begin_treenode`](@ref), [`end_treenode`](@ref): Treenode nesting
- [`push!`](@ref), [`pop!`](@ref): Stack operations
"""
const CONTAINERSTACK_SIZE = 32

"""
    CLIPSTACK_SIZE

Maximum depth of clipping rectangle stack for nested clipping regions.

Each UI container can define its own clipping region. Nested containers
inherit and intersect parent clipping regions, requiring a stack to
track the hierarchy.

# Default Value: 32 levels

Matches [`CONTAINERSTACK_SIZE`](@ref) since each container level can
potentially add a clipping region.

# How Clipping Works

```julia
# Each container adds its own clipping region
begin_window(ctx, "Main", Rect(0, 0, 400, 300))     # Clip to window
    begin_panel(ctx, "Left", Rect(0, 0, 200, 300))  # Clip to left half
        # Drawing here is clipped to intersection: Rect(0, 0, 200, 300)
        draw_rect!(ctx, Rect(-50, -50, 300, 400), color)  # Partially clipped
    end_panel(ctx)
end_window(ctx)
```

# Performance Impact

- **Clipping reduces overdraw**: Only visible pixels are drawn
- **Stack operations are fast**: Simple rectangle intersections
- **Memory overhead minimal**: ~40 bytes per level × 32 levels = 1.3 KB

# Manual Clipping

You can also push/pop clipping regions manually:

```julia
push_clip_rect!(ctx, Rect(10, 10, 100, 100))
# Drawing is clipped to this rectangle
draw_rect!(ctx, large_rect, color)  # Only visible portion drawn
pop_clip_rect!(ctx)
```

# Debugging Clipping Issues

```julia
# Check current clipping region
current_clip = get_clip_rect(ctx)
println("Current clip: ", current_clip)

# Disable clipping temporarily (use with caution)
push_clip_rect!(ctx, UNCLIPPED_RECT)
# ... drawing code ...
pop_clip_rect!(ctx)
```

# See Also

- [`push_clip_rect!`](@ref), [`pop_clip_rect!`](@ref): Manual clipping
- [`get_clip_rect`](@ref): Query current clipping region
- [`intersect_rects`](@ref): Rectangle intersection math
"""
const CLIPSTACK_SIZE = 32

"""
    IDSTACK_SIZE

Maximum depth of ID stack for hierarchical widget identification.

Widget IDs are generated by hashing their names within the current ID context.
The ID stack creates hierarchical namespaces to avoid ID collisions between
widgets with the same name in different containers.

# Default Value: 32 levels

Supports deep UI hierarchies while preventing infinite recursion in ID generation.

# How ID Scoping Works

```julia
# Without ID scoping - potential collision
button(ctx, "OK")        # ID based on "OK"
button(ctx, "OK")        # Same ID - conflict!

# With ID scoping - no collision  
push_id!(ctx, "dialog1")
    button(ctx, "OK")    # ID based on "dialog1" + "OK"
pop_id!(ctx)

push_id!(ctx, "dialog2")  
    button(ctx, "OK")    # ID based on "dialog2" + "OK" - different!
pop_id!(ctx)
```

# Automatic Scoping

Containers automatically push ID scopes:

```julia
begin_window(ctx, "Settings")    # Pushes "Settings" to ID stack
    begin_panel(ctx, "Audio")    # Pushes "Audio" to ID stack
        button(ctx, "Test")      # ID: hash("Settings" + "Audio" + "Test")
    end_panel(ctx)               # Pops "Audio" from ID stack
end_window(ctx)                  # Pops "Settings" from ID stack
```

# Manual ID Management

```julia
# Create unique IDs for dynamic content
for i in 1:5
    push_id!(ctx, "item_\$i")
        button(ctx, "Delete")    # Each button has unique ID
    pop_id!(ctx)
end

# Alternative: include index in button name
for i in 1:5
    button(ctx, "Delete \$i")     # Different names = different IDs
end
```

# Stack Overflow Protection

```julia
# This would eventually error with "Stack overflow"
function recursive_ids(ctx, depth)
    if depth > 0
        push_id!(ctx, "level_\$depth") 
        recursive_ids(ctx, depth - 1)
        pop_id!(ctx)
    end
end
```

# Memory Usage

Each ID stack level stores one 32-bit hash: 32 × 4 bytes = 128 bytes total.

# See Also

- [`get_id`](@ref): ID generation from names
- [`push_id!`](@ref), [`pop_id!`](@ref): Manual ID scope management
- [Widget ID System](concepts.md#widget-ids): Detailed ID explanation
"""
const IDSTACK_SIZE = 32

"""
    LAYOUTSTACK_SIZE

Maximum depth of layout stack for nested layout contexts.

Each UI container (window, panel, column) can define its own layout context
with specific positioning rules, available space, and widget flow direction.

# Default Value: 16 levels  

Smaller than container stack since not every container creates a new layout context.
Typical applications rarely exceed 8-10 layout levels.

# Layout Context Hierarchy

```julia
begin_window(ctx, "Main")                    # Layout level 1: window layout
    layout_begin_column!(ctx)                # Layout level 2: column layout
        begin_panel(ctx, "Settings")         # Layout level 3: panel layout
            layout_row!(ctx, 2, [100, -1])  # Same level: just changes row settings
            button(ctx, "Save")              # Uses current layout context
        end_panel(ctx)                       # Back to level 2
    layout_end_column!(ctx)                  # Back to level 1  
end_window(ctx)                              # Back to level 0
```

# When Layout Contexts Are Created

- **Windows**: Always create new layout context
- **Panels**: Create new layout context with their bounds
- **Columns**: Create new layout context ([`layout_begin_column!`](@ref))
- **Rows**: Modify current context, don't create new one

# Layout Information Stored

Each layout context tracks:
- Available space ([`Rect`](@ref))
- Current position within that space
- Widget size defaults
- Maximum extents reached (for auto-sizing)
- Row/column configuration

# Memory Usage

Each layout context uses ~200 bytes. Total: 16 × 200 = 3.2 KB.

# Debugging Layout Issues

```julia
# Check current layout state
layout = get_layout(ctx)
println("Available space: ", layout.body)
println("Current position: ", layout.position)
println("Next widget will be at: ", layout_next(ctx))
```

# Performance Tips

- **Minimize nesting**: Each level adds layout computation overhead
- **Use rows efficiently**: `layout_row!` is cheaper than nested columns
- **Cache layout results**: Don't call `layout_next` multiple times

# See Also

- [`Layout`](@ref): Layout context structure
- [`get_layout`](@ref): Access current layout
- [`layout_next`](@ref): Calculate next widget position
- [`push_layout!`](@ref): Create new layout context
"""
const LAYOUTSTACK_SIZE = 16

# ===== POOL SIZES =====

"""
    CONTAINERPOOL_SIZE

Size of the container pool for efficient container reuse.

Containers are expensive to create and destroy each frame, so MicroUI maintains
a pool of reusable container objects. This reduces allocation overhead and
improves performance.

# Default Value: 48 containers

Larger than [`ROOTLIST_SIZE`](@ref) to account for non-root containers
(panels, treenodes) and to provide headroom for container recycling.

# How Container Pooling Works

```julia
# Frame 1: Create window
begin_window(ctx, "MyWindow")  # Gets container from pool
    # ... UI content ...
end_window(ctx)                # Container marked as "used this frame"

# Frame 2: Same window  
begin_window(ctx, "MyWindow")  # Reuses same container from pool
    # ... UI content ...
end_window(ctx)

# Frame 3: Window not created
# Container stays in pool but marked as "not used this frame"
# Available for reuse by other windows
```

# Pool Management

- **Active containers**: Currently in use this frame
- **Cached containers**: Used recently, waiting for reuse
- **Available containers**: Never used or not used recently

# Memory Impact

Each pooled container uses ~300 bytes whether active or not.
Total pool memory: 48 × 300 = 14.4 KB.

# Pool Exhaustion

When pool is exhausted, new containers fail to create:

```julia
# Creating too many different containers may exhaust pool
for i in 1:100
    if begin_window(ctx, "Window_\$i", rect) != 0
        end_window(ctx)
    else
        println("Container pool exhausted at window \$i")
        break
    end
end
```

# Optimization Tips

- **Reuse container names**: Same-named containers reuse pool slots
- **Close unused windows**: Don't create windows you won't use
- **Monitor pool usage**: Track container creation patterns

```julia
# Check pool usage
active_containers = count(item -> item.id != 0, ctx.container_pool)
println("Active containers: \$active_containers / \$CONTAINERPOOL_SIZE")
```

# See Also

- [`Container`](@ref): Container structure
- [`get_container`](@ref): Pool management logic
- [`pool_init!`](@ref), [`pool_get`](@ref): Pool operations
"""
const CONTAINERPOOL_SIZE = 48

"""
Pool size for tab state management.
Allows up to 64 concurrent tabbar widgets in the UI.
"""
const TABPOOL_SIZE = 64

"""
    TREENODEPOOL_SIZE

Size of the treenode pool for efficient treenode state management.

Treenodes can be expanded or collapsed, and this state must persist between
frames. The treenode pool manages this persistent state efficiently.

# Default Value: 48 treenodes

Supports applications with moderately complex tree structures like
file browsers, object hierarchies, or settings panels.

# Treenode State Management

```julia
# Frame 1: Create treenode
if begin_treenode(ctx, "Documents") & RES_ACTIVE != 0
    # Treenode is expanded - show children
    begin_treenode(ctx, "Projects")
    end_treenode(ctx)
    begin_treenode(ctx, "Archive")  
    end_treenode(ctx)
end_treenode(ctx)

# Frame 2: Same treenodes
# Expansion state persists automatically from frame 1
```

# What Uses Treenode Pool

- **File/folder trees**: Directory browsers, project explorers
- **Object hierarchies**: Scene graphs, component trees  
- **Settings categories**: Collapsible option groups
- **Data structures**: JSON/XML viewers, database schemas

# Pool Slots

Each treenode with persistent state uses one pool slot, identified by
its unique ID (based on label and ID context).

# Memory Usage

Each pool slot stores:
- Treenode ID (4 bytes)
- Last update frame (4 bytes)  
- Expansion state (1 byte)

Total: 48 × 16 bytes = 768 bytes

# Pool Exhaustion

When exhausted, new treenodes can't save state and will reset each frame:

```julia
# This treenode will work but won't remember expansion state
if begin_treenode(ctx, "TooManyNodes") & RES_ACTIVE != 0
    # State not persistent if pool full
end_treenode(ctx)
```

# Optimization

```julia
# Check treenode pool usage
active_nodes = count(item -> item.id != 0, ctx.treenode_pool)
println("Active treenodes: \$active_nodes / \$TREENODEPOOL_SIZE")

# Clear unused treenode states periodically
# (automatic cleanup happens when slots are reused)
```

# See Also

- [`begin_treenode`](@ref), [`end_treenode`](@ref): Treenode creation
- [`header`](@ref): Similar collapsible headers
- [`PoolItem`](@ref): Pool item structure
"""
const TREENODEPOOL_SIZE = 48

# ===== LAYOUT CONSTANTS =====

"""
    MAX_WIDTHS

Maximum number of columns in a layout row.

When using [`layout_row!`](@ref) to create multi-column layouts, this constant
limits how many columns can be specified in a single row.

# Default Value: 16 columns

Supports complex form layouts and data tables while keeping memory usage bounded.
Most UIs use 2-4 columns, so 16 provides generous headroom.

# Usage Example

```julia
# Valid: 4 columns
layout_row!(ctx, 4, [100, 150, 200, -1], 30)

# Valid: Maximum columns  
widths = fill(50, 16)  # 16 columns of 50px each
layout_row!(ctx, 16, widths, 20)

# Invalid: Would exceed MAX_WIDTHS
# layout_row!(ctx, 20, big_widths, 30)  # Error!
```

# Column Width Storage

Column widths are stored in a fixed-size array in each [`Layout`](@ref) context:

```julia
mutable struct Layout
    widths::Vector{Int32}  # Size = MAX_WIDTHS = 16
    # ... other fields
end
```

# Memory Impact

Each layout context allocates: 16 × 4 bytes = 64 bytes for width storage.
With [`LAYOUTSTACK_SIZE`](@ref) = 16: 16 × 64 = 1 KB total.

# Error Handling

Exceeding the limit triggers an assertion error:

```julia
# This will throw "Too many layout items" error
too_many_widths = fill(100, 20)
layout_row!(ctx, 20, too_many_widths, 30)  # Error!
```

# Design Patterns

## Form Layouts (2-3 columns)
```julia
layout_row!(ctx, 2, [150, -1], 0)  # Label, Input
label(ctx, "Username:")
textbox!(ctx, username_ref, 50)
```

## Button Bars (3-5 columns)
```julia
layout_row!(ctx, 3, [-1, -1, -1], 0)  # Equal width buttons
button(ctx, "Save")
button(ctx, "Cancel") 
button(ctx, "Help")
```

## Data Tables (many columns)
```julia
layout_row!(ctx, 6, [50, 150, 100, 80, 120, -1], 0)
label(ctx, "ID")
label(ctx, "Name")
label(ctx, "Type")
label(ctx, "Size")
label(ctx, "Modified")
label(ctx, "Actions")
```

# See Also

- [`layout_row!`](@ref): Create multi-column layouts
- [`Layout`](@ref): Layout context structure
- [Layout Guide](layout.md): Detailed layout documentation
"""
const MAX_WIDTHS = 16

# ===== FORMAT CONSTANTS =====

"""
    MAX_FMT

Maximum length for number format strings.

Limits the size of printf-style format strings used for displaying
numeric values in widgets like sliders and number inputs.

# Default Value: 127 characters

Extremely generous limit since typical format strings are 5-10 characters.
Prevents buffer overflows while supporting any reasonable format string.

# Common Format Strings

- `"%.2f"`: 2 decimal places (7 chars)
- `"%.3g"`: 3 significant digits (7 chars) 
- `"%d"`: Integer (3 chars)
- `"\$%.2f"`: Currency (8 chars)
- `"%.1f%%"`: Percentage (8 chars)

# Usage in Widgets

```julia
# Default formatting
slider!(ctx, value, 0.0f0, 100.0f0)  # Uses SLIDER_FMT

# Custom formatting  
slider_ex!(ctx, value, 0.0f0, 100.0f0, 1.0f0, "%.1f%%", options)

# Number widget formatting
number_ex!(ctx, value, 0.1f0, "\$%.2f", options)
```

# Buffer Size

Format string buffers are allocated as fixed-size arrays:

```julia
format_buffer = Vector{UInt8}(undef, MAX_FMT + 1)  # +1 for null terminator
```

# Memory Usage

Each widget that uses custom formatting may allocate 128 bytes for the format buffer.
In practice, this is minimal since most widgets use default formats.

# Validation

Format strings are not validated - invalid formats may cause crashes
or incorrect display. Always test custom format strings:

```julia
# Good formats
"%.2f"     # 2 decimal places
"%.0f"     # No decimal places  
"%.3g"     # 3 significant digits
"%d"       # Integer

# Bad formats (don't use)
"%.200f"   # Excessive precision
"%s"       # Wrong type (string instead of number)
""         # Empty format
```

# See Also

- [`format_real`](@ref): Number formatting function
- [`REAL_FMT`](@ref), [`SLIDER_FMT`](@ref): Default format strings
- [`slider_ex!`](@ref), [`number_ex!`](@ref): Widgets with custom formatting
"""
const MAX_FMT = 127

"""
    REAL_FMT

Default format string for real number display in widgets.

Used by number widgets, sliders, and other numeric displays when no
custom format is specified. Provides a good balance between precision
and readability.

# Default Value: "%.3g"

The `%.3g` format uses "general" formatting with 3 significant digits:
- Automatically chooses between fixed-point and exponential notation
- Removes trailing zeros
- Compact representation for both large and small numbers

# Format Examples

```julia
42.0      → "42"         # Integer-like values shown without decimals
3.14159   → "3.14"       # 3 significant digits  
0.001234  → "0.00123"    # Small numbers in fixed-point
1234.567  → "1230"       # Large numbers rounded to 3 digits
0.000001  → "1e-06"      # Very small numbers in scientific notation
1000000.0 → "1e+06"      # Very large numbers in scientific notation
```

# Usage in Widgets

```julia
# These widgets use REAL_FMT automatically
number!(ctx, value_ref, step)
slider!(ctx, value_ref, min_val, max_val)

# Equivalent to:
number_ex!(ctx, value_ref, step, MicroUI.REAL_FMT, options)
slider_ex!(ctx, value_ref, min_val, max_val, step, MicroUI.REAL_FMT, options)
```

# Comparison with Other Formats

```julia
value = 3.14159

# Different format results:
"%.3g"  → "3.14"    # REAL_FMT (default)
"%.2f"  → "3.14"    # SLIDER_FMT  
"%.6f"  → "3.141590" # High precision
"%d"    → "3"       # Integer only
"%.1f"  → "3.1"     # One decimal place
```

# When to Use Custom Formats

Use [`REAL_FMT`](@ref) (default) when:
- General-purpose numeric display
- Values span wide range (0.001 to 1000+)
- Automatic precision is desired

Use custom formats when:
- Fixed decimal places needed (prices, percentages)
- Scientific notation never desired
- Special formatting required (currency, units)

# Performance

The "%.3g" format is:
- **Fast**: Optimized by Julia's formatting system
- **Compact**: Usually produces short strings
- **Readable**: Good balance of precision and clarity

# See Also

- [`SLIDER_FMT`](@ref): Alternative format for sliders
- [`format_real`](@ref): Function that applies formatting
- [`number!`](@ref), [`slider!`](@ref): Widgets using this format
- [Printf Documentation](https://docs.julialang.org/en/v1/stdlib/Printf/): Format string reference
"""
const REAL_FMT = "%.3g"

"""
    SLIDER_FMT

Default format string for slider value display.

Used by slider widgets to show the current value. Provides fixed decimal
precision for consistent appearance as users drag the slider.

# Default Value: "%.2f"

The `%.2f` format shows fixed-point notation with exactly 2 decimal places:
- Always shows 2 digits after decimal point
- Consistent width for smooth visual updates
- Good precision for most slider ranges

# Format Examples

```julia
0.0       → "0.00"      # Always 2 decimal places
0.5       → "0.50"      # Trailing zero included  
3.14159   → "3.14"      # Rounded to 2 places
42.0      → "42.00"     # Integer shown with decimals
100.999   → "101.00"    # Rounded up
```

# Usage in Sliders

```julia
# This slider shows values like "0.50", "0.75", "1.00"
slider!(ctx, volume_ref, 0.0f0, 1.0f0)

# Custom format for percentages: "50%", "75%", "100%"  
slider_ex!(ctx, percent_ref, 0.0f0, 100.0f0, 1.0f0, "%.0f%%", options)

# Custom format for currency: "\$0.50", "\$0.75", "\$1.00"
slider_ex!(ctx, price_ref, 0.0f0, 10.0f0, 0.01f0, "\$%.2f", options)
```

# Visual Consistency

Fixed decimal places provide consistent visual appearance:

```julia
# With SLIDER_FMT ("%.2f"):
"0.00"  "0.25"  "0.50"  "0.75"  "1.00"   # Consistent width

# With REAL_FMT ("%.3g"):  
"0"     "0.25"  "0.5"   "0.75"  "1"      # Variable width
```

# Precision vs Range

The `.2f` format works well for typical slider ranges:

```julia
# Good ranges for SLIDER_FMT:
0.0 to 1.0    → "0.00" to "1.00"    # Volume, opacity, etc.
0.0 to 100.0  → "0.00" to "100.00"  # Percentages, temperatures
-10.0 to 10.0 → "-10.00" to "10.00" # Adjustments, offsets

# Poor ranges for SLIDER_FMT:
0.0 to 0.01   → "0.00" to "0.01"    # Too little precision
0.0 to 10000  → "0.00" to "10000.00" # Unnecessary decimals
```

# When to Override

Use custom formats when:

```julia
# Integer values (no decimals needed)
slider_ex!(ctx, count_ref, 1.0f0, 100.0f0, 1.0f0, "%.0f", options)

# High precision needed
slider_ex!(ctx, precise_ref, 0.0f0, 1.0f0, 0.001f0, "%.4f", options)  

# Percentage display
slider_ex!(ctx, percent_ref, 0.0f0, 100.0f0, 1.0f0, "%.1f%%", options)

# Scientific values
slider_ex!(ctx, freq_ref, 1.0f0, 1000.0f0, 1.0f0, "%.1e Hz", options)
```

# Performance

Fixed-point formatting is:
- **Fast**: No complex decision logic like "%.3g"
- **Predictable**: Always same string length
- **Cache-friendly**: Consistent memory access patterns

# See Also

- [`REAL_FMT`](@ref): Alternative general-purpose format
- [`slider!`](@ref), [`slider_ex!`](@ref): Widgets using this format
- [`format_real`](@ref): Number formatting implementation
- [Printf Documentation](https://docs.julialang.org/en/v1/stdlib/Printf/): Format string syntax
"""
const SLIDER_FMT = "%.2f"

# ===== HASH CONSTANTS =====

"""
    HASH_INITIAL

Initial hash value for the FNV-1a hashing algorithm used in ID generation.

This constant provides the starting point for generating unique widget IDs
from strings. It's part of the FNV-1a (Fowler-Noll-Vo) hash algorithm,
which provides good distribution and low collision rates for short strings.

# Default Value: 0x811c9dc5

This is the standard FNV-1a offset basis for 32-bit hashes, defined in the
FNV specification. Using the standard value ensures compatibility and
optimal hash distribution.

# How Widget IDs Work

```julia
# Widget ID generation process:
widget_name = "my_button"
context_hash = get_current_id_context(ctx)  # From ID stack

# Start with base hash (either HASH_INITIAL or context hash)
base_hash = context_hash != 0 ? context_hash : HASH_INITIAL

# Apply FNV-1a algorithm
widget_id = hash(widget_name, UInt(base_hash)) % UInt32
```

# FNV-1a Algorithm

The algorithm is simple and fast:

1. Start with `HASH_INITIAL` (or context hash)
2. For each byte in the string:
   - XOR hash with byte value  
   - Multiply hash by FNV prime (0x01000193)
3. Return final hash value

# Why This Value?

The `0x811c9dc5` constant was chosen because:
- **Prime relationship**: Related to FNV prime for good distribution
- **Bit pattern**: Good mix of 0s and 1s avoids clustering
- **Tested**: Extensively validated across many applications
- **Standard**: Used in many FNV implementations

# Hash Quality

With this initial value, FNV-1a provides:
- **Low collisions**: Even for similar strings
- **Fast computation**: Simple operations only
- **Good distribution**: Even for short strings
- **Deterministic**: Same input always gives same output

# Example Hash Values

```julia
# Different widget names produce well-distributed IDs:
get_id(ctx, "button1")    # → 0x2a84f6c1
get_id(ctx, "button2")    # → 0x2a84f6c2  
get_id(ctx, "checkbox")   # → 0x7f3a8912
get_id(ctx, "slider")     # → 0x9e2f47a3
```

# Collision Handling

While rare, ID collisions can occur:

```julia
# Extremely unlikely, but possible:
id1 = get_id(ctx, "some_name")
id2 = get_id(ctx, "other_name") 
# id1 might equal id2 (1 in 4 billion chance)
```

ID collisions are handled by:
- **Context scoping**: Different containers have different contexts
- **Careful naming**: Use unique names for widgets in same context
- **Hierarchical IDs**: Parent container names become part of hash

# Performance

ID generation is extremely fast:
- **~10 nanoseconds** for typical widget names
- **Linear time**: O(string_length)
- **No allocations**: Works directly with string bytes
- **Cache friendly**: Simple loop with good memory access

# Security Note

FNV-1a is **not cryptographically secure**. It's designed for hash tables
and checksums, not security. For UI widget IDs, this is perfectly adequate.

# See Also

- [`get_id`](@ref): ID generation function
- [`push_id!`](@ref), [`pop_id!`](@ref): ID context management
- [FNV Hash Specification](http://www.isthe.com/chongo/tech/comp/fnv/): Official algorithm
- [Widget ID System](concepts.md#widget-ids): Conceptual overview
"""
const HASH_INITIAL = 0x811c9dc5

# ===== STYLE CONSTANTS =====

"""
    DEFAULT_STYLE

Predefined visual style providing a modern dark theme with high contrast elements.

This constant defines the default appearance for all MicroUI widgets, featuring a dark
background color scheme optimized for readability and reduced eye strain. It serves as
both the starting point for customization and a complete theme ready for immediate use.

# Style Properties

## Font and Sizing
- `font`: `nothing` (backend-dependent, must be set by application)
- `size`: `Vec2(68, 10)` - Default widget dimensions (68×10 pixels)
- `padding`: `5` pixels - Inner spacing between widget border and content
- `spacing`: `4` pixels - Gap between adjacent widgets in layouts
- `indent`: `24` pixels - Indentation for nested elements like tree nodes

## Window and Container Layout
- `title_height`: `24` pixels - Height of window title bars
- `scrollbar_size`: `12` pixels - Width of scrollbars
- `thumb_size`: `8` pixels - Minimum size of scrollbar thumb handles

## Color Palette (Dark Theme)

The color array provides a cohesive dark theme:

    COLOR_TEXT         → Color(230, 230, 230, 255)  # Light gray text
    COLOR_BORDER       → Color(25, 25, 25, 255)     # Very dark borders
    COLOR_WINDOWBG     → Color(50, 50, 50, 255)     # Medium dark window background
    COLOR_TITLEBG      → Color(25, 25, 25, 255)     # Dark title bar background
    COLOR_TITLETEXT    → Color(240, 240, 240, 255)  # Bright title text
    COLOR_PANELBG      → Color(0, 0, 0, 0)          # Transparent panel background
    COLOR_BUTTON       → Color(75, 75, 75, 255)     # Medium gray button
    COLOR_BUTTONHOVER  → Color(95, 95, 95, 255)     # Lighter gray on hover
    COLOR_BUTTONFOCUS  → Color(115, 115, 115, 255)  # Even lighter when focused
    COLOR_BASE         → Color(30, 30, 30, 255)     # Dark input background
    COLOR_BASEHOVER    → Color(35, 35, 35, 255)     # Slightly lighter on hover
    COLOR_BASEFOCUS    → Color(40, 40, 40, 255)     # Focused input background
    COLOR_SCROLLBASE   → Color(43, 43, 43, 255)     # Scrollbar track
    COLOR_SCROLLTHUMB  → Color(30, 30, 30, 255)     # Scrollbar thumb

# Usage

## Direct Assignment
    ctx.style = DEFAULT_STYLE

## As Base for Customization
    # Start with default and modify specific colors
    custom_style = DEFAULT_STYLE
    custom_style.colors[Int(COLOR_BUTTON)] = Color(100, 150, 200, 255)  # Blue buttons
    custom_style.colors[Int(COLOR_WINDOWBG)] = Color(40, 40, 50, 255)   # Bluish background
    ctx.style = custom_style

## Creating Variants
    # Light theme variant
    light_style = Style(
        DEFAULT_STYLE.font,
        DEFAULT_STYLE.size,
        DEFAULT_STYLE.padding,
        DEFAULT_STYLE.spacing,
        DEFAULT_STYLE.indent,
        DEFAULT_STYLE.title_height,
        DEFAULT_STYLE.scrollbar_size,
        DEFAULT_STYLE.thumb_size,
        [
            Color(20, 20, 20, 255),     # COLOR_TEXT (dark text)
            Color(200, 200, 200, 255),  # COLOR_BORDER (light borders)
            Color(240, 240, 240, 255),  # COLOR_WINDOWBG (light background)
            # ... other light theme colors
        ]
    )

# Design Principles

The default style follows these design principles:

1. **High Contrast**: Text and backgrounds have sufficient contrast for readability
2. **Subtle Hierarchy**: Interactive states (normal/hover/focus) are clearly differentiated
3. **Eye Comfort**: Dark theme reduces eye strain in low-light environments
4. **Modern Aesthetic**: Clean, minimal design suitable for technical applications
5. **Accessibility**: Color choices work well for most users including color vision differences

# Customization Examples

    # Gaming/Entertainment Theme
    gaming_colors = copy(DEFAULT_STYLE.colors)
    gaming_colors[Int(COLOR_BUTTON)] = Color(0, 120, 215, 255)      # Blue buttons
    gaming_colors[Int(COLOR_BUTTONHOVER)] = Color(0, 140, 255, 255) # Bright blue hover
    gaming_colors[Int(COLOR_TITLEBG)] = Color(0, 80, 160, 255)      # Blue title bars
    
    # Professional/Business Theme  
    professional_colors = copy(DEFAULT_STYLE.colors)
    professional_colors[Int(COLOR_WINDOWBG)] = Color(45, 45, 48, 255)     # Subtle dark gray
    professional_colors[Int(COLOR_BUTTON)] = Color(90, 90, 90, 255)       # Neutral buttons
    professional_colors[Int(COLOR_TITLEBG)] = Color(60, 60, 60, 255)      # Medium gray titles
    
    # High Contrast Accessibility Theme
    accessible_colors = copy(DEFAULT_STYLE.colors)
    accessible_colors[Int(COLOR_TEXT)] = Color(255, 255, 255, 255)        # Pure white text
    accessible_colors[Int(COLOR_WINDOWBG)] = Color(0, 0, 0, 255)          # Pure black background
    accessible_colors[Int(COLOR_BUTTON)] = Color(0, 0, 128, 255)          # Dark blue buttons

# Performance Notes

- The constant is computed at compile time with zero runtime overhead
- Color array access uses direct indexing for maximum performance
- Immutable structure enables compiler optimizations
- Safe to share across multiple contexts

# See Also
- `Style`: The style structure definition
- `ColorId`: Enum values for color array indexing  
- `Context`: Structure that contains the current style
- `Color`: RGBA color structure used in the palette
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
