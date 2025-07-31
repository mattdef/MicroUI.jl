# ===== ID MANAGEMENT =====
# System for generating unique widget identifiers

"""
Generate unique ID from string data
Uses FNV-1a hash algorithm for consistent ID generation
"""
@inline function get_id(ctx::Context, data::AbstractString)
    base_hash = ctx.id_stack.idx > 0 ? ctx.id_stack.items[ctx.id_stack.idx] : HASH_INITIAL
    ctx.last_id = hash(data, UInt(base_hash)) % UInt32
    return ctx.last_id
end

"""
Push new ID scope onto ID stack
Creates hierarchical namespace for widget IDs
"""
function push_id!(ctx::Context, data::AbstractString)
    push!(ctx.id_stack, get_id(ctx, data))
end

"""Pop ID scope from stack"""
function pop_id!(ctx::Context)
    pop!(ctx.id_stack)
end