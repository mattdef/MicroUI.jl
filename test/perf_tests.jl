using Test

# ============================================================================
# TESTS DE PERFORMANCE
# ============================================================================

@testset "Performance Test" begin

    @testset "Contexte Creation" begin
        t = @benchmark create_context()
        # Le contexte devrait être créé rapidement
        @test mean(t).time < 1_000_000  # < 1ms
    end
    
    @testset "Empty Frame" begin
        ctx = create_context()
        t = @benchmark begin
            begin_frame($ctx)
            end_frame($ctx)
        end
        @test mean(t).time < 100_000  # < 0.1ms
    end
    
    @testset "Simple Window" begin
        ctx = create_context()
        t = @benchmark begin
            begin_frame($ctx)
            if begin_window($ctx, "Test", Rect(0, 0, 200, 200)) != 0
                label($ctx, "Hello")
                end_window($ctx)
            end
            end_frame($ctx)
        end
        @test mean(t).time < 500_000  # < 0.5ms
    end
    
    @testset "Complex Interface" begin
        ctx = create_context()
        value = Ref(50.0f0)
        check = Ref(false)
        text = Ref("Test")
        
        t = @benchmark begin
            begin_frame($ctx)
            if begin_window($ctx, "Complex", Rect(0, 0, 400, 600)) != 0
                # Plusieurs contrôles
                for i in 1:10
                    layout_row!($ctx, 2, [100, -1], 0)
                    label($ctx, "Label $i:")
                    if i % 3 == 0
                        slider!($ctx, $value, 0.0f0, 100.0f0)
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
    
    @testset "Stress test - Many Windows" begin
        ctx = create_context()
        
        t = @benchmark begin
            begin_frame($ctx)
            for i in 1:20
                if begin_window($ctx, "Window$i", Rect(i*20, i*20, 150, 100)) != 0
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
        ctx = create_context()
        
        # Warmup
        for i in 1:3
            begin_frame(ctx)
            if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
                button(ctx, "Test")
                end_window(ctx)
            end
            end_frame(ctx)
        end
        
        # Tester chaque partie séparément
        @info "begin_frame" alloc=@allocated begin_frame(ctx)
        
        @info "begin_window" alloc=@allocated begin_window(ctx, "Test", Rect(0, 0, 200, 200))
        
        @info "button" alloc=@allocated button(ctx, "Test")
        
        @info "end_window" alloc=@allocated end_window(ctx)
        
        @info "end_frame" alloc=@allocated end_frame(ctx)
    end

    # Test de performance basique
    @testset "ID Performance" begin
        ctx = Context()
        init!(ctx)
        
        # Mesurer le temps de génération d'IDs
        n_ids = 10000
        start_time = time()
        
        for i in 1:n_ids
            get_id(ctx, "control_$i")
        end
        
        elapsed = time() - start_time
        res = n_ids / elapsed
        
        @info "Performance (IDs/seconde): " ids_per_second=@allocated round(Int, res)
        @test res > 100000  # Au moins 100k IDs/sec
    end

    # Test de performance du système de commandes
    @testset "Command System Performance" begin
        ctx = Context()
        init!(ctx)
        begin_frame(ctx)
        
        # Mesurer vitesse d'écriture de commandes
        n_commands = 10000
        start_time = time()
        
        for i in 1:n_commands
            if ctx.command_list.idx + sizeof(RectCommand) <= MicroUI.COMMANDLIST_SIZE
                push_command!(ctx, RectCommand(
                    BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
                    Rect(i % 1000, (i ÷ 1000) % 1000, 10, 10),
                    Color(i % 256, (i ÷ 256) % 256, (i ÷ 65536) % 256, 255)
                ))
            else
                break
            end
        end
        
        write_time = time() - start_time
        
        # Mesurer vitesse d'itération
        start_time = time()
        iter = CommandIterator(ctx.command_list)
        commands_read = 0
        
        while true
            (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
            if !has_cmd
                break
            end
            commands_read += 1
        end
        
        read_time = time() - start_time
        
        write_speed = commands_read / write_time
        read_speed = commands_read / read_time
        
        println("Performance Commands:")
        println("  • Écriture: $(round(Int, write_speed)) cmds/sec")
        println("  • Lecture: $(round(Int, read_speed)) cmds/sec")
        println("  • Buffer utilisé: $(ctx.command_list.idx) / $(MicroUI.COMMANDLIST_SIZE) bytes")
        
        @test write_speed > 100000  # Au moins 100k commandes/sec en écriture
        @test read_speed > 200000   # Au moins 500k commandes/sec en lecture
        
        end_frame(ctx)
    end

end