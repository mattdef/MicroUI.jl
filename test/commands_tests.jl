using Test

@testset "Commandes" begin
    ctx, renderer = MicroUI.create_context_with_buffer_renderer(Float32; w=200, h=200)
    
    MicroUI.begin_frame!(ctx)
    
    # Tester les commandes de dessin
    test_rect = MicroUI.rect(Float32, 10, 10, 50, 30)
    MicroUI.draw_rect!(ctx, test_rect, MicroUI.COLOR_BUTTON)
    
    # Vérifier qu'une commande a été ajoutée
    @test length(ctx.command_list) > 0
    @test ctx.command_list[end] isa MicroUI.RectCommand
    
    # Tester le dessin de texte
    text_pos = MicroUI.vec2(Float32, 20, 20)
    MicroUI.draw_text!(ctx, nothing, "Test", text_pos, MicroUI.COLOR_TEXT)
    
    @test ctx.command_list[end] isa MicroUI.TextCommand
    @test ctx.command_list[end].text == "Test"
    
    # Tester le dessin d'icône
    icon_rect = MicroUI.rect(Float32, 30, 30, 16, 16)
    MicroUI.draw_icon!(ctx, MicroUI.ICON_CLOSE, icon_rect, MicroUI.COLOR_TEXT)
    
    @test ctx.command_list[end] isa MicroUI.IconCommand
    @test ctx.command_list[end].id == MicroUI.ICON_CLOSE
    
    MicroUI.end_frame!(ctx)
end