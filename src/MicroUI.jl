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

include("export.jl")
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

end # module