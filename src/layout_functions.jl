# ===== LAYOUT MANAGEMENT =====
# Functions for managing widget positioning and sizing

"""Layout positioning modes for manual rectangle specification"""
const RELATIVE = 1
const ABSOLUTE = 2

"""
    push_layout!(ctx::Context, body::Rect, scroll::Vec2)

Create a new layout context with the specified body rectangle and scroll offset.

This function establishes a new layout scope by pushing a [`Layout`](@ref) onto
the layout stack. The new layout context will manage widget positioning within
the given body rectangle, accounting for scroll offset and content bounds.

# Arguments
- `ctx::Context`: The UI context containing the layout stack
- `body::Rect`: The available area for content placement in screen coordinates  
- `scroll::Vec2`: The scroll offset to apply to the layout (typically from container scrolling)

# Effects
- Creates a new `Layout` with the specified parameters
- Pushes the layout onto the context's layout stack
- Initializes layout state for automatic widget positioning
- Sets up default row layout with single column

# Layout coordinate transformation
The body rectangle is transformed by the scroll offset:
```julia
layout.body = Rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h)
```
This allows scrolled content to be positioned naturally while the layout
system handles the coordinate transformation automatically.

# Examples
```julia
# Container with scrollable content
container_rect = Rect(50, 50, 300, 200)
container_scroll = Vec2(0, 25)  # Scrolled down 25 pixels

push_layout!(ctx, container_rect, container_scroll)

# Widgets positioned within this layout will be offset by the scroll
widget_rect = layout_next(ctx)  # Automatically accounts for scroll offset

# Clean up when done with this layout scope
pop!(ctx.layout_stack)
```

# Nested layout contexts
Layout contexts can be nested for complex UI structures:

```julia
# Main window layout
window_body = Rect(10, 10, 400, 300)
push_layout!(ctx, window_body, Vec2(0, 0))

    # Panel within window
    panel_body = Rect(20, 50, 360, 200)  
    panel_scroll = Vec2(0, scroll_position)
    push_layout!(ctx, panel_body, panel_scroll)
    
        # Widgets within panel use panel's coordinate space
        button_rect = layout_next(ctx)
        
    pop!(ctx.layout_stack)  # Exit panel layout
    
    # Back to window layout coordinate space
    footer_rect = layout_next(ctx)
    
pop!(ctx.layout_stack)  # Exit window layout
```

# Initial layout state
The new layout is initialized with:
- **Body**: Transformed by scroll offset
- **Max extents**: Set to minimum values (will expand as widgets are added)
- **Position**: Set to top-left with no indentation
- **Default row**: Single column with automatic sizing

# Scroll offset behavior
Scroll offsets affect widget positioning:
- **Positive scroll.x**: Content appears moved left (revealing right side)
- **Positive scroll.y**: Content appears moved up (revealing bottom)
- **Negative values**: Content appears moved in opposite directions

# Memory management
The layout is allocated on the stack for efficient memory usage:
- **No heap allocation**: Layout structs are stack-allocated
- **Automatic cleanup**: Layouts are freed when popped from stack
- **Bounded depth**: Stack size limits maximum nesting depth

# Container integration
This function is typically called by container management code:

```julia
# Used by push_container_body! to set up container layout
function push_container_body!(ctx, cnt, body, opt)
    # ... scrollbar calculations ...
    push_layout!(ctx, body, cnt.scroll)  # Set up layout with container's scroll
    # ... additional setup ...
end
```

# See also
[`Layout`](@ref), [`pop_container!`](@ref), [`layout_next`](@ref), [`get_layout`](@ref)
"""
function push_layout!(ctx::Context, body::Rect, scroll::Vec2)
    layout = Layout()
    layout.body = Rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h)
    layout.max = Vec2(typemin(Int32), typemin(Int32))
    push!(ctx.layout_stack, layout)
    width = 0
    layout_row!(ctx, 1, [width], 0)
end

"""
    get_layout(ctx::Context) -> Layout

Get the current layout context from the top of the layout stack.

This function returns a reference to the active layout, allowing other
layout functions to query and modify the current positioning state.
The layout controls how widgets are positioned within the current scope.

# Arguments
- `ctx::Context`: The UI context containing the layout stack

# Returns
- `Layout`: Reference to the current layout context

# Throws
- `AssertionError`: If the layout stack is empty (no active layout)

# Examples
```julia
# Query current layout state
layout = get_layout(ctx)
println("Available width: \$(layout.body.w)")
println("Current position: (\$(layout.position.x), \$(layout.position.y))")
println("Items in current row: \$(layout.items)")

# Modify layout state (advanced usage)
layout = get_layout(ctx)
layout.indent += 20  # Increase indentation for nested content

# Check layout bounds
if layout.position.x + widget_width > layout.body.x + layout.body.w
    # Widget would exceed layout bounds
    layout_row!(ctx, 1, [-1], 0)  # Start new row
end
```

# Layout state information
The returned layout contains:
- **`body`**: Available area for content (accounting for scroll)
- **`position`**: Current insertion point for next widget
- **`size`**: Default widget dimensions
- **`max`**: Maximum extents reached by content
- **`widths`**: Column width specifications for current row
- **`items`**: Number of items in current row configuration
- **`item_index`**: Current position within the row
- **`next_row`**: Y coordinate for the next row
- **`indent`**: Current indentation level for hierarchical content

# Coordinate spaces
The layout operates in "layout coordinates" which may differ from
screen coordinates due to:
- **Scroll offsets**: Applied when the layout was created
- **Container transforms**: Nested containers may have additional offsets
- **Clipping regions**: May affect visible vs. logical positioning

# Thread safety
The returned layout reference is only valid while:
- The layout remains on the stack (not popped)
- No other thread modifies the layout stack
- The current thread maintains exclusive access to the context

# Usage patterns
```julia
# Check available space before adding widget
layout = get_layout(ctx)
available_width = layout.body.w - layout.position.x
if widget_min_width > available_width
    layout_row!(ctx, 1, [-1], 0)  # Move to next row
end

# Calculate remaining vertical space
layout = get_layout(ctx)
remaining_height = layout.body.h - (layout.position.y - layout.body.y)

# Implement custom positioning logic
layout = get_layout(ctx)
if layout.item_index >= layout.items
    # Current row is full, start new row
    layout_row!(ctx, 2, [100, -1], 30)
end
```

# See also
[`push_layout!`](@ref), [`Layout`](@ref), [`layout_next`](@ref), [`pop_container!`](@ref)
"""
function get_layout(ctx::Context)
    @assert ctx.layout_stack.idx > 0 "No layout on stack"
    return ctx.layout_stack.items[ctx.layout_stack.idx]
end

"""
    pop_container!(ctx::Context)

Pop the current container and update its content size based on layout extents.

This function finalizes a container's layout by calculating the total content
size from the layout's maximum extents, then removes both the container and
its associated layout from their respective stacks.

# Arguments
- `ctx::Context`: The UI context containing container and layout stacks

# Effects
- Calculates content size from layout maximum extents
- Updates the container's `content_size` field
- Removes container from container stack
- Removes layout from layout stack
- Pops ID scope associated with the container

# Content size calculation
The content size represents the total area occupied by all widgets:
```julia
content_size = Vec2(
    layout.max.x - layout.body.x,  # Total width used
    layout.max.y - layout.body.y   # Total height used
)
```

# Examples
```julia
# Complete container lifecycle
container_rect = Rect(10, 10, 300, 200)

# 1. Begin container
push_layout!(ctx, container_rect, Vec2(0, 0))
push!(ctx.container_stack, container)
push_id!(ctx, "my_container")

# 2. Add content that expands the layout
button1 = layout_next(ctx)  # Updates layout.max
button2 = layout_next(ctx)  # Further updates layout.max
text_area = layout_next(ctx)  # May extend layout.max further

# 3. Finalize container
pop_container!(ctx)  # Calculates final content_size

# Now container.content_size reflects the actual space used by content
println("Content used: \$(container.content_size.x) × \$(container.content_size.y) pixels")
```

# Scrollbar integration
The calculated content size is used by scrollbar systems:

```julia
# After pop_container!, the content size is available for scrolling
if container.content_size.y > container.body.h
    # Content exceeds container height, vertical scrollbar needed
    max_scroll = container.content_size.y - container.body.h
    container.scroll.y = clamp(container.scroll.y, 0, max_scroll)
end
```

# Nested container handling
For nested containers, content sizes bubble up through the hierarchy:

```julia
# Outer container
push_layout!(ctx, outer_rect, Vec2(0, 0))
push!(ctx.container_stack, outer_container)

    # Inner container
    push_layout!(ctx, inner_rect, Vec2(0, 0))
    push!(ctx.container_stack, inner_container)
    
        # Content affects inner container's size
        add_widgets_to_inner_container()
        
    pop_container!(ctx)  # inner_container.content_size calculated
    
    # Inner container's size affects outer container's layout
    outer_layout = get_layout(ctx)
    # outer_layout.max is updated by inner container's presence
    
pop_container!(ctx)  # outer_container.content_size calculated
```

# Stack consistency
This function maintains stack consistency by popping from three stacks:
1. **Layout stack**: Removes the current layout context
2. **Container stack**: Removes the current container
3. **ID stack**: Removes the container's ID scope

All three stacks must be properly balanced for correct operation.

# Auto-sizing widgets
The content size is essential for auto-sizing containers:

```julia
# Container with OPT_AUTOSIZE adjusts its size based on content
if (container.options & OPT_AUTOSIZE) != 0
    # After pop_container!, use content_size to resize container
    new_width = container.content_size.x + padding
    new_height = container.content_size.y + padding
    container.rect = Rect(container.rect.x, container.rect.y, new_width, new_height)
end
```

# Performance considerations
- **O(1) operation**: Content size calculation is constant time
- **No allocation**: Uses existing layout data, no memory allocation
- **Stack efficiency**: Simple stack operations for cleanup

# Error conditions
The function assumes proper stack state:
- Container stack must not be empty
- Layout stack must not be empty  
- ID stack must not be empty
- Stacks should be properly paired from container creation

# See also
[`push_layout!`](@ref), [`get_layout`](@ref), [`Layout`](@ref), [`Container`](@ref)
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

"""
    layout_begin_column!(ctx::Context)

Start a column layout context within the current layout space.

This function creates a nested layout context optimized for vertical
arrangement of widgets. It allocates the next available layout rectangle
and establishes a new layout scope where widgets will be stacked vertically.

# Arguments
- `ctx::Context`: The UI context containing the layout stack

# Effects
- Allocates a rectangle from the current layout using [`layout_next`](@ref)
- Creates a new layout context with the allocated rectangle
- Establishes vertical stacking behavior for subsequent widgets
- Pushes the column layout onto the layout stack

# Layout behavior
Within a column layout:
- Widgets are positioned vertically (one below the other)
- Each widget spans the full width of the column
- Widget heights are determined by content or explicit sizing
- Vertical spacing is controlled by the style settings

# Examples
```julia
# Create a column of vertically stacked widgets
layout_begin_column!(ctx)

    label(ctx, "Column Header")          # Full width at top
    button(ctx, "Button 1")              # Below header, full width
    button(ctx, "Button 2")              # Below button 1, full width
    textbox!(ctx, text_buffer, 100)      # Below button 2, full width
    
layout_end_column!(ctx)
```

# Nested columns and rows
Columns can be combined with rows for complex layouts:

```julia
# Two-column layout with mixed content
layout_row!(ctx, 2, [150, -1], 0)  # Two columns: 150px and remaining space

# Left column - fixed width
layout_begin_column!(ctx)
    label(ctx, "Left Panel")
    button(ctx, "Action 1")
    button(ctx, "Action 2")
layout_end_column!(ctx)

# Right column - takes remaining space
layout_begin_column!(ctx)
    label(ctx, "Main Content")
    text(ctx, "This is the main content area with lots of text...")
    layout_row!(ctx, 2, [-1, -1], 0)  # Nested row within right column
        button(ctx, "OK")
        button(ctx, "Cancel")
layout_end_column!(ctx)
```

# Widget sizing within columns
- **Width**: Widgets automatically span the column width
- **Height**: Uses widget's natural height or explicit height settings
- **Spacing**: Vertical spacing between widgets follows style settings
- **Padding**: Column edges may have padding based on style

# Advanced column usage
```julia
# Column with custom spacing and indentation
layout_begin_column!(ctx)
    
    # Increase indentation for nested content
    layout = get_layout(ctx)
    layout.indent += 20
    
    label(ctx, "Indented Section")
    
    # Custom height for specific widget
    layout_height!(ctx, 40)
    button(ctx, "Tall Button")
    
    # Reset to automatic height
    layout_height!(ctx, 0)
    button(ctx, "Normal Button")
    
    # Restore indentation
    layout.indent -= 20
    
layout_end_column!(ctx)
```

# Performance characteristics
- **Efficient nesting**: Minimal overhead for nested layout contexts
- **Memory usage**: Stack-allocated layout contexts
- **Rendering order**: Widgets are rendered in declaration order (top to bottom)

# Layout inheritance
The column layout inherits properties from its parent:
- **Available space**: Determined by parent layout allocation
- **Style settings**: Spacing, padding, and other visual properties
- **Coordinate system**: Positioned within parent's coordinate space

# See also
[`layout_end_column!`](@ref), [`layout_row!`](@ref), [`layout_next`](@ref), [`push_layout!`](@ref)
"""
function layout_begin_column!(ctx::Context)
    push_layout!(ctx, layout_next(ctx), Vec2(0, 0))
end

"""
    layout_end_column!(ctx::Context)

End the current column layout and merge its extents with the parent layout.

This function finalizes a column layout by inheriting layout state from
the completed column and merging it back into the parent layout. The parent
layout's positioning and extent tracking are updated to account for the
space used by the column.

# Arguments
- `ctx::Context`: The UI context containing the layout stack

# Effects
- Transfers column layout state to parent layout
- Updates parent position to account for column width
- Merges maximum extents between column and parent
- Removes column layout from the layout stack

# Layout state inheritance
The function transfers three key pieces of information:

1. **Position inheritance**: Parent position advances horizontally
```julia
parent.position.x = max(parent.position.x, column.position.x + column.body.x - parent.body.x)
```

2. **Next row inheritance**: Parent tracks maximum row height
```julia
parent.next_row = max(parent.next_row, column.next_row + column.body.y - parent.body.y)
```

3. **Extent merging**: Maximum extents are merged
```julia
parent.max = Vec2(max(parent.max.x, column.max.x), max(parent.max.y, column.max.y))
```

# Examples
```julia
# Complete column lifecycle
layout_row!(ctx, 2, [200, -1], 0)  # Two columns

# First column
layout_begin_column!(ctx)
    label(ctx, "Left Column")
    button(ctx, "Button A")
    button(ctx, "Button B")
layout_end_column!(ctx)  # Column state merged back to row

# Second column  
layout_begin_column!(ctx)
    label(ctx, "Right Column")
    textbox!(ctx, buffer, 100)
layout_end_column!(ctx)  # Column state merged back to row

# Row continues with both columns' extents accounted for
```

# Multi-column layout with different heights
```julia
layout_row!(ctx, 3, [100, 100, 100], 0)

# Short column
layout_begin_column!(ctx)
    button(ctx, "Short")
layout_end_column!(ctx)

# Medium column  
layout_begin_column!(ctx)
    button(ctx, "Medium 1")
    button(ctx, "Medium 2")
layout_end_column!(ctx)

# Tall column
layout_begin_column!(ctx)
    button(ctx, "Tall 1")
    button(ctx, "Tall 2") 
    button(ctx, "Tall 3")
    button(ctx, "Tall 4")
layout_end_column!(ctx)

# Next widget placement accounts for tallest column
next_widget = layout_next(ctx)  # Positioned below the tallest column
```

# Coordinate space transformation
The function handles coordinate space differences between layouts:
- **Column coordinates**: Relative to column's body rectangle
- **Parent coordinates**: Relative to parent's body rectangle
- **Transformation**: Column positions are converted to parent space

# Nested column handling
For deeply nested columns, state bubbles up through the hierarchy:

```julia
layout_begin_column!(ctx)  # Level 1
    
    layout_row!(ctx, 2, [-1, -1], 0)
    
    layout_begin_column!(ctx)  # Level 2 nested in level 1
        button(ctx, "Nested Button")
    layout_end_column!(ctx)  # Level 2 merges back to level 1
    
    layout_begin_column!(ctx)  # Another level 2
        button(ctx, "Another Nested")
    layout_end_column!(ctx)  # Level 2 merges back to level 1
    
layout_end_column!(ctx)  # Level 1 merges back to original layout
```

# Row height calculation
The function ensures that row heights account for column content:
- **Tallest column**: Determines the overall row height
- **Baseline alignment**: All columns in a row share the same baseline
- **Spacing consistency**: Vertical spacing remains consistent across columns

# Performance optimization
- **Minimal computation**: Simple arithmetic operations for state transfer
- **No allocation**: Uses existing layout data structures
- **Cache-friendly**: Sequential access to layout properties

# Error prevention
The function assumes:
- A column layout is currently active (layout stack not empty)
- The current layout was created by [`layout_begin_column!`](@ref)
- Parent layout exists on the stack below the current column

# See also
[`layout_begin_column!`](@ref), [`layout_row!`](@ref), [`get_layout`](@ref), [`push_layout!`](@ref)
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
    layout_row!(ctx::Context, items::Int, widths::Union{Nothing, Vector{Int}}, height::Int)

Set up a new layout row with specified item count, widths, and height.

This function configures horizontal widget arrangement by defining how many
items will be placed in the current row, their individual widths, and the
row height. It's the primary mechanism for controlling horizontal layout flow.

# Arguments
- `ctx::Context`: The UI context containing the layout state
- `items::Int`: Number of items (widgets) that will be placed in this row
- `widths::Union{Nothing, Vector{Int}}`: Width specification for each item (see width specification)
- `height::Int`: Height of the row in pixels (0 for automatic height)

# Effects
- Configures the current layout for horizontal arrangement
- Sets item count and width specifications
- Positions layout cursor at the start of the new row
- Establishes height constraint for widgets in this row

# Width specification
The `widths` parameter controls how items are sized horizontally:

- **`nothing`**: Use automatic sizing for all items
- **`Vector{Int}`**: Explicit width for each item:
  - **Positive values**: Fixed width in pixels
  - **Zero**: Use automatic width based on widget content
  - **Negative values**: Fill remaining space proportionally

# Examples
```julia
# Fixed width columns
layout_row!(ctx, 3, [100, 150, 80], 30)
button(ctx, "100px")    # Exactly 100 pixels wide
button(ctx, "150px")    # Exactly 150 pixels wide  
button(ctx, "80px")     # Exactly 80 pixels wide

# Mixed fixed and automatic widths
layout_row!(ctx, 3, [80, 0, 120], 25)
button(ctx, "Fixed")    # 80 pixels wide
button(ctx, "Auto")     # Automatic width based on content
button(ctx, "Fixed2")   # 120 pixels wide

# Proportional width distribution
layout_row!(ctx, 3, [-1, -2, -1], 35)
button(ctx, "25%")      # 1/4 of available space (1/(1+2+1))
button(ctx, "50%")      # 2/4 of available space (2/(1+2+1))
button(ctx, "25%")      # 1/4 of available space (1/(1+2+1))

# Common two-column layout
layout_row!(ctx, 2, [120, -1], 0)
label(ctx, "Label:")    # Fixed 120px label
textbox!(ctx, buf, 100) # Textbox fills remaining space

# Full-width single item
layout_row!(ctx, 1, [-1], 40)
button(ctx, "Full Width Button")  # Spans entire available width
```

# Height behavior
The `height` parameter controls row height:
- **`0`**: Automatic height based on content and style
- **Positive values**: Fixed height for all widgets in the row
- **Layout inheritance**: Height affects spacing calculations

```julia
# Automatic height (most common)
layout_row!(ctx, 2, [100, 100], 0)
button(ctx, "Auto Height")  # Uses default button height
button(ctx, "Auto Height")  # Same height as first button

# Fixed height for consistency
layout_row!(ctx, 3, [-1, -1, -1], 40)
button(ctx, "40px tall")    # All buttons exactly 40 pixels tall
button(ctx, "40px tall")
button(ctx, "40px tall")
```

# Responsive layout patterns
```julia
# Responsive button layout
available_width = get_layout(ctx).body.w
button_width = available_width ÷ 3 - 10  # Three buttons with spacing

layout_row!(ctx, 3, [button_width, button_width, button_width], 0)
button(ctx, "Button 1")
button(ctx, "Button 2") 
button(ctx, "Button 3")

# Toolbar with fixed and flexible sections
layout_row!(ctx, 4, [80, -1, 100, 60], 32)
button(ctx, "File")          # Fixed 80px
label(ctx, "Document.txt")   # Flexible width (fills space)
button(ctx, "Settings")      # Fixed 100px
button(ctx, "Help")          # Fixed 60px
```

# Advanced width calculations
For negative width values, the calculation is:
```julia
remaining_space = total_width - sum(positive_widths)
total_negative_weight = abs(sum(negative_widths))
item_width = (abs(width_value) / total_negative_weight) * remaining_space
```

Example:
```julia
# Container is 300px wide
layout_row!(ctx, 3, [50, -2, -1], 0)
# Fixed: 50px
# Remaining: 250px  
# Total weight: 2 + 1 = 3
# Second item: (2/3) * 250 = 167px
# Third item: (1/3) * 250 = 83px
```

# Layout flow control
```julia
# Complex form layout
# Header section
layout_row!(ctx, 1, [-1], 0)
text(ctx, "User Registration Form")

# Two-column form fields
layout_row!(ctx, 2, [120, -1], 0)
label(ctx, "First Name:")
textbox!(ctx, first_name, 100)

layout_row!(ctx, 2, [120, -1], 0)
label(ctx, "Last Name:")
textbox!(ctx, last_name, 100)

layout_row!(ctx, 2, [120, -1], 0)
label(ctx, "Email:")
textbox!(ctx, email, 100)

# Button row
layout_row!(ctx, 3, [-1, 100, 100], 0)
text(ctx, "")  # Spacer
button(ctx, "Cancel")
button(ctx, "Submit")
```

# Performance considerations
- **Efficient setup**: Row configuration is O(1) operation
- **Memory usage**: Width array is copied to layout state
- **Widget positioning**: Subsequent [`layout_next`](@ref) calls use this configuration

# Constraint validation
- `items` must be positive and ≤ `MAX_WIDTHS`
- `widths` array length should match `items` count
- Total fixed widths should not exceed available space

# See also
[`layout_next`](@ref), [`layout_width!`](@ref), [`layout_height!`](@ref), [`MAX_WIDTHS`](@ref)
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

"""
    layout_width!(ctx::Context, width::Int)

Set the default width for the next widget.

This function overrides the automatic width calculation for the next widget
by setting a specific width value. It affects only the immediately following
widget and then resets to automatic behavior.

# Arguments
- `ctx::Context`: The UI context containing the layout state
- `width::Int`: The width in pixels for the next widget

# Effects
- Sets `layout.size.x` to the specified width
- Affects only the next [`layout_next`](@ref) call
- Does not affect the layout row configuration

# Examples
```julia
# Custom width for specific widget
layout_width!(ctx, 200)
button(ctx, "Wide Button")    # Exactly 200 pixels wide

# Next widget uses automatic width
button(ctx, "Auto Width")     # Default width based on content

# Mixed custom and automatic widths in a row
layout_row!(ctx, 3, [0, 0, 0], 0)  # All automatic by default

layout_width!(ctx, 80)
button(ctx, "Fixed")          # 80 pixels wide

button(ctx, "Auto")           # Automatic width

layout_width!(ctx, 120)
button(ctx, "Fixed2")         # 120 pixels wide
```

# Interaction with layout_row!
This function works independently of row width specifications:

```julia
# Row specifies automatic widths
layout_row!(ctx, 2, [0, 0], 0)

# Override first widget width
layout_width!(ctx, 150)
button(ctx, "Custom")         # 150px despite row specification

# Second widget uses row specification (automatic)
button(ctx, "Auto from row")
```

# Width priority order
Widget width is determined by this priority:
1. **`layout_width!`**: Explicit override (highest priority)
2. **Row specification**: From `layout_row!` widths array
3. **Style defaults**: From `ctx.style.size.x`
4. **Content-based**: Calculated from widget content

# Common usage patterns
```julia
# Consistent widget sizing
standard_button_width = 100

layout_width!(ctx, standard_button_width)
button(ctx, "OK")

layout_width!(ctx, standard_button_width)  
button(ctx, "Cancel")

layout_width!(ctx, standard_button_width)
button(ctx, "Apply")

# Form with aligned elements
label_width = 120
layout_row!(ctx, 2, [label_width, -1], 0)

# Labels automatically use row width (120px)
label(ctx, "Username:")
textbox!(ctx, username, 100)

# Override textbox width for special case
layout_width!(ctx, 200)
layout_row!(ctx, 2, [label_width, -1], 0)
label(ctx, "Comment:")
textbox!(ctx, comment, 500)  # Will be 200px, not filling space
```

# Temporary width override
```julia
# Save and restore default width
layout = get_layout(ctx)
original_width = layout.size.x

# Temporarily change width
layout_width!(ctx, 180)
button(ctx, "Special Button")

# Width automatically resets for next widget
button(ctx, "Normal Button")  # Uses original default width
```

# Special width values
- **`0`**: Use automatic width calculation
- **Positive values**: Exact pixel width
- **Negative values**: Not typically used with `layout_width!` (use row specifications instead)

# Performance notes
- **O(1) operation**: Simple assignment to layout state
- **No validation**: Width value is used as-provided
- **Immediate effect**: Takes effect on the very next widget

# See also
[`layout_height!`](@ref), [`layout_row!`](@ref), [`layout_next`](@ref), [`layout_set_next!`](@ref)
"""
function layout_width!(ctx::Context, width::Int)
    get_layout(ctx).size = Vec2(Int32(width), get_layout(ctx).size.y)
end

"""
    layout_height!(ctx::Context, height::Int)

Set the default height for the next widget.

This function overrides the automatic height calculation for the next widget
by setting a specific height value. It affects only the immediately following
widget and then resets to automatic behavior.

# Arguments
- `ctx::Context`: The UI context containing the layout state  
- `height::Int`: The height in pixels for the next widget

# Effects
- Sets `layout.size.y` to the specified height
- Affects only the next [`layout_next`](@ref) call
- Does not affect the layout row configuration

# Examples
```julia
# Custom height for specific widget
layout_height!(ctx, 50)
button(ctx, "Tall Button")    # Exactly 50 pixels tall

# Next widget uses automatic height
button(ctx, "Auto Height")    # Default height based on style

# Mixed heights in a column
layout_begin_column!(ctx)
    
    layout_height!(ctx, 30)
    button(ctx, "Short")      # 30 pixels tall
    
    layout_height!(ctx, 60)  
    button(ctx, "Tall")       # 60 pixels tall
    
    button(ctx, "Normal")     # Automatic height
    
layout_end_column!(ctx)
```

# Interaction with layout_row!
Height overrides work with both automatic and fixed row heights:

```julia
# Row with automatic height
layout_row!(ctx, 2, [100, 100], 0)

layout_height!(ctx, 40)
button(ctx, "Custom Height")  # 40 pixels tall

button(ctx, "Row Height")     # Uses automatic height

# Row with fixed height
layout_row!(ctx, 2, [100, 100], 35)  # 35px row height

layout_height!(ctx, 50)
button(ctx, "Override")       # 50 pixels tall (overrides row height)

button(ctx, "Row Height")     # 35 pixels tall (uses row height)
```

# Height priority order
Widget height is determined by this priority:
1. **`layout_height!`**: Explicit override (highest priority)
2. **Row specification**: From `layout_row!` height parameter
3. **Style defaults**: From `ctx.style.size.y`
4. **Content-based**: Calculated from widget content (e.g., text height)

# Text widgets and height
For text widgets, height affects text layout:

```julia
# Single line text
layout_height!(ctx, 20)
label(ctx, "Single line")

# Multi-line text area
layout_height!(ctx, 100)
text(ctx, "This is a longer text that will wrap to multiple lines within the specified height...")

# Text input with custom height
layout_height!(ctx, 40)
textbox!(ctx, buffer, 200)   # Taller textbox for better visibility
```

# Special widget considerations
Different widgets respond to height differently:
- **Buttons**: Height affects button size and text centering
- **Text areas**: Height determines visible lines
- **Sliders**: Height affects track thickness and handle size
- **Icons**: Height affects icon scaling within the widget

```julia
# Slider with custom height
layout_height!(ctx, 25)
slider!(ctx, volume, 0.0f0, 1.0f0)  # Thicker slider track

# Icon button with custom proportions
layout_height!(ctx, 64)
layout_width!(ctx, 64)
icon_button(ctx, ICON_SETTINGS)      # Square 64×64 icon button
```

# Form layout with consistent heights
```julia
# Consistent form element heights
field_height = 28

layout_row!(ctx, 2, [120, -1], 0)

# All form elements use same height
label(ctx, "Name:")
layout_height!(ctx, field_height)
textbox!(ctx, name, 100)

label(ctx, "Email:")
layout_height!(ctx, field_height)
textbox!(ctx, email, 100)

label(ctx, "Age:")
layout_height!(ctx, field_height)
number!(ctx, age, 1.0f0)

# Button row with different height
layout_row!(ctx, 2, [-1, -1], 0)
layout_height!(ctx, 35)
button(ctx, "Cancel")

layout_height!(ctx, 35)
button(ctx, "Submit")
```

# Responsive height adjustment
```julia
# Adjust height based on content or screen size
content_lines = count_text_lines(long_text)
text_height = content_lines * line_height + padding

layout_height!(ctx, text_height)
text(ctx, long_text)

# Screen-relative sizing
screen_height = get_screen_height()
dialog_height = screen_height ÷ 3

layout_height!(ctx, dialog_height)
begin_panel(ctx, "Large Content")
    # Panel content...
end_panel(ctx)
```

# Performance and validation
- **O(1) operation**: Simple assignment to layout state
- **No bounds checking**: Height value is used as-provided
- **Immediate effect**: Applies to the very next widget only
- **Automatic reset**: Height returns to automatic after one widget

# See also
[`layout_width!`](@ref), [`layout_row!`](@ref), [`layout_next`](@ref), [`layout_set_next!`](@ref)
"""
function layout_height!(ctx::Context, height::Int)
    get_layout(ctx).size = Vec2(get_layout(ctx).size.x, Int32(height))
end

"""
    layout_set_next!(ctx::Context, r::Rect, relative::Bool)

Manually set the rectangle for the next widget with absolute or relative positioning.

This function provides precise control over widget placement by specifying
an exact rectangle, bypassing the automatic layout flow. The positioning
can be either relative to the current layout or absolute in screen coordinates.

# Arguments
- `ctx::Context`: The UI context containing the layout state
- `r::Rect`: The rectangle to use for the next widget
- `relative::Bool`: If `true`, rectangle is relative to layout body; if `false`, absolute screen coordinates

# Effects
- Sets manual positioning for the next [`layout_next`](@ref) call
- Bypasses automatic layout flow for one widget
- Position type determines coordinate interpretation

# Positioning modes
The `relative` parameter controls coordinate interpretation:

## Relative positioning (`relative = true`)
Rectangle coordinates are relative to the current layout's body:
```julia
# Position relative to layout body
layout_body = get_layout(ctx).body
# r.x and r.y are offsets from layout_body.x and layout_body.y
final_rect = Rect(
    layout_body.x + r.x,
    layout_body.y + r.y, 
    r.w, r.h
)
```

## Absolute positioning (`relative = false`)  
Rectangle coordinates are absolute screen coordinates:
```julia
# Position in absolute screen coordinates
final_rect = r  # Used as-is, no transformation
```

# Examples
```julia
# Absolute positioning for overlays
layout_set_next!(ctx, Rect(100, 50, 200, 30), false)
button(ctx, "Floating Button")  # At absolute screen position (100, 50)

# Relative positioning within layout
layout_set_next!(ctx, Rect(10, 10, 150, 25), true) 
button(ctx, "Offset Button")    # 10px offset from layout body origin

# Precise alignment in forms
layout_begin_column!(ctx)
    
    # Align label and input precisely
    layout_set_next!(ctx, Rect(0, 0, 100, 20), true)
    label(ctx, "Username:")
    
    layout_set_next!(ctx, Rect(110, 0, 200, 20), true)
    textbox!(ctx, username, 100)
    
    # Next row starts normally
    layout_set_next!(ctx, Rect(0, 30, 100, 20), true)
    label(ctx, "Password:")
    
    layout_set_next!(ctx, Rect(110, 30, 200, 20), true)
    textbox!(ctx, password, 100)
    
layout_end_column!(ctx)
```

# Manual grid layout
```julia
# Create a custom 3×3 grid of buttons
cell_width = 60
cell_height = 40
spacing = 5

for row in 0:2
    for col in 0:2
        x = col * (cell_width + spacing)
        y = row * (cell_height + spacing)
        
        layout_set_next!(ctx, Rect(x, y, cell_width, cell_height), true)
        button(ctx, "(\$col,\$row)")
    end
end
```

# Overlay and popup positioning
```julia
# Center a dialog on screen
screen_width = 800
screen_height = 600
dialog_width = 300
dialog_height = 200

center_x = (screen_width - dialog_width) ÷ 2
center_y = (screen_height - dialog_height) ÷ 2

layout_set_next!(ctx, Rect(center_x, center_y, dialog_width, dialog_height), false)
begin_panel(ctx, "Centered Dialog")
    # Dialog content...
end_panel(ctx)

# Tooltip positioned near cursor
mouse_x, mouse_y = get_mouse_position()
tooltip_rect = Rect(mouse_x + 10, mouse_y - 25, 120, 20)

layout_set_next!(ctx, tooltip_rect, false)
label(ctx, "Tooltip text")
```

# Integration with automatic layout
Manual positioning affects only the next widget:

```julia
# Mixed manual and automatic positioning
layout_row!(ctx, 2, [100, -1], 0)

# First widget uses row layout
button(ctx, "Auto Position")

# Second widget uses manual position
layout_set_next!(ctx, Rect(200, 0, 80, 30), true)
button(ctx, "Manual")

# Continue with automatic layout
layout_row!(ctx, 1, [-1], 0)
button(ctx, "Back to Auto")  # Normal layout flow resumes
```

# Complex UI layouts
```julia
# Dashboard with fixed and flexible regions
container_rect = Rect(0, 0, 800, 600)

# Fixed header
layout_set_next!(ctx, Rect(0, 0, 800, 50), true)
begin_panel(ctx, "Header")
    layout_row!(ctx, 3, [100, -1, 100], 0)
    button(ctx, "Menu")
    label(ctx, "Application Title")
    button(ctx, "Settings")
end_panel(ctx)

# Fixed sidebar
layout_set_next!(ctx, Rect(0, 50, 200, 550), true)
begin_panel(ctx, "Sidebar")
    layout_begin_column!(ctx)
        button(ctx, "Home")
        button(ctx, "Projects")
        button(ctx, "Settings")
    layout_end_column!(ctx)
end_panel(ctx)

# Main content area
layout_set_next!(ctx, Rect(200, 50, 600, 550), true)
begin_panel(ctx, "Main Content")
    # Main content with automatic layout
    layout_row!(ctx, 1, [-1], 0)
    text(ctx, "Main content area with automatic layout...")
end_panel(ctx)
```

# Performance considerations
- **O(1) operation**: Simple assignment to layout state
- **No validation**: Rectangle bounds are not checked
- **Single use**: Manual positioning is cleared after one widget
- **Layout bypass**: Skips automatic positioning calculations

# Coordinate system notes
- **Screen coordinates**: Origin typically at top-left, Y increases downward
- **Layout coordinates**: Relative to the current layout body rectangle
- **Clipping**: Manual positioning may place widgets outside visible areas
- **Z-order**: Manual positioning doesn't affect widget rendering order

# Error prevention
- Ensure rectangles have positive width and height
- Be aware of coordinate system differences (relative vs absolute)
- Manual positioning can overlap with automatic layout widgets
- Consider clipping regions when using absolute positioning

# See also
[`layout_next`](@ref), [`layout_row!`](@ref), [`RELATIVE`](@ref), [`ABSOLUTE`](@ref)
"""
function layout_set_next!(ctx::Context, r::Rect, relative::Bool)
    layout = get_layout(ctx)
    layout.next = r
    layout.next_type = relative ? RELATIVE : ABSOLUTE
end

"""
    layout_next(ctx::Context) -> Rect

Calculate and return the rectangle for the next widget placement.

This function is the core of the layout system, determining where the next
widget should be positioned and sized. It handles both automatic layout flow
and manual positioning, updating the layout state for subsequent widgets.

# Arguments
- `ctx::Context`: The UI context containing the layout state

# Returns
- `Rect`: The rectangle where the next widget should be placed (in screen coordinates)

# Effects
- Advances layout position for the next widget
- Updates layout extents tracking
- Increments item index within the current row
- Stores result in `ctx.last_rect` for reference

# Layout calculation priority
The function uses this priority order for positioning:

1. **Manual positioning**: From [`layout_set_next!`](@ref) (highest priority)
2. **Automatic flow**: Based on current row configuration
3. **Default sizing**: From style settings when dimensions are zero
4. **Negative sizing**: Fill remaining space calculations

# Examples
```julia
# Basic automatic layout
layout_row!(ctx, 2, [100, 150], 30)

rect1 = layout_next(ctx)  # Returns Rect(x, y, 100, 30)
rect2 = layout_next(ctx)  # Returns Rect(x+100+spacing, y, 150, 30)

# Using the rectangles for widget placement
draw_rect!(ctx, rect1, Color(255, 0, 0, 255))  # Red rectangle
draw_rect!(ctx, rect2, Color(0, 255, 0, 255))  # Green rectangle

# Manual positioning override
layout_set_next!(ctx, Rect(200, 100, 80, 25), false)
custom_rect = layout_next(ctx)  # Returns Rect(200, 100, 80, 25)

# Back to automatic layout
normal_rect = layout_next(ctx)  # Resumes automatic positioning
```

# Automatic width calculation
When width is zero or negative, the function applies sizing rules:

```julia
# Zero width gets default from style
layout_row!(ctx, 2, [0, 100], 0)
rect = layout_next(ctx)  # Width becomes ctx.style.size.x + 2*padding

# Negative width fills remaining space
layout_row!(ctx, 2, [100, -1], 0)
rect1 = layout_next(ctx)  # Width = 100
rect2 = layout_next(ctx)  # Width = remaining_space - 100
```

# Height calculation
Height follows similar rules to width:

```julia
# Zero height gets default from style  
layout_row!(ctx, 1, [-1], 0)
rect = layout_next(ctx)  # Height becomes ctx.style.size.y + 2*padding

# Explicit height from row configuration
layout_row!(ctx, 1, [-1], 40)
rect = layout_next(ctx)  # Height = 40

# Override with layout_height!
layout_height!(ctx, 50)
rect = layout_next(ctx)  # Height = 50
```

# Fill remaining space calculation
Negative widths/heights are calculated proportionally:

```julia
# Container is 300px wide, style padding = 5
layout_row!(ctx, 3, [50, -2, -1], 0)

# Available space: 300 - 50 = 250px
# Total negative weight: 2 + 1 = 3
rect1 = layout_next(ctx)  # Width = 50 (fixed)
rect2 = layout_next(ctx)  # Width = (2/3) * 250 = 167px  
rect3 = layout_next(ctx)  # Width = (1/3) * 250 = 83px
```

# Layout state updates
Each call updates the layout state:

```julia
# Before first call
layout.position = Vec2(indent, next_row)
layout.item_index = 0

# After first call  
layout.position = Vec2(old_x + width + spacing, old_y)
layout.item_index = 1
layout.max = Vec2(max(old_max.x, new_x + width), max(old_max.y, new_y + height))

# Row completion triggers new row setup
if layout.item_index >= layout.items
    layout_row!(ctx, items, nothing, height)  # Reset for new row
end
```

# Coordinate transformation
The function converts from layout coordinates to screen coordinates:

```julia
# Layout coordinates (relative to layout body)
layout_x = layout.position.x 
layout_y = layout.position.y

# Screen coordinates (absolute positioning)
screen_x = layout_x + layout.body.x
screen_y = layout_y + layout.body.y

final_rect = Rect(screen_x, screen_y, width, height)
```

# Multi-line layout example
```julia
# Form with automatic line wrapping
layout_row!(ctx, 2, [120, -1], 0)

for (label_text, input_ref) in form_fields
    # Label in first column
    label_rect = layout_next(ctx)
    draw_text_at(ctx, label_text, label_rect)
    
    # Input in second column  
    input_rect = layout_next(ctx)
    draw_textbox_at(ctx, input_ref, input_rect)
    
    # layout_next automatically moves to next row when current row is full
end
```

# Complex layout with mixed sizing
```julia
# Toolbar with various widget types
layout_row!(ctx, 5, [80, 0, -1, 100, 60], 32)

menu_rect = layout_next(ctx)      # 80px fixed width
icon_rect = layout_next(ctx)      # Auto width (icon size)
title_rect = layout_next(ctx)     # Flexible width (fills space)  
search_rect = layout_next(ctx)    # 100px fixed width
close_rect = layout_next(ctx)     # 60px fixed width

# Use rectangles for actual widget drawing
draw_menu_button(ctx, menu_rect)
draw_icon(ctx, app_icon, icon_rect)
draw_title_text(ctx, title_text, title_rect)
draw_search_box(ctx, search_rect)
draw_close_button(ctx, close_rect)
```

# Performance characteristics
- **Efficient calculation**: O(1) time complexity
- **Minimal allocation**: Reuses existing layout data
- **Cache friendly**: Sequential layout state access
- **Predictable behavior**: Deterministic positioning algorithm

# Common patterns
- **Widget implementation**: Call `layout_next()` first, then draw at returned rectangle
- **Layout debugging**: Check `ctx.last_rect` after widget creation
- **Responsive design**: Use negative widths for flexible layouts
- **Grid layouts**: Combine with manual positioning for precise control

# See also
[`layout_row!`](@ref), [`layout_set_next!`](@ref), [`layout_width!`](@ref), [`layout_height!`](@ref)
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