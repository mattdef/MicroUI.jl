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
