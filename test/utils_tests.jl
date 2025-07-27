using Test
using StaticArrays

# -----------------------------------------------------------------------------
# Fonctions utilitaires pour les tests
# -----------------------------------------------------------------------------

"""
Crée un contexte de test avec renderer mock
"""
function create_test_context()
    ctx, renderer = MicroUI.create_context_with_buffer_renderer(800, 600)
    MicroUI.begin_frame!(ctx)
    
    # Ouvre une fenêtre de test
    if MicroUI.begin_window!(ctx, "Test Window", 50, 50, 300, 400)
        return ctx, renderer, true
    else
        return ctx, renderer, false
    end
end

"""
Nettoie le contexte de test
"""
function cleanup_test_context(ctx)
    MicroUI.end_window!(ctx)
    MicroUI.end_frame!(ctx)
end

"""
Simule un clic de souris à une position donnée
"""
function simulate_click!(ctx, x, y)
    MicroUI.input_mousemove!(ctx, x, y)
    MicroUI.input_mousedown!(ctx, x, y, 1)
    MicroUI.input_mouseup!(ctx, x, y, 1)
end

"""
Fonction utilitaire pour simuler une interaction complète de clic
"""
function simulate_click!(ctx::MicroUI.Context{T}, pos::MicroUI.Vec2{T}, action) where T
    # Frame 1 – clic appuyé
    MicroUI.begin_frame!(ctx)
    ctx.mouse_pos = pos
    ctx.mouse_down = true
    ctx.mouse_pressed = true
    
    action()
    MicroUI.end_frame!(ctx)

    # Frame 2 – relâchement du clic
    MicroUI.begin_frame!(ctx)
    ctx.mouse_pos = pos
    ctx.mouse_pressed = false
    ctx.mouse_down = false
    
    result2 = action()
    MicroUI.end_frame!(ctx)

    return result2  # Le résultat du relâchement
end

"""
Simule un drag de souris
"""
function simulate_drag!(ctx, start_x, start_y, end_x, end_y)
    MicroUI.input_mousemove!(ctx, start_x, start_y)
    MicroUI.input_mousedown!(ctx, start_x, start_y, 1)
    MicroUI.input_mousemove!(ctx, end_x, end_y)
    MicroUI.input_mouseup!(ctx, end_x, end_y, 1)
end

"""
Simule le scroll de la souris
"""
function simulate_scroll!(ctx, x, y, delta_x=0, delta_y=-10)
    MicroUI.input_mousemove!(ctx, x, y)
    MicroUI.input_scroll!(ctx, delta_x, delta_y)
end