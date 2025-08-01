using Test

# -----------------------------------------------------------------------------
# Fonctions utilitaires pour les tests
# -----------------------------------------------------------------------------

function create_context()
    ctx = Context()
    init!(ctx)
    return ctx
end

function create_context_with_callback()
    ctx = Context()
    init!(ctx)
    
    # Set up minimal callbacks for testing
    ctx.text_width = (font, str) -> length(str) * 8
    ctx.text_height = font -> 16
    
    return ctx
end

function simulate_click(ctx::Context, x::Int, y::Int)
    input_mousemove!(ctx, x, y)
    input_mousedown!(ctx, x, y, MOUSE_LEFT)
end

function simulate_click_on_last_rect(ctx::Context)
    # Utiliser les coins du rectangle plutôt que le centre
    x = ctx.last_rect.x + 5  # Position X à l'intérieur
    y = ctx.last_rect.y + 5  # Position Y à l'intérieur
    simulate_click(ctx, Int(x), Int(y))
end