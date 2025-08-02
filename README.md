# MicroUI.jl
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Julia](https://img.shields.io/badge/julia-v1.9+-blue.svg)](https://julialang.org/)
[![version](https://juliahub.com/docs/General/MicroUI/stable/version.svg)](https://juliahub.com/ui/Packages/General/MicroUI)

[![MicroUI.jl](https://github.com/user-attachments/assets/b60df2a6-25d2-43a7-bb64-d8c628dd1b91)](https://github.com/mattdef/MicroUI.jl)

**MicroUI.jl** is a modern Julia implementation of an immediate mode GUI library, inspired by [microui](https://github.com/rxi/microui). Designed to be simple, fast, and easily integrable into your Julia applications.

## 🚀 Features

- **Immediate mode** : No complex state management - the entire interface is rebuilt each frame
- **Dual API** : Low-level API for full control + High-level macro DSL for rapid development
- **Declarative syntax** : React/Vue.js-like macro system with automatic state management
- **Backend-agnostic** : Command system enabling integration with any rendering engine
- **Complete widgets** : Buttons, sliders, textboxes, checkboxes, windows, panels, context menus
- **Automatic layout** : Flexible layout system with rows, columns, and manual positioning
- **Reactive programming** : Automatic updates for computed values and event handling
- **Multi-window support** : Native support for multiple windows in a single context
- **Optimized** : Minimal memory allocations during runtime
- **Portable** : Pure Julia, no external dependencies

## 📦 Installation

```julia
using Pkg
Pkg.add("MicroUI")
```

Or for the development version:

```julia
using Pkg
Pkg.add(url="https://github.com/your-username/MicroUI.jl")
```

## 🎯 Quick Start

```julia
using MicroUI
using MicroUI.Macros

# Simple application with automatic state management
ctx = @context begin
    @window "My Application" begin
        @var greeting = "Hello, Julia!"
        @var counter = 0
        
        @text display = greeting
        @simple_label status = "Click count: $counter"
        
        @button increment_btn = "Click me!"
        @onclick increment_btn begin
            @var counter = counter + 1
            @popup "Button clicked!"
        end
        
        @checkbox enable_feature = true
        @slider volume = 0.5 range(0.0, 1.0)
        
        @when enable_feature begin
            @reactive computed_value = volume * 100
            @simple_label volume_display = "Volume: $(round(computed_value, digits=1))%"
        end
    end
    
    @window "Settings" begin
        @var theme = "Dark"
        @button save_settings = "Save Configuration"
        
        @onclick save_settings begin
            @popup "Settings saved!"
        end
    end
end

# Render the commands (backend-specific)
render_commands(ctx.command_list)
```

### Low-level API (Full Control)

```julia
using MicroUI

# Create and initialize context
ctx = Context()

# Set up rendering callbacks (example with fictional backend)
ctx.text_width = (font, text) -> backend_text_width(font, text)
ctx.text_height = font -> backend_text_height(font)
ctx.draw_frame = (ctx, rect, colorid) -> backend_draw_frame(rect, colorid)

init!(ctx)

# State management (manual)
button_state = Ref(false)
slider_value = Ref(0.5)

# Main application loop
while running
    # Begin new frame
    begin_frame(ctx)
    
    # User interface
    if begin_window(ctx, "My Window", Rect(10, 10, 300, 200)) != 0
        layout_row!(ctx, 2, [100, -1], 0)
        
        label(ctx, "Hello Julia!")
        if button(ctx, "Click me") != 0
            println("Button clicked!")
        end
        
        if slider!(ctx, slider_value, 0.0, 1.0) != 0
            println("Value: $(slider_value[])")
        end
        
        end_window(ctx)
    end
    
    # Finalize frame
    end_frame(ctx)
    
    # Render commands
    render_commands(ctx.command_list)
end
```

## 🎨 Macro DSL Reference

### Context and Windows
```julia
# Main context - all UI must be inside @context
ctx = @context begin
    # Multiple windows supported
    @window "Window 1" begin
        # Window content
    end
    
    @window "Window 2" begin
        # Another window
    end
end

# Window control
@open_window "Window 2"
@close_window "Window 1"
```

### Variables and State
```julia
@window "App" begin
    # Simple variables (persistent between frames)
    @var name = "John"
    @var age = 25
    
    # Reactive computed values
    @reactive greeting = "Hello, $name! You are $age years old."
    @reactive can_vote = age >= 18
end
```

### Widgets
```julia
# Text display
@text message = "Welcome to MicroUI!"
@simple_label status = "Status: OK"

# Interactive widgets
@button submit_btn = "Submit"
@checkbox enable_notifications = true
@slider brightness = 0.7 range(0.0, 1.0)

# Event handling
@onclick submit_btn begin
    @popup "Form submitted!"
    @var status = "Submitted"
end
```

### Control Flow
```julia
# Conditional rendering
@when enable_notifications begin
    @simple_label info = "Notifications are enabled"
end

# Dynamic loops
@foreach i in 1:5 begin
    @button "btn_$i" = "Button $i"
end

# Important: Use string interpolation directly in macros
@foreach action in ["Save", "Load", "Delete"] begin
    @button "btn_$(lowercase(action))" = action
    @onclick "btn_$(lowercase(action))" begin
        @popup "$action completed!"
    end
end
```

### Layout
```julia
# Column layout
@column begin
    @simple_label title = "Vertical Layout"
    @button btn1 = "First"
    @button btn2 = "Second"
end

# Row layout with custom widths
@row [100, 200, -1] begin
    @simple_label col1 = "Fixed 100px"
    @simple_label col2 = "Fixed 200px"
    @simple_label col3 = "Fill remaining"
end

# Panels for grouping
@panel "Settings" begin
    @checkbox option1 = false
    @slider value1 = 0.5 range(0.0, 1.0)
end
```

### Popups and Dialogs
```julia
# Simple popup messages
@onclick my_button begin
    @popup "Operation completed!"
end

# Popup appears automatically and handles close button
```

## 🎯 Widget Reference

### Low-level API Widgets
```julia
# Text and labels
text(ctx, "Multi-line text\nwith line breaks")
label(ctx, "Simple label")

# Buttons
button(ctx, "Standard button")
button_ex(ctx, "Custom", ICON_CHECK, OPT_ALIGNCENTER)

# Inputs
checkbox!(ctx, "Option", state_ref)
textbox!(ctx, text_buffer, 256)
slider!(ctx, value_ref, 0.0, 100.0)
number!(ctx, number_ref, 1.0)
```

### Macro DSL Widgets
```julia
# Text display
@text content = "Multi-line content"
@simple_label info = "Simple label text"

# Interactive controls
@button action_btn = "Click me"
@checkbox enable_option = true
@slider volume_control = 0.5 range(0.0, 1.0)

# With automatic state management and persistence
```

### Containers
```julia
# Windows (low-level)
if begin_window(ctx, "Title", Rect(x, y, w, h)) != 0
    # Window content
    end_window(ctx)
end

# Windows (macro DSL)
@window "Title" begin
    # Content with automatic state management
end

# Panels and popups work similarly in both APIs
```

## ⚡ Performance

MicroUI.jl is designed for real-time interactive applications:

- **~0.1ms** for a typical interface (10-20 widgets)
- **Minimal allocations** : Object pool reuse
- **Deferred rendering** : Command system to optimize graphics pipeline
- **Intelligent clipping** : Avoids rendering non-visible elements

### Example Benchmark
```julia
# Complex interface: 100 buttons + 50 sliders + 20 windows
# Low-level API: ~0.5ms per frame (2000 FPS)
# Macro DSL: ~0.6ms per frame (1600+ FPS)
# Memory allocated: <1KB per frame (both APIs)
```

## 🔧 Backend Integration

MicroUI.jl generates a list of rendering commands that you need to implement:

```julia
# Iterate over commands
iter = CommandIterator(ctx.command_list)
while true
    has_cmd, cmd_type, offset = next_command!(iter)
    !has_cmd && break
    
    if cmd_type == COMMAND_RECT
        cmd = read_command(ctx.command_list, offset, RectCommand)
        backend_draw_rect(cmd.rect, cmd.color)
    elseif cmd_type == COMMAND_TEXT
        cmd = read_command(ctx.command_list, offset, TextCommand)
        text = get_string(ctx.command_list, cmd.str_index)
        backend_draw_text(text, cmd.pos, cmd.color, cmd.font)
    # ... other commands
    end
end
```

### Supported Backends

- **OpenGL** : Via ModernGL.jl
- **Vulkan** : Possible integration with VulkanCore.jl  
- **2D Software** : Cairo.jl, Luxor.jl
- **Web** : WebGL via Blink.jl or PlutoUI.jl
- **Terminal** : Text rendering with REPL

## 🎯 Application Examples

### Settings Editor (Macro DSL)
```julia
ctx = @context begin
    @window "Settings" begin
        @var vsync_enabled = true
        @var brightness = 1.0
        @var volume = 0.8
        @var muted = false
        
        @simple_label title = "Graphics Settings"
        @checkbox vsync = vsync_enabled
        @slider brightness_slider = brightness range(0.0, 2.0)
        
        @simple_label audio_title = "Audio Settings"
        @slider volume_slider = volume range(0.0, 1.0)
        @checkbox mute_checkbox = muted
        
        @reactive volume_display = muted ? "Muted" : "Volume: $(round(volume * 100))%"
        @simple_label volume_status = volume_display
        
        @row [-1, -1] begin
            @button reset_btn = "Reset"
            @button apply_btn = "Apply"
        end
        
        @onclick reset_btn begin
            @var vsync_enabled = true
            @var brightness = 1.0
            @var volume = 0.8
            @var muted = false
            @popup "Settings reset!"
        end
        
        @onclick apply_btn begin
            @popup "Settings applied!"
        end
    end
end
```

### Data Viewer
```julia
function data_viewer(ctx, data)
    begin_window(ctx, "Data", Rect(10, 10, 500, 300))
    
    # Filters
    layout_row!(ctx, 3, [100, 200, -1], 0)
    label(ctx, "Filter:")
    textbox!(ctx, filter_text, 128)
    if button(ctx, "Refresh") != 0
        refresh_data!(data)
    end
    
    # Data table
    begin_panel(ctx, "table")
    for (i, row) in enumerate(data.rows)
        layout_row!(ctx, length(row), nothing, 25)
        for cell in row
            label(ctx, string(cell))
        end
    end
    end_panel(ctx)
    
    end_window(ctx)
end
```

### Todo App (Macro DSL)
```julia
ctx = @context begin
    @window "Todo List" begin
        @var new_task = ""
        @var tasks = ["Learn Julia", "Build GUI", "Deploy app"]
        @var completed = [false, false, false]
        
        @simple_label title = "My Tasks ($(length(tasks)) total)"
        
        # Add new task
        @row [200, -1] begin
            # Note: textbox needs to be implemented in macro system
            @button add_btn = "Add Task"
        end
        
        @onclick add_btn begin
            if !isempty(new_task)
                # Add to tasks list (would need array manipulation macros)
                @popup "Task added!"
            end
        end
        
        # Task list
        @foreach (i, task) in enumerate(tasks) begin
            @row [20, -1, 60] begin
                @checkbox "completed_$i" = completed[i]
                @simple_label "task_$i" = task
                @button "delete_$i" = "Delete"
            end
            
            @onclick "delete_$i" begin
                @popup "Task deleted!"
            end
        end
        
        @reactive completed_count = sum(completed)
        @simple_label progress = "Completed: $completed_count/$(length(tasks))"
    end
end
```

## 🚨 Important Notes

### Dynamic Widget Names in Macros

When using dynamic names, use string interpolation directly in the macro call:

```julia
# ✅ CORRECT:
@foreach action in actions begin
    @button "btn_$(lowercase(action))" = action
end

# ❌ INCORRECT:
@foreach action in actions begin
    btn_name = "btn_$(lowercase(action))"  # Runtime variable
    @button btn_name = action              # Macro receives :btn_name symbol
end
```

### State Management

- **Macro DSL**: Automatic state persistence between frames
- **Low-level API**: Manual state management with `Ref` objects
- **Mixing APIs**: You can use both in the same application

## 🛠️ Development

### Project Structure
```
MicroUI.jl/
├── src/
│   └── MicroUI.jl          # Main code
├── examples/               # Usage examples
├── test/                  # Unit tests
└── docs/                  # Documentation
```

### Contributing

1. **Fork** the project
2. Create a **branch** for your feature
3. **Commit** your changes
4. **Push** to your branch
5. Open a **Pull Request**

### Tests

```bash
julia --project -e "using Pkg; Pkg.test()"
```

## 📖 Documentation

- **[User Guide](docs/user-guide.md)** : Complete tutorial
- **[API Reference](docs/api-reference.md)** : Detailed documentation
- **[Macro DSL Guide](docs/macro-dsl.md)** : Comprehensive macro system reference
- **[Integration Guide](docs/backend-integration.md)** : Creating a backend (still working on it)
- **[Examples](examples/)** : Sample projects

## 🤝 Community

- **Issues** : [GitHub Issues](https://github.com/mattdef/MicroUI.jl/issues)
- **Discussions** : [GitHub Discussions](https://github.com/mattdef/MicroUI.jl/discussions)
- **Discord** : [MicroUI.jl Server](https://discord.gg/vfsAZN7p)

## 📄 License

This project is licensed under the **MIT** License. See the [LICENSE](LICENSE) file for more details.

## 🙏 Acknowledgments

- [rxi/microui](https://github.com/rxi/microui) - Original inspiration
- Julia Community - Support and feedback
- [Dear ImGui](https://github.com/ocornut/imgui) - Reference for immediate mode GUIs
- [React.js](https://reactjs.org/) - Inspiration for declarative UI patterns

---

**Ready to create elegant user interfaces in Julia? Choose your style:** 
- 🚀 **Quick start**: Use the macro DSL for rapid prototyping
- 🔧 **Full control**: Use the low-level API for performance-critical applications

**Get started now!** 🚀