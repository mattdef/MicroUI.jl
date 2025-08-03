# ===== COMMAND FUNCTIONS =====
# Functions for building the command buffer

"""
    write_command!(cmdlist::CommandList, cmd::T) where T -> Int

Write a rendering command to the command buffer and return its position.

This function stores a command in the binary command buffer for later
execution by the rendering backend. The command is written as raw binary
data for maximum performance during rendering.

# Arguments
- `cmdlist::CommandList`: The command list to write to
- `cmd::T`: The command to write (must be a concrete command type)

# Returns
- `Int`: The byte offset where the command was written in the buffer

# Throws
- `ErrorException`: If the command buffer would overflow

# Examples
```julia
# Create a rectangle drawing command
rect_cmd = RectCommand(
    BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
    Rect(10, 20, 100, 50),
    Color(255, 0, 0, 255)
)

# Write it to the command list
offset = write_command!(ctx.command_list, rect_cmd)
```

# Implementation details
The function uses unsafe pointer operations for maximum performance,
directly copying the command struct into the buffer as binary data.

# See also
[`read_command`](@ref), [`push_command!`](@ref), [`CommandList`](@ref)
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
    write_string!(cmdlist::CommandList, str::String) -> Int32

Store a string in the command list and return its index.

This function adds a string to the string storage array and returns
an index that can be used by text rendering commands to reference
the string data. The string storage automatically grows as needed.

# Arguments
- `cmdlist::CommandList`: The command list to store the string in
- `str::String`: The string to store

# Returns
- `Int32`: The index of the stored string (1-based)

# Examples
```julia
# Store a string for later use in text commands
str_index = write_string!(ctx.command_list, "Hello, World!")

# The index can be used in text commands
text_cmd = TextCommand(
    BaseCommand(COMMAND_TEXT, sizeof(TextCommand)),
    font, pos, color, str_index, length("Hello, World!")
)
```

# Implementation details
- String indices are 1-based following Julia conventions
- The string array automatically doubles in size when needed
- Strings are stored by value, not by reference

# See also
[`get_string`](@ref), [`push_text_command!`](@ref), [`TextCommand`](@ref)
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
    read_command(cmdlist::CommandList, idx::CommandPtr, ::Type{T}) where T -> T

Read a command from the buffer at the specified offset.

This function retrieves a previously written command from the command
buffer by interpreting the binary data at the given offset as the
specified command type.

# Arguments
- `cmdlist::CommandList`: The command list to read from
- `idx::CommandPtr`: The byte offset where the command starts
- `::Type{T}`: The type of command to read (used for type parameter)

# Returns
- `T`: The command struct read from the buffer

# Throws
- `ErrorException`: If the index is out of bounds or would read past the buffer end

# Examples
```julia
# Read a rectangle command from a known offset
rect_cmd = read_command(cmdlist, 0, RectCommand)
println("Rectangle at: (\$(rect_cmd.rect.x), \$(rect_cmd.rect.y))")

# Read any command by checking its type first
base = read_command(cmdlist, offset, BaseCommand)
if base.type == COMMAND_RECT
    rect_cmd = read_command(cmdlist, offset, RectCommand)
end
```

# Safety considerations
This function uses unsafe pointer operations for performance. The caller
must ensure that the offset points to a valid command of the specified type.

# See also
[`write_command!`](@ref), [`next_command!`](@ref), [`CommandIterator`](@ref)
"""
function read_command(cmdlist::CommandList, idx::CommandPtr, ::Type{T}) where T
    if idx < 0 || idx + sizeof(T) > cmdlist.idx
        error("Invalid command index")
    end
    ptr = pointer(cmdlist.buffer, idx + 1)
    return unsafe_load(Ptr{T}(ptr))
end

"""
    get_string(cmdlist::CommandList, str_index::Int32) -> String

Retrieve a string from the string table by its index.

This function fetches a previously stored string using the index
returned by [`write_string!`](@ref). Used during command processing
to access string data for text rendering commands.

# Arguments
- `cmdlist::CommandList`: The command list containing the string table
- `str_index::Int32`: The 1-based index of the string to retrieve

# Returns
- `String`: The string stored at the specified index

# Examples
```julia
# Store a string and retrieve it later
str_index = write_string!(cmdlist, "Hello, World!")
retrieved = get_string(cmdlist, str_index)
@assert retrieved == "Hello, World!"

# Used during text command processing
text_cmd = read_command(cmdlist, offset, TextCommand)
display_text = get_string(cmdlist, text_cmd.str_index)
```

# Note
String indices are 1-based. Using an invalid index will cause
a bounds error when accessing the string array.

# See also
[`write_string!`](@ref), [`TextCommand`](@ref), [`push_text_command!`](@ref)
"""
function get_string(cmdlist::CommandList, str_index::Int32)
    return cmdlist.strings[str_index]
end

"""
    next_command!(iter::CommandIterator) -> (Bool, CommandType, CommandPtr)

Advance the command iterator to the next command, handling jumps automatically.

This function provides the primary mechanism for traversing the command
buffer. It automatically follows jump commands to maintain proper Z-order
rendering while skipping over commands that should not be executed.

# Arguments
- `iter::CommandIterator`: The iterator to advance

# Returns
- `Bool`: `true` if a command was found, `false` if at end of buffer
- `CommandType`: The type of the current command (valid only if first return is `true`)
- `CommandPtr`: The offset of the current command (valid only if first return is `true`)

# Examples
```julia
# Iterate through all commands in a command list
iter = CommandIterator(ctx.command_list)
while true
    (has_cmd, cmd_type, cmd_offset) = next_command!(iter)
    if !has_cmd
        break
    end
    
    if cmd_type == COMMAND_RECT
        rect_cmd = read_command(iter.cmdlist, cmd_offset, RectCommand)
        # Process rectangle command...
    elseif cmd_type == COMMAND_TEXT
        text_cmd = read_command(iter.cmdlist, cmd_offset, TextCommand)
        # Process text command...
    end
end
```

# Jump handling
When the iterator encounters a `COMMAND_JUMP`, it automatically follows
the jump destination instead of returning the jump command itself. This
allows the rendering system to maintain proper Z-order without manual
jump handling.

# Performance notes
The function is marked with `@inline` and uses `@inbounds` for maximum
performance during rendering, as this is typically called in tight loops.

# See also
[`CommandIterator`](@ref), [`read_command`](@ref), [`JumpCommand`](@ref)
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
    push_command!(ctx::Context, cmd::T) where T -> CommandPtr

Add a command to the command buffer in the UI context.

This is a convenience wrapper around [`write_command!`](@ref) that
operates on the context's command list. Most UI code should use this
function rather than calling `write_command!` directly.

# Arguments
- `ctx::Context`: The UI context containing the command list
- `cmd::T`: The command to add

# Returns
- `CommandPtr`: The offset where the command was written

# Examples
```julia
# Add a rectangle drawing command
rect_cmd = RectCommand(
    BaseCommand(COMMAND_RECT, sizeof(RectCommand)),
    Rect(10, 20, 100, 50),
    Color(255, 0, 0, 255)
)
offset = push_command!(ctx, rect_cmd)
```

# See also
[`write_command!`](@ref), [`push_text_command!`](@ref), [`push_jump_command!`](@ref)
"""
function push_command!(ctx::Context, cmd::T) where T
    return write_command!(ctx.command_list, cmd)
end

"""
    push_text_command!(ctx::Context, font::Font, str::String, pos::Vec2, color::Color) -> CommandPtr

Add a text rendering command with string data to the command buffer.

This function handles both string storage and command creation for text
rendering. It automatically stores the string in the string table and
creates a complete text command with the string reference.

# Arguments
- `ctx::Context`: The UI context
- `font::Font`: The font to use for rendering (type depends on backend)
- `str::String`: The text string to render
- `pos::Vec2`: The baseline position for the text
- `color::Color`: The text color

# Returns
- `CommandPtr`: The offset where the text command was written

# Examples
```julia
# Add a text rendering command
offset = push_text_command!(
    ctx,
    my_font,
    "Hello, World!",
    Vec2(100, 50),
    Color(255, 255, 255, 255)
)
```

# Implementation details
The function first stores the string using [`write_string!`](@ref), then
creates a [`TextCommand`](@ref) with the string index and length. This
design separates string storage from command data for efficient memory usage.

# See also
[`write_string!`](@ref), [`TextCommand`](@ref), [`push_command!`](@ref)
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
    push_jump_command!(ctx::Context, dst::CommandPtr) -> CommandPtr

Add a jump command for non-linear command buffer traversal.

Jump commands enable the Z-ordering system by allowing the command buffer
to skip sections or redirect execution flow. They are primarily used to
implement container layering where higher Z-index containers should be
rendered after lower ones.

# Arguments
- `ctx::Context`: The UI context
- `dst::CommandPtr`: The destination offset to jump to

# Returns
- `CommandPtr`: The offset where the jump command was written

# Examples
```julia
# Create a jump to skip over low-priority content
skip_target = ctx.command_list.idx + calculate_skip_size()
jump_offset = push_jump_command!(ctx, skip_target)

# Add low-priority commands here...
# When processed, these will be skipped due to the jump

# Continue with high-priority commands at skip_target
```

# Z-order implementation
The rendering system uses jump commands to implement Z-ordering:
1. Containers with lower Z-index have jumps to higher Z-index containers
2. The final container jumps to the end of the command buffer
3. This ensures higher Z-index content is rendered last (on top)

# See also
[`JumpCommand`](@ref), [`next_command!`](@ref), [`end_frame`](@ref)
"""
function push_jump_command!(ctx::Context, dst::CommandPtr)
    jump_cmd = JumpCommand(
        BaseCommand(COMMAND_JUMP, sizeof(JumpCommand)),
        dst
    )
    return write_command!(ctx.command_list, jump_cmd)
end

"""
    set_clip!(ctx::Context, rect::Rect)

Set the clipping rectangle for subsequent rendering commands.

This function adds a clip command to the command buffer that will
restrict all following rendering operations to the specified rectangle.
The clipping remains active until another clip command is issued.

# Arguments
- `ctx::Context`: The UI context
- `rect::Rect`: The clipping rectangle in screen coordinates

# Examples
```julia
# Set clipping to a specific area
set_clip!(ctx, Rect(10, 10, 200, 100))

# All subsequent drawing will be clipped to this rectangle
draw_rect!(ctx, Rect(0, 0, 300, 200), color)  # Only the intersection will be visible

# Reset to unclipped state
set_clip!(ctx, UNCLIPPED_RECT)
```

# Backend interaction
The rendering backend should process `COMMAND_CLIP` commands by updating
its clipping state. This typically involves setting scissor rectangles
or clip planes in the graphics API.

# Performance considerations
Excessive clipping changes can impact rendering performance. The drawing
functions use [`check_clip`](@ref) to minimize clip state changes by
only setting clips when actually needed.

# See also
[`ClipCommand`](@ref), [`check_clip`](@ref), [`UNCLIPPED_RECT`](@ref), [`push_clip_rect!`](@ref)
"""
function set_clip!(ctx::Context, rect::Rect)
    clip_cmd = ClipCommand(BaseCommand(COMMAND_CLIP, sizeof(ClipCommand)), rect)
    push_command!(ctx, clip_cmd)
end