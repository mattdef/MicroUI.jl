# ===== FRAME MANAGEMENT =====
# Functions to manage frame lifecycle and prepare for rendering

"""
    begin_frame(ctx::Context)

Begin a new frame of UI processing and reset all frame-specific state.

This function must be called at the start of each frame, before any widgets
or containers are created. It resets all temporary state and prepares the
context for a new round of UI construction.

# Arguments
- `ctx::Context`: The UI context to begin a frame for

# Throws
- `AssertionError`: If text measurement callbacks are not set

# Effects
- Resets command buffer and string storage to empty
- Clears root container list for new frame
- Updates mouse delta calculation from previous frame
- Increments frame counter for animation and timing
- Transfers hover state from previous frame
- Clears scroll target for new frame

# Examples
```julia
ctx = Context()
init!(ctx)

# Set required callbacks
ctx.text_width = (font, str) -> measure_text_width(font, str)
ctx.text_height = font -> get_font_height(font)

# Start the frame
begin_frame(ctx)

# Build UI here...
if begin_window(ctx, "My Window", Rect(10, 10, 300, 200)) != 0
    label(ctx, "Hello, World!")
    end_window(ctx)
end

# End the frame
end_frame(ctx)
```

# Frame lifecycle
Each frame in MicroUI follows this pattern:
1. [`begin_frame`](@ref) - Reset state and prepare for UI construction
2. UI construction - Create windows, widgets, handle input
3. [`end_frame`](@ref) - Finalize state and prepare rendering commands

# Performance considerations
The function is designed to minimize allocations by reusing existing
buffers rather than creating new ones each frame.

# See also
[`end_frame`](@ref), [`init!`](@ref), [`Context`](@ref)
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

"""
    compare_zindex(a::Container, b::Container) -> Int

Compare two containers by their Z-index for sorting purposes.

This utility function provides the comparison logic for sorting containers
by their Z-index values. Containers with lower Z-index values are considered
"less than" containers with higher Z-index values.

# Arguments
- `a::Container`: The first container to compare
- `b::Container`: The second container to compare

# Returns
- `Int`: Negative if `a < b`, zero if `a == b`, positive if `a > b`

# Examples
```julia
container1 = Container()  # zindex = 0
container2 = Container()  # zindex = 5
container1.zindex = 0
container2.zindex = 5

result = compare_zindex(container1, container2)  # Returns -5 (container1 < container2)

# Used internally for sorting:
sort!(containers, by = c -> c.zindex)
```

# Usage in rendering
This function is used internally by [`end_frame`](@ref) to sort containers
in Z-order before setting up the command buffer jump chains. Lower Z-index
containers are rendered first (appear behind), higher Z-index containers
are rendered last (appear in front).

# See also
[`end_frame`](@ref), [`bring_to_front!`](@ref), [`Container`](@ref)
"""
function compare_zindex(a::Container, b::Container)
    return a.zindex - b.zindex
end

"""
    end_frame(ctx::Context)

End the current frame and prepare the command buffer for rendering.

This function finalizes the current frame by performing cleanup, validation,
input processing, and most importantly, setting up the command buffer with
proper Z-ordering for rendering. It must be called after all UI construction
is complete.

# Arguments
- `ctx::Context`: The UI context to end the frame for

# Throws
- `AssertionError`: If any stacks are not properly balanced (indicates a programming error)

# Key operations performed

## Stack validation
Ensures all stacks (container, clip, ID, layout) are properly balanced,
which indicates that all `begin_*` calls have matching `end_*` calls.

## Scroll processing
Applies accumulated scroll input to the target container that was under
the mouse during scrolling operations.

## Focus management
Clears keyboard focus if no widget explicitly claimed it during this frame,
implementing the "focus must be claimed each frame" rule of immediate mode GUIs.

## Z-order rendering setup
The most complex operation: sorts all root containers by Z-index and sets up
a chain of jump commands in the command buffer to ensure proper rendering order.

## Input state reset
Clears frame-specific input state (key presses, mouse presses, etc.) to
prepare for the next frame.

# Examples
```julia
# Complete frame cycle
begin_frame(ctx)

# UI construction...
if begin_window(ctx, "Window 1", rect1) != 0
    button(ctx, "Button 1")
    end_window(ctx)
end

if begin_window(ctx, "Window 2", rect2) != 0
    button(ctx, "Button 2") 
    end_window(ctx)
end

# Finalize and prepare for rendering
end_frame(ctx)

# Now the command buffer is ready for the rendering backend
render_commands(ctx.command_list)
```

# Z-order implementation details

The Z-order system works by modifying jump commands in the command buffer:

1. **Container sorting**: All root containers are sorted by Z-index
2. **Jump chain creation**: Each container's tail jump is modified to point to the next container's head
3. **Rendering order**: Lower Z-index containers render first, higher Z-index containers render last (on top)

```
Command Buffer Layout (after end_frame):
[Initial Jump] -> [Container1 Commands] -> [Jump] -> [Container2 Commands] -> [Jump] -> [End]
     |              (Z-index: 1)             |         (Z-index: 5)            |
     |                                       |                                  |
     +-> Points to Container1                +-> Points to Container2           +-> Points to buffer end
```

# Performance considerations
- Container sorting is O(n log n) where n is the number of root containers
- Jump command modification uses unsafe pointer operations for maximum performance
- Most operations are designed to reuse existing memory rather than allocate

# See also
[`begin_frame`](@ref), [`bring_to_front!`](@ref), [`JumpCommand`](@ref), [`Container`](@ref)
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