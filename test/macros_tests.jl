using Test

# ===== BASIC MACRO TESTS =====

@testset "MicroUI Macro Tests" begin
    
    
    @testset "State Management" begin
        clear_widget_states!()
        
        # Test state creation and persistence
        state1 = get_widget_state(:TestWindow)
        state2 = get_widget_state(:TestWindow)
        
        @test state1 === state2  # Should return same instance
        @test isa(state1, WidgetState)
        @test isempty(state1.variables)
        @test isempty(state1.refs)
        @test state1.window_open == true
        
        # Test different windows have different states
        state3 = get_widget_state(:AnotherWindow)
        @test state1 !== state3
    end

    @testset "Valid Assignments - Symbol Names" begin
        # Test avec Symbol (:x)
        expr1 = :(x = 5)
        key_expr1, value1 = parse_assignment(expr1)
        
        # key_expr devrait être QuoteNode(:x)
        @test key_expr1 isa QuoteNode
        @test key_expr1.value == :x
        @test value1 == 5
        
        # Test avec Symbol (:message)
        expr2 = :(message = "hello")
        key_expr2, value2 = parse_assignment(expr2)
        
        @test key_expr2 isa QuoteNode
        @test key_expr2.value == :message
        @test value2 == "hello"
    end
    
    @testset "Valid Assignments - String Names" begin
        # Test avec String ("my_var")
        expr3 = :("my_var" = 42)
        key_expr3, value3 = parse_assignment(expr3)
        
        # key_expr devrait être QuoteNode(Symbol("my_var")) = QuoteNode(:my_var)
        @test key_expr3 isa QuoteNode
        @test key_expr3.value == Symbol("my_var")
        @test key_expr3.value == :my_var
        @test value3 == 42
        
        # Test avec String ("static_text")
        expr4 = :("static_text" = "content")
        key_expr4, value4 = parse_assignment(expr4)
        
        @test key_expr4 isa QuoteNode
        @test key_expr4.value == :static_text
        @test value4 == "content"
    end
    
    @testset "Valid Assignments - Expression Names" begin
        # Test avec Expression ("item_$i")
        expr5 = :("item_$i" = "dynamic content")
        key_expr5, value5 = parse_assignment(expr5)
        
        # key_expr devrait être une Expr de la forme :(Symbol($(esc("item_$i"))))
        @test key_expr5 isa Expr
        @test key_expr5.head == :call
        @test key_expr5.args[1] == :Symbol
        @test value5 == "dynamic content"
        
        # Test avec Expression plus complexe
        expr6 = :("widget_$(prefix)_$i" = "complex name")
        key_expr6, value6 = parse_assignment(expr6)
        
        @test key_expr6 isa Expr
        @test key_expr6.head == :call
        @test key_expr6.args[1] == :Symbol
        @test value6 == "complex name"
    end
    
    @testset "Invalid Assignments" begin
        # Test expression invalide (pas d'assignation)
        @test_throws ErrorException parse_assignment(:(x + y))
        
        # Test expression invalide (pas d'expression du tout)
        @test_throws ErrorException parse_assignment(:x)
        
        # Test avec head incorrect
        @test_throws ErrorException parse_assignment(:(if true; x = 5; end))
    end
    
    @testset "Edge Cases" begin
        # Test avec variable complexe
        complex_expr = :(very_long_variable_name = "value")
        key_expr, value_expr = parse_assignment(complex_expr)
        @test key_expr isa QuoteNode
        @test key_expr.value == :very_long_variable_name
        
        # Test avec valeur complexe
        complex_value_expr = :(x = 2 + 3 * 4)
        key_expr2, value_expr2 = parse_assignment(complex_value_expr)
        @test key_expr2 isa QuoteNode
        @test key_expr2.value == :x
        @test value_expr2 isa Expr  # L'expression de calcul
        
        # Test avec string vide
        empty_string_expr = :("" = "empty key")
        key_expr3, value_expr3 = parse_assignment(empty_string_expr)
        @test key_expr3 isa QuoteNode
        @test key_expr3.value == Symbol("")  # Symbol avec nom vide
    end

    @testset "@context Macro" begin
        clear_widget_states!()
        
        # Test basic context creation
        @test_nowarn begin
            ctx = @context begin
                # Empty context should work
            end
            @test isa(ctx, Context)
        end
        
        # Test that context has proper callbacks
        ctx = @context begin end
        @test !isnothing(ctx.text_width)
        @test !isnothing(ctx.text_height)
        @test ctx.text_width(nothing, "test") == 32  # 4 chars * 8
        @test ctx.text_height(nothing) == 16
    end

    @testset "Real Usage in Macro Context" begin
        clear_widget_states!()
        
        # Test que parse_assignment fonctionne bien dans un contexte réel
        @test_nowarn begin
            ctx = @context begin
                @window "Parse Test" begin
                    # Symboles - utilise QuoteNode
                    @text title = "Title Test"
                    @var counter = 10
                    
                    # Strings - utilise QuoteNode(Symbol(...))
                    @text "static_text" = "Static Content"
                    @var "static_var" = 20
                    
                    # Expressions - utilise Symbol($(esc(...)))
                    @foreach i in 1:2 begin
                        @text "dynamic_$i" = "Dynamic $i"
                        @var "value_$i" = i * 5
                    end
                end
            end
        end
        
        # Vérifier que tous les types ont été traités correctement
        window_id = Symbol("window_", hash("Parse Test"))
        state = get_widget_state(window_id)
        
        # Symboles
        @test state.variables[:title] == "Title Test"
        @test state.variables[:counter] == 10
        
        # Strings statiques
        @test state.variables[Symbol("static_text")] == "Static Content"
        @test state.variables[Symbol("static_var")] == 20
        
        # Expressions dynamiques
        @test state.variables[Symbol("dynamic_1")] == "Dynamic 1"
        @test state.variables[Symbol("dynamic_2")] == "Dynamic 2"
        @test state.variables[Symbol("value_1")] == 5
        @test state.variables[Symbol("value_2")] == 10
    end

    @testset "@window Macro" begin
        clear_widget_states!()
        
        @test_nowarn begin
            @context begin
                @window "Test Window" begin
                    test_message = "Hello from window"
                end
            end
        end
        
        # Check that window state was created
        window_id = Symbol("window_", hash("Test Window"))
        state = get_widget_state(window_id)
        @test !isnothing(state)
    end

    @testset "@var Macro" begin
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Variable Test" begin
                    @var simple_var = "Simple value"
                    @var computed_var = 2 + 3
                    @var string_var = "Count: $(1 + 2)"
                end
            end
        end
        
        window_id = Symbol("window_", hash("Variable Test"))
        state = get_widget_state(window_id)
        
        @test state.variables[:simple_var] == "Simple value"
        @test state.variables[:computed_var] == 5
        @test state.variables[:string_var] == "Count: 3"
    end

    @testset "@text Macro" begin
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Text Test" begin
                    @text title = "Title Test"
                    @text simple_text = "An another Test"
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Text Test")))
        
        # Check that result keys are created
        @test haskey(state.variables, :title)
        @test haskey(state.variables, :simple_text)
        #@test haskey(state.variables, :simple_label)
        @test state.variables[:title] == "Title Test"
        @test state.variables[:simple_text] == "An another Test"
        #@test state.variables[:simple_label] == "This is a label"
    end

    @testset "label Macro" begin
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Label Test" begin
                    @simple_label content = "This is a label"
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Label Test")))
        
        # Check that result keys are created
        @test haskey(state.variables, :content)
        @test state.variables[:content] == "This is a label"
    end

    @testset "@button Macro" begin
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Button Test" begin
                    @text title = "Button Test"
                    @button ok_btn = "OK"
                    @button cancel_btn = "Cancel"
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Button Test")))
        @test haskey(state.variables, :ok_btn)
        @test haskey(state.variables, :cancel_btn)
        @test state.variables[:ok_btn] == "OK"
        @test state.variables[:cancel_btn] == "Cancel"
        
    end

    @testset "@checkbox Macro" begin
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Checkbox Test" begin
                    @checkbox enable_feature = true
                    @checkbox debug_mode = false
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Checkbox Test")))
        
        # Check that refs were created
        @test haskey(state.refs, :enable_feature)
        @test haskey(state.refs, :debug_mode)
        
        # Check initial values
        @test state.refs[:enable_feature][] == true
        @test state.refs[:debug_mode][] == false
        
        # Check stored values
        @test state.variables[:enable_feature] == true
        @test state.variables[:debug_mode] == false
    end

    @testset "@slider Macro" begin
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Slider Test" begin
                    @slider volume = 0.5 range(0.0, 1.0)
                    @slider brightness = 75 range(0, 100)
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Slider Test")))
        
        # Check that refs were created
        @test haskey(state.refs, :volume)
        @test haskey(state.refs, :brightness)
        
        # Check initial values (converted to Real)
        @test state.refs[:volume][] ≈ Real(0.5)
        @test state.refs[:brightness][] ≈ Real(75)
    end

    @testset "@when Macro" begin
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Conditionnal Test" begin
                    # Define conditions inside the window context
                    show_message = true
                    hide_message = false
                    
                    @when show_message begin
                        @text visible = "This should appear"
                    end
                    
                    @when hide_message begin
                        @text hidden = "This should not appear"
                    end
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Conditionnal Test")))
        
        # The visible text should be in state
        @test state.variables[:visible] == "This should appear"
        
        # The hidden text should not be in state
        @test !haskey(state.variables, :hidden)
    end

    @testset "@foreach Macro" begin
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Loop Test" begin
                    @foreach i in 1:3 begin
                        @text "item_$i" = "Item number $i"
                    end
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Loop Test")))
        
        # Check that all items were created
        for i in 1:3
            key = Symbol("item_$i")
            @test haskey(state.variables, key)
            @test state.variables[key] == "Item number $i"
        end
        
        # Test with enumerate
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Enumerate Test" begin
                    items = ["Apple", "Banana", "Cherry"]
                    @foreach (i, item) in enumerate(items) begin
                        @text "fruit_$i" = "$i: $item"
                    end
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Enumerate Test")))
        
        # Check enumerate results
        @test state.variables[Symbol("fruit_1")] == "1: Apple"
        @test state.variables[Symbol("fruit_2")] == "2: Banana"
        @test state.variables[Symbol("fruit_3")] == "3: Cherry"
        
    end

    @testset "Layout Macros" begin
        clear_widget_states!()
        
        @test_nowarn begin
            ctx = @context begin
                @window "Layout Test" begin
                    @row [100, 200] begin
                        @text left = "Left side"
                        @text right = "Right side"
                    end
                    
                    @column begin
                        @text top = "Top"
                        @text bottom = "Bottom"
                    end
                    
                    @panel "Settings" begin
                        @text inside_panel = "Panel content"
                    end
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Layout Test")))
        
        # All widgets should be created regardless of layout
        @test state.variables[:left] == "Left side"
        @test state.variables[:right] == "Right side"
        @test state.variables[:top] == "Top"
        @test state.variables[:bottom] == "Bottom"
        @test state.variables[:inside_panel] == "Panel content"
    end

    @testset "Event Handling (@onclick)" begin
        clear_widget_states!()
        
        # Single execution with internal simulation
        local event_executed = false
        
        ctx = @context begin
            @window "Event Test" begin
                @button test_btn = "Click me"
                
                # Simulate click INSIDE the context
                window_state.variables[:test_btn_result] = Int(MicroUI.RES_SUBMIT)
                
                @onclick test_btn begin
                    event_executed = true
                    @text click_response = "Button was clicked!"
                end
            end
        end
        
        @test event_executed
        
        # Check the stored response
        state = get_widget_state(Symbol("window_", hash("Event Test")))
        @test haskey(state.variables, :click_response)
        @test state.variables[:click_response] == "Button was clicked!"
        
        # Test no event case (unchanged)
        clear_widget_states!()
        
        @context begin
            @window "No Event Test" begin
                @button no_click_btn = "No click"
                @onclick no_click_btn begin
                    @text should_not_appear = "Should not appear"
                end
            end
        end
        
        state_no_click = get_widget_state(Symbol("window_", hash("No Event Test")))
        @test !haskey(state_no_click.variables, :should_not_appear)
    end

    @testset "Complex Integration Test" begin
        clear_widget_states!()
        
        @test_nowarn begin
            # Phase 1: Créer l'interface de base avec tous les widgets
            ctx1 = @context begin
                @window "Complex Integration Test" begin
                    @text title = "Complex Application"
                    
                    @panel "User Settings" begin
                        @checkbox enable_notifications = true
                        @slider volume = 0.8 range(0.0, 1.0)
                    end
                    
                    @panel "Actions" begin
                        actions = ["Save", "Load", "Reset"]
                        @foreach action in actions begin
                            # ✅ SYNTAXE CORRECTE: Interpolation directe dans la macro
                            @button "btn_$(lowercase(action))" = action
                        end
                    end
                    
                    @row [150, 150] begin
                        @button ok_btn = "OK"
                        @button cancel_btn = "Cancel"
                    end
                end
            end
            
            # Phase 2: Récupérer le state et calculer les valeurs dérivées
            state = get_widget_state(Symbol("window_", hash("Complex Integration Test")))
            notifications_enabled = state.refs[:enable_notifications][]
            volume_value = state.refs[:volume][]
            volume_percent = round(Int, volume_value * 100)
            volume_display_text = "Volume: $(volume_percent)%"
            
            # Phase 3: Recréer l'interface avec la logique conditionnelle et réactive
            ctx2 = @context begin
                @window "Complex Integration Test" begin
                    @text title = "Complex Application"
                    
                    @panel "User Settings" begin
                        @checkbox enable_notifications = true
                        @slider volume = 0.8 range(0.0, 1.0)
                        
                        # Logique conditionnelle basée sur les valeurs actuelles
                        @when notifications_enabled begin
                            @text notification_status = "Notifications enabled"
                        end
                        
                        # Affichage réactif du volume
                        @reactive volume_percent = volume_percent
                        @text volume_display = volume_display_text
                    end
                    
                    @panel "Actions" begin
                        actions = ["Save", "Load", "Reset"]
                        @foreach action in actions begin
                            # Même syntaxe correcte pour la phase 3
                            @button "btn_$(lowercase(action))" = action
                        end
                    end
                    
                    @row [150, 150] begin
                        @button ok_btn = "OK"
                        @button cancel_btn = "Cancel"
                    end
                end
            end
        end
        
        # Phase 4: Vérifications finales
        final_state = get_widget_state(Symbol("window_", hash("Complex Integration Test")))
        
        # Check main elements
        @test final_state.variables[:title] == "Complex Application"
        @test final_state.refs[:enable_notifications][] == true
        @test final_state.refs[:volume][] ≈ Real(0.8)
        
        # Check conditional rendering (only appears because notifications are enabled)
        @test final_state.variables[:notification_status] == "Notifications enabled"
        
        # Check reactive values
        @test final_state.variables[:volume_percent] == 80
        @test final_state.variables[:volume_display] == "Volume: 80%"
        
        # Check loop-generated buttons (noms générés dynamiquement)
        @test final_state.variables[:btn_save] == "Save"
        @test final_state.variables[:btn_load] == "Load"
        @test final_state.variables[:btn_reset] == "Reset"
        
        # Check row buttons
        @test final_state.variables[:ok_btn] == "OK"
        @test final_state.variables[:cancel_btn] == "Cancel"
        
        # Phase 5: Test supplémentaire - Vérifier que la logique conditionnelle fonctionne
        # Disable notifications and check that conditional content doesn't update
        final_state.refs[:enable_notifications][] = false
        
        @context begin
            @window "Complex Integration Test" begin
                @text title = "Complex Application"
                
                @panel "User Settings" begin
                    @checkbox enable_notifications = true
                    @slider volume = 0.8 range(0.0, 1.0)
                    
                    # This should not execute now because notifications are disabled
                    notifications_enabled_now = final_state.refs[:enable_notifications][]
                    @when notifications_enabled_now begin
                        @text notification_status = "Should not appear"
                    end
                end
            end
        end
        
        # The notification_status should still be the old value (not updated) 
        # because the @when condition is now false
        @test final_state.variables[:notification_status] == "Notifications enabled"
        
        # Phase 6: Test de changement de valeur du slider
        # Modifier la valeur du slider et vérifier la réactivité
        original_volume = final_state.refs[:volume][]
        final_state.refs[:volume][] = Real(0.3)  # Changer le volume
        
        # Recréer l'interface pour refléter le changement
        @context begin
            @window "Complex Integration Test" begin
                @panel "User Settings" begin
                    @checkbox enable_notifications = true
                    @slider volume = 0.8 range(0.0, 1.0)  # Valeur initiale ignorée
                    
                    # Calculer le nouveau pourcentage
                    new_volume_value = final_state.refs[:volume][]
                    new_volume_percent = round(Int, new_volume_value * 100)
                    new_volume_display_text = "Volume: $(new_volume_percent)%"
                    
                    @reactive volume_percent = new_volume_percent
                    @text volume_display = new_volume_display_text
                end
            end
        end
        
        # Vérifier que les valeurs réactives ont été mises à jour
        @test final_state.variables[:volume_percent] == 30
        @test final_state.variables[:volume_display] == "Volume: 30%"
        @test final_state.refs[:volume][] ≈ Real(0.3)
        
        println("✅ All complex integration features working correctly!")
        println("   - Dynamic button names: ✓")
        println("   - Conditional rendering: ✓") 
        println("   - Reactive values: ✓")
        println("   - State persistence: ✓")
        println("   - Layout systems (panels, rows): ✓")
    end

    @testset "Dynamic Names with @foreach - Complete Working Test" begin
        clear_widget_states!()
        
        @test_nowarn begin
            @context begin
                @window "Dynamic Names Test" begin
                    @text title = "Testing Dynamic Names"
                    
                    # Test avec noms statiques (référence)
                    @button btn_manual_save = "Manual Save"
                    @button btn_manual_load = "Manual Load"
                    
                    # Test avec noms dynamiques - SYNTAXE QUI FONCTIONNE
                    actions = ["Save", "Load", "Reset"]
                    @foreach action in actions begin
                        # ✅ CORRECT: Interpolation directe dans la macro
                        @button "btn_$(lowercase(action))" = action
                    end
                    
                    # Test avec d'autres types de widgets dynamiques
                    categories = ["File", "Edit", "View"]
                    @foreach cat in categories begin
                        @text "header_$(lowercase(cat))" = "$(cat) Operations"
                    end
                    
                    # Test avec checkboxes dynamiques
                    features = ["AutoSave", "DarkMode", "Notifications"]
                    @foreach feature in features begin
                        @checkbox "enable_$(lowercase(feature))" = true
                    end
                end
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Dynamic Names Test")))
        
        # Vérifier les boutons manuels
        @test haskey(state.variables, :btn_manual_save)
        @test haskey(state.variables, :btn_manual_load)
        @test state.variables[:btn_manual_save] == "Manual Save"
        @test state.variables[:btn_manual_load] == "Manual Load"
        
        # Vérifier les boutons dynamiques
        @test haskey(state.variables, :btn_save)
        @test haskey(state.variables, :btn_load)  
        @test haskey(state.variables, :btn_reset)
        @test state.variables[:btn_save] == "Save"
        @test state.variables[:btn_load] == "Load"
        @test state.variables[:btn_reset] == "Reset"
        
        # Vérifier les textes dynamiques
        @test haskey(state.variables, :header_file)
        @test haskey(state.variables, :header_edit)
        @test haskey(state.variables, :header_view)
        @test state.variables[:header_file] == "File Operations"
        @test state.variables[:header_edit] == "Edit Operations"
        @test state.variables[:header_view] == "View Operations"
        
        # Vérifier les checkboxes dynamiques
        @test haskey(state.refs, :enable_autosave)
        @test haskey(state.refs, :enable_darkmode)
        @test haskey(state.refs, :enable_notifications)
        @test state.refs[:enable_autosave][] == true
        @test state.refs[:enable_darkmode][] == true
        @test state.refs[:enable_notifications][] == true
        
        # Vérifier que les valeurs sont aussi dans variables
        @test state.variables[:enable_autosave] == true
        @test state.variables[:enable_darkmode] == true
        @test state.variables[:enable_notifications] == true
        
        println("✅ Dynamic widget names working correctly for all widget types!")
        println("   - Dynamic buttons: $(length([k for k in keys(state.variables) if startswith(string(k), "btn_")]))")
        println("   - Dynamic texts: $(length([k for k in keys(state.variables) if startswith(string(k), "header_")]))")
        println("   - Dynamic checkboxes: $(length([k for k in keys(state.refs) if startswith(string(k), "enable_")]))")
    end

    @testset "Error Handling" begin
        clear_widget_states!()
        
        # Test invalid assignment in @text
        @test_throws LoadError @eval @text invalid_syntax
        
        # Test invalid loop expression in @foreach
        @test_throws LoadError @eval begin
            @foreach invalid_loop begin
                @text x = "test"
            end
        end
        
        # Test malformed assignments
        @test_throws ErrorException parse_assignment(:(x + y))
    end

    @testset "State Persistence" begin
        clear_widget_states!()
        
        # First window creation
        ctx = @context begin
            @window "Persistence Test" begin
                @checkbox persistent_flag = true
                @slider persistent_value = 0.3 range(0.0, 1.0)
            end
        end
        
        # Modify state manually (simulating user interaction)
        state = get_widget_state(Symbol("window_", hash("Persistence Test")))
        state.refs[:persistent_flag][] = false
        state.refs[:persistent_value][] = Real(0.7)
        
        # Second window creation - state should persist
        ctx2 = @context begin
            @window "Persistence Test" begin
                @checkbox persistent_flag = true  # Initial value ignored
                @slider persistent_value = 0.3 range(0.0, 1.0)  # Initial value ignored
            end
        end
        
        # Values should be what we set, not the initial values
        final_state = get_widget_state(Symbol("window_", hash("Persistence Test")))
        @test final_state.refs[:persistent_flag][] == false
        @test final_state.refs[:persistent_value][] ≈ Real(0.7)
    end

    @testset "Multiple Windows" begin
        clear_widget_states!()
        
        ctx = @context begin
            # Create two different windows
            @window "Window1" begin
                @text message = "Window 1 message"
                @checkbox flag = true
            end
            
            @window "Window2" begin
                @text message = "Window 2 message"
                @checkbox flag = false
            end            
        end

        # Each window should have its own state
        state1 = get_widget_state(Symbol("window_", hash("Window1")))
        state2 = get_widget_state(Symbol("window_", hash("Window2")))
        
        @test state1.variables[:message] == "Window 1 message"
        @test state2.variables[:message] == "Window 2 message"
        
        @test state1.refs[:flag][] == true
        @test state2.refs[:flag][] == false
        
        # States should be independent
        @test state1 !== state2
    end

end

# ===== PERFORMANCE TESTS =====

@testset "Performance Tests" begin
    
    @testset "Macro Compilation Performance" begin
        clear_widget_states!()
        
        # Test that macros don't have excessive compilation overhead
        compil = @elapsed begin
            ctx = @context begin
                @window "PerfTest" begin
                    @text title = "Performance Test"
                    @foreach i in 1:10 begin
                        @button "btn_$i" = "Button $i"
                    end
                end
            end
        end

        @test compil < 0.02 # should take less than 20ms
        println("Time for compilation: $(compil * 1000) ms")
    end
    
    @testset "Runtime Performance" begin
        clear_widget_states!()
        
        # First run to compile everything
        ctx = @context begin
            @window "RuntimePerfTest" begin
                @text title = "Runtime Performance Test"
                @foreach i in 1:5 begin
                    @button "btn_$i" = "Button $i"
                    @checkbox "check_$i" = false
                end
            end
        end
        
        # Measure subsequent runs
        runtime = @elapsed begin
            for _ in 1:100
                ctx = @context begin
                    @window "RuntimePerfTest" begin
                        @text title = "Runtime Performance Test"
                        @foreach i in 1:5 begin
                            @button "btn_$i" = "Button $i"
                            @checkbox "check_$i" = false
                        end
                    end
                end
            end
        end
        
        @test runtime < 0.1  # 100 iterations should take less than 100ms
        println("Runtime for 100 iterations: $(runtime * 1000) ms")
    end

end

# ===== TYPE FIX =====
include("test_type_fix.jl")

# ===== CLEANUP =====

# Clear all states after tests
clear_widget_states!()

println("✅ All MicroUI macro tests passed!")