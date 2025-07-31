using Test

# ============================================================================
# TESTS DE PERFORMANCE
# ============================================================================

@testset "Performance Test" begin

    @testset "Contexte Creation" begin
        t = @benchmark create_context()
        # Le contexte devrait être créé rapidement

        res_ns = mean(t).time
        println("-- Context Performance --")
        println("  • Time: $(round(Int, res_ns)) ns")
        @test res_ns < 1_000_000  # < 1ms
    end
    
    @testset "Empty Frame" begin
        ctx = create_context()
        t = @benchmark begin
            begin_frame($ctx)
            end_frame($ctx)
        end

        res_ns = mean(t).time
        println("-- Frame Performance --")
        println("  • Time: $(round(Int, res_ns)) ns")
        @test res_ns < 100_000  # < 0.1ms
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

        res_ns = mean(t).time
        println("-- Simple Interface Performance --")
        println("  • Time: $(round(Int, res_ns)) ns")
        @test res_ns < 500_000  # < 0.5ms
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

        res_ns = mean(t).time
        println("-- Complex Interface Performance --")
        println("  • Time: $(round(Int, res_ns)) ns")
        @test res_ns < 5_000_000  # < 5ms pour interface complexe
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
        res_ns = mean(t).time
        println("-- Stress Test Performance --")
        println("  • Display 20 windows: $(round(Int, res_ns)) ns")
        @test res_ns < 10_000_000  # < 10ms
    end
    
    @testset "Perf allocations" begin
        ctx = create_context()
        
        # Warmup
        for i in 1:3
            begin_frame(ctx)
            if begin_window(ctx, "Test", Rect(0, 0, 200, 200)) != 0
                layout_begin_column!(ctx)
                layout_row!(ctx, 2, [100, 150], 30)
                layout_end_column!(ctx)
                button(ctx, "Test")
                text(ctx, "Ceci est un\n long texte qui\n sera sur plusieurs\n lignes.")
                end_window(ctx)
            end
            end_frame(ctx)
        end
        
        # Tester chaque partie séparément
        println("-- Memory Allocations Performance --")
        println("  • begin_frame: $(@allocated begin_frame(ctx)) bytes")
        println("  • begin_window: $(@allocated begin_window(ctx, "Test", Rect(0, 0, 200, 200))) bytes")
        println("  • layout_begin_column!: $(@allocated layout_begin_column!(ctx)) bytes")
        println("  • layout_row!: $(@allocated layout_row!(ctx, 2, [100, 150], 30)) bytes")
        println("  • layout_end_column!: $(@allocated layout_end_column!(ctx)) bytes")
        println("  • button: $(@allocated button(ctx, "Test")) bytes")
        println("  • text: $(@allocated text(ctx, "Ceci est un\n long texte qui\n sera sur plusieurs\n lignes.")) bytes")
        println("  • end_window: $(@allocated end_window(ctx)) bytes")
        println("  • end_frame: $(@allocated end_frame(ctx)) bytes")

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
        
        println("-- IDs Performance --")
        println("  • IDs/second: $(round(Int, res))")
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
        
        println("-- Commands Performance --")
        println("  • Écriture: $(round(Int, write_speed)) cmds/sec")
        println("  • Lecture: $(round(Int, read_speed)) cmds/sec")
        println("  • Buffer utilisé: $(ctx.command_list.idx) / $(MicroUI.COMMANDLIST_SIZE) bytes")
        
        @test write_speed > 100000  # Au moins 100k commandes/sec en écriture
        @test read_speed > 200000   # Au moins 500k commandes/sec en lecture
        
        end_frame(ctx)
    end

end