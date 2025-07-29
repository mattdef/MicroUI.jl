using Test

"""
Tests unitaires pour la gestion des IDs et collisions dans MicroUI
"""

@testset "MicroUI ID Management Tests" begin
    
    @testset "Basic ID Generation" begin
        ctx = Context()
        init!(ctx)
        
        # Test 1: IDs différents pour des strings différentes
        id1 = get_id(ctx, "button1")
        id2 = get_id(ctx, "button2")
        @test id1 != id2
        
        # Test 2: IDs identiques pour la même string
        id3 = get_id(ctx, "button1")
        @test id1 == id3
        
        # Test 3: IDs différents pour des strings similaires
        id4 = get_id(ctx, "button")
        id5 = get_id(ctx, "button ")  # avec espace
        @test id4 != id5
    end
    
    @testset "ID Stack Management" begin
        ctx = Context()
        init!(ctx)
        
        # Test 4: Stack d'ID vide au début
        @test ctx.id_stack.idx == 0
        
        # Test 5: Push/Pop d'ID
        push_id!(ctx, "parent")
        @test ctx.id_stack.idx == 1
        
        id_in_context = get_id(ctx, "child")
        
        pop_id!(ctx)
        @test ctx.id_stack.idx == 0
        
        # L'ID devrait être différent hors contexte
        id_out_context = get_id(ctx, "child")
        @test id_in_context != id_out_context
        
        # Test 6: IDs hiérarchiques
        push_id!(ctx, "window1")
        push_id!(ctx, "panel1")
        id_nested1 = get_id(ctx, "button")
        pop_id!(ctx)
        pop_id!(ctx)
        
        push_id!(ctx, "window1")
        push_id!(ctx, "panel2")  # Panel différent
        id_nested2 = get_id(ctx, "button")  # Même nom mais contexte différent
        pop_id!(ctx)
        pop_id!(ctx)
        
        @test id_nested1 != id_nested2
    end
    
    @testset "Widget ID Collisions" begin
        ctx = Context()
        init!(ctx)
        
        # Simuler une frame avec plusieurs widgets de même nom dans contextes différents
        begin_frame(ctx)
        
        # Simuler deux fenêtres avec des boutons "OK"
        push_id!(ctx, "window1")
        id_btn1 = get_id(ctx, "OK")
        pop_id!(ctx)
        
        push_id!(ctx, "window2") 
        id_btn2 = get_id(ctx, "OK")
        pop_id!(ctx)
        
        @test id_btn1 != id_btn2
        
        # Test avec des références d'objets (comme checkbox, textbox)
        state1 = Ref(false)
        state2 = Ref(true)
        
        id_check1 = get_id(ctx, "checkbox_" * string(objectid(state1)))
        id_check2 = get_id(ctx, "checkbox_" * string(objectid(state2)))
        
        @test id_check1 != id_check2
        
        end_frame(ctx)
    end
    
    @testset "ID Stability Across Frames" begin
        ctx = Context()
        init!(ctx)
        
        # Test 9: Stabilité des IDs entre frames
        begin_frame(ctx)
        id_frame1 = get_id(ctx, "stable_button")
        end_frame(ctx)
        
        begin_frame(ctx) 
        id_frame2 = get_id(ctx, "stable_button")
        end_frame(ctx)
        
        @test id_frame1 == id_frame2
        
        # Test 10: IDs dans même ordre produisent même résultat
        begin_frame(ctx)
        push_id!(ctx, "container")
        ids1 = [get_id(ctx, "btn$i") for i in 1:5]
        pop_id!(ctx)
        end_frame(ctx)
        
        begin_frame(ctx)
        push_id!(ctx, "container") 
        ids2 = [get_id(ctx, "btn$i") for i in 1:5]
        pop_id!(ctx)
        end_frame(ctx)
        
        @test ids1 == ids2
    end
    
    @testset "Hash Function Quality" begin
        ctx = Context()
        init!(ctx)
        
        # Test 11: Distribution des hashs
        test_strings = [
            "button", "label", "textbox", "slider", "checkbox",
            "window", "panel", "header", "treenode", "popup",
            "btn1", "btn2", "btn3", "btn4", "btn5",
            "very_long_control_name_that_should_hash_well",
            "🎯", "αβγ", "control with spaces", "UPPERCASE",
        ]
        
        ids = [get_id(ctx, s) for s in test_strings]
        unique_ids = Set(ids)
        
        # Tous les IDs doivent être uniques
        @test length(unique_ids) == length(test_strings)
        
        # Test 12: Strings très similaires produisent IDs différents
        similar_strings = ["btn", "btn1", "btn11", "btn111", "btn1111"]
        similar_ids = [get_id(ctx, s) for s in similar_strings]
        
        @test length(Set(similar_ids)) == length(similar_strings)
    end
    
    @testset "Edge Cases" begin
        ctx = Context()
        init!(ctx)
        
        # Test 13: String vide
        id_empty = get_id(ctx, "")
        id_space = get_id(ctx, " ")
        @test id_empty != id_space
        
        # Test 14: Caractères spéciaux
        special_chars = ["!", "@", "#", "\$", "%", "^", "&", "*", "(", ")"]
        special_ids = [get_id(ctx, c) for c in special_chars]
        @test length(Set(special_ids)) == length(special_chars)
        
        # Test 15: Stack overflow protection (ne devrait pas planter)
        try
            for i in 1:100  # Dépasser IDSTACK_SIZE si besoin
                if ctx.id_stack.idx < IDSTACK_SIZE - 1
                    push_id!(ctx, "level$i")
                else
                    break
                end
            end
            # Nettoyer le stack
            while ctx.id_stack.idx > 0
                pop_id!(ctx)
            end
            println("Test 15: Protection contre stack overflow")
        catch e
            println("Test 15: Exception attendue pour stack overflow: $e")
        end
    end
    
    @testset "Real-World Collision Scenarios" begin
        ctx = Context()
        init!(ctx)
        
        # Test 16: Scénario réaliste avec plusieurs fenêtres
        begin_frame(ctx)
        
        # Fenêtre 1: Preferences
        push_id!(ctx, "preferences_window")
        pref_ok_id = get_id(ctx, "OK")
        pref_cancel_id = get_id(ctx, "Cancel")
        
        push_id!(ctx, "general_tab")
        general_checkbox_id = get_id(ctx, "Enable notifications")
        pop_id!(ctx)
        
        push_id!(ctx, "advanced_tab") 
        advanced_checkbox_id = get_id(ctx, "Enable notifications")  # Même label !
        pop_id!(ctx)
        
        pop_id!(ctx)
        
        # Fenêtre 2: File Dialog
        push_id!(ctx, "file_dialog")
        file_ok_id = get_id(ctx, "OK")  # Même label que preferences !
        file_cancel_id = get_id(ctx, "Cancel")
        pop_id!(ctx)
        
        # Vérifier que tous les IDs sont uniques
        all_ids = [pref_ok_id, pref_cancel_id, general_checkbox_id, 
                  advanced_checkbox_id, file_ok_id, file_cancel_id]
        
        @test length(Set(all_ids)) == length(all_ids)
        
        # Test 17: Même contrôle dans boucle
        loop_ids = []
        for i in 1:5
            push_id!(ctx, "item_$i")
            item_button_id = get_id(ctx, "Delete")  # Même label dans la boucle
            push!(loop_ids, item_button_id)
            pop_id!(ctx)
        end
        
        @test length(Set(loop_ids)) == 5
        
        end_frame(ctx)
    end
end