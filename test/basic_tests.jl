using Test

# ============================================================================
# TESTS BASIQUES
# ============================================================================

@testset "Basic Types and Structs" begin
    @testset "Vec2" begin
        v1 = Vec2(10, 20)
        v2 = Vec2(5, 15)
        
        @test v1.x == 10
        @test v1.y == 20
        
        # Opérations arithmétiques
        @test (v1 + v2).x == 15
        @test (v1 - v2).x == 5
        @test (v1 * 2).x == 20
    end
    
    @testset "Rect" begin
        r = Rect(10, 20, 100, 50)
        @test r.x == 10
        @test r.y == 20
        @test r.w == 100
        @test r.h == 50
        
        # Expansion
        r2 = expand_rect(r, Int32(5))
        @test r2.x == 5
        @test r2.y == 15
        @test r2.w == 110
        @test r2.h == 60
    end
    
    @testset "Color" begin
        c = Color(255, 128, 64, 255)
        @test c.r == 255
        @test c.g == 128
        @test c.b == 64
        @test c.a == 255
    end
    
    @testset "Rect Intersect" begin
        r1 = Rect(0, 0, 100, 100)
        r2 = Rect(50, 50, 100, 100)
        r3 = intersect_rects(r1, r2)
        
        @test r3.x == 50
        @test r3.y == 50
        @test r3.w == 50
        @test r3.h == 50
        
        # Pas d'intersection
        r4 = Rect(200, 200, 50, 50)
        r5 = intersect_rects(r1, r4)
        @test r5.w == 0
        @test r5.h == 0
    end
    
    @testset "Point inside Rect" begin
        r = Rect(10, 10, 100, 100)
        @test MicroUI.rect_overlaps_vec2(r, Vec2(50, 50)) == true
        @test MicroUI.rect_overlaps_vec2(r, Vec2(5, 5)) == false
        @test MicroUI.rect_overlaps_vec2(r, Vec2(10, 10)) == true  # Bord inclus
        @test MicroUI.rect_overlaps_vec2(r, Vec2(110, 110)) == false  # Bord exclus
    end
end

@testset "ID system" begin
    ctx = create_context()
    
    @testset "Hash FNV-1a" begin
        # Même données = même ID
        id1 = get_id(ctx, "test")
        id2 = get_id(ctx, "test")
        @test id1 == id2
        
        # Données différentes = ID différents
        id3 = get_id(ctx, "other")
        @test id1 != id3
    end
    
    @testset "ID Stack" begin
        base_id = get_id(ctx, "base")
        
        push_id!(ctx, "child")
        child_id = get_id(ctx, "item")
        
        push_id!(ctx, "subchild")
        subchild_id = get_id(ctx, "item")
        
        # Les IDs doivent être différents grâce au contexte
        @test child_id != subchild_id
        
        pop_id!(ctx)
        pop_id!(ctx)
        
        # Retour au contexte initial
        @test get_id(ctx, "base") == base_id
    end
end