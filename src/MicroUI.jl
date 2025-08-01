"""
MicroUI.jl - A Julia implementation of an immediate mode GUI library

This module provides a complete immediate mode GUI (IMGUI) implementation in Julia,
inspired by the microui C library. Immediate mode GUIs rebuild the entire interface
each frame, making them simpler to reason about and integrate into applications.

Key concepts:
- No persistent widget state - everything is recreated each frame
- Direct integration with rendering backends
- Minimal memory allocations during runtime
- Command-based rendering system for backend independence
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

# Optional macro DSL module
"""
    MicroUI.Macros

High-level declarative macro system for MicroUI.

To use the macro DSL, import this module after MicroUI:
```julia
using MicroUI          # Core API
using MicroUI.Macros   # Macro DSL (@context, @window, etc.)
```
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
    Widget state container that persists between frames.
    Stores variables, refs for stateful widgets, event handlers, and window state.
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
