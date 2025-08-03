# Simple Text Renderer for MicroUI
# This provides a basic text-based renderer to demonstrate the complete workflow

include("../src/MicroUI.jl")
using .MicroUI

# ===== SIMPLE TEXT RENDERER =====

"""
Simple text-based renderer for testing and demonstration.
Renders the UI as ASCII art to the console.
"""
mutable struct SimpleTextRenderer
    width::Int
    height::Int
    buffer::Matrix{Char}
    
    SimpleTextRenderer(w=80, h=25) = new(w, h, fill(' ', h, w))
end

"""Clear the renderer buffer"""
function clear!(renderer::SimpleTextRenderer)
    fill!(renderer.buffer, ' ')
end

"""Set a character at specific position"""
function set_char!(renderer::SimpleTextRenderer, x::Int, y::Int, c::Char)
    if 1 <= x <= renderer.width && 1 <= y <= renderer.height
        renderer.buffer[y, x] = c
    end
end

"""Draw a string starting at position"""
function draw_string!(renderer::SimpleTextRenderer, x::Int, y::Int, text::String)
    # Convert to ASCII-safe string to avoid UTF-8 indexing issues
    for (i, c) in enumerate(text)
        if x + i - 1 <= renderer.width
            set_char!(renderer, x + i - 1, y, c)
        end
    end
end

"""Draw a filled rectangle"""
function draw_rect!(renderer::SimpleTextRenderer, x::Int, y::Int, w::Int, h::Int, char::Char='█')
    for dy in 0:h-1
        for dx in 0:w-1
            if x + dx <= renderer.width && y + dy <= renderer.height
                set_char!(renderer, x + dx, y + dy, char)
            end
        end
    end
end

"""Draw a rectangle border"""
function draw_border!(renderer::SimpleTextRenderer, x::Int, y::Int, w::Int, h::Int)
    # Corners
    set_char!(renderer, x, y, '┌')
    set_char!(renderer, x + w - 1, y, '┐')
    set_char!(renderer, x, y + h - 1, '└')
    set_char!(renderer, x + w - 1, y + h - 1, '┘')
    
    # Horizontal lines
    for dx in 1:w-2
        set_char!(renderer, x + dx, y, '─')
        set_char!(renderer, x + dx, y + h - 1, '─')
    end
    
    # Vertical lines  
    for dy in 1:h-2
        set_char!(renderer, x, y + dy, '│')
        set_char!(renderer, x + w - 1, y + dy, '│')
    end
end

"""Render the buffer to console"""
function display!(renderer::SimpleTextRenderer)
    for y in 1:renderer.height
        for x in 1:renderer.width
            print(renderer.buffer[y, x])
        end
        println()
    end
end

# ===== MICROUI COMMAND PROCESSOR =====

"""
Process MicroUI commands and render them using the text renderer
"""
function render_context!(renderer::SimpleTextRenderer, ctx::Context)
    clear!(renderer)
    
    # Create command iterator
    iter = CommandIterator(ctx.command_list)
    
    current_clip = Rect(1, 1, Int32(renderer.width), Int32(renderer.height))
    
    while true
        has_command, cmd_type, offset = next_command!(iter)
        
        if !has_command
            break
        end
        
        if cmd_type == MicroUI.COMMAND_CLIP
            cmd = read_command(ctx.command_list, offset, ClipCommand)
            # Update clipping (simplified - just store for bounds checking)
            current_clip = cmd.rect
            
        elseif cmd_type == MicroUI.COMMAND_RECT
            cmd = read_command(ctx.command_list, offset, RectCommand)
            # Convert to renderer coordinates and draw
            char = cmd.color.r > 128 ? '█' : '░'  # Simple color mapping
            draw_rect!(renderer, 
                      max(1, Int(cmd.rect.x ÷ 8)), 
                      max(1, Int(cmd.rect.y ÷ 16)), 
                      max(1, Int(cmd.rect.w ÷ 8)), 
                      max(1, Int(cmd.rect.h ÷ 16)), 
                      char)
            
        elseif cmd_type == MicroUI.COMMAND_TEXT
            cmd = read_command(ctx.command_list, offset, TextCommand)
            text = get_string(ctx.command_list, cmd.str_index)
            # Draw text at position
            draw_string!(renderer,
                        max(1, Int(cmd.pos.x ÷ 8)), 
                        max(1, Int(cmd.pos.y ÷ 16)), 
                        text)
            
        elseif cmd_type == MicroUI.COMMAND_ICON
            cmd = read_command(ctx.command_list, offset, IconCommand)
            # Draw simple icon representation
            icon_char = if cmd.id == MicroUI.ICON_CLOSE
                '✕'
            elseif cmd.id == MicroUI.ICON_CHECK
                '✓'
            elseif cmd.id == MicroUI.ICON_COLLAPSED
                '▶'
            elseif cmd.id == MicroUI.ICON_EXPANDED
                '▼'
            else
                '?'
            end
            
            set_char!(renderer, 
                     max(1, Int(cmd.rect.x ÷ 8)), 
                     max(1, Int(cmd.rect.y ÷ 16)), 
                     icon_char)
        end
    end
end

# ===== DEMO APPLICATION STATE =====

# Simple application state
mutable struct AppState
    counter::Int
    greeting::String
    enable_feature::Bool
    volume::Float32
    user_started::Bool
    
    AppState() = new(0, "Hello, Julia!", false, 0.5f0, false)
end

# ===== DEMO APPLICATIONS =====

"""
Demo application using the direct MicroUI API
"""
function demo_application()
    println("🎮 MicroUI Demo with Text Renderer")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(70, 25)
    ctx = setup_context()
    state = AppState()
    
    # Simulate multiple frames
    for frame in 1:3
        println("\\n📺 Frame $frame:")
        println("-" ^ 30)
        
        # Setup input (simulate mouse position)
        input_mousemove!(ctx, 100, 100)
        
        # Begin frame
        begin_frame(ctx)
        
        # Main window
        if begin_window(ctx, "Simple Demo", Rect(50, 50, 400, 200)) != 0
            
            # Display greeting
            text(ctx, state.greeting)
            
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
    
    println("\\n✅ Demo completed!")
end

"""
Interactive demo where user can control the UI
"""
function interactive_demo()
    println("🎮 Interactive MicroUI Demo")
    println("Commands: start, stop, toggle, slider <value>, quit")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(70, 30)
    ctx = setup_context()
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
    ctx = setup_context()
    
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
        println("4. Exit")
        
        print("\\nEnter choice (1-4): ")
        choice = strip(readline())
        
        try
            if choice == "1"
                demo_application()
            elseif choice == "2"
                interactive_demo()
            elseif choice == "3"
                performance_test()
            elseif choice == "4"
                println("👋 Thanks for trying MicroUI!")
                break
            else
                println("❌ Invalid choice. Please enter 1-4.")
            end
        catch e
            println("❌ Error running demo: $e")
            println("Please try again.")
        end
    end
end

# Uncomment to run demos when file is executed
run_all_demos()