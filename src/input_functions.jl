# ===== INPUT FUNCTIONS =====
# Functions for handling mouse, keyboard, and text input

"""Update mouse position"""
function input_mousemove!(ctx::Context, x::Int, y::Int)
    ctx.mouse_pos = Vec2(Int32(x), Int32(y))
end

"""Handle mouse button press event"""
function input_mousedown!(ctx::Context, x::Int, y::Int, btn::MouseButton)
    input_mousemove!(ctx, x, y)
    ctx.mouse_down |= UInt8(btn)
    ctx.mouse_pressed |= UInt8(btn)
end

"""Convenience overload for Int32 coordinates"""
input_mousedown!(ctx::Context, x::Int32, y::Int32, btn::MouseButton) = input_mousedown!(ctx, Int64(x), Int64(y), btn)

"""Handle mouse button release event"""
function input_mouseup!(ctx::Context, x::Int, y::Int, btn::MouseButton)
    input_mousemove!(ctx, x, y)
    ctx.mouse_down &= ~UInt8(btn)
end

"""Convenience overload for Int32 coordinates"""
input_mouseup!(ctx::Context, x::Int32, y::Int32, btn::MouseButton) = input_mouseup!(ctx, Int64(x), Int64(y), btn)

"""Handle mouse scroll wheel input"""
function input_scroll!(ctx::Context, x::Int, y::Int)
    ctx.scroll_delta = Vec2(ctx.scroll_delta.x + Int32(x), ctx.scroll_delta.y + Int32(y))
end

"""Handle key press event"""
function input_keydown!(ctx::Context, key::Key)
    ctx.key_pressed |= UInt8(key)
    ctx.key_down |= UInt8(key)
end

"""Handle key release event"""
function input_keyup!(ctx::Context, key::Key)
    ctx.key_down &= ~UInt8(key)
end

"""Add text input for current frame"""
function input_text!(ctx::Context, text::String)
    ctx.input_text *= text
end