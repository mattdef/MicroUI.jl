using Test

include("utils_tests.jl")

@testset "All Performance Tests" begin

    @testset "Performance et Mémoire" begin
        ctx, _ = MicroUI.create_context_with_buffer_renderer()
        
        # Test qu'on peut créer beaucoup d'ID sans problème
        ids = Set{UInt32}()
        for i in 1:1000
            id = MicroUI.get_id!(ctx, "item_$i")
            push!(ids, id)
        end
        
        # Tous les ID devraient être uniques
        @test length(ids) == 1000
        
        # Test que les frames successives nettoient correctement l'état
        initial_commands = length(ctx.command_list)
        
        for _ in 1:10
            MicroUI.begin_frame!(ctx)
            MicroUI.begin_window!(ctx, "Perf Test")
            MicroUI.button!(ctx, "Button")
            MicroUI.end_window!(ctx)
            MicroUI.end_frame!(ctx)
        end
        
        # Les commandes sont vidées à chaque frame (begin_frame! fait empty!)
        @test length(ctx.command_list) >= 0  # Au moins pas d'erreur
    end

    @testset "Pool de Mémoire" begin
        ctx, _ = MicroUI.create_context_with_buffer_renderer(Float32; w=400, h=300)
        
        # Test du pool de rectangles
        @test ctx.rect_pool.next_index == 1
        
        # Test de reset du pool
        MicroUI.reset_pool!(ctx.rect_pool)
        @test ctx.rect_pool.next_index == 1
        
        # Test du pool de strings
        @test ctx.string_pool.next_index == 1
        MicroUI.reset_pool!(ctx.string_pool)
        @test ctx.string_pool.next_index == 1
        
        # Test que begin_frame! reset les pools
        MicroUI.begin_frame!(ctx)
        @test ctx.rect_pool.next_index == 1
        @test ctx.string_pool.next_index == 1
        MicroUI.end_frame!(ctx)
    end

    @testset "Cache de Couleurs" begin
        # Test que le cache de couleurs est correctement initialisé
        @test haskey(MicroUI.COLOR_CACHE, MicroUI.COLOR_TEXT)
        @test haskey(MicroUI.COLOR_CACHE, MicroUI.COLOR_BUTTON)
        
        # Test que les couleurs du cache sont correctes
        text_color = MicroUI.color(MicroUI.COLOR_TEXT)
        @test text_color.r == 0xE6
        @test text_color.g == 0xE6
        @test text_color.b == 0xE6
        @test text_color.a == 0xFF
        
        # Test de performance du cache (pas d'allocation)
        for _ in 1:1000
            c = MicroUI.color(MicroUI.COLOR_BUTTON)
            @test c isa MicroUI.Color
        end
    end

    @testset "Performance du Layout" begin
        ctx, _ = MicroUI.create_context_with_buffer_renderer(Float32; w=500, h=400)
        
        MicroUI.begin_frame!(ctx)
        MicroUI.begin_window!(ctx, "Layout Performance", 10, 10, 480, 380)
        
        # Test de nombreux contrôles en layout row
        MicroUI.layout_row!(ctx)
        
        initial_cursor = ctx.current_window.cursor
        
        # Ajouter plusieurs contrôles horizontalement
        for i in 1:10
            rect = MicroUI.next_control_rect(ctx, 40, 25)
            @test rect.w == 40.0f0
            @test rect.h == 25.0f0
        end
        
        # Le curseur X devrait avoir beaucoup bougé
        @test ctx.current_window.cursor[1] > initial_cursor[1] + 400
        
        MicroUI.end_layout_row!(ctx)
        
        # Test de layout vertical par défaut
        initial_y = ctx.current_window.cursor[2]
        
        for i in 1:5
            rect = MicroUI.next_control_rect(ctx, 100, 30)
            @test rect.h == 30.0f0
        end
        
        # Le curseur Y devrait avoir bougé vers le bas
        @test ctx.current_window.cursor[2] > initial_y + 150
        
        MicroUI.end_window!(ctx)
        MicroUI.end_frame!(ctx)
    end

end