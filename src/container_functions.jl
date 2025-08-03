# ===== CONTAINER MANAGEMENT =====
# Functions for managing containers (windows, panels, etc.)

"""
    get_current_container(ctx::Context) -> Container

Get the current active container from the container stack.

This function returns the container that is currently at the top of the container stack,
which represents the currently active UI container (window, panel, etc.) that widgets
are being added to.

# Arguments
- `ctx::Context`: The MicroUI context containing the container stack

# Returns
- `Container`: The currently active container

# Throws
- `AssertionError`: If the container stack is empty (no active container)

# Examples
```julia
ctx = Context()
begin_frame(ctx)
if begin_window(ctx, "MyWindow", Rect(0, 0, 300, 200)) != 0
    container = get_current_container(ctx)
    # Use container for layout calculations, etc.
    end_window(ctx)
end
end_frame(ctx)
```

# See Also
- [`begin_window`](@ref): Start a new window container
- [`begin_panel`](@ref): Start a new panel container
"""
function get_current_container(ctx::Context)
    @assert ctx.container_stack.idx > 0 "No container on stack"
    return ctx.container_stack.items[ctx.container_stack.idx]
end

"""
    get_container(ctx::Context, id::Id, opt::UInt16) -> Union{Container, Nothing}

Get an existing container from the pool or create a new one with the given ID.

This function implements efficient container reuse through a pooling system. It first
attempts to find an existing container with the specified ID. If found and the container
meets the visibility criteria, it updates the pool and returns the container. If not found
and the container should be visible, it initializes a new container from the pool.

# Arguments
- `ctx::Context`: The MicroUI context
- `id::Id`: Unique identifier for the container
- `opt::UInt16`: Option flags controlling container behavior (see [`Option`](@ref))

# Returns
- `Container`: The requested container if it should be visible
- `Nothing`: If the container should be closed (when `OPT_CLOSED` flag is set and container doesn't exist)

# Container Pool Behavior
The function uses a least-recently-used (LRU) pool for efficient memory management:
1. Searches for existing container with matching ID
2. If found and should be visible, updates access time and returns it
3. If not found and should be visible, allocates from pool and initializes
4. If `OPT_CLOSED` flag is set and container doesn't exist, returns `nothing`

# Examples
```julia
ctx = Context()
id = get_id(ctx, "my_window")

# Get or create a normal container
container = get_container(ctx, id, UInt16(0))

# Get container only if it already exists and is open
container = get_container(ctx, id, UInt16(OPT_CLOSED))
if container !== nothing
    # Container exists and is open
end
```

# See Also
- [`get_container(ctx::Context, name::String)`](@ref): Convenience overload using string name
- [`pool_get`](@ref): Low-level pool lookup function
- [`pool_init!`](@ref): Pool initialization function
- [`bring_to_front!`](@ref): Z-index management
"""
function get_container(ctx::Context, id::Id, opt::UInt16)
    # Try to get existing container from pool
    idx = pool_get(ctx, ctx.container_pool, CONTAINERPOOL_SIZE, id)
    if idx >= 0
        if ctx.containers[idx].open || (opt & UInt16(OPT_CLOSED)) == 0
            pool_update!(ctx, ctx.container_pool, idx)
        end
        return ctx.containers[idx]
    end
    
    if (opt & UInt16(OPT_CLOSED)) != 0
        return nothing
    end
    
    # Container not found: initialize new one
    idx = pool_init!(ctx, ctx.container_pool, CONTAINERPOOL_SIZE, id)
    cnt = ctx.containers[idx]
    cnt.head = 0
    cnt.tail = 0
    cnt.rect = Rect(0, 0, 0, 0)
    cnt.body = Rect(0, 0, 0, 0)
    cnt.content_size = Vec2(0, 0)
    cnt.scroll = Vec2(0, 0)
    cnt.zindex = 0
    cnt.open = true
    bring_to_front!(ctx, cnt)
    return cnt
end

"""
    get_container(ctx::Context, name::String) -> Union{Container, Nothing}

Convenience function to get a container by its string name.

This is a convenience overload that generates an ID from the string name and calls
the main `get_container` function with default options (no special flags).

# Arguments
- `ctx::Context`: The MicroUI context
- `name::String`: String name of the container (will be hashed to generate ID)

# Returns
- `Container`: The requested container if it should be visible
- `Nothing`: If the container cannot be created

# Examples
```julia
ctx = Context()

# Get or create container by name
container = get_container(ctx, "settings_window")

# Equivalent to:
# id = get_id(ctx, "settings_window")
# container = get_container(ctx, id, UInt16(0))
```

# See Also
- [`get_container(ctx::Context, id::Id, opt::UInt16)`](@ref): Main implementation
- [`get_id`](@ref): ID generation from string
"""
function get_container(ctx::Context, name::String)
    id = get_id(ctx, name)
    return get_container(ctx, id, UInt16(0))
end

"""
    bring_to_front!(ctx::Context, cnt::Container) -> Nothing

Bring a container to the front by updating its Z-index.

This function ensures that the specified container will be rendered on top of all
other containers by assigning it the highest Z-index value. The global Z-index counter
is incremented, and the container's Z-index is set to this new maximum value.

# Arguments
- `ctx::Context`: The MicroUI context containing the Z-index counter
- `cnt::Container`: The container to bring to front

# Z-Index Behavior
- Higher Z-index values are rendered on top of lower values
- The global `last_zindex` counter ensures each container gets a unique Z-index
- Containers are sorted by Z-index during frame rendering in [`end_frame`](@ref)

# Examples
```julia
ctx = Context()
container = get_container(ctx, "popup_window")

# Bring popup to front (e.g., when user clicks on it)
bring_to_front!(ctx, container)

# The container will now render on top of all others
```

# Performance Notes
This operation is O(1) and only updates the Z-index. The actual sorting of containers
by Z-index happens once per frame during `end_frame()`.

# See Also
- [`end_frame`](@ref): Frame finalization where Z-index sorting occurs
- [`get_container`](@ref): Container creation automatically calls this function
"""
function bring_to_front!(ctx::Context, cnt::Container)
    ctx.last_zindex += 1
    cnt.zindex = ctx.last_zindex
end