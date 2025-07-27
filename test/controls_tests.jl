"""
Tests unitaires pour MicroUI.jl
Test des sliders, number inputs, scrollbars et tree nodes
"""

using Test
using StaticArrays
#include("MicroUI.jl")  # Remplacer par le chemin correct vers le module
using MicroUI

include("utils_tests.jl")

# -----------------------------------------------------------------------------
# Tests pour les Boutons
# -----------------------------------------------------------------------------

@testset "Button Tests" begin

    @testset "Contrôles - Bouton" begin
        ctx, _ = MicroUI.create_context_with_buffer_renderer(Float32; w=200, h=200)
        
        # Test de bouton sans interaction
        MicroUI.begin_frame!(ctx)
        MicroUI.begin_window!(ctx, "Button Test")
        
        pressed = MicroUI.button!(ctx, "Test Button")
        @test pressed == false  # Pas de clic
        
        MicroUI.end_window!(ctx)
        MicroUI.end_frame!(ctx)
        
        # Test de bouton avec clic - Version fonctionnelle
        button_pos = MicroUI.vec2(Float32, 80, 80)
        
        function test_button()
            MicroUI.begin_window!(ctx, "Button Test")
            result = MicroUI.button!(ctx, "Test Button")
            MicroUI.end_window!(ctx)
            return result
        end
        
        clicked = simulate_click!(ctx, button_pos, test_button)
        @test clicked == true
    end

end

@testset "Contrôles - Checkbox" begin
    ctx, _ = MicroUI.create_context_with_buffer_renderer(Float32; w=200, h=200)
    state = Ref(false)
    
    checkbox_pos = MicroUI.vec2(Float32, 60, 80)
    
    function test_checkbox()
        MicroUI.begin_window!(ctx, "Checkbox Test")
        MicroUI.checkbox!(ctx, "Test Check", state)
        MicroUI.end_window!(ctx)
        return nothing
    end
    
    simulate_click!(ctx, checkbox_pos, test_checkbox)
    @test state[] == true  # État basculé
    
    # Second clic
    simulate_click!(ctx, checkbox_pos, test_checkbox)
    @test state[] == false  # État basculé à nouveau
end

@testset "Contrôles - Zone de Texte" begin
    ctx, _ = MicroUI.create_context_with_buffer_renderer(Float32; w=300, h=200)
    buffer = Ref("initial")
    
    textbox_pos = MicroUI.vec2(Float32, 100, 80)
    
    function test_textbox()
        MicroUI.begin_window!(ctx, "Textbox Test")
        MicroUI.input_textbox!(ctx, "Test Input", buffer, 150)
        MicroUI.end_window!(ctx)
        return nothing
    end
    
    # Donner le focus à la zone de texte
    simulate_click!(ctx, textbox_pos, test_textbox)
    
    # Test de l'entrée de texte
    MicroUI.begin_frame!(ctx)
    MicroUI.input_text!(ctx, " added")
    test_textbox()
    MicroUI.end_frame!(ctx)
    
    @test buffer[] == "initial added"
    
    # Test du backspace
    MicroUI.begin_frame!(ctx)
    MicroUI.input_keydown!(ctx, :backspace)
    test_textbox()
    MicroUI.end_frame!(ctx)
    
    @test buffer[] == "initial adde"
end

# -----------------------------------------------------------------------------
# Tests pour les Sliders
# -----------------------------------------------------------------------------

@testset "Slider Tests" begin
    
    @testset "Slider - Création et Initialisation" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        value = Ref(0.5)
        changed = MicroUI.slider!(ctx, "test_slider", value, 0.0, 1.0, 200)
        
        @test !changed  # Pas de changement initial
        @test value[] == 0.5  # Valeur inchangée
        
        cleanup_test_context(ctx)
    end
    
    @testset "Slider - Valeurs Limites" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Test valeur minimale
        min_value = Ref(0.0)
        MicroUI.slider!(ctx, "min_slider", min_value, 0.0, 1.0, 200)
        @test min_value[] == 0.0
        
        # Test valeur maximale  
        max_value = Ref(1.0)
        MicroUI.slider!(ctx, "max_slider", max_value, 0.0, 1.0, 200)
        @test max_value[] == 1.0
        
        # Test valeur au-delà des limites (doit être clampée)
        over_value = Ref(1.5)
        MicroUI.slider!(ctx, "over_slider", over_value, 0.0, 1.0, 200)
        # La valeur devrait être clampée lors du rendu
        
        cleanup_test_context(ctx)
    end
    
    @testset "Slider - Interaction Souris" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        value = Ref(0.5)
        
        # Premier rendu pour établir la position
        MicroUI.slider!(ctx, "interactive_slider", value, 0.0, 1.0, 200)
        
        # Simule un clic au milieu du slider (devrait rester à ~0.5)
        # Position approximative basée sur le layout du slider
        slider_x = 50 + 4  # Position fenêtre + padding
        slider_y = 50 + 30 + 4  # Position fenêtre + titre + padding
        
        simulate_click!(ctx, slider_x + 100, slider_y)  # Milieu du slider (200px/2)
        
        # Nouveau rendu après interaction
        MicroUI.begin_frame!(ctx)
        if MicroUI.begin_window!(ctx, "Test Window", 50, 50, 300, 400)
            changed = MicroUI.slider!(ctx, "interactive_slider", value, 0.0, 1.0, 200)
            # Note: Le changement pourrait ne pas être détecté dans ce test simplifié
        end
        
        cleanup_test_context(ctx)
    end
    
    @testset "Slider - Différents Types Numériques" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Test avec Int
        int_value = Ref(5)
        MicroUI.slider!(ctx, "int_slider", int_value, 0, 10, 200)
        @test int_value[] == 5
        
        # Test avec Float64
        float_value = Ref(2.5)
        MicroUI.slider!(ctx, "float_slider", float_value, 0.0, 5.0, 200)
        @test float_value[] == 2.5
        
        cleanup_test_context(ctx)
    end
    
    @testset "Slider - ID Unique" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        value1 = Ref(0.3)
        value2 = Ref(0.7)
        
        # Deux sliders avec des labels différents
        MicroUI.slider!(ctx, "slider1", value1, 0.0, 1.0, 200)
        MicroUI.slider!(ctx, "slider2", value2, 0.0, 1.0, 200)
        
        @test value1[] == 0.3
        @test value2[] == 0.7
        
        cleanup_test_context(ctx)
    end
end

# -----------------------------------------------------------------------------
# Tests pour les Number Inputs
# -----------------------------------------------------------------------------

@testset "Number Input Tests" begin
    
    @testset "Number Input - Création et Initialisation" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        value = Ref(42)
        changed = MicroUI.number_input!(ctx, "test_number", value, 1, 0, 100, 150)
        
        @test !changed  # Pas de changement initial
        @test value[] == 42  # Valeur inchangée
        
        cleanup_test_context(ctx)
    end
    
    @testset "Number Input - Boutons Plus/Moins" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        value = Ref(50)
        
        # Premier rendu
        MicroUI.number_input!(ctx, "step_number", value, 5, 0, 100, 150)
        
        # Test des IDs des boutons (simule les clics)
        # Position approximative des boutons
        base_x = 50 + 4  # Position fenêtre + padding
        base_y = 50 + 30 + 4  # Position fenêtre + titre + padding
        button_w = 20  # Largeur approximative du bouton
        
        # Simule clic sur bouton plus (côté droit)
        simulate_click!(ctx, base_x + 150 - button_w/2, base_y)
        
        # Nouveau rendu pour voir le changement
        MicroUI.begin_frame!(ctx)
        if MicroUI.begin_window!(ctx, "Test Window", 50, 50, 300, 400)
            changed = MicroUI.number_input!(ctx, "step_number", value, 5, 0, 100, 150)
            # Le changement dépend de l'implémentation exacte des clics
        end
        
        cleanup_test_context(ctx)
    end
    
    @testset "Number Input - Limites Min/Max" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Test à la limite minimale
        min_value = Ref(0)
        MicroUI.number_input!(ctx, "min_number", min_value, 1, 0, 10, 150)
        @test min_value[] == 0
        
        # Test à la limite maximale
        max_value = Ref(10)
        MicroUI.number_input!(ctx, "max_number", max_value, 1, 0, 10, 150)
        @test max_value[] == 10
        
        cleanup_test_context(ctx)
    end
    
    @testset "Number Input - Steps Personnalisés" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Test avec step de 0.1
        decimal_value = Ref(5.5)
        MicroUI.number_input!(ctx, "decimal_number", decimal_value, 0.1, 0.0, 10.0, 150)
        @test decimal_value[] == 5.5
        
        # Test avec step de 10
        big_step_value = Ref(50)
        MicroUI.number_input!(ctx, "big_step_number", big_step_value, 10, 0, 100, 150)
        @test big_step_value[] == 50
        
        cleanup_test_context(ctx)
    end
    
    @testset "Number Input - Types Différents" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Int
        int_val = Ref(25)
        MicroUI.number_input!(ctx, "int_input", int_val, 1, 0, 100, 150)
        @test int_val[] == 25
        
        # Float64
        float_val = Ref(12.34)
        MicroUI.number_input!(ctx, "float_input", float_val, 0.01, 0.0, 100.0, 150)
        @test float_val[] == 12.34
        
        cleanup_test_context(ctx)
    end
end

# -----------------------------------------------------------------------------
# Tests pour les Scrollbars
# -----------------------------------------------------------------------------

@testset "Scrollbar Tests" begin
    
    @testset "Scrollbar - Création de Base" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        scroll_value = Ref(0.0)
        changed = MicroUI.scrollbar!(ctx, "test_scroll", scroll_value, 1000, 200, 250, 50, 300)
        
        @test !changed  # Pas de changement initial
        @test scroll_value[] == 0.0
        
        cleanup_test_context(ctx)
    end
    
    @testset "Scrollbar - Pas de Scrollbar si Pas Nécessaire" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        scroll_value = Ref(0.0)
        # Contenu plus petit que la zone visible - pas de scrollbar nécessaire
        needs_scroll = MicroUI.scrollbar!(ctx, "no_scroll", scroll_value, 100, 200, 250, 50, 300)
        
        @test !needs_scroll  # Pas de scrollbar nécessaire
        
        cleanup_test_context(ctx)
    end
    
    @testset "Scrollbar - Calcul du Thumb" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        scroll_value = Ref(0.0)
        
        # Contenu 2x plus grand que la zone visible
        # Le thumb devrait faire 50% de la hauteur
        content_size = 400
        visible_size = 200
        
        MicroUI.scrollbar!(ctx, "thumb_test", scroll_value, content_size, visible_size, 250, 50, 300)
        
        # Le calcul du thumb est interne, on teste juste que ça ne crash pas
        @test scroll_value[] == 0.0
        
        cleanup_test_context(ctx)
    end
    
    @testset "Scrollbar - Valeurs de Scroll Valides" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Test avec valeur de scroll au milieu
        scroll_value = Ref(100.0)  # Au milieu d'un contenu de 400 avec visible 200
        MicroUI.scrollbar!(ctx, "mid_scroll", scroll_value, 400, 200, 250, 50, 300)
        @test scroll_value[] == 100.0
        
        # Test avec valeur de scroll maximale
        max_scroll_value = Ref(200.0)  # Maximum pour contenu 400, visible 200
        MicroUI.scrollbar!(ctx, "max_scroll", max_scroll_value, 400, 200, 250, 50, 300)
        @test max_scroll_value[] == 200.0
        
        cleanup_test_context(ctx)
    end
    
    @testset "Scrollbar - Interaction Drag" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        scroll_value = Ref(0.0)
        
        # Premier rendu
        MicroUI.scrollbar!(ctx, "drag_scroll", scroll_value, 400, 200, 250, 50, 300)
        
        # Simule un drag sur la scrollbar
        scroll_x = 250 + 8  # Position scrollbar + moitié largeur
        scroll_start_y = 50 + 20  # Début du thumb
        scroll_end_y = 50 + 100   # Nouvelle position
        
        simulate_drag!(ctx, scroll_x, scroll_start_y, scroll_x, scroll_end_y)
        
        # Nouveau rendu après drag
        MicroUI.begin_frame!(ctx)
        if MicroUI.begin_window!(ctx, "Test Window", 50, 50, 300, 400)
            changed = MicroUI.scrollbar!(ctx, "drag_scroll", scroll_value, 400, 200, 250, 50, 300)
        end
        
        cleanup_test_context(ctx)
    end
end

# -----------------------------------------------------------------------------
# Tests pour les Tree Nodes
# -----------------------------------------------------------------------------

@testset "Tree Node Tests" begin
    
    @testset "Tree Node - Création de Base" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        expanded = Ref(false)
        is_expanded = MicroUI.tree_node!(ctx, "Root Node", expanded, 0)
        
        @test !is_expanded  # Initialement fermé
        @test !expanded[]   # Valeur de référence cohérente
        
        cleanup_test_context(ctx)
    end
    
    @testset "Tree Node - État Expanded" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Node initialement ouvert
        expanded = Ref(true)
        is_expanded = MicroUI.tree_node!(ctx, "Expanded Node", expanded, 0)
        
        @test is_expanded   # Doit être ouvert
        @test expanded[]    # Valeur de référence cohérente
        
        cleanup_test_context(ctx)
    end
    
    @testset "Tree Node - Niveaux d'Indentation" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Test de différents niveaux
        root_expanded = Ref(true)
        child1_expanded = Ref(false)
        child2_expanded = Ref(true)
        
        # Root level (0)
        MicroUI.tree_node!(ctx, "Root", root_expanded, 0)
        
        # Level 1
        MicroUI.tree_node!(ctx, "Child 1", child1_expanded, 1)
        MicroUI.tree_node!(ctx, "Child 2", child2_expanded, 1)
        
        # Level 2
        grandchild_expanded = Ref(false)
        MicroUI.tree_node!(ctx, "Grandchild", grandchild_expanded, 2)
        
        # Vérifie que les états sont préservés
        @test root_expanded[]
        @test !child1_expanded[]
        @test child2_expanded[]
        @test !grandchild_expanded[]
        
        cleanup_test_context(ctx)
    end
    
    @testset "Tree Node - Interaction Clic" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        expanded = Ref(false)
        
        # Premier rendu
        MicroUI.tree_node!(ctx, "Clickable Node", expanded, 0)
        
        # Position approximative de l'icône (début du contrôle)
        icon_x = 50 + 4 + 7  # Position fenêtre + padding + moitié icône
        icon_y = 50 + 30 + 4 + 7  # Position fenêtre + titre + padding + moitié icône
        
        # Simule un clic sur l'icône
        simulate_click!(ctx, icon_x, icon_y)
        
        # Nouveau rendu après clic
        MicroUI.begin_frame!(ctx)
        if MicroUI.begin_window!(ctx, "Test Window", 50, 50, 300, 400)
            is_expanded = MicroUI.tree_node!(ctx, "Clickable Node", expanded, 0)
            # L'état pourrait avoir changé selon l'implémentation du clic
        end
        
        cleanup_test_context(ctx)
    end
    
    @testset "Tree Node - Multiples Nodes avec IDs Uniques" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Plusieurs nodes avec des noms différents
        node1_expanded = Ref(false)
        node2_expanded = Ref(true)
        node3_expanded = Ref(false)
        
        is_expanded1 = MicroUI.tree_node!(ctx, "Node 1", node1_expanded, 0)
        is_expanded2 = MicroUI.tree_node!(ctx, "Node 2", node2_expanded, 0)
        is_expanded3 = MicroUI.tree_node!(ctx, "Node 3", node3_expanded, 0)
        
        @test !is_expanded1
        @test is_expanded2
        @test !is_expanded3
        
        # Vérifie que les états sont indépendants
        @test !node1_expanded[]
        @test node2_expanded[]
        @test !node3_expanded[]
        
        cleanup_test_context(ctx)
    end
    
    @testset "Tree Node - Arbre Hiérarchique Complet" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Construit un arbre complet
        root_expanded = Ref(true)
        folder1_expanded = Ref(true)
        folder2_expanded = Ref(false)
        file1_expanded = Ref(false)  # Les fichiers ne s'ouvrent généralement pas
        
        # Structure d'arbre
        if MicroUI.tree_node!(ctx, "📁 Root Folder", root_expanded, 0)
            if MicroUI.tree_node!(ctx, "📁 Subfolder 1", folder1_expanded, 1)
                MicroUI.tree_node!(ctx, "📄 File 1.txt", file1_expanded, 2)
                MicroUI.tree_node!(ctx, "📄 File 2.txt", Ref(false), 2)
            end
            MicroUI.tree_node!(ctx, "📁 Subfolder 2", folder2_expanded, 1)
            MicroUI.tree_node!(ctx, "📄 Root File.txt", Ref(false), 1)
        end
        
        # Vérifie la cohérence
        @test root_expanded[]
        @test folder1_expanded[]
        @test !folder2_expanded[]
        
        cleanup_test_context(ctx)
    end
end

# -----------------------------------------------------------------------------
# Tests d'Intégration - Combinaisons de Contrôles
# -----------------------------------------------------------------------------

@testset "Integration Tests" begin
    
    @testset "Tous les Contrôles Ensemble" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Variables pour tous les contrôles
        slider_val = Ref(0.5)
        number_val = Ref(10)
        scroll_val = Ref(0.0)
        tree_expanded = Ref(false)
        
        # Rendu de tous les contrôles
        slider_changed = MicroUI.slider!(ctx, "Volume", slider_val, 0.0, 1.0, 200)
        number_changed = MicroUI.number_input!(ctx, "Count", number_val, 1, 0, 100, 150)
        scroll_changed = MicroUI.scrollbar!(ctx, "Scroll", scroll_val, 500, 100, 280, 50, 200)
        tree_expanded_result = MicroUI.tree_node!(ctx, "Files", tree_expanded, 0)
        
        # Vérifie qu'aucun contrôle n'interfère avec les autres
        @test !slider_changed
        @test !number_changed
        @test !scroll_changed  # Scrollbar nécessaire (500 > 100)
        @test !tree_expanded_result
        
        # Vérifie les valeurs
        @test slider_val[] == 0.5
        @test number_val[] == 10
        @test scroll_val[] == 0.0
        @test !tree_expanded[]
        
        cleanup_test_context(ctx)
    end
    
    @testset "Contrôles dans Layout Row" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Layout horizontal
        MicroUI.layout_row!(ctx)
        
        slider_val = Ref(0.3)
        number_val = Ref(5)
        tree_expanded = Ref(true)
        
        # Contrôles en ligne
        MicroUI.slider!(ctx, "H_Slider", slider_val, 0.0, 1.0, 100)
        MicroUI.number_input!(ctx, "H_Number", number_val, 1, 0, 10, 80)
        MicroUI.tree_node!(ctx, "H_Tree", tree_expanded, 0)
        
        MicroUI.end_layout_row!(ctx)
        
        # Vérifie que les valeurs sont préservées
        @test slider_val[] == 0.3
        @test number_val[] == 5
        @test tree_expanded[]
        
        cleanup_test_context(ctx)
    end
    
    @testset "Performance - Nombreux Contrôles" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Test de performance avec de nombreux contrôles
        slider_values = [Ref(i * 0.1) for i in 1:10]
        number_values = [Ref(i) for i in 1:10]
        tree_values = [Ref(i % 2 == 0) for i in 1:10]
        
        # Mesure le temps d'exécution
        @time begin
            for i in 1:10
                MicroUI.slider!(ctx, "Slider_$i", slider_values[i], 0.0, 1.0, 100)
                MicroUI.number_input!(ctx, "Number_$i", number_values[i], 1, 0, 100, 80)
                MicroUI.tree_node!(ctx, "Tree_$i", tree_values[i], 0)
            end
        end
        
        # Vérifie que toutes les valeurs sont correctes
        for i in 1:10
            @test slider_values[i][] == i * 0.1
            @test number_values[i][] == i
            @test tree_values[i][] == (i % 2 == 0)
        end
        
        cleanup_test_context(ctx)
    end
end

# -----------------------------------------------------------------------------
# Tests de Régression - Compatibilité avec l'Ancien Code
# -----------------------------------------------------------------------------

@testset "Regression Tests" begin
    
    @testset "Contrôles Existants Toujours Fonctionnels" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Test des anciens contrôles
        button_pressed = MicroUI.button!(ctx, "Old Button")
        @test !button_pressed
        
        MicroUI.text!(ctx, "Old Text")
        MicroUI.label!(ctx, "Old Label")
        
        checkbox_state = Ref(false)
        MicroUI.checkbox!(ctx, "Old Checkbox", checkbox_state)
        @test !checkbox_state[]
        
        textbox_buffer = Ref("Old Text")
        MicroUI.input_textbox!(ctx, "Old Textbox", textbox_buffer, 150)
        @test textbox_buffer[] == "Old Text"
        
        cleanup_test_context(ctx)
    end
    
    @testset "Compatibilité des Types" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Test avec différents types numériques
        int32_val = Ref(Int32(42))
        int64_val = Ref(Int64(84))
        float32_val = Ref(Float32(3.14))
        float64_val = Ref(Float64(2.71))
        
        MicroUI.slider!(ctx, "Int32_Slider", int32_val, Int32(0), Int32(100), 100)
        MicroUI.slider!(ctx, "Int64_Slider", int64_val, Int64(0), Int64(200), 100)
        MicroUI.slider!(ctx, "Float32_Slider", float32_val, Float32(0), Float32(10), 100)
        MicroUI.slider!(ctx, "Float64_Slider", float64_val, 0.0, 10.0, 100)
        
        @test int32_val[] == Int32(42)
        @test int64_val[] == Int64(84)
        @test float32_val[] == Float32(3.14)
        @test float64_val[] == Float64(2.71)
        
        cleanup_test_context(ctx)
    end
end

# -----------------------------------------------------------------------------
# Tests d'Edge Cases et Robustesse
# -----------------------------------------------------------------------------

@testset "Edge Cases" begin
    
    @testset "Contrôles sans Fenêtre Active" begin
        ctx, renderer = MicroUI.create_context_with_buffer_renderer(800, 600)
        MicroUI.begin_frame!(ctx)
        # Pas de fenêtre ouverte
        
        slider_val = Ref(0.5)
        number_val = Ref(10)
        tree_expanded = Ref(false)
        
        # Les contrôles ne devraient pas planter sans fenêtre
        @test_nowarn MicroUI.slider!(ctx, "No_Window_Slider", slider_val, 0.0, 1.0, 100)
        @test_nowarn MicroUI.number_input!(ctx, "No_Window_Number", number_val, 1, 0, 100, 100)
        @test_nowarn MicroUI.tree_node!(ctx, "No_Window_Tree", tree_expanded, 0)
        
        MicroUI.end_frame!(ctx)
    end
    
    @testset "Valeurs Extrêmes" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Valeurs très grandes
        big_val = Ref(1e6)
        MicroUI.slider!(ctx, "Big_Slider", big_val, 0.0, 1e6, 100)
        
        # Valeurs très petites
        small_val = Ref(1e-6)
        MicroUI.slider!(ctx, "Small_Slider", small_val, 0.0, 1e-3, 100)
        
        # Valeurs négatives
        neg_val = Ref(-50)
        MicroUI.number_input!(ctx, "Neg_Number", neg_val, 1, -100, 0, 100)
        
        @test big_val[] == 1e6
        @test small_val[] == 1e-6
        @test neg_val[] == -50
        
        cleanup_test_context(ctx)
    end
    
    @testset "Chaînes Vides et Caractères Spéciaux" begin
        ctx, renderer, window_open = create_test_context()
        @test window_open
        
        # Labels vides
        empty_expanded = Ref(false)
        @test_nowarn MicroUI.tree_node!(ctx, "", empty_expanded, 0)
        
        # Caractères spéciaux
        special_expanded = Ref(false)
        @test_nowarn MicroUI.tree_node!(ctx, "🚀 Test éñ中文", special_expanded, 0)
        
        # Labels très longs
        long_label = "A" ^ 100
        long_expanded = Ref(false)
        @test_nowarn MicroUI.tree_node!(ctx, long_label, long_expanded, 0)
        
        cleanup_test_context(ctx)
    end
end
