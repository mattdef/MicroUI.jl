# Getting Started

This guide will walk you through creating your first MicroUI application, from basic setup to building interactive interfaces.

## Installation

```julia
using Pkg
Pkg.add("MicroUI")
```

## Understanding Immediate Mode GUIs

MicroUI is an **immediate mode** GUI library, which means:

- **No persistent widgets**: UI elements are created fresh each frame
- **Direct state management**: You control all application state
- **Simple mental model**: UI code runs top-to-bottom, like a regular program
- **Easy integration**: No complex event handling or widget hierarchies

This is different from traditional **retained mode** GUIs where widgets persist between frames.

## Your First MicroUI Application

Let's start with the absolute minimum:

### Core API Approach

```julia
using MicroUI

# Create and initialize context
ctx = Context()
init!(ctx)

# Set up text measurement callbacks (required)
ctx.text_width = (font, str) -> length(str) * 8  # 8 pixels per character
ctx.text_height = font -> 16                     # 16 pixels line height

# Main UI loop (you'd typically put this in a render loop)
begin_frame(ctx)

if begin_window(ctx, "Hello MicroUI", Rect(100, 100, 300, 200)) != 0
    text(ctx, "Welcome to MicroUI!")
    
    if button(ctx, "Click Me!") != 0
        println("Button was clicked!")
    end
    
    end_window(ctx)
end

end_frame(ctx)

# At this point, ctx.command_list contains all rendering commands
# You would pass these to your rendering backend
```

### Macro DSL Approach (Recommended for Beginners)

```julia
using MicroUI
using MicroUI.Macros

ctx = @context begin
    @window "Hello MicroUI" begin
        @text welcome = "Welcome to MicroUI!"
        
        @button click_btn = "Click Me!"
        @onclick click_btn begin
            @popup "Button was clicked!"
        end
    end
end

# ctx now contains all rendering commands
```

The macro approach is much more concise and handles state management automatically!

## Building Interactive Applications

### Example 1: Counter Application

```julia
using MicroUI.Macros

# Application runs in a loop (simplified here)
function run_counter_app()
    ctx = @context begin
        @window "Counter App" begin
            @var counter_value = 0
            
            @text display = "Count: $counter_value"
            
            @row [100, 100, 100] begin
                @button increment_btn = "+"
                @button decrement_btn = "-"  
                @button reset_btn = "Reset"
            end
            
            @onclick increment_btn begin
                counter_value += 1
            end
            
            @onclick decrement_btn begin
                counter_value -= 1
            end
            
            @onclick reset_btn begin
                counter_value = 0
            end
        end
    end
    
    return ctx
end

# In a real application, you'd call this in your render loop
ctx = run_counter_app()
```

### Example 2: Settings Panel

```julia
using MicroUI.Macros

ctx = @context begin
    @window "Application Settings" begin
        @text title = "Settings"
        
        @panel "Audio" begin
            @checkbox enable_sound = true
            @slider volume = 0.8 range(0.0, 1.0)
            
            @when enable_sound begin
                @reactive volume_percent = "Volume: $(round(Int, volume * 100))%"
                @text volume_display = volume_percent
            end
        end
        
        @panel "Graphics" begin
            @checkbox fullscreen = false
            @checkbox vsync = true
            @slider brightness = 1.0 range(0.1, 2.0)
        end
        
        @panel "Controls" begin
            @row [100, 100] begin
                @button save_btn = "Save"
                @button cancel_btn = "Cancel"
            end
            
            @onclick save_btn begin
                @popup "Settings saved!"
            end
        end
    end
end
```

## Understanding State Management

### Automatic State Persistence

With the macro DSL, widget states automatically persist between frames:

```julia
# First frame
@context begin
    @window "Persistent State" begin
        @checkbox remember_me = false  # Initial value
        @slider volume = 0.5 range(0.0, 1.0)
    end
end

# Second frame - values persist!
@context begin  
    @window "Persistent State" begin
        @checkbox remember_me = false  # This initial value is IGNORED
        @slider volume = 0.5 range(0.0, 1.0)  # User's actual value is used
        
        # Access current values
        @reactive status = remember_me ? "Remembered" : "Not remembered"
        @text status_display = status
    end
end
```

### Multiple Windows

You can create multiple windows easily:

```julia
@context begin
    @window "Main Application" begin
        @text title = "My App"
        @button settings_btn = "Open Settings"
    end
    
    @window "Settings" begin
        @text settings_title = "Application Settings"
        @checkbox dark_mode = false
        @button close_btn = "Close"
    end
    
    @window "About" begin
        @text about_text = "MicroUI Application v1.0"
        @button ok_btn = "OK"
    end
end
```

## Common Patterns

### Conditional UI Elements

```julia
@context begin
    @window "Conditional Demo" begin
        @checkbox show_advanced = false
        
        @when show_advanced begin
            @panel "Advanced Options" begin
                @slider precision = 0.01 range(0.001, 1.0)
                @checkbox debug_mode = false
            end
        end
    end
end
```

### Dynamic Lists

```julia
@context begin
    @window "Dynamic List" begin
        @var items = ["Apple", "Banana", "Cherry"]
        
        @foreach (i, item) in enumerate(items) begin
            @row [200, 80] begin
                @text "item_$i" = "$i. $item"
                @button "delete_$i" = "Delete"
            end
            
            @onclick "delete_$i" begin
                # In a real app, you'd modify the items list
                @popup "Would delete: $item"
            end
        end
        
        @button add_btn = "Add Item"
        @onclick add_btn begin
            # In a real app, you'd add to items list
            @popup "Would add new item"
        end
    end
end
```

### Input Forms

```julia
@context begin
    @window "User Registration" begin
        @text title = "Create Account"
        
        @textbox username = "" maxlength(32)
        @textbox email = "" maxlength(100)
        @textbox password = "" maxlength(64)  # Note: real apps need password masking
        
        @checkbox agree_terms = false
        
        @row [100, 100] begin
            @button register_btn = "Register"
            @button cancel_btn = "Cancel"
        end
        
        @onclick register_btn begin
            @when agree_terms begin
                @when (length(username) > 0 && length(email) > 0) begin
                    @popup "Registration successful!"
                end
            end
        end
    end
end
```

## Layout System

MicroUI provides flexible layout options:

### Row Layouts

```julia
@row [100, 200, -1] begin  # Fixed, Fixed, Fill remaining
    @button btn1 = "100px"
    @button btn2 = "200px" 
    @button btn3 = "Remaining space"
end
```

### Column Layouts

```julia
@column begin
    @text header = "Column Header"
    @button item1 = "First Item"
    @button item2 = "Second Item"
    @button item3 = "Third Item"
end
```

### Panels (Grouped Content)

```julia
@panel "Network Settings" begin
    @checkbox enable_wifi = true
    @textbox ssid = "MyNetwork"
    @button connect_btn = "Connect"
end
```

## Error Handling and Debugging

### Debug Widget States

```julia
@context begin
    @window "Debug Example" begin
        @checkbox test_flag = true
        @slider test_value = 0.5 range(0.0, 1.0)
        
        # Debug all widget states for this window
        @debug_types "Debug Example"
    end
end
```

### Common Issues

1. **Widget state not persisting**: Make sure you're using the same variable names between frames
2. **Type errors with sliders**: Use `Real` type or let the macro handle conversion
3. **Events not firing**: Remember that `@onclick` checks for `RES_SUBMIT` flag
4. **Layout issues**: Check your row/column specifications

## Integration with Rendering Backends

MicroUI generates rendering commands that you pass to your graphics backend:

```julia
ctx = @context begin
    # ... your UI code ...
end

# Process rendering commands
iter = CommandIterator(ctx.command_list)
while true
    (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
    if !has_cmd
        break
    end
    
    if cmd_type == MicroUI.COMMAND_RECT
        rect_cmd = read_command(ctx.command_list, cmd_idx, RectCommand)
        # Draw rectangle: rect_cmd.rect, rect_cmd.color
    elseif cmd_type == MicroUI.COMMAND_TEXT
        text_cmd = read_command(ctx.command_list, cmd_idx, TextCommand)
        text_str = get_string(ctx.command_list, text_cmd.str_index)
        # Draw text: text_str at text_cmd.pos with text_cmd.color
    end
    # ... handle other command types
end
```

## Tips for Success

1. **Start simple**: Begin with basic windows and buttons, add complexity gradually
2. **Use the macro DSL**: It's much easier than the core API for most applications
3. **Think in frames**: Remember that your UI code runs every frame
4. **Embrace immediate mode**: Don't try to cache or optimize prematurely
5. **Handle state explicitly**: You control all application state, which gives you power and responsibility

Happy coding with MicroUI! 🚀