using Test

# ============================================================================
# TESTS DES CONTRÔLES
# ============================================================================

@testset "Controls et Widgets" begin

    @testset "Button Simple" begin
        ctx = create_context()
        
        # Frame 1: Setup
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            button(ctx, "Test Button")
            rect = ctx.last_rect
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Hover d'abord
        input_mousemove!(ctx, Int(rect.x + 10), Int(rect.y + 10))
        @info "État après mousemove" mouse_down=ctx.mouse_down
        
        # Frame 2: Établir hover
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            button(ctx, "Test Button")
            @info "Après hover frame" hover=ctx.hover mouse_down=ctx.mouse_down
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Maintenant cliquer
        input_mousedown!(ctx, Int(rect.x + 10), Int(rect.y + 10), MicroUI.MOUSE_LEFT)
        @info "État après mousedown" mouse_down=ctx.mouse_down mouse_pressed=ctx.mouse_pressed
        
        # Frame 3: Détecter clic
        begin_frame(ctx)
        clicked = false
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            res = button(ctx, "Test Button")
            @info "Après click frame" hover=ctx.hover focus=ctx.focus res=res
            if res & Int(MicroUI.RES_SUBMIT) != 0
                clicked = true
            end
            end_window(ctx)
        end
        end_frame(ctx)

        input_mouseup!(ctx, Int(rect.x + 10), Int(rect.y + 10), MicroUI.MOUSE_LEFT)
        @info "État après mouseup" mouse_down=ctx.mouse_down
        
        @test clicked == true
    end

    @testset "Checkbox" begin
        ctx = create_context()
        state = Ref(false)
        
        # Frame 1: Setup sans clic
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            checkbox!(ctx, "Test Check", state)
            rect = ctx.last_rect
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Hover d'abord (sans clic)
        input_mousemove!(ctx, rect.x + 5, rect.y + 5)
        
        # Frame 2: Établir hover
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            checkbox!(ctx, "Test Check", state)
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Maintenant cliquer
        input_mousedown!(ctx, rect.x + 5, rect.y + 5, MicroUI.MOUSE_LEFT)
        
        # Frame 3: Traiter le clic DANS LE MÊME FRAME
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            res = checkbox!(ctx, "Test Check", state)
            @test res & Int(MicroUI.RES_CHANGE) != 0
            @test state[] == true
            end_window(ctx)
        end
        end_frame(ctx)
        
        input_mouseup!(ctx, rect.x + 5, rect.y + 5, MicroUI.MOUSE_LEFT)
    end
    
    @testset "Textbox" begin
        ctx = create_context()
        text = Ref("Initial")
        
        # Frame 1: Setup
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            textbox!(ctx, text, 100)
            rect = ctx.last_rect
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Hover d'abord
        input_mousemove!(ctx, rect.x + 10, rect.y + 10)
        
        # Frame 2: Établir hover
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            textbox!(ctx, text, 100)
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Maintenant cliquer pour le focus ET donner l'input text
        input_mousedown!(ctx, rect.x + 10, rect.y + 10, MicroUI.MOUSE_LEFT)
        input_text!(ctx, " Text")  # L'input text AVANT le frame
        
        # Frame 3: Focus + traiter l'input text
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            res = textbox!(ctx, text, 100)
            @test text[] == "Initial Text"
            @test res & Int(MicroUI.RES_CHANGE) != 0
            end_window(ctx)
        end
        end_frame(ctx)
        
        input_mouseup!(ctx, rect.x + 10, rect.y + 10, MicroUI.MOUSE_LEFT)
    end
    
    @testset "Slider" begin
        ctx = create_context()
        value = Ref(5.0f0)
        initial = value[]
        
        # Frame 1: Setup
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            slider!(ctx, value, 0.0f0, 10.0f0)
            rect = ctx.last_rect
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Hover d'abord (au milieu du slider)
        mid_x = rect.x + rect.w ÷ 2
        mid_y = rect.y + rect.h ÷ 2
        input_mousemove!(ctx, mid_x, mid_y)
        
        # Frame 2: Établir hover
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            slider!(ctx, value, 0.0f0, 10.0f0)
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Maintenant cliquer ET bouger DANS LA LIMITE DU SLIDER
        input_mousedown!(ctx, mid_x, mid_y, MicroUI.MOUSE_LEFT)
        # CORRECTION : Utiliser round(Int, ...) au lieu de Int(...)
        new_x = rect.x + round(Int, rect.w * 0.8) 
        input_mousemove!(ctx, new_x, mid_y)
        
        # Frame 3: Détecter drag
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            res = slider!(ctx, value, 0.0f0, 10.0f0)
            @info "Slider test" initial=initial new_value=value[] rect=rect new_x=new_x
            @test value[] > initial
            @test value[] <= 10.0f0
            @test res & Int(MicroUI.RES_CHANGE) != 0
            end_window(ctx)
        end
        end_frame(ctx)
        
        input_mouseup!(ctx, new_x, mid_y, MicroUI.MOUSE_LEFT)
    end
    
    @testset "Number" begin
        ctx = create_context()
        value = Ref(42.0f0)
        
        # Frame 1: Setup
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            number!(ctx, value, 1.0f0)
            rect = ctx.last_rect
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Hover d'abord
        input_mousemove!(ctx, rect.x + 10, rect.y + 10)
        
        # Frame 2: Établir hover
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            number!(ctx, value, 1.0f0)
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Maintenant cliquer ET commencer le drag dans le même input
        input_mousedown!(ctx, rect.x + 10, rect.y + 10, MicroUI.MOUSE_LEFT)
        input_mousemove!(ctx, rect.x + 20, rect.y + 10)  # Bouger de 10 pixels vers la droite
        
        # Frame 3: Détecter focus + drag
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
            res = number!(ctx, value, 1.0f0)
            @test value[] == 52.0f0  # 42 + 10*1
            @test res & Int(MicroUI.RES_CHANGE) != 0
            end_window(ctx)
        end
        end_frame(ctx)
        
        input_mouseup!(ctx, ctx.mouse_pos.x, ctx.mouse_pos.y, MicroUI.MOUSE_LEFT)
    end

end