using Test

include("utils_tests.jl")

# ============================================================================
# TESTS DES COMMANDES
# ============================================================================

@testset "Système de Commandes" begin
    ctx = create_test_context()
    
    @testset "Buffer de commandes" begin
        begin_frame(ctx)
        
        # Taille initiale
        @test ctx.command_idx == 0
        
        # Ajouter des commandes
        draw_rect!(ctx, Rect(0, 0, 100, 100), Color(255, 0, 0, 255))
        @test ctx.command_idx > 0
        
        initial_size = ctx.command_idx
        draw_rect!(ctx, Rect(10, 10, 50, 50), Color(0, 255, 0, 255))
        @test ctx.command_idx > initial_size
        
        end_frame(ctx)
    end
    
    @testset "Clipping" begin
        ctx = create_test_context()
        begin_frame(ctx)
        
        # Clip rect par défaut
        default_clip = get_clip_rect(ctx)
        @test default_clip.w == typemax(Int32)
        @test default_clip.h == typemax(Int32)
        
        # Push nouveau clip
        push_clip_rect!(ctx, Rect(10, 10, 100, 100))
        clip = get_clip_rect(ctx)
        @test clip.x == 10
        @test clip.y == 10
        @test clip.w == 100
        @test clip.h == 100
        
        # Clip imbriqué (intersection)
        push_clip_rect!(ctx, Rect(20, 20, 200, 200))
        clip2 = get_clip_rect(ctx)
        @test clip2.x == 20
        @test clip2.y == 20
        @test clip2.w == 90  # Limité par le parent
        @test clip2.h == 90
        
        pop_clip_rect!(ctx)
        pop_clip_rect!(ctx)
        
        end_frame(ctx)
    end
    
    @testset "Check clip" begin
        ctx = create_test_context()
        begin_frame(ctx)
        
        push_clip_rect!(ctx, Rect(50, 50, 100, 100))
        
        # Complètement à l'intérieur
        @test check_clip(ctx, Rect(60, 60, 20, 20)) == CLIP_NONE
        
        # Partiellement à l'intérieur
        @test check_clip(ctx, Rect(40, 60, 30, 20)) == CLIP_PART
        
        # Complètement à l'extérieur
        @test check_clip(ctx, Rect(0, 0, 20, 20)) == CLIP_ALL
        
        pop_clip_rect!(ctx)
        end_frame(ctx)
    end
end