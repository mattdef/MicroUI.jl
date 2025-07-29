using Test

"""
Tests unitaires pour le système de commandes de MicroUI
Vérifie le command buffer, jump commands, iterator, etc.
"""

@testset "MicroUI Command System Tests" begin
    
    @testset "Command Buffer Basic Operations" begin
        ctx = Context()
        init!(ctx)
        begin_frame(ctx)
        
        # Test 1: Buffer vide au début
        @test ctx.command_list.idx == 0
        @test ctx.command_list.string_idx == 0
        
        # Test 2: Écriture d'une commande rectangle
        rect_cmd = RectCommand(
            BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
            Rect(10, 20, 100, 50),
            Color(255, 0, 0, 255)
        )
        
        cmd_idx = write_command!(ctx.command_list, rect_cmd)
        @test cmd_idx == 0  # Premier index
        @test ctx.command_list.idx == sizeof(RectCommand)
        
        # Test 3: Lecture de la commande écrite
        read_cmd = read_command(ctx.command_list, cmd_idx, RectCommand)
        @test read_cmd.base.type == MicroUI.COMMAND_RECT
        @test read_cmd.rect.x == 10
        @test read_cmd.rect.y == 20
        @test read_cmd.color.r == 255
        
        end_frame(ctx)
    end
    
    @testset "Text Command and String Storage" begin
        ctx = Context()
        init!(ctx)
        begin_frame(ctx)
        
        # Test 4: Stockage et récupération de strings
        test_string = "Hello MicroUI!"
        str_idx = write_string!(ctx.command_list, test_string)
        @test str_idx == 1
        
        retrieved_string = get_string(ctx.command_list, str_idx)
        @test retrieved_string == test_string
        
        # Test 5: Commande texte complète
        font = nothing  # Font stub
        pos = Vec2(50, 100)
        color = Color(0, 255, 0, 255)
        
        text_for_command = "Command text"
        text_cmd_idx = push_text_command!(ctx, font, text_for_command, pos, color)
        text_cmd = read_command(ctx.command_list, text_cmd_idx, TextCommand)
        
        @test text_cmd.base.type == MicroUI.COMMAND_TEXT
        @test text_cmd.pos.x == 50
        @test text_cmd.pos.y == 100
        @test text_cmd.str_index == 2  # Deuxième string stockée
        @test text_cmd.str_length == length(text_for_command)

        retrieved_cmd_string = get_string(ctx.command_list, text_cmd.str_index)
        @test retrieved_cmd_string == text_for_command
        
        # Test 6: Multiple strings
        strings = ["String 1", "String 2", "String 3"]
        str_indices = [write_string!(ctx.command_list, s) for s in strings]
        
        # Vérifier que chaque string est récupérable
        for (i, expected) in enumerate(strings)
            retrieved = get_string(ctx.command_list, str_indices[i])
            @test retrieved == expected
        end
        
        end_frame(ctx)
    end
    
    @testset "Jump Commands and Optimization" begin
        ctx = Context()
        init!(ctx)
        begin_frame(ctx)
        
        # Test 7: Jump command basique
        destination = CommandPtr(100)
        jump_idx = push_jump_command!(ctx, destination)
        
        jump_cmd = read_command(ctx.command_list, jump_idx, JumpCommand)
        @test jump_cmd.base.type == MicroUI.COMMAND_JUMP
        @test jump_cmd.dst == destination
        
        # Test 8: Séquence avec jump
        # Créer une séquence : RECT -> JUMP -> RECT -> TEXT
        rect1_idx = push_command!(ctx, RectCommand(
            BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
            Rect(0, 0, 10, 10), Color(255, 0, 0, 255)
        ))
        
        # Jump qui pointe vers la commande TEXT
        jump_destination = ctx.command_list.idx + sizeof(JumpCommand) + sizeof(RectCommand)
        jump_idx = push_jump_command!(ctx, Int32(jump_destination))
        
        # Rect qui devrait être skippé
        skipped_rect_idx = push_command!(ctx, RectCommand(
            BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
            Rect(999, 999, 1, 1), Color(0, 0, 0, 255)  # Marqueur pour skip
        ))
        
        # Text command final
        text_idx = push_text_command!(ctx, nothing, "Final text", Vec2(0, 0), Color(0, 255, 0, 255))
        
        end_frame(ctx)
    end
    
    @testset "Command Iterator" begin
        ctx = Context()
        init!(ctx)
        begin_frame(ctx)
        
        # Test 9: Iterator sur commandes simples
        # Créer une séquence sans jumps
        push_command!(ctx, RectCommand(
            BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
            Rect(1, 1, 1, 1), Color(1, 0, 0, 255)
        ))
        
        push_text_command!(ctx, nothing, "Text 1", Vec2(0, 0), Color(0, 1, 0, 255))
        
        push_command!(ctx, IconCommand(
            BaseCommand(MicroUI.COMMAND_ICON, sizeof(IconCommand)),
            Rect(2, 2, 2, 2), MicroUI.ICON_CHECK, Color(0, 0, 1, 255)
        ))
        
        # Parcourir avec l'iterator
        iter = CommandIterator(ctx.command_list)
        commands_found = []
        
        while true
            (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
            if !has_cmd
                break
            end
            push!(commands_found, cmd_type)
        end
        
        expected_sequence = [MicroUI.COMMAND_RECT, MicroUI.COMMAND_TEXT, MicroUI.COMMAND_ICON]
        @test commands_found == expected_sequence
        
        end_frame(ctx)
    end
    
    @testset "Jump Command Iterator Behavior" begin
        ctx = Context()
        init!(ctx)
        begin_frame(ctx)
        
        # Test 10: Iterator avec jumps
        # Créer : RECT -> JUMP -> RECT_SKIPPED -> TEXT
        push_command!(ctx, RectCommand(
            BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
            Rect(1, 1, 1, 1), Color(255, 0, 0, 255)
        ))
        
        # Calculer où sera la commande TEXT après JUMP + RECT_SKIPPED
        text_position = ctx.command_list.idx + sizeof(JumpCommand) + sizeof(RectCommand)
        push_jump_command!(ctx, Int32(text_position))
        
        # Cette commande devrait être skippée
        push_command!(ctx, RectCommand(
            BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
            Rect(999, 999, 999, 999), Color(99, 99, 99, 255)  # Marqueur skip
        ))
        
        # Commande finale
        push_text_command!(ctx, nothing, "After jump", Vec2(0, 0), Color(0, 255, 0, 255))
        
        # Parcourir avec iterator
        iter = CommandIterator(ctx.command_list)
        visited_commands = []
        
        while true
            (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
            if !has_cmd
                break
            end
            
            if cmd_type == MicroUI.COMMAND_RECT
                rect_cmd = read_command(ctx.command_list, cmd_idx, RectCommand)
                push!(visited_commands, (cmd_type, rect_cmd.rect.x))
            elseif cmd_type == MicroUI.COMMAND_TEXT
                push!(visited_commands, (cmd_type, 0))
            end
        end
        
        # On ne devrait voir que RECT(1) et TEXT, pas RECT(999)
        @test length(visited_commands) == 2
        @test visited_commands[1] == (MicroUI.COMMAND_RECT, Int32(1))  # Premier rect
        @test visited_commands[2] == (MicroUI.COMMAND_TEXT, 0)         # Text après jump
        
        end_frame(ctx)
    end
    
    @testset "Drawing Functions Integration" begin
        ctx = Context()
        init!(ctx)
        begin_frame(ctx)
        
        # Initialiser le clipping pour les drawing functions
        MicroUI.push!(ctx.clip_stack, MicroUI.UNCLIPPED_RECT)
        
        # Test 11: draw_rect! génère bonne commande
        test_rect = Rect(50, 60, 70, 80)
        test_color = Color(128, 64, 32, 255)
        
        initial_idx = ctx.command_list.idx
        draw_rect!(ctx, test_rect, test_color)
        
        @test ctx.command_list.idx > initial_idx  # Commande ajoutée
        
        # Trouver et vérifier la commande
        iter = CommandIterator(ctx.command_list)
        (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
        
        @test has_cmd
        @test cmd_type == MicroUI.COMMAND_RECT
        
        rect_cmd = read_command(ctx.command_list, cmd_idx, RectCommand)
        @test rect_cmd.rect.x == test_rect.x
        @test rect_cmd.color.r == test_color.r
        
        # Test 12: draw_text! avec clipping
        ctx.command_list.idx = 0  # Reset buffer
        ctx.command_list.string_idx = 0
        
        draw_text!(ctx, nothing, "Test text", -1, Vec2(100, 200), Color(255, 255, 255, 255))
        
        iter = CommandIterator(ctx.command_list)
        found_text = false
        
        while true
            (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
            if !has_cmd
                break
            end
            
            if cmd_type == MicroUI.COMMAND_TEXT
                text_cmd = read_command(ctx.command_list, cmd_idx, TextCommand)
                text_str = get_string(ctx.command_list, text_cmd.str_index)
                @test text_str == "Test text"
                @test text_cmd.pos.x == 100
                found_text = true
                break
            end
        end
        
        @test found_text
        
        MicroUI.pop!(ctx.clip_stack)
        end_frame(ctx)
    end
    
    @testset "Buffer Limits and Safety" begin
        ctx = Context()
        init!(ctx)
        begin_frame(ctx)
        
        # Test 13: Détection buffer overflow
        # Essayer de remplir le buffer jusqu'à la limite
        commands_written = 0
        max_attempts = MicroUI.COMMANDLIST_SIZE ÷ sizeof(RectCommand)
        
        try
            for i in 1:max_attempts
                if ctx.command_list.idx + sizeof(RectCommand) <= MicroUI.COMMANDLIST_SIZE
                    push_command!(ctx, RectCommand(
                        BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
                        Rect(i, i, 1, 1), Color(0, 0, 0, 255)
                    ))
                    commands_written += 1
                else
                    break
                end
            end
            println("Test 13: Buffer utilisé jusqu'à $(commands_written) commandes sans overflow")
        catch e
            if occursin("overflow", string(e))
                println("Test 13: Protection overflow détectée: $e")
            else
                rethrow(e)
            end
        end
        
        # Test 14: String buffer growth
        initial_string_capacity = length(ctx.command_list.strings)
        
        # Ajouter plus de strings que la capacité initiale
        for i in 1:(initial_string_capacity + 5)
            write_string!(ctx.command_list, "String $i")
        end
        
        @test length(ctx.command_list.strings) > initial_string_capacity
        @test ctx.command_list.string_idx == initial_string_capacity + 5
        
        end_frame(ctx)
    end
    
    @testset "Container Command Chaining" begin
        ctx = Context()
        init!(ctx)
        begin_frame(ctx)
        
        # Test 15: Container avec head/tail commands
        container = Container()
        container.head = push_jump_command!(ctx, CommandPtr(0))  # Placeholder
        
        # Ajouter du contenu
        push_command!(ctx, RectCommand(
            BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
            Rect(10, 10, 100, 100), Color(255, 0, 0, 255)
        ))
        
        container.tail = push_jump_command!(ctx, CommandPtr(0))  # Placeholder
        
        @test container.head >= 0
        @test container.tail > container.head
        @test container.tail > container.head + sizeof(JumpCommand)
        
        # Test 16: Multiple containers avec z-index
        containers = Container[]
        
        for i in 1:3
            cnt = Container()
            cnt.zindex = i * 10  # Z-index différents
            cnt.head = push_jump_command!(ctx, CommandPtr(0))
            
            # Contenu unique pour chaque container
            push_command!(ctx, RectCommand(
                BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
                Rect(i*20, i*20, 50, 50), Color(i*80, 0, 0, 255)
            ))
            
            cnt.tail = push_jump_command!(ctx, CommandPtr(0))
            push!(containers, cnt)
        end
        
        # Trier par z-index (comme fait end_frame)
        sort!(containers, by = c -> c.zindex)
        
        # Vérifier l'ordre
        for i in 1:3
            @test containers[i].zindex == i * 10
        end
        
        end_frame(ctx)
    end
    
    @testset "Frame Command Management" begin
        ctx = Context()
        init!(ctx)
        
        # Test 17: Reset entre frames
        begin_frame(ctx)
        push_command!(ctx, RectCommand(
            BaseCommand(MicroUI.COMMAND_RECT, sizeof(RectCommand)),
            Rect(1, 1, 1, 1), Color(1, 1, 1, 255)
        ))
        @test ctx.command_list.idx > 0
        end_frame(ctx)
        
        begin_frame(ctx)
        @test ctx.command_list.idx == 0  # Reset
        @test ctx.command_list.string_idx == 0  # Reset
        
        # Test 18: Persistence des structures mais reset du contenu
        push_text_command!(ctx, nothing, "Frame 2", Vec2(0, 0), Color(255, 255, 255, 255))
        
        iter = CommandIterator(ctx.command_list)
        (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
        
        @test has_cmd
        @test cmd_type == MicroUI.COMMAND_TEXT
        
        text_cmd = read_command(ctx.command_list, cmd_idx, TextCommand)
        text_str = get_string(ctx.command_list, text_cmd.str_index)
        @test text_str == "Frame 2"
        
        end_frame(ctx)
    end

end
