using Test

include("utils_tests.jl")

# ============================================================================
# TESTS DES LAYOUTS
# ============================================================================

@testset "Système de Layout" begin
    @testset "Layout basique" begin
        ctx = create_test_context()
        begin_frame(ctx)
        
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) == RES_ACTIVE
            # Layout par défaut
            r1 = layout_next(ctx)
            @test r1.w > 0
            @test r1.h > 0
            
            # Layout en ligne avec largeurs fixes
            layout_row!(ctx, 2, [100, 150], 30)
            r2 = layout_next(ctx)
            @test r2.w == 100
            @test r2.h == 30
            
            r3 = layout_next(ctx)
            @test r3.w == 150
            @test r3.h == 30
            @test r3.x > r2.x  # Doit être à droite
            
            end_window(ctx)
        end
        
        end_frame(ctx)
    end
    
    @testset "Layout avec largeurs dynamiques" begin
        ctx = create_test_context()
        begin_frame(ctx)
        
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) == RES_ACTIVE
            # -1 signifie "remplir l'espace restant"
            layout_row!(ctx, 2, [50, -1], 0)
            
            r1 = layout_next(ctx)
            @test r1.w == 50
            
            r2 = layout_next(ctx)
            @test r2.w > 50  # Doit prendre l'espace restant
            
            end_window(ctx)
        end
        
        end_frame(ctx)
    end
    
    @testset "Colonnes imbriquées" begin
        ctx = create_test_context()
        begin_frame(ctx)
        
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) == RES_ACTIVE
            layout_begin_column!(ctx)
            
            # Premier élément dans la colonne
            r1 = layout_next(ctx)
            y1 = r1.y
            
            # Deuxième élément
            r2 = layout_next(ctx)
            @test r2.y > y1  # Doit être en dessous
            @test r2.x == r1.x  # Même position X
            
            layout_end_column!(ctx)
            end_window(ctx)
        end
        
        end_frame(ctx)
    end
    
    @testset "Layout set_next" begin
        ctx = create_test_context()
        begin_frame(ctx)
        
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) == RES_ACTIVE
            # Position absolue
            layout_set_next!(ctx, Rect(50, 60, 70, 80), false)
            r = layout_next(ctx)
            @test r.x == 50
            @test r.y == 60
            @test r.w == 70
            @test r.h == 80
            
            end_window(ctx)
        end
        
        end_frame(ctx)
    end
end

# ============================================================================
# TESTS DES CONTAINERS
# ============================================================================

@testset "Containers et Windows" begin
    @testset "Window basique" begin
        ctx = create_test_context()
        
        begin_frame(ctx)
        opened = begin_window(ctx, "Test Window", Rect(10, 10, 200, 150))
        @test opened == RES_ACTIVE
        
        if opened == RES_ACTIVE
            # La fenêtre doit avoir un container actif
            cnt = get_current_container(ctx)
            @test cnt !== nothing
            @test cnt.open == true
            
            end_window(ctx)
        end
        end_frame(ctx)
    end
    
    @testset "Window avec options" begin
        ctx = create_test_context()
        
        begin_frame(ctx)
        # Fenêtre sans titre ni bouton fermer
        opts = UInt16(OPT_NOTITLE) | UInt16(OPT_NOCLOSE)
        opened = begin_window_ex(ctx, "NoTitle", Rect(10, 10, 200, 150), opts)
        @test opened == RES_ACTIVE
        
        if opened == RES_ACTIVE
            end_window(ctx)
        end
        end_frame(ctx)
    end
    
    @testset "Popup" begin
        ctx = create_test_context()
        
        begin_frame(ctx)
        
        # Ouvrir un popup
        open_popup!(ctx, "TestPopup")
        
        opened = begin_popup(ctx, "TestPopup")
        @test opened == RES_ACTIVE
        
        if opened == RES_ACTIVE
            label(ctx, "Popup content")
            end_popup(ctx)
        end
        
        end_frame(ctx)
    end
    
    @testset "Panel" begin
        ctx = create_test_context()
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) == RES_ACTIVE
            begin_panel(ctx, "TestPanel")
            
            # Le panel doit créer son propre contexte de layout
            label(ctx, "Panel content")
            
            end_panel(ctx)
            end_window(ctx)
        end
        end_frame(ctx)
    end
    
    @testset "TreeNode" begin
        ctx = create_test_context()
        expanded = false
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) == RES_ACTIVE
            res = begin_treenode(ctx, "Node")
            
            if res & Int(RES_ACTIVE) != 0
                expanded = true
                label(ctx, "Child content")

                end_treenode(ctx)
            end

            end_window(ctx)
        end
        end_frame(ctx)
        
        # Le treenode démarre fermé par défaut
        @test expanded == false
    end
end

@testset "Pool Management" begin
    ctx = create_test_context()
    
    @testset "Container pool" begin
        # Créer plusieurs containers
        for i in 1:5
            begin_frame(ctx)
            begin_window(ctx, "Window$i", Rect(i*10, i*10, 100, 100))
            end_window(ctx)
            end_frame(ctx)
        end
        
        # Vérifier que les containers sont dans le pool
        used_count = 0
        for item in ctx.container_pool
            if item.id != 0
                used_count += 1
            end
        end
        @test used_count >= 5
    end
    
    @testset "Pool recycling" begin
        ctx = create_test_context()
        
        # Créer et fermer une fenêtre
        for frame in 1:10
            begin_frame(ctx)
            if frame <= 5
                begin_window(ctx, "TempWindow", Rect(0, 0, 100, 100))
                end_window(ctx)
            end
            end_frame(ctx)
        end
        
        # Le pool devrait recycler les containers non utilisés
        old_items = count(item -> item.id != 0, ctx.container_pool)
        
        # Créer une nouvelle fenêtre
        begin_frame(ctx)
        begin_window(ctx, "NewWindow", Rect(0, 0, 100, 100))
        end_window(ctx)
        end_frame(ctx)
        
        new_items = count(item -> item.id != 0, ctx.container_pool)
        @test new_items <= old_items + 1
    end
end

# ============================================================================
# TESTS D'INTÉGRATION
# ============================================================================

@testset "Tests d'Intégration" begin
    @testset "Interface complète" begin
        ctx = create_test_context()
        
        # État de l'application
        button_clicks = 0
        check_state = Ref(false)
        text_value = Ref("Hello")
        slider_value = Ref(50.0f0)
        
        # Simuler plusieurs frames
        for frame in 1:5
            begin_frame(ctx)
            
            if begin_window(ctx, "Main Window", Rect(10, 10, 400, 300)) == RES_ACTIVE
                # Header
                if header(ctx, "Options") != 0
                    checkbox!(ctx, "Enable feature", check_state)
                    slider!(ctx, slider_value, 0.0f0, 100.0f0)
                end
                
                # Contenu principal
                layout_row!(ctx, 2, [100, -1], 0)
                label(ctx, "Name:")
                textbox!(ctx, "Textbox", text_value)
                
                # Boutons
                layout_row!(ctx, 3, [-1, -1, -1], 0)
                if button(ctx, "Save") != 0
                    button_clicks += 1
                end
                if button(ctx, "Load") != 0
                    button_clicks += 1
                end
                if button(ctx, "Cancel") != 0
                    button_clicks += 1
                end
                
                end_window(ctx)
            end
            
            # Fenêtre secondaire
            if check_state[]
                if begin_window(ctx, "Options", Rect(420, 10, 200, 200)) == RES_ACTIVE
                    text(ctx, "Additional options here")
                    end_window(ctx)
                end
            end
            
            end_frame(ctx)
        end
        
        # Vérifier que l'interface fonctionne
        @test ctx.frame == 5
        @test length(text_value[]) > 0
    end
    
    @testset "Gestion focus/hover" begin
        ctx = create_test_context()
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) == RES_ACTIVE
            # Créer plusieurs contrôles
            button(ctx, "Button1")
            button(ctx, "Button2")
            textbox!(ctx, "Textbox", Ref("Text"))
            
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Simuler hover sur le premier bouton
        input_mousemove!(ctx, 10, 10)
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) == RES_ACTIVE
            res1 = button(ctx, "Button1")
            res2 = button(ctx, "Button2")
            
            # Un seul contrôle devrait avoir le hover
            @test ctx.hover != 0
            
            end_window(ctx)
        end
        end_frame(ctx)
    end
end