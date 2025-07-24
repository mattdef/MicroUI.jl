using MicroUI
using Test


@testset "MicroUI.jl - context & renderer" begin
    ctx, renderer = create_context_with_buffer_renderer(320, 240)
    @test ctx !== nothing
    @test renderer !== nothing
end

@testset "MicroUI.jl - types de base" begin
    v = Vec2(1, 2)
    r = Rect(3, 4, 5, 6)
    c = Color(7, 8, 9, 255)
    @test v.x == 1 && v.y == 2
    @test r.x == 3 && r.y == 4 && r.w == 5 && r.h == 6
    @test c.r == 7 && c.g == 8 && c.b == 9 && c.a == 255
end

@testset "MicroUI.jl - fonctions utilitaires" begin
    c = mu_color(10, 20, 30, 40)
    r = mu_rect(1, 2, 3, 4)
    v = mu_vec2(5, 6)
    @test c.r == 10 && c.g == 20 && c.b == 30 && c.a == 40
    @test r.x == 1 && r.y == 2 && r.w == 3 && r.h == 4
    @test v.x == 5 && v.y == 6
end

@testset "MicroUI.jl - boucle UI minimale" begin
    ctx, renderer = create_context_with_buffer_renderer(100, 100)
    mu_begin(ctx)
    mu_end(ctx)
    @test ctx !== nothing  # Le contexte doit rester valide
end

@testset "MicroUI.jl - sauvegarde buffer" begin
    ctx, renderer = create_context_with_buffer_renderer(10, 10)
    filename = "test_output.ppm"
    save_buffer_as_ppm(renderer, filename)
    @test isfile(filename)
    rm(filename)
end
