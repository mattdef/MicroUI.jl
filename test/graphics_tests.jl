using Test

# ============================================================================
# TESTS DES LAYOUTS
# ============================================================================

@testset "Système de Layout" begin
    @testset "Layout basique" begin
        ctx = create_context()
        begin_frame(ctx)
        
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) != 0
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
        ctx = create_context()
        begin_frame(ctx)
        
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) != 0
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
        ctx = create_context()
        begin_frame(ctx)
        
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) != 0
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
        ctx = create_context()
        begin_frame(ctx)
        
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) != 0
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
        ctx = create_context()
        
        begin_frame(ctx)
        opened = begin_window(ctx, "Test Window", Rect(10, 10, 200, 150))
        @test opened != 0
        
        if opened != 0
            # La fenêtre doit avoir un container actif
            cnt = get_current_container(ctx)
            @test cnt !== nothing
            @test cnt.open == true
            
            end_window(ctx)
        end
        end_frame(ctx)
    end
    
    @testset "Window avec options" begin
        ctx = create_context()
        
        begin_frame(ctx)
        # Fenêtre sans titre ni bouton fermer
        opts = UInt16(MicroUI.OPT_NOTITLE) | UInt16(MicroUI.OPT_NOCLOSE)
        opened = begin_window_ex(ctx, "NoTitle", Rect(10, 10, 200, 150), opts)
        @test opened != 0
        
        if opened != 0
            end_window(ctx)
        end
        end_frame(ctx)
    end
    
    @testset "Popup" begin
        ctx = create_context()
        
        begin_frame(ctx)
        
        # Ouvrir un popup
        open_popup!(ctx, "TestPopup")
        
        opened = begin_popup(ctx, "TestPopup")
        @test opened != 0
        
        if opened != 0
            label(ctx, "Popup content")
            end_popup(ctx)
        end
        
        end_frame(ctx)
    end
    
    @testset "Panel" begin
        ctx = create_context()
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) != 0
            begin_panel(ctx, "TestPanel")
            
            # Le panel doit créer son propre contexte de layout
            label(ctx, "Panel content")
            
            end_panel(ctx)
            end_window(ctx)
        end
        end_frame(ctx)
    end
    
    @testset "TreeNode" begin
        ctx = create_context()
        expanded = false
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) != 0
            res = begin_treenode(ctx, "Node")
            
            if res & Int(MicroUI.RES_ACTIVE) != 0
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
    ctx = create_context()
    
    @testset "Container pool" begin
        # Créer plusieurs containers
        begin_frame(ctx)
    
        # Créer 3 fenêtres simultanément
        window_ids = []
        for i in 1:5
            push_id!(ctx, "multi_$i")
            if begin_window(ctx, "TestWindow", Rect(i*50, i*50, 100, 100)) != 0
                push!(window_ids, ctx.last_id)
                label(ctx, "Content $i")
                end_window(ctx)
            end
            pop_id!(ctx);
        end
        
        # Compter les containers actifs
        active_containers = count(item -> item.id != 0, ctx.container_pool)
        
        end_frame(ctx)
        
        @test active_containers >= 5
        @test length(unique(window_ids)) == 5
    end
    
    @testset "Pool recycling" begin
        ctx = create_context()
        
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
        ctx = create_context()
        
        # État de l'application
        button_clicks = 0
        check_state = Ref(false)
        text_value = Ref("Hello")
        slider_value = Ref(50.0f0)
        
        # Simuler plusieurs frames
        for frame in 1:5
            begin_frame(ctx)
            
            if begin_window(ctx, "Main Window", Rect(10, 10, 400, 300)) != 0
                # Header
                if header(ctx, "Options") != 0
                    checkbox!(ctx, "Enable feature", check_state)
                    slider!(ctx, slider_value, 0.0f0, 100.0f0)
                end
                
                # Contenu principal
                layout_row!(ctx, 2, [100, -1], 0)
                label(ctx, "Name:")
                textbox!(ctx, text_value, 100)
                
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
                if begin_window(ctx, "Options", Rect(420, 10, 200, 200)) != 0
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
        ctx = create_context()
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) != 0
            # Créer plusieurs contrôles
            button(ctx, "Button1")
            button(ctx, "Button2")
            textbox!(ctx, Ref("Text"), 100)
            
            end_window(ctx)
        end
        end_frame(ctx)
        
        # Simuler hover sur le premier bouton
        input_mousemove!(ctx, 10, 10)
        
        begin_frame(ctx)
        if begin_window(ctx, "Test", Rect(0, 0, 300, 200)) != 0
            res1 = button(ctx, "Button1")
            res2 = button(ctx, "Button2")
            
            # Un seul contrôle devrait avoir le hover
            @test ctx.hover != 0
            
            end_window(ctx)
        end
        end_frame(ctx)
    end
end