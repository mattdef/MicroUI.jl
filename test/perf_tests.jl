using Test

include("utils_tests.jl")

# ============================================================================
# TESTS DE PERFORMANCE
# ============================================================================

@testset "Tests de Performance" begin
    @testset "Création de contexte" begin
        t = @benchmark Context()
        # Le contexte devrait être créé rapidement
        @test mean(t).time < 1_000_000  # < 1ms
    end
    
    @testset "Frame vide" begin
        ctx = create_test_context()
        t = @benchmark begin
            begin_frame($ctx)
            end_frame($ctx)
        end
        @test mean(t).time < 100_000  # < 0.1ms
    end
    
    @testset "Fenêtre simple" begin
        ctx = create_test_context()
        t = @benchmark begin
            begin_frame($ctx)
            if begin_window($ctx, "Test", Rect(0, 0, 200, 200)) == RES_ACTIVE
                label($ctx, "Hello")
                end_window($ctx)
            end
            end_frame($ctx)
        end
        @test mean(t).time < 500_000  # < 0.5ms
    end
    
    @testset "Interface complexe" begin
        ctx = create_test_context()
        value = Ref(50.0f0)
        check = Ref(false)
        text = Ref("Test")
        
        t = @benchmark begin
            begin_frame($ctx)
            if begin_window($ctx, "Complex", Rect(0, 0, 400, 600)) == RES_ACTIVE
                # Plusieurs contrôles
                for i in 1:10
                    layout_row!($ctx, 2, [100, -1], 0)
                    label($ctx, "Label $i:")
                    if i % 3 == 0
                        slider!($ctx, "Slide", $value, 0.0f0, 100.0f0)
                    elseif i % 3 == 1
                        checkbox!($ctx, "Check $i", $check)
                    else
                        button($ctx, "Button $i")
                    end
                end
                end_window($ctx)
            end
            end_frame($ctx)
        end
        @test mean(t).time < 5_000_000  # < 5ms pour interface complexe
    end
    
    @testset "Stress test - Nombreuses fenêtres" begin
        ctx = create_test_context()
        
        t = @benchmark begin
            begin_frame($ctx)
            for i in 1:20
                if begin_window($ctx, "Window$i", Rect(i*20, i*20, 150, 100)) == RES_ACTIVE
                    label($ctx, "Content $i")
                    end_window($ctx)
                end
            end
            end_frame($ctx)
        end
        # Même avec 20 fenêtres, devrait rester performant
        @test mean(t).time < 10_000_000  # < 10ms
    end
    
    @testset "Perf allocations" begin
        ctx = create_test_context()
        
        # Warmup
        for i in 1:3
            begin_frame(ctx)
            if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) == RES_ACTIVE
                button(ctx, "Test")
                end_window(ctx)
            end
            end_frame(ctx)
        end
        
        # Tester chaque partie séparément
        @info "begin_frame" alloc=@allocated begin_frame(ctx)
        
        @info "begin_window" alloc=@allocated begin
            begin_window(ctx, "Test", Rect(0, 0, 200, 200))
        end
        
        @info "button" alloc=@allocated button(ctx, "Test")
        
        @info "end_window" alloc=@allocated end_window(ctx)
        
        @info "end_frame" alloc=@allocated end_frame(ctx)
    end
end