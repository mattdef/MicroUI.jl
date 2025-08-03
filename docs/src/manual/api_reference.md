# API Reference

Complete reference for all MicroUI.jl functions and types.

## Core Module

```@autodocs
Modules = [MicroUI]
Order = [:module, :constant, :type, :function, :macro]
Filter = t -> !startswith(string(t), "MicroUI.Macros")
```

## Macro DSL

```@autodocs
Modules = [MicroUI.Macros]
Order = [:module, :constant, :type, :function, :macro]
```

## Usage Examples

### Basic Application

```julia
using MicroUI

# Create context
ctx = Context()
init!(ctx)

# Set up text callbacks
ctx.text_width = (font, str) -> length(str) * 8
ctx.text_height = font -> 16

# Main loop
begin_frame(ctx)

if begin_window(ctx, "My App", Rect(50, 50, 300, 200)) != 0
    text(ctx, "Hello, MicroUI!")
    
    if button(ctx, "Click me!") != 0
        println("Button clicked!")
    end
    
    end_window(ctx)
end

end_frame(ctx)
```

### Using Macro DSL

```julia
using MicroUI
using MicroUI.Macros

ctx = @context begin
    @window "Settings" begin
        @var title = "Application Settings"
        @text header = title
        
        @checkbox auto_save = true
        @slider volume = 0.5 range(0.0, 1.0)
        
        @button save_btn = "Save"
        @onclick save_btn begin
            @popup "Settings saved!"
        end
    end
end
```

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

## Required Callbacks

Before using MicroUI, set these callbacks on your context:

```julia
ctx.text_width = (font, str) -> Int        # Measure text width
ctx.text_height = font -> Int               # Get font height
ctx.draw_frame = (ctx, rect, colorid) -> Nothing # Draw widget frames (optional)
```