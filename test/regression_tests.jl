using Test

include("utils_tests.jl")

# ============================================================================
# TESTS DE RÉGRESSION
# ============================================================================

@testset "Tests de Régression" begin
    @testset "ID collision" begin
        ctx = create_test_context()
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) == RES_ACTIVE
            # Deux boutons avec le même label ne doivent pas avoir le même ID
            # grâce au contexte de layout
            id1 = ctx.last_id
            button(ctx, "Button")
            id2 = ctx.last_id
            button(ctx, "Button")
            id3 = ctx.last_id
            
            @test id2 != id3  # IDs différents malgré le même label
            
            end_window(ctx)
        end
        end_frame(ctx)
    end
    
    @testset "Stack overflow protection" begin
        ctx = create_test_context()
        
        begin_frame(ctx)
        
        # Pousser trop d'éléments sur la stack d'ID
        for i in 1:MicroUI.IDSTACK_SIZE
            push_id!(ctx, "id$i")
        end
        
        # Le prochain push devrait échouer
        @test_throws ErrorException push_id!(ctx, "overflow")
        
        # Nettoyer
        for i in 1:MicroUI.IDSTACK_SIZE
            pop_id!(ctx)
        end
        
        end_frame(ctx)
    end
    
    @testset "Window sans end_window" begin
        ctx = create_test_context()
        
        # Devrait échouer si on oublie end_window
        begin_frame(ctx)
        opened = begin_window(ctx, "Test", Rect(0, 0, 200, 200))
        @test opened == RES_ACTIVE
        # Pas de end_window!
        # Mais nous devons quand même nettoyer pour les tests suivants
        try
            @test_throws AssertionError end_frame(ctx)
        finally
            # Nettoyer la pile manuellement
            while ctx.id_stack.idx > 0
                pop_id!(ctx)
            end
        end
    end
    
    @testset "Clip rect cohérence" begin
        ctx = create_test_context()
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) == RES_ACTIVE
            # Push plusieurs clip rects
            push_clip_rect!(ctx, Rect(10, 10, 100, 100))
            push_clip_rect!(ctx, Rect(20, 20, 80, 80))
            
            clip = get_clip_rect(ctx)
            @test clip.w <= 80  # Ne peut pas être plus grand que le parent
            @test clip.h <= 80
            
            pop_clip_rect!(ctx)
            pop_clip_rect!(ctx)
            end_window(ctx)
        end
        end_frame(ctx)
    end
end
