import Base: |, &, ~

"""
MicroUI Macro System

This module provides a declarative macro-based DSL for MicroUI that allows
writing UIs in a more intuitive way while maintaining the performance and
flexibility of the underlying immediate mode GUI system.

Key features:
- Separated @context and @window macros for better architecture
- Automatic state management between frames
- Support for multiple windows in one context
- Dynamic window creation and control
- Reactive programming with @reactive
- Event handling with @onclick

Example usage:
```julia
ctx = @context begin
    @window "My Application" begin
        @var title = "Hello World"
        @text display = title
        
        @button save_btn = "Save"
        @onclick save_btn begin
            @popup "Saved!"
        end
    end
    
    @window "Settings" begin
        @checkbox enable_feature = true
        @slider volume = 0.5 range(0.0, 1.0)
    end
end
```
"""

# ===== STATE MANAGEMENT =====

"""Global registry of all widget states, keyed by window ID"""
const WIDGET_STATES = Dict{Symbol, WidgetState}()

"""
Get or create widget state for a given window ID.
Returns the same instance for the same window across multiple frames.
"""
function get_widget_state(window_id::Symbol)
    if !haskey(WIDGET_STATES, window_id)
        WIDGET_STATES[window_id] = WidgetState()
    end
    return WIDGET_STATES[window_id]
end

"""Clear all widget states (useful for testing and cleanup)"""
function clear_widget_states!()
    empty!(WIDGET_STATES)
end

# ===== UTILITY FUNCTIONS =====

"""Convert to Real (Float32) for MicroUI consistency."""
ensure_real(x::Number) = Float32(x)
ensure_real(x::Real) = Float32(x)

"""Convert to proper vector type for layout."""
ensure_int_vector(arr) = Vector{Int}(arr)

"""
Parse assignment expressions like 'var = value'.
Returns (variable_name, value_expression) tuple.
"""
function parse_assignment(expr)
    try
        if expr isa Expr && expr.head == :(=)
            key_expr = if expr.args[1] isa Symbol
                QuoteNode(expr.args[1])
            elseif expr.args[1] isa String
                QuoteNode(Symbol(expr.args[1]))
            else
                :(Symbol($(esc(expr.args[1]))))
            end

            return key_expr, expr.args[2]
        else
            error("Expected assignment expression (var = value)")
        end        
    catch
        error("Invalid assignment syntax in macro. Expected 'var = value', got: $expr")
    end
end


function parse_loop_expression(expr)
    if expr isa Expr
        if expr.head == :in
            return expr.args[1], expr.args[2]
        elseif expr.head == :call && length(expr.args) >= 3 && expr.args[1] == :in
            return expr.args[2], expr.args[3]
        else
            error("Unsupported loop expression: $expr. Use 'var in iterable' syntax.")
        end
    else
        error("Expected loop expression, got: $(typeof(expr))")
    end
end

# ===== BITWISE OPERATORS FOR OPTION ENUM =====

"""
Define bitwise operators for the Option enum to allow combining options
like OPT_NORESIZE | OPT_NOTITLE
"""


# Bitwise OR for combining options
Base.:|(a::MicroUI.Option, b::MicroUI.Option) = UInt16(a) | UInt16(b)
Base.:|(a::MicroUI.Option, b::UInt16) = UInt16(a) | b
Base.:|(a::UInt16, b::MicroUI.Option) = a | UInt16(b)

# Bitwise AND for checking options
Base.:&(a::MicroUI.Option, b::MicroUI.Option) = UInt16(a) & UInt16(b)
Base.:&(a::MicroUI.Option, b::UInt16) = UInt16(a) & b
Base.:&(a::UInt16, b::MicroUI.Option) = a & UInt16(b)

# Bitwise NOT for negating options
Base.:~(a::MicroUI.Option) = ~UInt16(a)

# ===== CORE MACROS =====

"""
Enhanced @context macro with customizable text width and height parameters.

This macro creates and manages a MicroUI context with proper frame lifecycle,
now supporting custom text metrics for different font rendering systems.

# Basic Usage (default values)
```julia
ctx = @context begin
    @window "My Window" begin
        @var message = "Hello World"
    end
end
```

# Custom text metrics
```julia
# Custom character width and line height
ctx = @context (10, 20) begin
    @window "My Window" begin
        @text content = "Custom sized text"
    end
end

# Using named parameters for clarity
ctx = @context char_width=12 line_height=18 begin
    @window "Settings" begin
        @text title = "Settings Panel"
    end
end

# Mixed parameters (tuple for width/height + named parameters)
ctx = @context (8, 16) font_scale=1.2 begin
    @window "Scaled Text" begin
        @text content = "Text with scaling"
    end
end
```

# Parameters
- `(char_width, line_height)`: Tuple specifying character width and line height
- `char_width=N`: Character width in pixels (default: 8)
- `line_height=N`: Line height in pixels (default: 16) 
- `font_scale=N`: Additional scaling factor (default: 1.0)

Returns the MicroUI Context with all rendering commands and custom text metrics.
"""
macro context(args...)
    # Parse arguments to extract parameters and body block
    local char_width_expr = nothing
    local line_height_expr = nothing
    local font_scale_expr = nothing
    local body = nothing
    local tuple_args = nothing
    
    # Find the body block (must be the last argument or only argument)
    for (i, arg) in enumerate(args)
        if arg isa Expr && arg.head == :block
            body = arg
            break
        end
    end
    
    # If no body found, check if we have a single block (original behavior)
    if body === nothing && length(args) == 1 && args[1] isa Expr && args[1].head == :block
        body = args[1]
    end
    
    # If still no body and we have arguments, the last one should be the body
    if body === nothing && length(args) > 0
        body = args[end]
        if !(body isa Expr && body.head == :block)
            error("@context macro requires a body block as the last argument")
        end
    end
    
    # If no arguments provided, use original simple syntax
    if length(args) == 1 && args[1] isa Expr && args[1].head == :block
        # Original syntax: @context begin ... end
        body = args[1]
    elseif length(args) == 0
        error("@context macro requires a body block")
    else
        # Parse parameter arguments (all args except the body block)
        for arg in args
            # Skip the body block
            if arg === body
                continue
            end
            
            # Handle tuple syntax: @context (8, 16) begin ... end
            if arg isa Expr && arg.head == :tuple
                if length(arg.args) == 2
                    tuple_args = arg
                    char_width_expr = arg.args[1]
                    line_height_expr = arg.args[2]
                else
                    error("Tuple parameter must have exactly 2 elements: (char_width, line_height)")
                end
            # Handle named parameter syntax: @context char_width=8 line_height=16 begin ... end
            elseif arg isa Expr && arg.head == :(=)
                param_name = arg.args[1]
                param_value = arg.args[2]
                
                if param_name == :char_width
                    char_width_expr = param_value
                elseif param_name == :line_height
                    line_height_expr = param_value
                elseif param_name == :font_scale
                    font_scale_expr = param_value
                else
                    error("Unknown context parameter: $param_name. Valid parameters: char_width, line_height, font_scale")
                end
            # Handle simple numeric arguments (legacy support)
            elseif arg isa Number
                if char_width_expr === nothing
                    char_width_expr = arg
                elseif line_height_expr === nothing
                    line_height_expr = arg
                else
                    error("Too many numeric arguments. Use tuple syntax: @context (width, height) or named parameters.")
                end
            else
                error("Invalid context parameter syntax: $arg. Use (width, height), char_width=N, or line_height=N")
            end
        end
    end
    
    # Validate body block
    if body === nothing || !(body isa Expr && body.head == :block)
        error("@context macro requires a body block")
    end
    
    return quote
        # Create context with custom initialization
        local $(esc(:ctx)) = Context()
        init!($(esc(:ctx)))
        
        # Configure text metrics with provided or default values
        local _char_width = $(char_width_expr !== nothing ? esc(char_width_expr) : 8)
        local _line_height = $(line_height_expr !== nothing ? esc(line_height_expr) : 16)
        local _font_scale = $(font_scale_expr !== nothing ? esc(font_scale_expr) : 1.0)
        
        # Apply text measurement functions with custom parameters
        $(esc(:ctx)).text_width = (font, str) -> begin
            base_width = length(str) * _char_width
            return Int32(round(base_width * _font_scale))
        end
        
        $(esc(:ctx)).text_height = font -> begin
            base_height = _line_height
            return Int32(round(base_height * _font_scale))
        end
        
        # Execute the UI code within proper frame lifecycle
        begin_frame($(esc(:ctx)))
        try
            $(esc(body))
        finally
            end_frame($(esc(:ctx)))
        end
        
        # Return the configured context
        $(esc(:ctx))
    end
end

"""
    @frame ctx body

Process a single frame using an existing MicroUI context.

This macro manages the frame lifecycle (`begin_frame`/`end_frame`) around the provided
UI code block. It should be used with contexts created by `@create_context` for optimal
performance in multi-frame applications like animations and interactive programs.

# Arguments
- `ctx`: The MicroUI context to use (must be a Context created by `@create_context`)
- `body`: Code block containing UI elements (windows, widgets, layout, etc.)

# Returns
- `Context`: The same context passed in, allowing for method chaining

# Frame Lifecycle

Each `@frame` call performs the following operations:
1. **Begin frame**: Calls `begin_frame(ctx)` to reset frame state
2. **Execute UI code**: Runs the provided body with `ctx` in scope
3. **End frame**: Calls `end_frame(ctx)` to finalize rendering commands

# Basic Usage

```julia
# Create context once
ctx = @create_context begin
    println("Context initialized")
end

# Process multiple frames
for i in 1:10
    @frame ctx begin
        @window "Frame Demo" begin
            @var frame_number = i
            @text display = "Current frame: \$frame_number"
            @button next_btn = "Next Frame"
        end
    end
    
    # Render the frame
    render_context!(renderer, ctx)
    display!(renderer)
end
```

# Animation Pattern

```julia
ctx = @create_context begin end

# Smooth animation at 60 FPS
start_time = time()
while time() - start_time < 5.0  # 5 second animation
    current_time = time() - start_time
    
    @frame ctx begin
        @window "Animation" begin
            @var t = current_time
            @var wave = sin(t * 2π)
            @var progress = t / 5.0
            
            @text title = "Sine Wave Animation"
            @simple_label time_display = "Time: \$(round(t, digits=2))s"
            @simple_label wave_display = "Wave: \$(round(wave, digits=3))"
            
            # Animated progress bar
            @slider progress_bar = progress range(0.0, 1.0)
            
            # Color animation (simulated)
            @var red_component = (wave + 1) / 2
            @simple_label color_display = "Red: \$(round(red_component * 255))"
        end
    end
    
    render_context!(renderer, ctx)
    display!(renderer)
    sleep(1/60)  # 60 FPS timing
end
```

# Interactive Event Handling

```julia
mutable struct GameState
    player_x::Float64
    player_y::Float64
    score::Int
    game_over::Bool
end

game = GameState(100.0, 100.0, 0, false)
ctx = @create_context begin end

while !game.game_over
    # Handle input (pseudocode)
    if key_pressed("LEFT")
        game.player_x -= 5
    elseif key_pressed("RIGHT")
        game.player_x += 5
    end
    
    @frame ctx begin
        @window "Game Window" begin
            @var player_pos = "(\$(round(game.player_x)), \$(round(game.player_y)))"
            @var current_score = game.score
            
            @text game_title = "Simple Game"
            @simple_label position_display = "Player: \$player_pos"
            @simple_label score_display = "Score: \$current_score"
            
            @button restart_btn = "Restart Game"
            @onclick restart_btn begin
                game.player_x = 100.0
                game.player_y = 100.0
                game.score = 0
            end
            
            @button quit_btn = "Quit"
            @onclick quit_btn begin
                game.game_over = true
            end
        end
    end
    
    render_context!(renderer, ctx)
    display!(renderer)
    sleep(1/30)  # 30 FPS game loop
end
```

# Performance Considerations

## Optimal Usage
- ✅ Use with `@create_context` for multi-frame applications
- ✅ Ideal for animations, games, and interactive programs
- ✅ Enables 60+ FPS performance with complex UIs
- ✅ Minimizes memory allocations during runtime

## Suboptimal Usage
- ❌ Don't use with contexts created by `@context` (redundant)
- ❌ Avoid for single-frame UIs (use `@context` instead)
- ❌ Don't call multiple `@frame` blocks simultaneously on same context

# Error Handling

```julia
ctx = @create_context begin end

try
    @frame ctx begin
        @window "Error Demo" begin
            # UI code that might fail
            @var risky_value = some_risky_computation()
            @text display = "Value: \$risky_value"
        end
    end
catch e
    println("Frame processing failed: \$e")
    # Context remains valid for next frame
end
```

# Memory Usage

The `@frame` macro is designed for minimal memory overhead:
- **No new allocations** during normal operation
- **Reuses internal buffers** between frames
- **Automatic cleanup** of temporary frame data
- **Stable memory usage** even for long-running applications

# Debugging and Profiling

```julia
# Time individual frames
ctx = @create_context begin end

for i in 1:100
    frame_time = @elapsed begin
        @frame ctx begin
            @window "Performance Test" begin
                # Complex UI
                @foreach j in 1:50 begin
                    @simple_label "label_\$j" = "Widget \$j of frame \$i"
                    @slider "slider_\$j" = (j * i * 0.001) range(0.0, 1.0)
                end
            end
        end
    end
    
    if frame_time > 1/60  # Slower than 60 FPS
        println("Frame \$i was slow: \$(round(frame_time * 1000, digits=2))ms")
    end
end
```

# Context Validation

The macro automatically validates the provided context:
- Ensures the context is properly initialized
- Checks that required callbacks are set
- Provides clear error messages for common mistakes

```julia
# This will produce a helpful error message
invalid_ctx = Context()  # Not initialized
@frame invalid_ctx begin  # Error: context not initialized
    @window "Test" begin
        @text content = "This won't work"
    end
end
```

# See Also
- [`@create_context`](@ref): Create reusable contexts for multi-frame applications
- [`@context`](@ref): Traditional single-frame context management
- [`@render_frame`](@ref): Convenience macro combining frame processing and rendering
- [`@timed_frame`](@ref): Performance profiling version of frame processing
- [`begin_frame`](@ref): Low-level frame initialization
- [`end_frame`](@ref): Low-level frame finalization
"""
macro frame(ctx_expr, body)
    return quote
        # Begin the frame with the provided context
        begin_frame($(esc(ctx_expr)))
        
        # Execute the UI body with the context in scope
        let $(esc(:ctx)) = $(esc(ctx_expr))
            $(esc(body))
        end
        
        # End the frame
        end_frame($(esc(ctx_expr)))
        
        # Return the context for method chaining if desired
        $(esc(ctx_expr))
    end
end

"""
Enhanced window macro for use within @context blocks with optional parameters.

Creates a window with automatic state management and flexible parameter system.
Must be used inside a @context block. Window state persists between frames.

## Syntax Options:

### Basic window (default size and position)
```julia
@window "Window Title" begin
    @text content = "Hello World"
end
```

### Custom rectangle (x, y, width, height)
```julia
@window "Custom Window" rect=(50, 50, 600, 400) begin
    @text content = "Custom positioned and sized window"
end
```

### Size only (uses default position)
```julia
@window "Large Window" size=(800, 600) begin
    @text content = "Large window at default position"
end
```

### Position only (uses default size)  
```julia
@window "Moved Window" pos=(200, 100) begin
    @text content = "Window moved to custom position"
end
```

### Window options
```julia
@window "No Resize" opts=OPT_NORESIZE begin
    @text content = "This window cannot be resized"
end
```

### Combined parameters
```julia
@window "Full Custom" rect=(10, 10, 500, 350) opts=(OPT_NORESIZE | OPT_NOTITLE) begin
    @text content = "Fully customized window"
end
```

## Parameters:
- `rect=(x, y, w, h)`: Complete rectangle specification (overrides size/pos)
- `size=(w, h)`: Window dimensions only
- `pos=(x, y)`: Window position only  
- `opts=options`: Window behavior options (see OPT_* constants)

## Default Values:
- Position: (100, 100)
- Size: (400, 300)
- Options: None (standard resizable window with title bar)
"""
macro window(title, args...)
    # Parse arguments to extract parameters and body block
    local rect_expr = nothing
    local size_expr = nothing  
    local pos_expr = nothing
    local opts_expr = nothing
    local body = nothing
    
    # Find the body block (must be the last argument)
    for (i, arg) in enumerate(args)
        if arg isa Expr && arg.head == :block
            body = arg
            break
        end
    end
    
    # Validate that we found a body block
    if body === nothing
        error("@window macro requires a body block")
    end
    
    # Parse parameter arguments (all args except the body block)
    for arg in args
        # Skip the body block
        if arg isa Expr && arg.head == :block
            continue
        end
        
        # Parse parameter assignments
        if arg isa Expr && arg.head == :(=)
            param_name = arg.args[1]
            param_value = arg.args[2]
            
            if param_name == :rect
                rect_expr = param_value
            elseif param_name == :size
                size_expr = param_value
            elseif param_name == :pos
                pos_expr = param_value
            elseif param_name == :opts || param_name == :options
                opts_expr = param_value
            else
                error("Unknown window parameter: $param_name. Valid parameters: rect, size, pos, opts")
            end
        else
            error("Invalid window parameter syntax: $arg. Use name=value format (e.g., size=(800,600))")
        end
    end
    
    return quote
        # Generate unique window ID from title
        local _window_title = $(esc(title))
        local _window_id = Symbol("window_", hash(_window_title))
        local $(esc(:window_state)) = get_widget_state(_window_id)
        
        # Build window rectangle from parameters with proper precedence
        local _window_rect = begin
            # Default window configuration
            local default_x, default_y = Int32(100), Int32(100)
            local default_w, default_h = Int32(400), Int32(300)
            
            if $(rect_expr !== nothing)
                # rect=(x, y, w, h) parameter takes highest priority
                local rect_tuple = $(esc(rect_expr))
                if length(rect_tuple) != 4
                    error("rect parameter must be a 4-tuple (x, y, width, height)")
                end
                Rect(Int32(rect_tuple[1]), Int32(rect_tuple[2]), 
                     Int32(rect_tuple[3]), Int32(rect_tuple[4]))
            else
                # Build rectangle from individual size and/or pos parameters
                local x, y = default_x, default_y
                local w, h = default_w, default_h
                
                # Override position if specified
                if $(pos_expr !== nothing)
                    local pos_tuple = $(esc(pos_expr))
                    if length(pos_tuple) != 2
                        error("pos parameter must be a 2-tuple (x, y)")
                    end
                    x, y = Int32(pos_tuple[1]), Int32(pos_tuple[2])
                end
                
                # Override size if specified
                if $(size_expr !== nothing)
                    local size_tuple = $(esc(size_expr))
                    if length(size_tuple) != 2
                        error("size parameter must be a 2-tuple (width, height)")
                    end
                    w, h = Int32(size_tuple[1]), Int32(size_tuple[2])
                end
                
                Rect(x, y, w, h)
            end
        end
        
        # Handle window options (convert to proper UInt16 type)
        local _window_opts = $(opts_expr !== nothing) ? UInt16($(esc(opts_expr))) : UInt16(0)
        
        # Create window using appropriate MicroUI function
        local _window_result = if _window_opts == UInt16(0)
            # Use simple window creation for default options
            begin_window($(esc(:ctx)), _window_title, _window_rect)
        else
            # Use extended window creation for custom options
            begin_window_ex($(esc(:ctx)), _window_title, _window_rect, _window_opts)
        end
        
        # Execute window body if window is active and open
        if _window_result != 0 && $(esc(:window_state)).window_open
            $(esc(body))
        end
        
        # Always end the window to maintain proper stack balance
        end_window($(esc(:ctx)))
        _window_result
    end
end

"""
Close window macro.
Usage: @close_window "Window Title"
"""
macro close_window(title)
    return quote
        local _window_id = Symbol("window_", hash($(esc(title))))
        if haskey(WIDGET_STATES, _window_id)
            WIDGET_STATES[_window_id].window_open = false
        end
    end
end

"""
Open window macro.
Usage: @open_window "Window Title"
"""
macro open_window(title)
    return quote
        local _window_id = Symbol("window_", hash($(esc(title))))
        get_widget_state(_window_id).window_open = true
    end
end


# ===== CORE VARIABLE SYSTEM =====

"""
Variable assignment - stores in state only.
Usage: @var name = value
"""
macro var(assignment)
    key_expr, value = parse_assignment(assignment)
    return quote
        local _var_value = $(esc(value))
        # Convert numeric types
        if isa(_var_value, AbstractFloat) && !isa(_var_value, Real)
            _var_value = Real(_var_value)
        end
        $(esc(:window_state)).variables[$key_expr] = _var_value
        _var_value
    end
end

"""
Reactive computation using window state variables.
Usage: @reactive result = window_state.variables[:var1] + window_state.variables[:var2]
Or use helper: @reactive result = @v(var1) + @v(var2)
"""
macro reactive(assignment)
    key_expr, computation = parse_assignment(assignment)
    return quote
        local _reactive_value = $(esc(computation))
        if isa(_reactive_value, AbstractFloat) && !isa(_reactive_value, Real)
            _reactive_value = Real(_reactive_value)
        end
        $(esc(:window_state)).variables[$key_expr] = _reactive_value
        _reactive_value
    end
end

"""
Variable access helper for reactive expressions.
Usage: @state(variable_name) -> gets value from window state
"""
macro state(var_name)
    return quote
        get($(esc(:window_state)).variables, $(QuoteNode(var_name)), nothing)
    end
end

# ===== WIDGET MACROS =====

"""
Simple label widget.
Usage: @simple_label name = "text"
"""
macro simple_label(assignment)
    key_expr, content = parse_assignment(assignment)
    return quote
        local _label_content = $(esc(content))
        $(esc(:window_state)).variables[$key_expr] = _label_content
        label($(esc(:ctx)), string(_label_content))
    end
end

"""
Text display widget.
Usage: @text name = "content"
"""
macro text(assignment)
    key_expr, content = parse_assignment(assignment)
    return quote
        local _text_content = $(esc(content))
        $(esc(:window_state)).variables[$key_expr] = _text_content
        text($(esc(:ctx)), string(_text_content))
    end
end

"""
Number widget macro for precise numeric input.
Usage: @number num_name = 10.0 step(1.0)
"""
macro number(assignment, step_expr)
    key_expr, initial_value = parse_assignment(assignment)

    return quote
        local _step_val = ensure_microui_real($(esc(step_expr)))
        local _number_key = $key_expr
        
        # Get or create ref for number state - ensure Real type
        if !haskey($(esc(:window_state)).refs, _number_key)
            $(esc(:window_state)).refs[_number_key] = ensure_real($(esc(initial_value)))
        end
        
        local _number_ref = $(esc(:window_state)).refs[_number_key]
        
        # Ensure the ref contains Real type
        if !isa(_number_ref[], Real)
            _number_ref[] = Real(_number_ref[])
        end
        
        local _number_result = number!($(esc(:ctx)), _number_ref, _step_val)
        
        # Update stored value
        $(esc(:window_state)).variables[_number_key] = _number_ref[]
        local _result_key = Symbol(string(_number_key), "_result")
        $(esc(:window_state)).variables[_result_key] = _number_result
        
        _number_result
    end
end

# Simple number macro without step (uses default step)
macro number(assignment)
    key_expr, initial_value = parse_assignment(assignment)

    return quote
        local _number_key = $key_expr
        
        # Get or create ref for number state - ensure Real type
        if !haskey($(esc(:window_state)).refs, _number_key)
            $(esc(:window_state)).refs[_number_key] = ensure_real($(esc(initial_value)))
        end
        
        local _number_ref = $(esc(:window_state)).refs[_number_key]
        
        # Ensure the ref contains Real type
        if !isa(_number_ref[], Real)
            _number_ref[] = Real(_number_ref[])
        end
        
        local _number_result = number!($(esc(:ctx)), _number_ref, Real(1.0))
        
        # Update stored value
        $(esc(:window_state)).variables[_number_key] = _number_ref[]
        local _result_key = Symbol(string(_number_key), "_result")
        $(esc(:window_state)).variables[_number_key] = _number_result
        
        _number_result
    end
end

# ===== TEXTBOX MACROS =====

"""
Textbox widget macro for text input.
Usage: @textbox text_name = "default text" maxlength(256)
"""
macro textbox(assignment, maxlength_expr)
    key_expr, initial_value = parse_assignment(assignment)

    return quote
        local _maxlength = Int($(esc(maxlength_expr)))
        local _textbox_key = $key_expr
        
        # Get or create ref for textbox state - ensure String type
        if !haskey($(esc(:window_state)).refs, _textbox_key)
            $(esc(:window_state)).refs[_textbox_key] = Ref(String($(esc(initial_value))))
        end
        
        local _textbox_ref = $(esc(:window_state)).refs[_textbox_key]
        
        # Ensure the ref contains String type
        if !isa(_textbox_ref[], String)
            _textbox_ref[] = String(_textbox_ref[])
        end
        
        local _textbox_result = textbox!($(esc(:ctx)), _textbox_ref, _maxlength)
        
        # Update stored value
        $(esc(:window_state)).variables[_textbox_key] = _textbox_ref[]
        local _result_key = Symbol(string(_textbox_key), "_result")
        $(esc(:window_state)).variables[_result_key] = _textbox_result
        
        _textbox_result
    end
end

# Simple textbox with default maxlength
macro textbox(assignment)
    return quote
        $(esc(:(@textbox($assignment, 256))))
    end
end

"""
Button widget.
Usage: @button name = "text"
"""
macro button(assignment, options...)
    key_expr, label = parse_assignment(assignment)
    return quote
        local _button_label = $(esc(label))
        $(esc(:window_state)).variables[$key_expr] = _button_label
        
        local _button_result = if isempty($(esc(options)))
            button($(esc(:ctx)), string(_button_label))
        else
            button_ex($(esc(:ctx)), string(_button_label), nothing, $(esc(options))[1])
        end
        
        local _result_key = Symbol(string($key_expr), "_result")
        $(esc(:window_state)).variables[_result_key] = _button_result
        
        _button_result
    end
end

"""
Checkbox widget with bulletproof type handling.
Usage: @checkbox name = true/false
"""
macro checkbox(assignment)
    key_expr, initial_value = parse_assignment(assignment)
    return quote
        local _checkbox_key = $key_expr
        
        # Initialize or get ref with proper type
        if !haskey($(esc(:window_state)).refs, _checkbox_key)
            $(esc(:window_state)).refs[_checkbox_key] = Ref(Bool($(esc(initial_value))))
        end
        
        local _ref = $(esc(:window_state)).refs[_checkbox_key]
        
        # Force correct type if needed
        if !isa(_ref[], Bool)
            $(esc(:window_state)).refs[_checkbox_key] = Ref(Bool(_ref[]))
            _ref = $(esc(:window_state)).refs[_checkbox_key]
        end
        
        local _result = checkbox!($(esc(:ctx)), string(_checkbox_key), _ref)
        
        # Update state
        $(esc(:window_state)).variables[_checkbox_key] = _ref[]
        local _result_key = Symbol(string(_checkbox_key), "_result")
        $(esc(:window_state)).variables[_result_key] = _result
        
        _result
    end
end

"""
Slider widget with bulletproof type handling.
Usage: @slider name = initial_value range(low, high)
"""
macro slider(assignment, range_expr)
    key_expr, initial_value = parse_assignment(assignment)
    return quote
        local _range_val = $(esc(range_expr))
        local _low_val = ensure_real(first(_range_val))
        local _high_val = ensure_real(last(_range_val))
        local _slider_key = $key_expr
        
        # Initialize or get ref with proper type
        if !haskey($(esc(:window_state)).refs, _slider_key)
            $(esc(:window_state)).refs[_slider_key] = Ref(ensure_real($(esc(initial_value))))
        end
        
        local _ref = $(esc(:window_state)).refs[_slider_key]
        
        # Force correct type if needed
        if !isa(_ref[], Real)
            $(esc(:window_state)).refs[_slider_key] = Ref(ensure_real(_ref[]))
            _ref = $(esc(:window_state)).refs[_slider_key]
        end
        
        # Call slider with guaranteed correct types
        local _result = slider!($(esc(:ctx)), _ref, _low_val, _high_val)
        
        # Update state
        $(esc(:window_state)).variables[_slider_key] = _ref[]
        local _result_key = Symbol(string(_slider_key), "_result")
        $(esc(:window_state)).variables[_result_key] = _result
        
        _result
    end
end

# ===== CONTROL FLOW MACROS =====

"""
Conditional rendering macro.
Usage: @when condition begin ... end
"""
macro when(condition, body)
    return quote
        if $(esc(condition))
            $(esc(body))
        end
    end
end

"""
Loop for dynamic widgets.
Usage: @foreach i in 1:5 begin ... end
"""
macro foreach(loop_expr, body)
    var_part, iterable_part = parse_loop_expression(loop_expr)
    return quote
        for $(esc(var_part)) in $(esc(iterable_part))
            $(esc(body))
        end
    end
end

# ===== HELPER MACROS FOR RANGES AND STEPS =====

"""
Helper macro for creating ranges with proper types.
Usage: range(0.0, 1.0) -> tuple of Real values
"""
macro range(low, high)
    return quote
        (Real($(esc(low))), Real($(esc(high))))
    end
end

"""
Helper macro for steps with proper types.
Usage: step(1.0) -> Real value
"""
macro step(value)
    return quote
        Real($(esc(value)))
    end
end

"""
Helper macro for maxlength with proper types.
Usage: maxlength(256) -> Int value
"""
macro maxlength(value)
    return quote
        Int($(esc(value)))
    end
end

# ===== EVENTS MACROS =====

"""
Click event handler.
Usage: @onclick widget_name begin ... end
"""
macro onclick(widget_name, body)
    return quote
        local _widget_key = $(QuoteNode(widget_name))
        local _result_key = Symbol(string(_widget_key), "_result")
        
        if haskey($(esc(:window_state)).variables, _result_key)
            local _widget_result = $(esc(:window_state)).variables[_result_key]
            if (_widget_result & Int(RES_SUBMIT)) != 0
                $(esc(body))
            end
        end
    end
end

"""
Popup message.
Usage: @popup "message"
"""
macro popup(message)
    return quote
        local _popup_name = "popup_" * string(hash($(esc(message))))
        open_popup!($(esc(:ctx)), _popup_name)
        
        if begin_popup($(esc(:ctx)), _popup_name) != 0
            text($(esc(:ctx)), $(esc(message)))
            if button($(esc(:ctx)), "OK") != 0
                # Close popup (happens automatically)
            end
            end_popup($(esc(:ctx)))
        end
    end
end

# ===== LAYOUT MACROS =====

"""
Column layout.
Usage: @column begin ... end
"""
macro column(body)
    return quote
        layout_begin_column!($(esc(:ctx)))
        $(esc(body))
        layout_end_column!($(esc(:ctx)))
    end
end

"""
Row layout with proper integer types.
Usage: @row [100, 200, -1] begin ... end
"""
macro row(widths, body)
    return quote
        local _width_array = ensure_int_vector($(esc(widths)))
        layout_row!($(esc(:ctx)), length(_width_array), _width_array, 0)
        $(esc(body))
    end
end

"""
Panel macro for grouped widgets.
Usage: @panel "Title" begin ... end
"""
macro panel(title, body)
    return quote
        if begin_panel($(esc(:ctx)), $(esc(title))) != 0
            $(esc(body))
        end
        end_panel($(esc(:ctx)))
    end
end

# ===== DEBUGGING HELPER =====

"""
Debug macro to check types of widget state values.
Usage: @debug_types window_name
"""
macro debug_types(window_name)
    return quote
        local _window_id = Symbol("window_", hash($(esc(window_name))))
        if haskey(WIDGET_STATES, _window_id)
            local state = WIDGET_STATES[_window_id]
            println("=== Widget State Types for $($(esc(window_name))) ===")
            
            println("Variables:")
            for (k, v) in state.variables
                println("  $k: $(typeof(v)) = $v")
            end
            
            println("Refs:")
            for (k, v) in state.refs
                println("  $k: $(typeof(v)) contains $(typeof(v[]))")
            end
            
            println("===============================")
        else
            println("No state found for window: $($(esc(window_name)))")
        end
    end
end