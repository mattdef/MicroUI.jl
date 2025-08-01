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

# ===== CORE MACROS =====

"""
Context management macro for MicroUI.

Creates and manages a MicroUI context with proper frame lifecycle.
All windows and UI elements must be inside a @context block.

Usage:
```julia
ctx = @context begin
    @window "My Window" begin
        @var message = "Hello World"
    end
end
```

Returns the MicroUI Context with all rendering commands.
"""
macro context(expr)
    return quote
        # injecte un `ctx` visible à l'extérieur
        local $(esc(:ctx)) = Context()
        init!($(esc(:ctx)))
        $(esc(:ctx)).text_width  = (font, str) -> length(str) * 8
        $(esc(:ctx)).text_height = font -> 16

        begin_frame($(esc(:ctx)))
          $(esc(expr))
        end_frame($(esc(:ctx)))
        $(esc(:ctx))
    end
end

"""
Window macro for use within @context blocks.

Creates a window with automatic state management. Must be used inside a @context block.
The window state persists between frames for stateful widgets.

Usage:
```julia
@context begin
    @window "Window Title" begin
        @var message = "Hello"
    end
end
```
"""
macro window(title, body)
    mod = __module__
    return quote
        local _window_title = $(esc(title))
        local _window_id    = Symbol("window_", hash(_window_title))
        local $(esc(:window_state)) = get_widget_state(_window_id)

        # ici, on lit le `ctx` injecté par @context
        local _window_rect   = Rect(100, 100, 400, 300)
        local _window_result = begin_window($(esc(:ctx)), _window_title, _window_rect)

        if _window_result != 0 && $(esc(:window_state)).window_open
            $(esc(body))
        end

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