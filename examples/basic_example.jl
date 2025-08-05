# Simple Text Renderer for MicroUI
# This provides a basic text-based renderer to demonstrate the complete workflow

include("../src/MicroUI.jl")
using .MicroUI

include("text_renderer.jl")

# ===== DEMO APPLICATION STATE =====

# Simple application state
mutable struct AppState
    counter::Int
    greeting::String
    enable_feature::Bool
    volume::Float32
    user_started::Bool
    
    AppState() = new(0, "Hello, Julia!", true, 0.5f0, false)
end

# ===== DEMO APPLICATIONS =====

"""
Demo application using the direct MicroUI API
"""
function demo_application()
    println("🎮 MicroUI Demo with Text Renderer")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(70, 25)
    ctx = create_context()
    state = AppState()
    
    # Simulate multiple frames
    for frame in 1:3
        println("📺 Frame $frame:")
        println("-" ^ 30)
        
        # Setup input (simulate mouse position)
        input_mousemove!(ctx, 100, 100)
        
        # Begin frame
        begin_frame(ctx)
        
        # Main window
        if begin_window(ctx, "Simple Demo", Rect(50, 50, 400, 200)) != 0

            layout_row!(ctx, 1, [-1], 30)  # 30px de hauteur pour le texte
            if begin_panel(ctx, "greeting_panel") != 0
                text(ctx, state.greeting)
                end_panel(ctx)
            end
            
            # Status label
            label(ctx, "Click count: $(state.counter)")
            
            # Increment button
            if button(ctx, "Click me!") & Int(MicroUI.RES_SUBMIT) != 0
                state.counter += 1
                println("Button clicked! Counter: $(state.counter)")
            end
            
            # Checkbox
            checkbox_ref = Ref(state.enable_feature)
            if checkbox!(ctx, "Enable feature", checkbox_ref) & Int(MicroUI.RES_CHANGE) != 0
                state.enable_feature = checkbox_ref[]
                println("Feature $(state.enable_feature ? "enabled" : "disabled")")
            end
            
            # Slider
            volume_ref = Ref(state.volume)
            if slider!(ctx, volume_ref, 0.0f0, 1.0f0) & Int(MicroUI.RES_CHANGE) != 0
                state.volume = volume_ref[]
                println("Volume changed to: $(round(state.volume * 100, digits=1))%")
            end
            
            # Conditional content
            if state.enable_feature
                computed_value = state.volume * 100
                label(ctx, "Volume: $(round(computed_value, digits=1))%")
            end
            
            end_window(ctx)
        end
        
        # End frame
        end_frame(ctx)
        
        # Render using text renderer
        render_context!(renderer, ctx)
        display!(renderer)
        
        # Small delay for demo effect
        sleep(1.0)
    end
    
    println("✅ Demo completed!")
end

"""
Interactive demo where user can control the UI
"""
function interactive_demo()
    println("🎮 Interactive MicroUI Demo")
    println("Commands: start, stop, toggle, slider <value>, quit")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(70, 30)
    ctx = create_context()
    state = AppState()
    running = true
    
    while running
        # Setup input
        input_mousemove!(ctx, 200, 150)
        
        # Begin frame
        begin_frame(ctx)
        
        # Main window
        if begin_window(ctx, "Interactive Demo", Rect(10, 10, 500, 350)) != 0
            
            label(ctx, "🎮 Interactive MicroUI Demo")
            
            # Status panel
            if begin_panel(ctx, "Status") != 0
                status_text = state.user_started ? "🟢 Running" : "🔴 Stopped"
                label(ctx, "Status: $status_text")
                
                slider_percent = round(Int, state.volume * 100)
                label(ctx, "Value: $(slider_percent)%")
                
                if state.enable_feature
                    label(ctx, "🤖 Auto mode: ON")
                end
                
                end_panel(ctx)
            end
            
            # Controls panel
            if begin_panel(ctx, "Controls") != 0
                
                # Button row
                layout_row!(ctx, 3, [80, 80, 80], 0)
                
                if button(ctx, "Start") & Int(MicroUI.RES_SUBMIT) != 0
                    state.user_started = true
                    println("✅ Started!")
                end
                
                if button(ctx, "Stop") & Int(MicroUI.RES_SUBMIT) != 0
                    state.user_started = false
                    println("⏹️ Stopped!")
                end
                
                if button(ctx, "Quit") & Int(MicroUI.RES_SUBMIT) != 0
                    running = false
                    println("👋 Goodbye!")
                end
                
                # Auto checkbox
                auto_ref = Ref(state.enable_feature)
                if checkbox!(ctx, "Auto mode", auto_ref) & Int(MicroUI.RES_CHANGE) != 0
                    state.enable_feature = auto_ref[]
                    println("🔄 Auto mode: $(state.enable_feature ? "ON" : "OFF")")
                end
                
                # Value slider
                value_ref = Ref(state.volume)
                if slider!(ctx, value_ref, 0.0f0, 1.0f0) & Int(MicroUI.RES_CHANGE) != 0
                    state.volume = value_ref[]
                    println("🎚️ Slider set to $(round(state.volume, digits=2))")
                end
                
                end_panel(ctx)
            end
            
            # Help panel
            if begin_panel(ctx, "Help") != 0
                label(ctx, "Type commands and press Enter:")
                label(ctx, "• start, stop, quit")
                label(ctx, "• toggle (auto mode)")
                label(ctx, "• slider <0.0-1.0>")
                end_panel(ctx)
            end
            
            end_window(ctx)
        end
        
        # End frame
        end_frame(ctx)
        
        # Render
        render_context!(renderer, ctx)
        display!(renderer)
        
        # Get user input
        print("\\n> ")
        input = strip(readline())
        
        # Process commands
        if input == "start"
            state.user_started = true
            println("✅ Started!")
            
        elseif input == "stop"
            state.user_started = false
            println("⏹️ Stopped!")
            
        elseif input == "toggle"
            state.enable_feature = !state.enable_feature
            println("🔄 Auto mode: $(state.enable_feature ? "ON" : "OFF")")
            
        elseif startswith(input, "slider ")
            try
                value = parse(Float64, input[8:end])
                if 0.0 <= value <= 1.0
                    state.volume = Float32(value)
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
            # Just refresh the display
            continue
            
        else
            println("❌ Unknown command: $input")
        end
        
        # Auto-update slider in auto mode
        if state.enable_feature
            state.volume = mod(state.volume + 0.1f0, 1.0f0)
        end
        
        println()
    end
end

"""
Performance test of the MicroUI library
"""
function performance_test()
    println("⚡ MicroUI Performance Test")
    println("=" ^ 40)
    
    renderer = SimpleTextRenderer(80, 30)
    ctx = create_context()
    
    # Test widget creation performance
    println("🔥 Testing widget creation performance...")
    
    time_start = time()
    
    for frame in 1:100
        begin_frame(ctx)
        
        if begin_window(ctx, "Performance Test", Rect(10, 10, 600, 400)) != 0
            
            # Create many widgets
            for i in 1:20
                label(ctx, "Label $i")
        
                button(ctx, "Button $i")
                
                check_ref = Ref(i % 2 == 0)
                checkbox!(ctx, "Checkbox $i", check_ref)
                
                slider_ref = Ref(Float32(i * 0.05))
                slider!(ctx, slider_ref, 0.0f0, 1.0f0)
            end
            
            end_window(ctx)
        end
        
        end_frame(ctx)
        
        # Render every 20th frame to avoid too much output
        if frame % 20 == 0
            render_context!(renderer, ctx)
            println("Frame $frame completed")
        end
    end
    
    time_end = time()
    total_time = time_end - time_start
    
    println("\\n📊 Performance Results:")
    println("Total time for 100 frames: $(round(total_time * 1000, digits=3)) ms")
    println("Average time per frame: $(round(total_time / 100 * 1000, digits=2)) ms")
    println("Frames per second: $(round(100 / total_time, digits=1)) FPS")
    
    # Final render
    render_context!(renderer, ctx)
    display!(renderer)
end

"""
    test_renderer_alignment() -> Nothing

Test function to compare old and new renderer alignment.
This helps verify that the coordinate conversion improvements work correctly.
"""
function test_renderer_alignment()
    println("🔧 Testing Renderer Coordinate Alignment")
    println("=" ^ 50)
    
    # Test with both renderers
    old_renderer = SimpleTextRenderer(70, 25)  # Using your original
    new_renderer = SimpleTextRenderer(70, 25, char_width=8.0, char_height=16.0)  # Using improved version
    
    ctx = create_context()
    
    # Create a simple test UI
    begin_frame(ctx)
    
    if begin_window(ctx, "Test Window", Rect(40, 32, 320, 160)) != 0
        text(ctx, "Alignment Test")
        
        if button(ctx, "Test Button") & Int(MicroUI.RES_SUBMIT) != 0
            println("Button clicked!")
        end
        
        checkbox_ref = Ref(true)
        checkbox!(ctx, "Test Checkbox", checkbox_ref)

        label(ctx, "Test simple Label")
        
        end_window(ctx)
    end
    
    end_frame(ctx)
    
    # Test coordinate conversions
    println("📊 Coordinate Conversion Comparison:")
    println("-" ^ 40)
    
    test_coords = [
        (0, 0, "Origin"),
        (40, 32, "Window top-left"),
        (360, 192, "Window bottom-right"),
        (200, 100, "Center point")
    ]
    
    for (px, py, desc) in test_coords
        # Old method (from your original code)
        old_x = max(1, Int(px ÷ 8))
        old_y = max(1, Int(py ÷ 16))
        
        # New method
        new_x = pixel_to_char_x(new_renderer, px)
        new_y = pixel_to_char_y(new_renderer, py)
        
        println("$desc ($px, $py):")
        println("  Old: ($old_x, $old_y)")
        println("  New: ($new_x, $new_y)")
        println("  Diff: ($(new_x - old_x), $(new_y - old_y))")
        println()
    end
    
    # Render with improved renderer
    println("🎨 Rendering with improved renderer:")
    println("-" ^ 40)
    render_context!(new_renderer, ctx)
    display!(new_renderer)
end

"""
    debug_renderer_info(renderer::SimpleTextRenderer) -> Nothing

Display debugging information about the renderer configuration.
"""
function debug_renderer_info(renderer::SimpleTextRenderer)
    println("🔍 Renderer Debug Info:")
    println("Size: $(renderer.width) × $(renderer.height) characters")
    println("Char size: $(renderer.char_width) × $(renderer.char_height) pixels")
    
    # Calculate the effective pixel coverage
    pixel_width = renderer.width * renderer.char_width
    pixel_height = renderer.height * renderer.char_height
    println("Pixel coverage: $(pixel_width) × $(pixel_height) pixels")
    
    # Test some common UI element sizes
    println("Common element conversions:")
    
    # Button: typically 80×24 pixels
    btn_w = pixel_to_char_w(renderer, 80)
    btn_h = pixel_to_char_h(renderer, 24)
    println("Button (80×24px) → $(btn_w)×$(btn_h) chars")
    
    # Window: typically 320×200 pixels  
    win_w = pixel_to_char_w(renderer, 320)
    win_h = pixel_to_char_h(renderer, 200)
    println("Window (320×200px) → $(win_w)×$(win_h) chars")
    
    # Icon: typically 16×16 pixels
    icon_w = pixel_to_char_w(renderer, 16)
    icon_h = pixel_to_char_h(renderer, 16)
    println("Icon (16×16px) → $(icon_w)×$(icon_h) chars")
end

# ===== MAIN DEMO RUNNER =====

"""
Main function to run all demos
"""
function run_all_demos()
    println("🚀 MicroUI.jl - Complete Demo Suite")
    println("=" ^ 50)
    
    while true
        println("\\nChoose a demo:")
        println("1. Basic Demo (automated)")
        println("2. Interactive Demo") 
        println("3. Performance Test")
        println("4. Renderer Test")
        println("5. Renderer Debug")
        println("6. Exit")
        
        print("\\nEnter choice (1-6): ")
        choice = strip(readline())
        
        try
            if choice == "1"
                demo_application()
            elseif choice == "2"
                interactive_demo()
            elseif choice == "3"
                performance_test()
            elseif choice == "4"
                test_renderer_alignment()
            elseif choice == "5"
                renderer = SimpleTextRenderer(70, 25)
                debug_renderer_info(renderer)
            elseif choice == "6"
                println("👋 Thanks for trying MicroUI!")
                break
            else
                println("❌ Invalid choice. Please enter 1-6.")
            end
        catch e
            println("❌ Error running demo: $e")
            println("Please try again.")
        end
    end
end

# Uncomment to run demos when file is executed
run_all_demos()