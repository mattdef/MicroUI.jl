# MicroUI Macro-based Demo Examples
# This demonstrates using the high-level macro DSL instead of the low-level API

include("../src/MicroUI.jl")
using .MicroUI
using .MicroUI.Macros

include("text_renderer.jl")

# ===== DEMO APPLICATIONS USING MACROS =====

"""
Demo application using the new @context_no_frame + @frame approach
"""
function demo_application()
    println("🎮 MicroUI New Macro Demo with Context Reuse")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(70, 25)
    
    # 🎯 NEW APPROACH: Create context once
    ctx = create_context()
    
    # Simulate multiple frames
    for frame in 1:3
        println("📺 Frame $frame:")
        println("-" ^ 30)
        
        # 🎯 Use @frame for each frame with existing context
        @frame ctx begin
            @window "Simple Demo" begin
                # Variables managed by macro system
                @var greeting = "Hello, Julia!"
                @var counter = frame * 2  # Simulate increasing counter
                @var enable_feature = frame > 1  # Enable after frame 1
                @var volume = 0.3 + (frame * 0.2)  # Simulate changing volume
                
                # Display content using macros
                @panel "Hello" begin
                    @text greeting_display = @state(greeting)
                end
                
                @simple_label counter_display = "Click count: $(@state(counter))"
                
                # Interactive elements
                @button click_btn = "Click me!"
                
                # Checkbox
                @checkbox feature_checkbox = @state(enable_feature)
                
                # Slider  
                @slider volume_slider = @state(volume) range(0.0, 1.0)
                
                # Conditional content using @when
                @when @state(enable_feature) begin
                    @reactive volume_percent = round(@state(volume) * 100, digits=1)
                    @simple_label volume_display = "Volume: $(@state(volume_percent))%"
                end
            end
            
            # Second window using same context
            @window "Settings" begin
                @simple_label theme_label = "Theme: Dark"
                @button save_btn = "Save Configuration"
            end
        end
        
        # ✅ ctx is available here for rendering!
        render_context!(renderer, ctx)
        display!(renderer)
        
        # Small delay for demo effect
        sleep(1.0)
    end
    
    println("✅ New macro approach demo completed!")
end

"""
Interactive demo using the new @context_no_frame + @frame approach
Best performance with macro syntax!
"""
function interactive_demo()
    println("🎮 Interactive MicroUI Demo (@context_no_frame + @frame)")
    println("Commands: start, stop, toggle, slider <value>, quit")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(70, 30)
    
    # 🎯 NEW APPROACH: Create context once, reuse for all frames
    ctx = create_context()
    # Context is ready, no frames here
    
    # Global state variables
    user_started = false
    enable_feature = false
    volume_value = 0.5
    running = true
    
    while running
        # 🎯 Use @frame for each iteration
        @frame ctx begin
            @window "Interactive Demo" begin
                @simple_label title = "🎮 Interactive MicroUI Demo (Optimized)"
                
                # Status panel
                @panel "Status" begin
                    @reactive status_text = user_started ? "🟢 Running" : "🔴 Stopped"
                    @simple_label status_display = "Status: $(@state(status_text))"
                    
                    @reactive slider_percent = round(Int, volume_value * 100)
                    @simple_label value_display = "Value: $(@state(slider_percent))%"
                    
                    @when enable_feature begin
                        @simple_label auto_display = "🤖 Auto mode: ON"
                    end
                end
                
                # Controls panel
                @panel "Controls" begin
                    @row [80, 80, 80] begin
                        @button start_btn = "Start"
                        @button stop_btn = "Stop"  
                        @button quit_btn = "Quit"
                    end
                    
                    @checkbox auto_checkbox = enable_feature
                    @slider value_slider = volume_value range(0.0, 1.0)
                    
                    # Event handling with @onclick
                    @onclick start_btn begin
                        user_started = true
                        println("✅ Started!")
                    end
                    
                    @onclick stop_btn begin
                        user_started = false
                        println("⏹️ Stopped!")
                    end
                    
                    @onclick quit_btn begin
                        running = false
                        println("👋 Goodbye!")
                    end
                end
                
                # Help panel
                @panel "Help" begin
                    @simple_label help1 = "Optimized: Context reuse + @frame macro"
                    @simple_label help2 = "• start, stop, quit"
                    @simple_label help3 = "• toggle (auto mode)"
                    @simple_label help4 = "• slider <0.0-1.0>"
                end
            end
        end
        
        # Update global state from UI state (reactive sync)
        window_state = get_widget_state(Symbol("window_", hash("Interactive Demo")))
        if haskey(window_state.refs, :auto_checkbox)
            enable_feature = window_state.refs[:auto_checkbox][]
        end
        if haskey(window_state.refs, :value_slider)
            volume_value = window_state.refs[:value_slider][]
        end
        
        # ✅ ctx is available here for rendering!
        render_context!(renderer, ctx)
        display!(renderer)
        
        # Get user input
        print("\\n> ")
        input = strip(readline())
        
        # Process commands
        if input == "start"
            user_started = true
            println("✅ Started!")
        elseif input == "stop"
            user_started = false
            println("⏹️ Stopped!")
        elseif input == "toggle"
            enable_feature = !enable_feature
            println("🔄 Auto mode: $(enable_feature ? "ON" : "OFF")")
        elseif startswith(input, "slider ")
            try
                value = parse(Float64, input[8:end])
                if 0.0 <= value <= 1.0
                    volume_value = value
                    println("🎚️ Slider set to $value")
                else
                    println("❌ Value must be between 0.0 and 1.0")
                end
            catch
                println("❌ Invalid number format")
            end
        elseif input == "quit"
            running = false
            println("👋 Goodbye!")
        elseif input == ""
            continue
        else
            println("❌ Unknown command: $input")
        end
        
        # Auto-update slider in auto mode
        if enable_feature
            volume_value = mod(volume_value + 0.1, 1.0)
        end
        
        println()
    end
    
    # Clean up widget states
    clear_widget_states!()
end

"""
Performance test comparing the old @context vs new @context_no_frame + @frame approach
"""
function performance_test()
    println("⚡ MicroUI Macro Performance Test")
    println("=" ^ 40)
    
    renderer = SimpleTextRenderer(80, 30)
    
    println("🔥 Testing macro-based widget creation performance...")
    
    # 🎯 APPROACH 1: New optimized approach (@context_no_frame + @frame)
    println("Testing new @context_no_frame + @frame approach...")
    clear_widget_states!()
    
    time_start = time()
    
    # Create context once
    ctx_optimized = create_context()
    
    for frame in 1:100
        @frame ctx_optimized begin
            @window "Performance Test" begin
                # Create many widgets using @foreach
                @foreach i in 1:20 begin
                    @simple_label "label_$i" = "Label $i"
                    @button "button_$i" = "Button $i"
                    @checkbox "checkbox_$i" = (i % 2 == 0)
                    @slider "slider_$i" = (i * 0.05) range(0.0, 1.0)
                end
            end
        end
        
        # Render every 20th frame to avoid too much output
        if frame % 20 == 0
            render_context!(renderer, ctx_optimized)
            println("Optimized frame $frame completed")
        end
    end
    
    time_end = time()
    time_optimized = time_end - time_start
    
    println("📊 Optimized Approach Performance:")
    println("Total time for 100 frames: $(round(time_optimized, digits=3)) seconds")
    println("Average time per frame: $(round(time_optimized / 100 * 1000, digits=2)) ms")
    println("Frames per second: $(round(100 / time_optimized, digits=1)) FPS")
    
    println("="^50)
    
    # 🎯 APPROACH 2: Original @context approach (for comparison)
    println("Testing original @context approach...")
    clear_widget_states!()
    
    time_start = time()
    
    for frame in 1:100
        # Full macro version - creates new context each time
        ctx_original = @context begin
            @window "Performance Test" begin
                # Create many widgets using @foreach
                @foreach i in 1:20 begin
                    @simple_label "label_$i" = "Label $i"
                    @button "button_$i" = "Button $i"
                    @checkbox "checkbox_$i" = (i % 2 == 0)
                    @slider "slider_$i" = (i * 0.05) range(0.0, 1.0)
                end
            end
        end
        
        # Render every 20th frame to avoid too much output
        if frame % 20 == 0
            render_context!(renderer, ctx_original)
            println("Original frame $frame completed")
        end
    end
    
    time_end = time()
    time_original = time_end - time_start
    
    println("📊 Original @context Performance:")
    println("Total time for 100 frames: $(round(time_original, digits=3)) seconds")
    println("Average time per frame: $(round(time_original / 100 * 1000, digits=2)) ms")
    println("Frames per second: $(round(100 / time_original, digits=1)) FPS")
    
    # Performance comparison
    println("🏁 Performance Comparison:")
    if time_optimized < time_original
        speedup = time_original / time_optimized
        println("✅ New approach is $(round(speedup, digits=2))x FASTER!")
        println("   Context reuse saves $(round((time_original - time_optimized) * 1000, digits=1)) ms per 100 frames")
    else
        slowdown = time_optimized / time_original
        println("❌ New approach is $(round(slowdown, digits=2))x slower")
    end
    
    # Final render with optimized context
    render_context!(renderer, ctx_optimized)
    display!(renderer)
    
    # Clean up
    clear_widget_states!()
end

"""
Advanced demo showing complex macro features with the new approach
"""
function advanced_macro_demo()
    println("🚀 Advanced MicroUI Macro Features Demo")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(80, 35)
    
    # 🎯 NEW APPROACH: Create context once for better performance
    ctx = create_context()
    
    # Simulate complex application with multiple windows and state
    for frame in 1:2
        println("📺 Advanced Frame $frame:")
        println("-" ^ 30)
        
        @frame ctx begin
            # Main application window
            @window "Advanced Demo" begin
                @var app_title = "MicroUI Advanced Features"
                @var user_name = "Julia Developer"
                @var session_time = frame * 30  # seconds
                
                @text title_display = app_title
                @simple_label user_display = "User: $user_name"
                @simple_label time_display = "Session: $(session_time)s"
                
                # Feature toggles section
                @panel "Features" begin
                    @var dark_mode = frame > 1
                    @var auto_save = true
                    @var notifications = frame % 2 == 0
                    
                    @checkbox dark_toggle = dark_mode
                    @checkbox autosave_toggle = auto_save  
                    @checkbox notify_toggle = notifications
                    
                    # Reactive styling based on dark mode
                    @when dark_mode begin
                        @simple_label theme_info = "🌙 Dark theme active"
                    end
                    
                    @when !dark_mode begin
                        @simple_label theme_info = "☀️ Light theme active"
                    end
                end
                
                # Data visualization section
                @panel "Metrics" begin
                    @var cpu_usage = 0.2 + (frame * 0.15)
                    @var memory_usage = 0.4 + (frame * 0.1)
                    @var disk_usage = 0.6
                    
                    @slider cpu_slider = cpu_usage range(0.0, 1.0)
                    @slider memory_slider = memory_usage range(0.0, 1.0)
                    @slider disk_slider = disk_usage range(0.0, 1.0)
                    
                    # Reactive status based on values
                    @reactive cpu_percent = round(cpu_usage * 100, digits=1)
                    @reactive memory_percent = round(memory_usage * 100, digits=1)
                    @reactive disk_percent = round(disk_usage * 100, digits=1)
                    
                    @simple_label cpu_display = "CPU: $(cpu_percent)%"
                    @simple_label memory_display = "Memory: $(memory_percent)%"
                    @simple_label disk_display = "Disk: $(disk_percent)%"
                    
                    # Warning conditions
                    @when cpu_usage > 0.8 begin
                        @simple_label cpu_warning = "⚠️ High CPU usage!"
                    end
                    
                    @when memory_usage > 0.7 begin
                        @simple_label memory_warning = "⚠️ High memory usage!"
                    end
                end
                
                # Action buttons
                @row [100, 100, 100] begin
                    @button refresh_btn = "Refresh"
                    @button export_btn = "Export"
                    @button settings_btn = "Settings"
                end
            end
            
            # Settings window (conditional)
            @when frame > 1 begin
                @window "Settings" begin
                    @simple_label settings_title = "⚙️ Application Settings"
                    
                    @panel "Preferences" begin
                        @var update_interval = 5.0
                        @var max_history = 100
                        @var export_format = "JSON"
                        
                        @slider interval_slider = update_interval range(1.0, 60.0)
                        @simple_label interval_display = "Update interval: $(update_interval)s"
                        
                        @checkbox compact_view = false
                        @checkbox show_tooltips = true
                        
                        @simple_label format_display = "Export format: $export_format"
                    end
                    
                    @row [80, 80] begin
                        @button apply_btn = "Apply"
                        @button cancel_btn = "Cancel"
                    end
                end
            end
        end
        
        # ✅ ctx is available here for rendering!
        render_context!(renderer, ctx)
        display!(renderer)
        
        sleep(1.5)
    end
    
    println("\\n✅ Advanced demo completed!")
    clear_widget_states!()
end

# ===== MAIN DEMO RUNNER =====

"""
Main function to run all macro-based demos using the new @context_no_frame + @frame approach
"""
function run_all_macro_demos()
    println("🚀 MicroUI.jl - Optimized Macro Demo Suite")
    println("Using new @context_no_frame + @frame approach")
    println("=" ^ 50)
    
    while true
        println("\\nChoose a demo:")
        println("1. Basic Macro Demo (automated)")
        println("2. Interactive Macro Demo (@context_no_frame + @frame)")
        println("3. Performance Test (compares old vs new approach)")
        println("4. Advanced Macro Features")
        println("5. Exit")
        
        print("\\nEnter choice (1-5): ")
        choice = strip(readline())
        
        try
            if choice == "1"
                demo_application()
            elseif choice == "2"
                interactive_demo()
            elseif choice == "3"
                performance_test()
            elseif choice == "4"
                advanced_macro_demo()
            elseif choice == "5"
                println("👋 Thanks for trying MicroUI Macros!")
                break
            else
                println("❌ Invalid choice. Please enter 1-5.")
            end
        catch e
            println("❌ Error running demo: $e")
            println("Please try again.")
        end
    end
end

# Uncomment to run demos when file is executed
run_all_macro_demos()