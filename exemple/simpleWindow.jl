import MicroUI

ctx, renderer = MicroUI.create_context_with_buffer_renderer(200, 120)

function render_frame()
    MicroUI.clear!(renderer, MicroUI.mu_color(50, 50, 50, 255))

    MicroUI.mu_begin(ctx)

    if MicroUI.mu_begin_window(ctx, "My Window", MicroUI.mu_rect(10, 10, 140, 86)) != 0
        MicroUI.mu_layout_row(ctx, 2, [60, -1], 0)

        MicroUI.mu_label(ctx, "First:")
        if MicroUI.mu_button(ctx, "Button1") != 0
            println("Button1 pressed")
        end

        MicroUI.mu_label(ctx, "Second:")
        if MicroUI.mu_button(ctx, "Button2") != 0
            MicroUI.mu_open_popup(ctx, "My Popup")
        end

        if MicroUI.mu_begin_popup(ctx, "My Popup") != 0
            MicroUI.mu_label(ctx, "Hello world!")
            MicroUI.mu_end_popup(ctx)
        end

        MicroUI.mu_end_window(ctx)
    end

    MicroUI.mu_end(ctx)
    present!(renderer)
end

render_frame()
# save_buffer_as_ppm(renderer, "simpleWindow.ppm")