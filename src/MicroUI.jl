"""
    MicroUI

A Julia implementation of an immediate mode GUI (IMGUI) library.

MicroUI provides a complete immediate mode GUI implementation in Julia,
inspired by the microui C library. Immediate mode GUIs rebuild the entire interface
each frame, making them simpler to reason about and integrate into applications.

# Key Concepts

- **No persistent widget state**: Everything is recreated each frame
- **Direct integration**: Works with any rendering backend
- **Minimal allocations**: Optimized for performance during runtime
- **Command-based rendering**: Backend-independent rendering system

# Basic Usage

```julia
using MicroUI

# Create and initialize context
ctx = Context()
init!(ctx)

# Set up rendering callbacks
ctx.text_width = (font, str) -> length(str) * 8
ctx.text_height = font -> 16

# Main UI loop
begin_frame(ctx)

if begin_window(ctx, "My Window", Rect(10, 10, 300, 200)) != 0
    if button(ctx, "Click me!") != 0
        println("Button clicked!")
    end
    end_window(ctx)
end

end_frame(ctx)

# Process rendering commands
iter = CommandIterator(ctx.command_list)
while true
    (has_cmd, cmd_type, cmd_idx) = next_command!(iter)
    if !has_cmd
        break
    end
    # Handle rendering commands based on cmd_type
end
```

# Core API

The core API provides low-level control over UI creation:

- [`Context`](@ref): Main UI context and state
- [`begin_frame`](@ref)/[`end_frame`](@ref): Frame lifecycle management
- [`begin_window`](@ref)/[`end_window`](@ref): Window creation
- [`button`](@ref), [`checkbox!`](@ref), [`slider!`](@ref): Interactive widgets
- [`layout_row!`](@ref), [`layout_begin_column!`](@ref): Layout management

# Macro DSL

For easier UI development, use the high-level macro DSL:

```julia
using MicroUI.Macros

ctx = @context begin
    @window "My App" begin
        @button save_btn = "Save"
        @onclick save_btn begin
            @popup "File saved!"
        end
    end
end
```

See [`MicroUI.Macros`](@ref) for the complete macro API.

# Modules

- [`MicroUI.Macros`](@ref): High-level declarative macro system

# See Also

- [Getting Started Guide](getting_started.md)
- [Core Concepts](concepts.md)
- [API Reference](api.md)
- [Examples](examples.md)
"""
module MicroUI

include("constantes.jl")
include("enumerations.jl")
include("custom_types.jl")
include("structures.jl")
include("utils_functions.jl")
include("commands_functions.jl")
include("frame_functions.jl")
include("id_management_functions.jl")
include("input_functions.jl")
include("drawing_functions.jl")
include("layout_functions.jl")
include("clipping_functions.jl")
include("container_functions.jl")
include("controls_functions.jl")
include("window_functions.jl")
include("export.jl")

"""
    MicroUI.Macros

High-level declarative macro system for MicroUI.

The Macros module provides a user-friendly DSL (Domain Specific Language) for building
UIs with MicroUI. Instead of manually managing contexts, frames, and widget states,
the macro system handles this automatically while providing a clean, declarative syntax.

# Key Features

- **Automatic state management**: Widget states persist between frames automatically
- **Declarative syntax**: Write UI code that reads like a description of the interface
- **Event handling**: Simple `@onclick` syntax for handling user interactions
- **Reactive programming**: Use `@reactive` for computed values that update automatically
- **Multiple windows**: Easy creation and management of multiple application windows
- **Layout helpers**: Simplified row/column/panel layouts

# Basic Usage

```julia
using MicroUI          # Core API
using MicroUI.Macros   # Macro DSL

ctx = @context begin
    @window "My Application" begin
        @text title = "Hello World"
        
        @button save_btn = "Save File"
        @onclick save_btn begin
            @popup "File saved successfully!"
        end
        
        @checkbox enable_feature = true
        @slider volume = 0.8 range(0.0, 1.0)
        
        @when enable_feature begin
            @text status = "Feature is enabled"
        end
    end
end
```

# Core Macros

- [`@context`](@ref): Create and manage UI context with automatic frame lifecycle
- [`@window`](@ref): Create windows with automatic state management
- [`@var`](@ref): Define variables that persist between frames
- [`@reactive`](@ref): Create computed values that update automatically

# Widget Macros

- [`@text`](@ref): Display text content
- [`@button`](@ref): Create clickable buttons
- [`@checkbox`](@ref): Create checkboxes for boolean values
- [`@slider`](@ref): Create sliders for numeric input
- [`@textbox`](@ref): Create text input fields
- [`@number`](@ref): Create numeric input widgets

# Layout Macros

- [`@row`](@ref): Arrange widgets horizontally
- [`@column`](@ref): Arrange widgets vertically  
- [`@panel`](@ref): Group widgets in labeled panels

# Control Flow Macros

- [`@when`](@ref): Conditional UI rendering
- [`@foreach`](@ref): Loop over collections to create dynamic UI elements

# Event Handling

- [`@onclick`](@ref): Handle button clicks and widget activation
- [`@popup`](@ref): Show popup messages

# State Management

The macro system automatically manages widget states using [`WidgetState`](@ref) containers.
Each window gets its own state that persists between frames, allowing for stateful
widgets like checkboxes and sliders to maintain their values.

# Advanced Example

```julia
ctx = @context begin
    @window "Settings Panel" begin
        @var app_name = "My Application"
        @text title = "Settings for: \$app_name"
        
        @panel "Audio Settings" begin
            @checkbox enable_sound = true
            @slider master_volume = 0.7 range(0.0, 1.0)
            
            @when enable_sound begin
                @reactive volume_text = "Volume: \$(round(Int, master_volume * 100))%"
                @text volume_display = volume_text
            end
        end
        
        @panel "Video Settings" begin
            @checkbox fullscreen = false
            @checkbox vsync = true
            @slider brightness = 1.0 range(0.1, 2.0)
        end
        
        @row [100, 100] begin
            @button apply_btn = "Apply"
            @button cancel_btn = "Cancel"
        end
        
        @onclick apply_btn begin
            @popup "Settings applied successfully!"
        end
    end
    
    # Multiple windows in one context
    @window "About" begin
        @text about_title = "About \$app_name"
        @text version_info = "Version 1.0.0"
        @button close_btn = "Close"
    end
end
```

# Type Safety

The macro system handles type conversions automatically:

- Float values are converted to `Real` (Float32) for sliders and numbers
- Boolean values are properly handled for checkboxes
- String interpolation works in widget labels and text

# Performance

The macro system is designed for performance:

- State lookups use efficient `Dict` operations
- Widget creation has minimal overhead
- Automatic type conversions are optimized
- Memory allocations are minimized during UI updates

# Integration with Core API

Macros generate core API calls internally, so you can mix macro and core API usage:

```julia
ctx = @context begin
    @window "Mixed API" begin
        @text title = "Macro-created title"
        
        # Drop down to core API when needed
        if button(ctx, "Core API Button") != 0
            println("Core API button clicked")
        end
    end
end
```

# See Also

- [Macro DSL Reference](macros.md)
- [Getting Started Guide](getting_started.md)
- [Core API Reference](api.md)
"""
module Macros

    # Import all core functionality from parent module
    using ..MicroUI
    
    # Import specific symbols that macros need to generate code
    import ..MicroUI: Context, begin_frame, end_frame, init!, begin_window, end_window
    import ..MicroUI: text, label, button, button_ex, checkbox!, slider!
    import ..MicroUI: RES_SUBMIT, RES_CHANGE, RES_ACTIVE
    import ..MicroUI: open_popup!, begin_popup, end_popup
    import ..MicroUI: layout_row!, layout_begin_column!, layout_end_column!
    import ..MicroUI: begin_panel, end_panel

    """
        WidgetState

    Container for widget state that persists between frames in the macro system.

    Each window created with [`@window`](@ref) gets its own `WidgetState` instance
    that stores widget values, references for stateful widgets, event handlers,
    and window visibility state. This allows widgets to maintain their state
    between UI frames without manual state management.

    # Fields

    - `variables::Dict{Symbol, Any}`: Regular variables and computed values
    - `refs::Dict{Symbol, Ref}`: References for stateful widgets (checkboxes, sliders, etc.)
    - `event_handlers::Dict{Symbol, Function}`: Event handler functions (currently unused)
    - `window_open::Bool`: Whether the window is currently open and visible

    # Usage

    You typically don't create `WidgetState` instances directly. They are automatically
    created and managed by the macro system:

    ```julia
    # This automatically creates a WidgetState for the window
    @context begin
        @window "My Window" begin
            @checkbox enable_feature = true  # Stored in refs
            @var app_name = "MyApp"          # Stored in variables
        end
    end
    ```

    # Accessing State

    Use [`get_widget_state`](@ref) to access the state for debugging or advanced usage:

    ```julia
    # Get state for a specific window
    window_id = Symbol("window_", hash("My Window"))
    state = get_widget_state(window_id)

    # Inspect current values
    println("Checkbox value: ", state.refs[:enable_feature][])
    println("App name: ", state.variables[:app_name])
    ```

    # State Persistence

    Widget states automatically persist between frames:

    ```julia
    # First frame - checkbox starts as false
    @context begin
        @window "Persistent Example" begin
            @checkbox flag = false
        end
    end

    # User clicks checkbox, flag becomes true

    # Second frame - checkbox retains true value
    @context begin
        @window "Persistent Example" begin
            @checkbox flag = false  # Initial value ignored, true value retained
        end
    end
    ```

    # Types of Stored Values

    ## Variables (`variables` field)
    - Simple values: strings, numbers, booleans
    - Computed/reactive values from [`@reactive`](@ref)
    - Widget results and interaction flags

    ## References (`refs` field)  
    - Checkbox states: `Ref{Bool}`
    - Slider values: `Ref{Real}`
    - Text input contents: `Ref{String}`
    - Any widget that needs mutable state

    # Memory Management

    Widget states are stored in a global dictionary and persist for the lifetime
    of the application. Use [`clear_widget_states!`](@ref) to clear all states
    if needed:

    ```julia
    # Clear all widget states (useful for testing)
    clear_widget_states!()
    ```

    # Thread Safety

    The current implementation is not thread-safe. Widget states should only
    be accessed from the main UI thread.

    # See Also

    - [`get_widget_state`](@ref): Access widget state for a window
    - [`clear_widget_states!`](@ref): Clear all widget states
    - [`@window`](@ref): Create windows with automatic state management
    - [`@var`](@ref): Store variables in widget state
    - [`@checkbox`](@ref), [`@slider`](@ref): Stateful widgets that use refs
    """
    mutable struct WidgetState
        variables::Dict{Symbol, Any}      # Regular variables and computed values
        refs::Dict{Symbol, Ref}          # Refs for stateful widgets (checkboxes, sliders)
        event_handlers::Dict{Symbol, Function}  # Event handler functions
        window_open::Bool                 # Whether the window is currently open
        
        WidgetState() = new(Dict(), Dict(), Dict(), true)
    end

    # Include macro definitions
    include("macros.jl")

    # Export macro symbols (will be available as MicroUI.Macros.@context, etc.)
    export @context, @window, @var, @simple_label
    export @text, @button, @checkbox, @slider
    export @range, @step, @maxlength, @number, @textbox
    export @when, @foreach, @onclick, @popup, @reactive
    export @column, @row, @panel, @close_window, @open_window
    export @debug_types, @state  # Variable access helper
    export get_widget_state, clear_widget_states!, parse_assignment
    export WidgetState

end # module Macros

end # module MicroUI