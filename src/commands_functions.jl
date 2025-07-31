# ===== COMMAND FUNCTIONS =====
# Functions for building the command buffer

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