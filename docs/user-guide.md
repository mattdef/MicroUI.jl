# MicroUI.jl User Guide

Welcome to MicroUI.jl! 

This comprehensive guide will teach you everything you need to know to create beautiful, responsive user interfaces using immediate mode GUI concepts in Julia.

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Core Concepts](#core-concepts)
4. [Your First Interface](#your-first-interface)
5. [Working with Widgets](#working-with-widgets)
6. [Layout Management](#layout-management)
7. [Event Handling](#event-handling)
8. [Windows and Containers](#windows-and-containers)
9. [Styling and Customization](#styling-and-customization)
10. [Backend Integration](#backend-integration)
11. [Common Patterns](#common-patterns)
12. [Best Practices](#best-practices)
13. [Troubleshooting](#troubleshooting)
14. [Complete Examples](#complete-examples)

---

## Introduction

### What is Immediate Mode GUI?

Traditional GUI frameworks use **retained mode** - you create widgets once, and the framework maintains their state and handles updates. MicroUI.jl uses **immediate mode** - your application code describes the entire interface each frame, similar to how game engines render graphics.

**Benefits of Immediate Mode:**
- **Simplicity**: No complex widget hierarchies to manage
- **Flexibility**: Easy to create dynamic interfaces
- **Debugging**: Interface state is always explicit in your code
- **Integration**: Perfect for data visualization and interactive applications

**Key Principle:**
```julia
# Every frame, your code says "I want a button here"
if button(ctx, "Click me") != 0
    println("Button was clicked!")
end
```

### When to Use MicroUI.jl

MicroUI.jl is perfect for:
- **Scientific applications** with dynamic data visualization
- **Game development** tools and editors
- **Real-time monitoring** dashboards
- **Prototyping** user interfaces quickly
- **Embedded GUIs** in larger applications

Not ideal for:
- Traditional desktop applications with complex menus
- Applications requiring native OS integration
- Interfaces with thousands of widgets

---

## Getting Started

### Installation

```julia
using Pkg
Pkg.add("MicroUI")  # When published
```

### Basic Setup

Every MicroUI.jl application follows this pattern:

```julia
using MicroUI

# 1. Create context
ctx = Context()

# 2. Set up rendering callbacks
ctx.text_width = (font, text) -> your_text_width_function(font, text)
ctx.text_height = font -> your_text_height_function(font)
ctx.draw_frame = (ctx, rect, colorid) -> your_draw_frame_function(rect, colorid)

# 3. Initialize
init!(ctx)

# 4. Main loop
while app_running
    # Handle input events
    handle_input_events(ctx)
    
    # Begin frame
    begin_frame(ctx)
    
    # Define your interface
    create_ui(ctx)
    
    # End frame
    end_frame(ctx)
    
    # Render commands
    render_commands(ctx.command_list)
end
```

### Minimal Working Example

Here's the smallest possible MicroUI.jl application:

```julia
using MicroUI

function minimal_app()
    ctx = Context()
    
    # Dummy rendering functions (for demonstration)
    ctx.text_width = (font, text) -> length(text) * 8
    ctx.text_height = font -> 16
    ctx.draw_frame = (ctx, rect, colorid) -> nothing
    
    init!(ctx)
    
    for frame in 1:100  # Run for 100 frames
        begin_frame(ctx)
        
        if begin_window(ctx, "Hello", Rect(10, 10, 200, 100)) != 0
            label(ctx, "Hello, World!")
            end_window(ctx)
        end
        
        end_frame(ctx)
        
        # Here you would render the commands
        println("Frame $frame generated $(ctx.command_list.idx) bytes of commands")
    end
end

minimal_app()
```

---

## Core Concepts

### The Context

The `Context` is the central object that holds all UI state:

```julia
ctx = Context()

# Required callbacks
ctx.text_width = (font, text) -> measure_text_width(font, text)
ctx.text_height = font -> get_font_height(font)
ctx.draw_frame = (ctx, rect, colorid) -> draw_widget_frame(rect, colorid)

# Optional customization
ctx.style.colors[Int(COLOR_BUTTON)] = Color(100, 150, 200, 255)
```

### IDs and State

MicroUI.jl uses automatic ID generation for widgets:

```julia
# These are different widgets
button(ctx, "Save")    # ID based on "Save"
button(ctx, "Load")    # ID based on "Load"

# Use push_id!/pop_id! for scoping
push_id!(ctx, "toolbar")
    button(ctx, "Save")    # ID: toolbar/Save
    button(ctx, "Load")    # ID: toolbar/Load
pop_id!(ctx)

push_id!(ctx, "menu")
    button(ctx, "Save")    # ID: menu/Save (different from toolbar/Save)
pop_id!(ctx)
```

### The Command System

MicroUI.jl doesn't draw directly - it generates commands:

```julia
# After end_frame(), iterate through commands
iter = CommandIterator(ctx.command_list)
while true
    has_cmd, cmd_type, offset = next_command!(iter)
    !has_cmd && break
    
    if cmd_type == COMMAND_RECT
        cmd = read_command(ctx.command_list, offset, RectCommand)
        # Draw rectangle with your backend
        your_draw_rect(cmd.rect, cmd.color)
    elseif cmd_type == COMMAND_TEXT
        cmd = read_command(ctx.command_list, offset, TextCommand)
        text = get_string(ctx.command_list, cmd.str_index)
        # Draw text with your backend
        your_draw_text(text, cmd.pos, cmd.color, cmd.font)
    # ... handle other command types
    end
end
```

---

## Your First Interface

Let's build a simple calculator interface step by step.

### Step 1: Basic Window

```julia
function calculator_ui(ctx)
    if begin_window(ctx, "Calculator", Rect(100, 100, 250, 300)) != 0
        label(ctx, "0")
        end_window(ctx)
    end
end
```

### Step 2: Add Display

```julia
mutable struct Calculator
    display::String
    accumulator::Float64
    operation::String
    Calculator() = new("0", 0.0, "")
end

function calculator_ui(ctx, calc::Calculator)
    if begin_window(ctx, "Calculator", Rect(100, 100, 250, 300)) != 0
        # Display
        layout_row!(ctx, 1, [-1], 40)
        begin_panel(ctx, "display")
            layout_row!(ctx, 1, [-1], 30)
            label(ctx, calc.display)
        end_panel(ctx)
        
        end_window(ctx)
    end
end
```

### Step 3: Add Number Buttons

```julia
function calculator_ui(ctx, calc::Calculator)
    if begin_window(ctx, "Calculator", Rect(100, 100, 250, 300)) != 0
        # Display
        layout_row!(ctx, 1, [-1], 40)
        begin_panel(ctx, "display")
            layout_row!(ctx, 1, [-1], 30)
            label(ctx, calc.display)
        end_panel(ctx)
        
        # Number pad
        layout_row!(ctx, 3, [-1, -1, -1], 40)
        
        for row in [["7", "8", "9"], ["4", "5", "6"], ["1", "2", "3"]]
            for num in row
                if button(ctx, num) != 0
                    if calc.display == "0"
                        calc.display = num
                    else
                        calc.display *= num
                    end
                end
            end
        end
        
        # Zero button spans two columns
        layout_row!(ctx, 2, [-2, -1], 40)
        if button(ctx, "0") != 0
            if calc.display != "0"
                calc.display *= "0"
            end
        end
        
        if button(ctx, "=") != 0
            # Handle equals
            evaluate_calculator!(calc)
        end
        
        end_window(ctx)
    end
end
```

### Step 4: Complete Calculator

```julia
function evaluate_calculator!(calc::Calculator)
    try
        if calc.operation != ""
            current = parse(Float64, calc.display)
            result = if calc.operation == "+"
                calc.accumulator + current
            elseif calc.operation == "-"
                calc.accumulator - current
            elseif calc.operation == "*"
                calc.accumulator * current
            elseif calc.operation == "/"
                calc.accumulator / current
            else
                current
            end
            calc.display = string(result)
            calc.operation = ""
            calc.accumulator = 0.0
        end
    catch
        calc.display = "Error"
    end
end

function calculator_ui(ctx, calc::Calculator)
    if begin_window(ctx, "Calculator", Rect(100, 100, 250, 350)) != 0
        # Display
        layout_row!(ctx, 1, [-1], 40)
        begin_panel(ctx, "display")
            layout_row!(ctx, 1, [-1], 30)
            label(ctx, calc.display)
        end_panel(ctx)
        
        # Operations
        layout_row!(ctx, 4, [-1, -1, -1, -1], 40)
        if button(ctx, "C") != 0
            calc.display = "0"
            calc.accumulator = 0.0
            calc.operation = ""
        end
        
        for op in ["+", "-", "*", "/"]
            if button(ctx, op) != 0
                calc.accumulator = parse(Float64, calc.display)
                calc.operation = op
                calc.display = "0"
            end
        end
        
        # Number pad
        for row in [["7", "8", "9"], ["4", "5", "6"], ["1", "2", "3"]]
            layout_row!(ctx, 3, [-1, -1, -1], 40)
            for num in row
                if button(ctx, num) != 0
                    if calc.display == "0"
                        calc.display = num
                    else
                        calc.display *= num
                    end
                end
            end
        end
        
        # Bottom row
        layout_row!(ctx, 2, [-2, -1], 40)
        if button(ctx, "0") != 0
            if calc.display != "0"
                calc.display *= "0"
            end
        end
        
        if button(ctx, "=") != 0
            evaluate_calculator!(calc)
        end
        
        end_window(ctx)
    end
end
```

---

## Working with Widgets

### Text Display

```julia
# Simple label
label(ctx, "Username:")

# Multi-line text with automatic wrapping
text(ctx, "This is a long text that will wrap automatically when it reaches the edge of the container.")

# Styled text using options
layout_row!(ctx, 3, [-1, -1, -1], 0)
label(ctx, "Left")           # Default left alignment
# Center aligned button text
button_ex(ctx, "Center", nothing, OPT_ALIGNCENTER)
# Right aligned in the available space would need custom positioning
```

### Buttons

```julia
# Basic button
if button(ctx, "Click Me") != 0
    println("Button clicked!")
end

# Button with icon
if button_ex(ctx, "Save", ICON_CHECK, OPT_ALIGNCENTER) != 0
    save_file()
end

# Styled buttons
if button_ex(ctx, "Danger", nothing, OPT_ALIGNCENTER) != 0
    # Custom styling would be done in your draw_frame callback
    dangerous_action()
end
```

### Input Controls

```julia
# Checkbox
enabled = Ref(true)
if checkbox!(ctx, "Enable feature", enabled) != 0
    println("Feature is now: $(enabled[])")
end

# Text input
username = Ref("Player1")
if textbox!(ctx, username, 32) != 0
    println("Username changed to: $(username[])")
end

# Slider
volume = Ref(0.5)
if slider!(ctx, volume, 0.0, 1.0) != 0
    set_audio_volume(volume[])
end

# Number input with drag
fps_limit = Ref(60.0)
if number!(ctx, fps_limit, 1.0) != 0
    set_fps_limit(fps_limit[])
end
```

### Advanced Input Examples

```julia
# Password field (you'd implement this in your textbox rendering)
password = Ref("")
push_id!(ctx, "password")
if textbox!(ctx, password, 64) != 0
    # Handle password change
end
pop_id!(ctx)

# Slider with custom formatting
brightness = Ref(0.8)
if slider_ex!(ctx, brightness, 0.0, 1.0, 0.01, "%.0f%%", OPT_ALIGNCENTER) != 0
    # Displays as percentage: 80%
    set_brightness(brightness[])
end

# Multi-line text input (requires custom implementation)
notes = Ref("Enter your notes here...")
layout_height!(ctx, 100)
if textbox_ex!(ctx, notes, 1024, UInt16(0)) != 0
    save_notes(notes[])
end
```

---

## Layout Management

### Row Layouts

```julia
# Fixed width columns
layout_row!(ctx, 3, [100, 200, 150], 30)
button(ctx, "100px")
button(ctx, "200px") 
button(ctx, "150px")

# Proportional columns (-1 means "fill remaining space")
layout_row!(ctx, 3, [100, -1, 50], 30)
button(ctx, "Fixed")
button(ctx, "Flexible")  # Takes remaining space
button(ctx, "Fixed")

# Equal width columns
layout_row!(ctx, 4, [-1, -1, -1, -1], 30)
for i in 1:4
    button(ctx, "Button $i")
end

# Mixed layout
layout_row!(ctx, 4, [80, -2, -1, 60], 30)
button(ctx, "Icon")      # 80px
button(ctx, "Title")     # 2/3 of remaining space
button(ctx, "Status")    # 1/3 of remaining space  
button(ctx, "Close")     # 60px
```

### Column Layouts

```julia
layout_row!(ctx, 2, [-1, -1], 0)

# Left column
layout_begin_column!(ctx)
    label(ctx, "Settings")
    checkbox!(ctx, "Option 1", opt1)
    checkbox!(ctx, "Option 2", opt2)
    slider!(ctx, value, 0.0, 100.0)
layout_end_column!(ctx)

# Right column
layout_begin_column!(ctx)
    label(ctx, "Preview")
    # Preview content
    text(ctx, "This is how your settings will look...")
layout_end_column!(ctx)
```

### Manual Positioning

```julia
# Position widget at specific location
layout_set_next!(ctx, Rect(10, 10, 100, 30), false)  # Absolute position
button(ctx, "Positioned")

# Relative positioning
layout_set_next!(ctx, Rect(0, 5, 0, 0), true)  # 5px down from current
button(ctx, "Offset")
```

### Dynamic Layouts

```julia
function dynamic_toolbar(ctx, items)
    # Calculate button width based on available space and number of items
    container_width = 400  # Get this from your container
    button_width = max(60, (container_width - 10) ÷ length(items))
    
    layout_row!(ctx, length(items), fill(-1, length(items)), 30)
    
    for item in items
        if button(ctx, item.name) != 0
            item.action()
        end
    end
end
```

---

## Event Handling

### Input Processing

```julia
function handle_input_events(ctx, window_events)
    for event in window_events
        if event.type == :mouse_move
            input_mousemove!(ctx, event.x, event.y)
        elseif event.type == :mouse_down
            input_mousedown!(ctx, event.x, event.y, 
                           event.button == :left ? MOUSE_LEFT : MOUSE_RIGHT)
        elseif event.type == :mouse_up
            input_mouseup!(ctx, event.x, event.y,
                          event.button == :left ? MOUSE_LEFT : MOUSE_RIGHT)
        elseif event.type == :scroll
            input_scroll!(ctx, event.dx, event.dy)
        elseif event.type == :key_down
            key = map_key(event.key)  # Convert to MicroUI key
            input_keydown!(ctx, key)
        elseif event.type == :key_up
            key = map_key(event.key)
            input_keyup!(ctx, key)
        elseif event.type == :text_input
            input_text!(ctx, event.text)
        end
    end
end

function map_key(system_key)
    if system_key == :shift
        return KEY_SHIFT
    elseif system_key == :ctrl
        return KEY_CTRL
    elseif system_key == :backspace
        return KEY_BACKSPACE
    elseif system_key == :return
        return KEY_RETURN
    else
        return 0  # Unknown key
    end
end
```

### Widget Response Patterns

```julia
# Immediate response
if button(ctx, "Play") != 0
    start_playback()
end

# State-based response
play_button_text = is_playing ? "Pause" : "Play"
if button(ctx, play_button_text) != 0
    if is_playing
        pause_playback()
    else
        start_playback()
    end
    is_playing = !is_playing
end

# Conditional widgets
if show_advanced_options
    if button(ctx, "Hide Advanced") != 0
        show_advanced_options = false
    end
    
    # Advanced controls
    slider!(ctx, advanced_param1, 0.0, 1.0)
    slider!(ctx, advanced_param2, 0.0, 1.0)
else
    if button(ctx, "Show Advanced") != 0
        show_advanced_options = true
    end
end
```

---

## Windows and Containers

### Window Management

```julia
# Basic window
if begin_window(ctx, "My Window", Rect(100, 100, 300, 200)) != 0
    # Window content
    end_window(ctx)
end

# Window with options
window_flags = UInt16(OPT_NORESIZE) | UInt16(OPT_NOCLOSE)
if begin_window_ex(ctx, "Fixed Window", rect, window_flags) != 0
    # Content for non-resizable window
    end_window(ctx)
end

# Conditional windows
show_settings = Ref(false)
if show_settings[]
    if begin_window(ctx, "Settings", Rect(200, 200, 300, 400)) != 0
        if button(ctx, "Close") != 0
            show_settings[] = false
        end
        # Settings content
        end_window(ctx)
    end
end
```

### Panels for Organization

```julia
function create_inspector(ctx, selected_object)
    if begin_window(ctx, "Inspector", Rect(50, 50, 300, 500)) != 0
        
        # Object info panel
        begin_panel(ctx, "info")
            label(ctx, "Object: $(selected_object.name)")
            label(ctx, "Type: $(selected_object.type)")
        end_panel(ctx)
        
        # Transform panel
        if header(ctx, "Transform") != 0
            slider!(ctx, selected_object.position.x, -100.0, 100.0)
            slider!(ctx, selected_object.position.y, -100.0, 100.0)
            slider!(ctx, selected_object.rotation, 0.0, 360.0)
        end
        
        # Material panel
        if header(ctx, "Material") != 0
            slider!(ctx, selected_object.material.color.r, 0.0, 1.0)
            slider!(ctx, selected_object.material.color.g, 0.0, 1.0)
            slider!(ctx, selected_object.material.color.b, 0.0, 1.0)
        end
        
        end_window(ctx)
    end
end
```

### Context Menus and Popups

```julia
# Right-click context menu
if button_ex(ctx, "Right-click me", nothing, UInt16(0)) != 0 && 
   ctx.mouse_down & UInt8(MOUSE_RIGHT) != 0
    open_popup!(ctx, "context_menu")
end

if begin_popup(ctx, "context_menu") != 0
    if button(ctx, "Copy") != 0
        copy_selection()
    end
    if button(ctx, "Paste") != 0
        paste_clipboard()
    end
    if button(ctx, "Delete") != 0
        delete_selection()
    end
    end_popup(ctx)
end

# Modal dialog
if show_dialog[]
    # Semi-transparent overlay (implement in your renderer)
    if begin_window_ex(ctx, "Confirm", Rect(150, 150, 200, 100), UInt16(OPT_POPUP)) != 0
        text(ctx, "Are you sure you want to delete this file?")
        
        layout_row!(ctx, 2, [-1, -1], 0)
        if button(ctx, "Yes") != 0
            delete_file()
            show_dialog[] = false
        end
        if button(ctx, "No") != 0
            show_dialog[] = false
        end
        
        end_window(ctx)
    end
end
```

---

## Styling and Customization

### Color Customization

```julia
function setup_custom_theme!(ctx)
    # Dark theme
    ctx.style.colors[Int(COLOR_TEXT)] = Color(200, 200, 200, 255)
    ctx.style.colors[Int(COLOR_WINDOWBG)] = Color(30, 30, 30, 255)
    ctx.style.colors[Int(COLOR_BUTTON)] = Color(60, 60, 60, 255)
    ctx.style.colors[Int(COLOR_BUTTONHOVER)] = Color(80, 80, 80, 255)
    ctx.style.colors[Int(COLOR_BUTTONFOCUS)] = Color(100, 100, 100, 255)
    
    # Accent colors
    ctx.style.colors[Int(COLOR_TITLEBG)] = Color(0, 120, 200, 255)
    ctx.style.colors[Int(COLOR_TITLETEXT)] = Color(255, 255, 255, 255)
end

function setup_light_theme!(ctx)
    # Light theme
    ctx.style.colors[Int(COLOR_TEXT)] = Color(50, 50, 50, 255)
    ctx.style.colors[Int(COLOR_WINDOWBG)] = Color(240, 240, 240, 255)
    ctx.style.colors[Int(COLOR_BUTTON)] = Color(200, 200, 200, 255)
    ctx.style.colors[Int(COLOR_BUTTONHOVER)] = Color(220, 220, 220, 255)
    ctx.style.colors[Int(COLOR_BUTTONFOCUS)] = Color(180, 180, 180, 255)
end
```

### Custom Drawing

```julia
function custom_draw_frame(ctx, rect, colorid)
    if colorid == COLOR_BUTTON
        # Custom button rendering
        if ctx.hover == ctx.last_id
            # Gradient or special hover effect
            draw_custom_button_hover(rect)
        else
            draw_custom_button_normal(rect)
        end
    else
        # Use default rendering for other elements
        default_draw_frame(ctx, rect, colorid)
    end
end

# Set custom renderer
ctx.draw_frame = custom_draw_frame
```

### Spacing and Sizing

```julia
function setup_compact_style!(ctx)
    ctx.style.padding = 3       # Smaller padding
    ctx.style.spacing = 2       # Tighter spacing
    ctx.style.size = Vec2(60, 8) # Smaller default widget size
end

function setup_spacious_style!(ctx)
    ctx.style.padding = 8
    ctx.style.spacing = 6
    ctx.style.size = Vec2(80, 12)
end
```

---

## Backend Integration

### Basic Backend Structure

```julia
abstract type MicroUIBackend end

struct OpenGLBackend <: MicroUIBackend
    # OpenGL-specific data
    shader_program::UInt32
    vertex_buffer::UInt32
    font_texture::UInt32
end

function setup_backend(backend::OpenGLBackend)
    # Initialize OpenGL resources
    backend.shader_program = create_shader_program()
    backend.vertex_buffer = create_vertex_buffer()
    backend.font_texture = load_font_texture()
end

function render_commands(backend::OpenGLBackend, command_list::CommandList)
    # Set up OpenGL state
    glUseProgram(backend.shader_program)
    glBindBuffer(GL_ARRAY_BUFFER, backend.vertex_buffer)
    
    # Process commands
    iter = CommandIterator(command_list)
    while true
        has_cmd, cmd_type, offset = next_command!(iter)
        !has_cmd && break
        
        if cmd_type == COMMAND_RECT
            cmd = read_command(command_list, offset, RectCommand)
            render_rect(backend, cmd.rect, cmd.color)
        elseif cmd_type == COMMAND_TEXT
            cmd = read_command(command_list, offset, TextCommand)
            text = get_string(command_list, cmd.str_index)
            render_text(backend, text, cmd.pos, cmd.color, cmd.font)
        elseif cmd_type == COMMAND_ICON
            cmd = read_command(command_list, offset, IconCommand)
            render_icon(backend, cmd.id, cmd.rect, cmd.color)
        elseif cmd_type == COMMAND_CLIP
            cmd = read_command(command_list, offset, ClipCommand)
            set_scissor_rect(backend, cmd.rect)
        end
    end
end
```

### Text Measurement

```julia
function setup_text_callbacks(ctx, backend)
    ctx.text_width = (font, text) -> measure_text_width(backend, font, text)
    ctx.text_height = font -> get_font_height(backend, font)
end

function measure_text_width(backend::OpenGLBackend, font, text::String)
    # Use your text rendering library
    return calculate_text_width(font, text)
end

function get_font_height(backend::OpenGLBackend, font)
    return get_font_line_height(font)
end
```

---

## Common Patterns

### Model-View Pattern

```julia
# Model
mutable struct AppState
    current_tab::Int
    settings::Dict{String, Any}
    data::Vector{DataPoint}
    selected_items::Set{Int}
end

# View functions
function render_tab_bar(ctx, state)
    tabs = ["Data", "Settings", "Analysis"]
    layout_row!(ctx, length(tabs), fill(-1, length(tabs)), 30)
    
    for (i, tab) in enumerate(tabs)
        style = i == state.current_tab ? OPT_ALIGNCENTER : UInt16(0)
        if button_ex(ctx, tab, nothing, style) != 0
            state.current_tab = i
        end
    end
end

function render_current_tab(ctx, state)
    if state.current_tab == 1
        render_data_tab(ctx, state)
    elseif state.current_tab == 2
        render_settings_tab(ctx, state)
    elseif state.current_tab == 3
        render_analysis_tab(ctx, state)
    end
end
```

### Reusable Components

```julia
function color_picker(ctx, name::String, color::Ref{Color})
    changed = false
    push_id!(ctx, name)
    
    # Color preview
    layout_row!(ctx, 2, [50, -1], 30)
    
    # Draw color swatch (implement in your renderer)
    layout_set_next!(ctx, Rect(0, 0, 50, 30), true)
    if button_ex(ctx, "", nothing, OPT_NOFRAME) != 0
        # Open color picker dialog
    end
    
    # RGB sliders
    layout_begin_column!(ctx)
        r_val = Ref(Float64(color[].r) / 255.0)
        if slider_ex!(ctx, r_val, 0.0, 1.0, 0.01, "R: %.0f", UInt16(0)) != 0
            color[] = Color(UInt8(r_val[] * 255), color[].g, color[].b, color[].a)
            changed = true
        end
        
        g_val = Ref(Float64(color[].g) / 255.0)
        if slider_ex!(ctx, g_val, 0.0, 1.0, 0.01, "G: %.0f", UInt16(0)) != 0
            color[] = Color(color[].r, UInt8(g_val[] * 255), color[].b, color[].a)
            changed = true
        end
        
        b_val = Ref(Float64(color[].b) / 255.0)
        if slider_ex!(ctx, b_val, 0.0, 1.0, 0.01, "B: %.0f", UInt16(0)) != 0
            color[] = Color(color[].r, color[].g, UInt8(b_val[] * 255), color[].a)
            changed = true
        end
    layout_end_column!(ctx)
    
    pop_id!(ctx)
    return changed
end
```

### Data Tables

```julia
function data_table(ctx, headers::Vector{String}, rows::Vector{Vector{String}})
    if isempty(rows)
        label(ctx, "No data")
        return
    end
    
    # Header
    layout_row!(ctx, length(headers), fill(-1, length(headers)), 25)
    for header in headers
        if button_ex(ctx, header, nothing, OPT_ALIGNCENTER) != 0
            # Handle column sorting
        end
    end
    
    # Data rows
    begin_panel(ctx, "table_data")
        for (i, row) in enumerate(rows)
            push_id!(ctx, "row_$i")
            layout_row!(ctx, length(row), fill(-1, length(row)), 20)
            
            for cell in row
                label(ctx, cell)
            end
            pop_id!(ctx)
        end
    end_panel(ctx)
end
```

---

## Best Practices

### Performance Tips

```julia
# ✅ Good: Minimize string allocations
function efficient_counter(ctx, count::Ref{Int})
    count_str = string(count[])  # Allocate once per frame
    if button(ctx, count_str) != 0
        count[] += 1
    end
end

# ❌ Bad: Allocating strings in widget calls
function inefficient_counter(ctx, count::Ref{Int})
    if button(ctx, "Count: $(count[])") != 0  # String interpolation every call
        count[] += 1
    end
end

# ✅ Good: Cache expensive calculations
function cached_layout(ctx, data)
    if data.layout_dirty
        data.cached_layout = calculate_complex_layout(data)
        data.layout_dirty = false
    end
    
    render_with_layout(ctx, data.cached_layout)
end
```

### State Management

```julia
# ✅ Good: Use Ref for mutable state
settings_enabled = Ref(true)
volume = Ref(0.5)

checkbox!(ctx, "Enable audio", settings_enabled)
if settings_enabled[]
    slider!(ctx, volume, 0.0, 1.0)
end

# ✅ Good: Group related state
mutable struct AudioSettings
    enabled::Bool
    volume::Float64
    device::String
end

function audio_settings_ui(ctx, settings::AudioSettings)
    enabled_ref = Ref(settings.enabled)
    volume_ref = Ref(settings.volume)
    
    if checkbox!(ctx, "Enable audio", enabled_ref) != 0
        settings.enabled = enabled_ref[]
    end
    
    if settings.enabled
        if slider!(ctx, volume_ref, 0.0, 1.0) != 0
            settings.volume = volume_ref[]
        end
    end
end
```

### Error Handling

```julia
function safe_ui_function(ctx, data)
    try
        # UI code that might fail
        create_complex_interface(ctx, data)
    catch e
        # Fallback UI
        label(ctx, "Error loading interface: $(string(e))")
        if button(ctx, "Retry") != 0
            # Trigger reload
            data.needs_reload = true
        end
    end
end
```

---

## Troubleshooting

### Common Issues

**Problem: Widgets not responding to input**
```julia
# Check that input is being processed
function debug_input(ctx)
    label(ctx, "Mouse: ($(ctx.mouse_pos.x), $(ctx.mouse_pos.y))")
    label(ctx, "Buttons: $(ctx.mouse_down)")
    label(ctx, "Hover: $(ctx.hover)")
    label(ctx, "Focus: $(ctx.focus)")
end
```

**Problem: Layout looks wrong**
```julia
# Visualize layout rectangles
function debug_layout(ctx)
    # Draw layout bounds (implement in your renderer)
    layout = get_layout(ctx)
    draw_debug_rect(layout.body, Color(255, 0, 0, 100))  # Red overlay
    draw_debug_rect(layout.next, Color(0, 255, 0, 100))   # Green overlay
end
```

**Problem: Performance issues**
```julia
# Profile command generation
function profile_commands(ctx)
    start_time = time_ns()
    end_frame(ctx)
    end_time = time_ns()
    
    println("Frame time: $((end_time - start_time) / 1e6) ms")
    println("Commands generated: $(ctx.command_list.idx) bytes")
    println("Strings: $(ctx.command_list.string_idx)")
end
```

### Debugging Tools

```julia
function ui_debugger(ctx)
    if begin_window(ctx, "UI Debugger", Rect(10, 10, 300, 400)) != 0
        
        if header(ctx, "Context Info") != 0
            label(ctx, "Frame: $(ctx.frame)")
            label(ctx, "Hover ID: $(ctx.hover)")
            label(ctx, "Focus ID: $(ctx.focus)")
            label(ctx, "Command bytes: $(ctx.command_list.idx)")
        end
        
        if header(ctx, "Input State") != 0
            label(ctx, "Mouse: ($(ctx.mouse_pos.x), $(ctx.mouse_pos.y))")
            label(ctx, "Mouse buttons: $(ctx.mouse_down)")
            label(ctx, "Keys: $(ctx.key_down)")
        end
        
        if header(ctx, "Stack Info") != 0
            label(ctx, "Containers: $(ctx.container_stack.idx)")
            label(ctx, "Clips: $(ctx.clip_stack.idx)")
            label(ctx, "IDs: $(ctx.id_stack.idx)")
            label(ctx, "Layouts: $(ctx.layout_stack.idx)")
        end
        
        end_window(ctx)
    end
end
```

---

## Complete Examples

### Scientific Data Viewer

```julia
mutable struct DataViewer
    data::Matrix{Float64}
    selected_row::Int
    selected_col::Int
    zoom::Float64
    show_statistics::Bool
    
    DataViewer(data) = new(data, 1, 1, 1.0, false)
end

function data_viewer_ui(ctx, viewer::DataViewer)
    # Main window
    if begin_window(ctx, "Data Viewer", Rect(50, 50, 800, 600)) != 0
        
        # Toolbar
        layout_row!(ctx, 4, [100, 100, -1, 100], 30)
        
        if button(ctx, "Load Data") != 0
            # Handle file loading
        end
        
        if button(ctx, "Export") != 0
            # Handle export
        end
        
        # Zoom control
        zoom_ref = Ref(viewer.zoom)
        if slider_ex!(ctx, zoom_ref, 0.1, 5.0, 0.1, "Zoom: %.1fx", UInt16(0)) != 0
            viewer.zoom = zoom_ref[]
        end
        
        stats_ref = Ref(viewer.show_statistics)
        if checkbox!(ctx, "Statistics", stats_ref) != 0
            viewer.show_statistics = stats_ref[]
        end
        
        # Content area
        layout_row!(ctx, 2, [-3, -1], -1)
        
        # Data table
        begin_panel(ctx, "data_table")
            render_data_table(ctx, viewer)
        end_panel(ctx)
        
        # Side panel
        if viewer.show_statistics
            begin_panel(ctx, "statistics")
                render_statistics(ctx, viewer)
            end_panel(ctx)
        end
        
        end_window(ctx)
    end
end

function render_data_table(ctx, viewer::DataViewer)
    rows, cols = size(viewer.data)
    
    # Column headers
    layout_row!(ctx, cols + 1, vcat([50], fill(-1, cols)), 25)
    label(ctx, "Row")
    for col in 1:cols
        if button(ctx, "Col $col") != 0
            viewer.selected_col = col
        end
    end
    
    # Data rows
    for row in 1:rows
        layout_row!(ctx, cols + 1, vcat([50], fill(-1, cols)), 20)
        
        # Row header
        if button(ctx, "$row") != 0
            viewer.selected_row = row
        end
        
        # Data cells
        for col in 1:cols
            value = viewer.data[row, col]
            cell_text = @sprintf("%.3f", value)
            
            # Highlight selected cell
            if row == viewer.selected_row && col == viewer.selected_col
                if button_ex(ctx, cell_text, nothing, OPT_ALIGNRIGHT) != 0
                    # Handle cell selection
                end
            else
                label(ctx, cell_text)
            end
        end
    end
end

function render_statistics(ctx, viewer::DataViewer)
    if viewer.selected_row > 0 && viewer.selected_col > 0
        label(ctx, "Selected Cell:")
        label(ctx, "Row: $(viewer.selected_row)")
        label(ctx, "Col: $(viewer.selected_col)")
        
        value = viewer.data[viewer.selected_row, viewer.selected_col]
        label(ctx, @sprintf("Value: %.6f", value))
    end
    
    if header(ctx, "Column Statistics") != 0 && viewer.selected_col > 0
        col_data = viewer.data[:, viewer.selected_col]
        label(ctx, @sprintf("Mean: %.3f", mean(col_data)))
        label(ctx, @sprintf("Std: %.3f", std(col_data)))
        label(ctx, @sprintf("Min: %.3f", minimum(col_data)))
        label(ctx, @sprintf("Max: %.3f", maximum(col_data)))
    end
end
```

### Game Settings Menu

```julia
mutable struct GameSettings
    graphics::GraphicsSettings
    audio::AudioSettings
    controls::ControlSettings
end

mutable struct GraphicsSettings
    resolution::String
    fullscreen::Bool
    vsync::Bool
    quality::Float64
    brightness::Float64
end

function game_settings_ui(ctx, settings::GameSettings)
    if begin_window(ctx, "Game Settings", Rect(100, 100, 400, 500)) != 0
        
        # Tab system
        persistent_tab = Ref(1)  # This would be stored elsewhere in real app
        tab_names = ["Graphics", "Audio", "Controls"]
        
        layout_row!(ctx, length(tab_names), fill(-1, length(tab_names)), 30)
        for (i, name) in enumerate(tab_names)
            style = i == persistent_tab[] ? UInt16(OPT_ALIGNCENTER) : UInt16(0)
            if button_ex(ctx, name, nothing, style) != 0
                persistent_tab[] = i
            end
        end
        
        # Tab content
        begin_panel(ctx, "tab_content")
            if persistent_tab[] == 1
                graphics_settings_ui(ctx, settings.graphics)
            elseif persistent_tab[] == 2
                audio_settings_ui(ctx, settings.audio)
            elseif persistent_tab[] == 3
                controls_settings_ui(ctx, settings.controls)
            end
        end_panel(ctx)
        
        # Bottom buttons
        layout_row!(ctx, 3, [-1, -1, -1], 35)
        if button(ctx, "Apply") != 0
            apply_settings(settings)
        end
        if button(ctx, "Reset") != 0
            reset_to_defaults(settings)
        end
        if button(ctx, "Close") != 0
            # Close settings
        end
        
        end_window(ctx)
    end
end

function graphics_settings_ui(ctx, graphics::GraphicsSettings)
    # Resolution dropdown (simplified)
    layout_row!(ctx, 2, [100, -1], 25)
    label(ctx, "Resolution:")
    if button(ctx, graphics.resolution) != 0
        # Open resolution picker
    end
    
    # Checkboxes
    fullscreen_ref = Ref(graphics.fullscreen)
    if checkbox!(ctx, "Fullscreen", fullscreen_ref) != 0
        graphics.fullscreen = fullscreen_ref[]
    end
    
    vsync_ref = Ref(graphics.vsync)
    if checkbox!(ctx, "V-Sync", vsync_ref) != 0
        graphics.vsync = vsync_ref[]
    end
    
    # Quality slider
    layout_row!(ctx, 2, [100, -1], 25)
    label(ctx, "Quality:")
    quality_ref = Ref(graphics.quality)
    if slider_ex!(ctx, quality_ref, 0.0, 1.0, 0.1, "%.0f%%", UInt16(0)) != 0
        graphics.quality = quality_ref[]
    end
    
    # Brightness
    label(ctx, "Brightness:")
    brightness_ref = Ref(graphics.brightness)
    if slider!(ctx, brightness_ref, 0.1, 2.0) != 0
        graphics.brightness = brightness_ref[]
    end
end
```

This comprehensive user guide covers all aspects of MicroUI.jl from basic concepts to advanced usage patterns. It provides practical examples and real-world scenarios that will help developers get up to speed quickly and build effective immediate mode interfaces.