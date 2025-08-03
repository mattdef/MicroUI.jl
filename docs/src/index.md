# MicroUI.jl

A Julia implementation of an immediate mode GUI (IMGUI) library, inspired by the MicroUI C library.

## Features

- **Immediate Mode**: No persistent widget state - everything is recreated each frame
- **Backend Independent**: Command-based rendering system that works with any renderer
- **Minimal Allocations**: Optimized for performance with minimal runtime allocations
- **Declarative Macros**: High-level DSL for building UIs quickly
- **Multiple Windows**: Support for complex applications with multiple windows

## Quick Example

### Core API
```julia
using MicroUI

# Create context and set up callbacks
ctx = Context()
init!(ctx)
ctx.text_width = (font, str) -> length(str) * 8
ctx.text_height = font -> 16

# Main UI loop
begin_frame(ctx)

if begin_window(ctx, "My Window", Rect(10, 10, 300, 200)) != 0
    if button(ctx, "Click me!") != 0
        println("Button clicked!")
    end
    
    checkbox_state = Ref(false)
    checkbox!(ctx, "Enable feature", checkbox_state)
    
    slider_value = Ref(50.0f0)
    slider!(ctx, slider_value, 0.0f0, 100.0f0)
    
    end_window(ctx)
end

end_frame(ctx)
```

### Macro DSL
```julia
using MicroUI
using MicroUI.Macros

ctx = @context begin
    @window "My Application" begin
        @text title = "Hello World"
        
        @button save_btn = "Save"
        @onclick save_btn begin
            @popup "File saved!"
        end
        
        @checkbox enable_feature = true
        @slider volume = 0.5 range(0.0, 1.0)
        
        @when enable_feature begin
            @text status = "Feature is enabled"
        end
    end
end
```

## Installation

```julia
# From Julia REPL
using Pkg
Pkg.add("MicroUI")
```