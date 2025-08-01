# ===== TESTS POUR VÉRIFIER LES CORRECTIONS =====
using Test


@testset "Type Safety in Macros" begin
    
    @testset "Slider Type Consistency" begin
        clear_widget_states!()
        
        # Test avec différents types d'entrée
        ctx = @context begin
            @window "Type Test" begin
                # Float64 par défaut (devrait être converti)
                @slider s1 = 0.5 range(0.0, 1.0)
                
                # Types explicites
                @slider s2 = Real(0.3) range(Real(0.0), Real(1.0))
                
                # Entiers (devraient être convertis)
                @slider s3 = 1 range(0, 10)
                
                # Vérifier les types dans l'état
                @debug_types "Type Test"
            end
        end
        
        # Vérifier que le contexte s'est créé sans erreur
        @test isa(ctx, Context)
        
        # Vérifier les types dans l'état des widgets
        state = get_widget_state(Symbol("window_", hash("Type Test")))
        
        # Tous les sliders doivent utiliser Real (Float32)
        @test isa(state.refs[:s1][], Real)
        @test isa(state.refs[:s2][], Real)  
        @test isa(state.refs[:s3][], Real)
        
        println("✅ Slider types are consistent")
    end
    
    @testset "Checkbox Type Consistency" begin
        clear_widget_states!()
        
        ctx = @context begin
            @window "Checkbox Test" begin
                @checkbox c1 = true
                @checkbox c2 = false
                @checkbox c3 = 1  # Should convert to Bool
                @checkbox c4 = 0  # Should convert to Bool
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Checkbox Test")))
        
        # Tous les checkboxes doivent être Bool
        @test isa(state.refs[:c1][], Bool)
        @test isa(state.refs[:c2][], Bool)
        @test isa(state.refs[:c3][], Bool)
        @test isa(state.refs[:c4][], Bool)
        
        @test state.refs[:c1][] == true
        @test state.refs[:c2][] == false
        @test state.refs[:c3][] == true   # 1 -> true
        @test state.refs[:c4][] == false  # 0 -> false
        
        println("✅ Checkbox types are consistent")
    end
    
    @testset "Variable Type Conversion" begin
        clear_widget_states!()
        
        ctx = @context begin
            @window "Variable Test" begin
                @var float_var = 3.14159    # Float64 -> Real
                @var int_var = 42           # Int -> Real  
                @var bool_var = true        # Bool -> Bool
                @var string_var = "test"    # String -> String
                
                @reactive computed_float = @state(float_var) * 2.0
                @reactive computed_bool = @state(int_var) > 40
            end
        end
        
        state = get_widget_state(Symbol("window_", hash("Variable Test")))
        
        # Vérifier les conversions automatiques
        @test isa(state.variables[:float_var], Real)
        @test isa(state.variables[:int_var], Real)
        @test isa(state.variables[:bool_var], Bool)
        @test isa(state.variables[:string_var], String)
        @test isa(state.variables[:computed_float], Real)
        @test isa(state.variables[:computed_bool], Bool)
        
        println("✅ Variable type conversions work correctly")
    end
    
    @testset "Helper Macros" begin
        # Test des macros helper
        range_val = @range(0.0, 1.0)
        @test isa(range_val[1], Real)
        @test isa(range_val[2], Real)
        
        step_val = @step(0.1)
        @test isa(step_val, Real)
        
        maxlen_val = @maxlength(128)
        @test isa(maxlen_val, Int)
        
        println("✅ Helper macros work correctly")
    end
    
    @testset "Complex UI with Mixed Types" begin
        clear_widget_states!()
        
        # Test d'une interface complexe avec différents types
        ctx = @context begin
            @window "Complex UI" begin
                @var temperature = 20.5      # Float64 -> Real
                @var humidity = 65           # Int -> Real
                @var auto_mode = true        # Bool -> Bool
                @var device_name = "Sensor1" # String -> String
                
                @slider temp_slider = @state(temperature) range(-10.0, 50.0)
                @slider hum_slider = @state(humidity) range(0, 100)
                @checkbox auto_checkbox = @state(auto_mode)
                
                @reactive status = @state(auto_mode) ? "Automatic" : "Manual"
                @reactive temp_celsius = "$(round(@state(temperature), digits=1))°C"
                @reactive hum_percent = "$(round(@state(humidity)))%"
                
                @simple_label temp_display = @state(temp_celsius)
                @simple_label hum_display = @state(hum_percent)
                @simple_label mode_display = @state(status)
            end
        end
        
        @test isa(ctx, Context)
        
        state = get_widget_state(Symbol("window_", hash("Complex UI")))
        
        # Vérifier que tous les types sont corrects
        @test isa(state.variables[:temperature], Real)
        @test isa(state.variables[:humidity], Real)
        @test isa(state.variables[:auto_mode], Bool)
        @test isa(state.variables[:device_name], String)
        @test isa(state.variables[:status], String)
        @test isa(state.variables[:temp_celsius], String)
        @test isa(state.variables[:hum_percent], String)
        
        @test isa(state.refs[:temp_slider][], Real)
        @test isa(state.refs[:hum_slider][], Real)
        @test isa(state.refs[:auto_checkbox][], Bool)
        
        println("✅ Complex UI handles mixed types correctly")
    end
end

# ===== FONCTION POUR TESTER MANUELLEMENT =====

function test_slider_fix()
    println("Testing slider type fix...")
    clear_widget_states!()
    
    try
        ctx = @context begin
            @window "Slider Test" begin
                @var volume = 0.7
                @slider volume_control = volume range(0.0, 1.0)
                @reactive volume_percent = "Volume: $(round(volume_control * 100))%"
                @simple_label display = volume_percent
            end
        end
        
        println("✅ SUCCESS: Slider created without type errors!")
        println("Context created: $(typeof(ctx))")
        
        # Vérifier l'état
        @debug_types "Slider Test"
        
        return true
    catch e
        println("❌ ERROR: $e")
        return false
    end
end

# ===== FONCTION POUR VÉRIFIER LES PERFORMANCES =====

function benchmark_type_conversions()
    
    println("Benchmarking type conversion overhead...")
    
    # Test sans conversion (baseline)
    function baseline_slider()
        val = Real(0.5)
        low = Real(0.0)
        high = Real(1.0)
        return (val, low, high)
    end
    
    # Test avec conversion
    function conversion_slider()
        val = 0.5  # Float64
        low = 0.0  # Float64
        high = 1.0 # Float64
        return (Real(val), Real(low), Real(high))
    end
    
    println("Baseline (no conversion):")
    @btime baseline_slider()
    
    println("With conversion:")
    @btime conversion_slider()
    
    println("Helper function:")
    @btime ensure_microui_range((0.0, 1.0))
end