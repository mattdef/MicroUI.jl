# ===== ID MANAGEMENT =====
# System for generating unique widget identifiers

"""
    get_id(ctx::Context, data::AbstractString) -> Id

Generate a unique widget identifier from string data using FNV-1a hashing.

This function creates a unique 32-bit identifier for widgets based on the input
string and the current ID stack context. The same string will generate the same
ID within the same context, but different IDs in different contexts, enabling
proper widget identification even when multiple widgets share the same name.

# Arguments
- `ctx::Context`: The UI context containing the ID stack
- `data::AbstractString`: The string data to generate an ID from (typically widget name)

# Returns
- `Id`: A unique 32-bit identifier for the widget

# Algorithm details
Uses the FNV-1a (Fowler-Noll-Vo) hash algorithm with the following properties:
- **Base hash**: Uses the current ID stack top as seed, or `HASH_INITIAL` if stack is empty
- **Collision resistance**: FNV-1a provides good distribution for short strings
- **Deterministic**: Same input + same context = same ID
- **Context-sensitive**: Different ID stack contexts produce different IDs

# Examples
```julia
ctx = Context()
init!(ctx)

# Simple ID generation
button_id = get_id(ctx, "save_button")    # Returns unique ID
same_id = get_id(ctx, "save_button")      # Returns same ID
different_id = get_id(ctx, "load_button") # Returns different ID

# Context-sensitive IDs
push_id!(ctx, "window1")
window1_button = get_id(ctx, "ok")  # ID for "ok" in window1 context
pop_id!(ctx)

push_id!(ctx, "window2") 
window2_button = get_id(ctx, "ok")  # Different ID for "ok" in window2 context
pop_id!(ctx)

@assert window1_button != window2_button  # Same name, different contexts
```

# Hierarchical ID system
The ID generation is hierarchical - the current ID stack state affects the
generated ID, allowing the same widget name to have different identities
in different contexts:

```julia
# Without context - global scope
global_button = get_id(ctx, "button")

# With single context level
push_id!(ctx, "dialog")
dialog_button = get_id(ctx, "button")  # Different from global_button

# With nested context levels  
push_id!(ctx, "settings_panel")
nested_button = get_id(ctx, "button")  # Different from both above
pop_id!(ctx)  # Exit settings_panel
pop_id!(ctx)  # Exit dialog
```

# Performance characteristics
- **Time complexity**: O(n) where n is the length of the input string
- **Space complexity**: O(1) - no additional memory allocation
- **Cache friendly**: Uses simple arithmetic operations
- **Inlined**: Marked with `@inline` for zero-overhead calls

# Implementation notes
- The generated ID is stored in `ctx.last_id` for convenience
- Uses Julia's built-in `hash()` function with FNV-1a algorithm
- Result is truncated to 32-bit for consistent `Id` type
- Thread-safe as long as the context is not shared between threads

# See also
[`push_id!`](@ref), [`pop_id!`](@ref), [`Id`](@ref), [`HASH_INITIAL`](@ref)
"""
@inline function get_id(ctx::Context, data::AbstractString)
    base_hash = ctx.id_stack.idx > 0 ? ctx.id_stack.items[ctx.id_stack.idx] : HASH_INITIAL
    ctx.last_id = hash(data, UInt(base_hash)) % UInt32
    return ctx.last_id
end

"""
    push_id!(ctx::Context, data::AbstractString)

Push a new ID scope onto the ID stack, creating a hierarchical namespace.

This function creates a new ID context by generating an ID from the input
data and pushing it onto the ID stack. All subsequent `get_id` calls will
use this new context as their base hash, creating a hierarchical namespace
for widget identification.

# Arguments
- `ctx::Context`: The UI context containing the ID stack
- `data::AbstractString`: The string data defining the new scope (e.g., window name, panel name)

# Effects
- Generates an ID from `data` using current context
- Pushes the generated ID onto the ID stack
- All subsequent widget IDs will be scoped within this context

# Throws
- `ErrorException`: If the ID stack overflows (too many nested contexts)

# Examples
```julia
ctx = Context()
init!(ctx)

# Create a window scope
push_id!(ctx, "preferences_window")

# These widgets are scoped within the preferences window
ok_button_id = get_id(ctx, "ok")
cancel_button_id = get_id(ctx, "cancel")

# Create a nested panel scope
push_id!(ctx, "advanced_panel")
reset_button_id = get_id(ctx, "reset")  # Scoped within window + panel
pop_id!(ctx)  # Exit panel scope

# Still within window scope
apply_button_id = get_id(ctx, "apply")
pop_id!(ctx)  # Exit window scope

# Back to global scope
global_button_id = get_id(ctx, "help")
```

# Common usage patterns

## Window scoping
```julia
# Each window creates its own ID scope
push_id!(ctx, "main_window")
# ... window content ...
pop_id!(ctx)

push_id!(ctx, "settings_dialog")  
# ... dialog content ...
pop_id!(ctx)
```

## Dynamic scoping
```julia
# Loop with unique scopes
for i in 1:5
    push_id!(ctx, "item_\$i")
    item_button = get_id(ctx, "delete")  # Each button gets unique ID
    pop_id!(ctx)
end
```

## Object-based scoping
```julia
# Use object identity for unique scoping
for obj in objects
    push_id!(ctx, string(objectid(obj)))
    obj_controls = create_object_ui(ctx, obj)
    pop_id!(ctx)
end
```

# Stack management
The ID stack has a maximum depth defined by `IDSTACK_SIZE`. Exceeding this
limit will raise an error. Always ensure that every `push_id!` has a
corresponding `pop_id!` call, preferably using try-finally blocks for
error safety:

```julia
push_id!(ctx, "critical_section")
try
    # UI code that might throw
    build_complex_ui(ctx)
finally
    pop_id!(ctx)  # Always cleanup, even on error
end
```

# See also
[`pop_id!`](@ref), [`get_id`](@ref), [`Stack`](@ref), [`IDSTACK_SIZE`](@ref)
"""
function push_id!(ctx::Context, data::AbstractString)
    push!(ctx.id_stack, get_id(ctx, data))
end

"""
    pop_id!(ctx::Context)

Remove the current ID scope from the stack, returning to the previous context.

This function removes the top ID context from the ID stack, reverting to
the previous scope level. All subsequent `get_id` calls will use the
previous context as their base hash.

# Arguments
- `ctx::Context`: The UI context containing the ID stack

# Effects
- Removes the top ID from the ID stack
- Subsequent widget IDs will use the previous context scope
- If stack becomes empty, future IDs will use global scope

# Throws
- `ErrorException`: If the ID stack is already empty (stack underflow)

# Examples
```julia
ctx = Context()
init!(ctx)

# Start in global scope
global_id = get_id(ctx, "widget")

# Enter a scoped context
push_id!(ctx, "window1")
scoped_id = get_id(ctx, "widget")  # Different from global_id

# Return to global scope
pop_id!(ctx)
back_to_global = get_id(ctx, "widget")  # Same as global_id

@assert global_id == back_to_global
@assert global_id != scoped_id
```

# Balanced usage
Always ensure that `push_id!` and `pop_id!` calls are balanced:

```julia
# ✅ Correct - balanced calls
push_id!(ctx, "scope1")
    push_id!(ctx, "scope2")
        # ... widgets ...
    pop_id!(ctx)  # Exit scope2
pop_id!(ctx)      # Exit scope1

# ❌ Incorrect - unbalanced (will cause assertion errors)
push_id!(ctx, "scope1")
    push_id!(ctx, "scope2") 
        # ... widgets ...
    # Missing pop_id!() for scope2
pop_id!(ctx)  # Only exits scope1, scope2 remains on stack
```

# Error handling
For robust code, especially when exceptions might occur during UI construction,
use try-finally blocks to ensure cleanup:

```julia
push_id!(ctx, "error_prone_section")
try
    # Code that might throw exceptions
    complex_ui_with_potential_errors(ctx)
    
    push_id!(ctx, "nested_section")
    try
        even_more_complex_ui(ctx)
    finally
        pop_id!(ctx)  # Always cleanup nested section
    end
    
finally
    pop_id!(ctx)  # Always cleanup main section
end
```

# Stack validation
MicroUI automatically validates stack balance at frame end. If the ID stack
is not empty when [`end_frame`](@ref) is called, an assertion error will be
raised, helping catch unbalanced push/pop calls during development.

# Performance notes
- **Time complexity**: O(1) - constant time operation
- **Space complexity**: O(1) - no memory allocation
- **Inlined**: Stack operations are optimized for performance

# See also
[`push_id!`](@ref), [`get_id`](@ref), [`end_frame`](@ref), [`Stack`](@ref)
"""
function pop_id!(ctx::Context)
    pop!(ctx.id_stack)
end