# Simple Text Renderer for MicroUI Macro System
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
    for (i, c) in enumerate(text)
        set_char!(renderer, x + i - 1, y, c)
    end
end

"""Draw a filled rectangle"""
function draw_rect!(renderer::SimpleTextRenderer, x::Int, y::Int, w::Int, h::Int, char::Char='█')
    for dy in 0:h-1
        for dx in 0:w-1
            set_char!(renderer, x + dx, y + dy, char)
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
    
    current_clip = Rect(1, 1, renderer.width, renderer.height)
    
    while true
        has_command, cmd_type, offset = next_command!(iter)
        
        if !has_command
            break
        end
        
        if cmd_type == COMMAND_CLIP
            cmd = read_command(ctx.command_list, offset, ClipCommand)
            # Update clipping (simplified - just store for bounds checking)
            current_clip = cmd.rect
            
        elseif cmd_type == COMMAND_RECT
            cmd = read_command(ctx.command_list, offset, RectCommand)
            # Convert to renderer coordinates and draw
            char = cmd.color.r > 128 ? '█' : '░'  # Simple color mapping
            draw_rect!(renderer, 
                      max(1, Int(cmd.rect.x ÷ 8)), 
                      max(1, Int(cmd.rect.y ÷ 16)), 
                      max(1, Int(cmd.rect.w ÷ 8)), 
                      max(1, Int(cmd.rect.h ÷ 16)), 
                      char)
            
        elseif cmd_type == COMMAND_TEXT
            cmd = read_command(ctx.command_list, offset, TextCommand)
            text = get_string(ctx.command_list, cmd.str_index)
            # Draw text at position
            draw_string!(renderer,
                        max(1, Int(cmd.pos.x ÷ 8)), 
                        max(1, Int(cmd.pos.y ÷ 16)), 
                        text)
            
        elseif cmd_type == COMMAND_ICON
            cmd = read_command(ctx.command_list, offset, IconCommand)
            # Draw simple icon representation
            icon_char = if cmd.id == ICON_CLOSE
                '✕'
            elseif cmd.id == ICON_CHECK
                '✓'
            elseif cmd.id == ICON_COLLAPSED
                '▶'
            elseif cmd.id == ICON_EXPANDED
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

# ===== DEMO APPLICATION =====

"""
Demo application using the macro system with text renderer
"""
function demo_application()
    println("🎮 MicroUI Macro Demo with Text Renderer")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(60, 20)
    
    # Simulate multiple frames
    for frame in 1:5
        println("\\n📺 Frame $frame:")
        println("-" ^ 30)
        
        # Generate UI using macros
        ctx = @window DemoApp begin
            @text title = "Demo App - Frame $frame"
            
            @panel "Controls" begin
                @row [15, 15] begin
                    @button start_btn = "Start"
                    @button stop_btn = "Stop"
                end
                
                @checkbox auto_mode = (frame % 2 == 0)
                @slider progress = (frame * 0.2) range(0.0, 1.0)
                
                @reactive progress_percent = round(Int, progress * 100)
                @text "Progress: $(progress_percent)%"
                
                @when auto_mode begin
                    @text "🤖 Auto mode enabled"
                end
            end
            
            @onclick start_btn begin
                state.variables[:status] = "Running..."
            end
            
            @onclick stop_btn begin
                state.variables[:status] = "Stopped"
            end
        end
        
        # Render using text renderer
        render_context!(renderer, ctx)
        display!(renderer)
        
        # Small delay for demo effect
        sleep(0.5)
    end
    
    println("\\n✅ Demo completed!")
end

# ===== INTERACTIVE DEMO =====

"""
Interactive demo where user can control the UI
"""
function interactive_demo()
    println("🎮 Interactive MicroUI Demo")
    println("Commands: start, stop, toggle, slider <value>, quit")
    println("=" ^ 50)
    
    renderer = SimpleTextRenderer(70, 25)
    running = true
    user_started = false
    auto_enabled = false
    slider_value = 0.5
    
    while running
        # Generate UI based on current state
        ctx = @window InteractiveDemo begin
            @text title = "🎮 Interactive MicroUI Demo"
            
            @panel "Status" begin
                status = user_started ? "🟢 Running" : "🔴 Stopped"
                @text "Status: $status"
                
                @reactive slider_percent = round(Int, slider_value * 100)
                @text "Value: $(slider_percent)%"
                
                @when auto_enabled begin
                    @text "🤖 Auto mode: ON"
                end
            end
            
            @panel "Controls" begin
                @row [12, 12, 12] begin
                    @button start_btn = "Start"
                    @button stop_btn = "Stop"  
                    @button quit_btn = "Quit"
                end
                
                @checkbox auto_check = auto_enabled
                @slider value_slider = slider_value range(0.0, 1.0)
            end
            
            @panel "Help" begin
                @text "Type commands and press Enter:"
                @text "• start, stop, quit"
                @text "• toggle (auto mode)"
                @text "• slider <0.0-1.0>"
            end
        end
        
        # Render
        clear!(renderer)
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
            auto_enabled = !auto_enabled
            println("🔄 Auto mode: $(auto_enabled ? "ON" : "OFF")")
            
        elseif startswith(input, "slider ")
            try
                value = parse(Float64, input[8:end])
                if 0.0 <= value <= 1.0
                    slider_value = value
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
        if auto_enabled
            slider_value = (slider_value + 0.1) % 1.0
        end
        
        println()
    end
end

# ===== BENCHMARK DEMO =====

"""
Benchmark the macro system performance
"""
function benchmark_demo()
    println("⚡ MicroUI Macro Performance Benchmark")
    println("=" ^ 40)
    
    using BenchmarkTools
    
    # Clear state
    clear_widget_states!()
    
    # Benchmark simple window
    println("🔥 Benchmarking simple window...")
    simple_time = @benchmark begin
        ctx = @window BenchmarkSimple begin
            @text hello = "Hello, World!"
            @button ok = "OK"
        end
    end
    
    println("Simple window: $(mean(simple_time.times) / 1e6) ms")
    
    # Benchmark complex window
    println("\\n🔥 Benchmarking complex window...")
    complex_time = @benchmark begin
        ctx = @window BenchmarkComplex begin
            @foreach i in 1:10 begin
                @row [100, 100] begin
                    @text "label_$i" = "Item $i"
                    @button "btn_$i" = "Button $i"
                end
                @checkbox "check_$i" = (i % 2 == 0)
                @slider "slider_$i" = (i * 0.1) range(0.0, 1.0)
            end
        end
    end
    
    println("Complex window (40 widgets): $(mean(complex_time.times) / 1e6) ms")
    
    # Memory allocation test
    println("\\n📊 Memory allocation test...")
    allocs = @allocated begin
        for _ in 1:100
            ctx = @window MemoryTest begin
                @text message = "Memory test"
                @button btn = "Test"
                @checkbox flag = false
            end
        end
    end
    
    println("Memory allocated for 100 iterations: $(allocs) bytes")
    println("Average per iteration: $(allocs ÷ 100) bytes")
    
    clear_widget_states!()
end

# ===== MAIN DEMO RUNNER =====

"""
Main function to run all demos
"""
function run_all_demos()
    println("🚀 MicroUI Macro System - Complete Demo Suite")
    println("=" ^ 50)
    
    while true
        println("\\nChoose a demo:")
        println("1. Basic Demo (automated)")
        println("2. Interactive Demo") 
        println("3. Performance Benchmark")
        println("4. Exit")
        
        print("\\nEnter choice (1-4): ")
        choice = strip(readline())
        
        if choice == "1"
            demo_application()
        elseif choice == "2"
            interactive_demo()
        elseif choice == "3"
            benchmark_demo()
        elseif choice == "4"
            println("👋 Thanks for trying MicroUI macros!")
            break
        else
            println("❌ Invalid choice. Please enter 1-4.")
        end
    end
end

# Uncomment to run demos
# run_all_demos()