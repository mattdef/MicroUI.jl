import MicroUI

ctx, renderer = create_context_with_buffer_renderer()

mu_input_mousemove(ctx, 60, 70)
mu_input_mousedown(ctx, 60, 70, 1)

mu_begin(ctx)

mu_begin_window(ctx, "Ma Fenetre", 50, 50, 300, 150)
mu_text(ctx, "Bonjour Julia UI")
if mu_button(ctx, "Cliquez-moi")
    println("Bouton cliqué !")
end
mu_end_window(ctx)

mu_end(ctx)