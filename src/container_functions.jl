# ===== CONTAINER MANAGEMENT =====
# Functions for managing containers (windows, panels, etc.)

"""Get current container from container stack"""
function get_current_container(ctx::Context)
    @assert ctx.container_stack.idx > 0 "No container on stack"
    return ctx.container_stack.items[ctx.container_stack.idx]
end

"""
Get or create container with given ID
Uses pool for efficient container reuse
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

"""Convenience function to get container by name"""
function get_container(ctx::Context, name::String)
    id = get_id(ctx, name)
    return get_container(ctx, id, UInt16(0))
end

"""
Bring container to front by updating its Z-index
Higher Z-index containers are rendered on top
"""
function bring_to_front!(ctx::Context, cnt::Container)
    ctx.last_zindex += 1
    cnt.zindex = ctx.last_zindex
end