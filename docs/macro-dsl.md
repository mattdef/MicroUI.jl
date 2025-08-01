# MicroUI.jl Macro DSL Guide

**Complete guide to the declarative macro system for rapid GUI development**

## 📚 Table of Contents

1. [Introduction](#introduction)
2. [Core Concepts](#core-concepts)
3. [Basic Macros](#basic-macros)
4. [State Management](#state-management)
5. [Widget Reference](#widget-reference)
6. [Control Flow](#control-flow)
7. [Layout System](#layout-system)
8. [Event Handling](#event-handling)
9. [Advanced Patterns](#advanced-patterns)
10. [Best Practices](#best-practices)
11. [Common Pitfalls](#common-pitfalls)
12. [Migration from Low-level API](#migration-from-low-level-api)
13. [Examples](#examples)

## Introduction

The MicroUI.jl Macro DSL provides a **declarative, React-like syntax** for building user interfaces. Instead of manually managing state and calling low-level functions, you describe **what** your UI should look like, and the macro system handles the **how**.

### Why Use the Macro DSL?

**Before (Low-level API):**
```julia
# Manual state management
button_clicked = Ref(false)
slider_value = Ref(0.5)
text_buffer = Ref("Hello")

# Manual widget calls with state checking
if button(ctx, "Click me") != 0
    button_clicked[] = true
    println("Button was clicked!")
end

if slider!(ctx, slider_value, 0.0, 1.0) != 0
    println("Slider value: $(slider_value[])")
end
```

**After (Macro DSL):**
```julia
@context begin
    @window "My App" begin
        @var counter = 0
        @button click_me = "Click me"
        @slider volume = 0.5 range(0.0, 1.0)
        
        @onclick click_me begin
            @var counter = counter + 1
            @popup "Clicked $(counter) times!"
        end
        
        @reactive volume_percent = "Volume: $(round(volume * 100))%"
        @simple_label display = volume_percent
    end
end
```

## Core Concepts

### 1. Context and Windows

Every UI must be wrapped in a `@context` block, which contains one or more `@window` blocks:

```julia
ctx = @context begin          # Creates and manages MicroUI context
    @window "Window 1" begin  # Each window has isolated state
        # UI elements go here
    end
    
    @window "Window 2" begin  # Multiple windows supported
        # Different UI elements
    end
end
```

### 2. Automatic State Management

Variables declared with `@var` persist between frames automatically:

```julia
@window "Persistent State" begin
    @var name = "John"        # Persists between frames
    @var age = 25             # Automatically managed
    @var items = ["a", "b"]   # Works with any Julia type
end
```

### 3. Reactive Programming

Use `@reactive` for computed values that update automatically:

```julia
@window "Reactive Demo" begin
    @var first_name = "John"
    @var last_name = "Doe"
    
    # Updates automatically when first_name or last_name changes
    @reactive full_name = "$first_name $last_name"
    @reactive initials = "$(first_name[1]).$(last_name[1])."
end
```

## Basic Macros

### @context - Context Management

Creates and manages the MicroUI context with proper frame lifecycle.

```julia
# Basic usage
ctx = @context begin
    # All UI code goes here
end

# The context is automatically available as 'ctx'
render_commands(ctx.command_list)
```

**What it does:**
- Creates a new `Context()`
- Calls `init!()`, `begin_frame()`, and `end_frame()`
- Sets up default text measurement functions
- Makes the context available to all nested macros

### @window - Window Management

Creates a window with automatic state management.

```julia
@context begin
    @window "My Application" begin
        # Window content
    end
end

# Window with dynamic title
@context begin
    @var app_version = "v1.0"
    @window "Calculator $(app_version)" begin
        # Content
    end
end
```

**Features:**
- Automatic state persistence per window
- Each window has isolated state
- Windows can be opened/closed dynamically

### @var - Variable Declaration

Declares persistent variables that survive between frames.

```julia
@window "Variables" begin
    # Basic types
    @var message = "Hello World"
    @var count = 0
    @var enabled = true
    @var temperature = 23.5
    
    # Collections
    @var items = ["apple", "banana", "cherry"]
    @var settings = Dict("theme" => "dark", "lang" => "en")
    
    # Custom types
    @var point = (x=10, y=20)
end
```

## State Management

### Variable Persistence

Variables persist between frames and maintain their values:

```julia
@window "Counter" begin
    @var count = 0
    
    @simple_label display = "Count: $count"
    @button increment = "+"
    @button decrement = "-"
    
    @onclick increment begin
        @var count = count + 1  # Updates persisted value
    end
    
    @onclick decrement begin
        @var count = count - 1
    end
end
```

### Reactive Variables

Reactive variables automatically update when their dependencies change:

```julia
@window "Calculator" begin
    @var a = 10
    @var b = 20
    @var operation = "+"
    
    # Automatically updates when a, b, or operation changes
    @reactive result = begin
        if operation == "+"
            a + b
        elseif operation == "-"
            a - b
        elseif operation == "*"
            a * b
        else
            b != 0 ? a / b : 0
        end
    end
    
    @simple_label display = "$(a) $(operation) $(b) = $(result)"
end
```

### Cross-Window State

Each window has isolated state, but you can share data through external variables:

```julia
# Shared state outside windows
shared_settings = Dict("theme" => "dark")

ctx = @context begin
    @window "Main" begin
        @var local_data = "Window 1"
        # Can read shared_settings but changes won't persist
    end
    
    @window "Settings" begin
        @var local_data = "Window 2"  # Different from Window 1
        # Also can access shared_settings
    end
end
```

## Widget Reference

### Text Widgets

#### @text - Multi-line Text Display
```julia
@text content = "Multi-line text\nwith line breaks\nand automatic wrapping"

# Dynamic content
@var user_name = "Alice"
@text greeting = "Welcome back, $(user_name)!\n\nYou have 3 new messages."
```

#### @simple_label - Single Line Labels
```julia
@simple_label title = "Application Title"
@simple_label status = "Ready"

# With reactive content
@var items_count = 5
@simple_label counter = "Items: $(items_count)"
```

### Interactive Widgets

#### @button - Clickable Buttons
```julia
# Basic button
@button save_btn = "Save File"
@button load_btn = "Load File"
```

#### @checkbox - Boolean Toggle
```julia
@checkbox enable_sound = true
@checkbox auto_save = false

# Access the value in reactive expressions
@reactive status = enable_sound ? "Sound ON" : "Sound OFF"
```

#### @slider - Numeric Input
```julia
@slider volume = 0.7 range(0.0, 1.0)
@slider temperature = 20.0 range(-10.0, 40.0)
@slider count = 50 range(0, 100)

# Use in reactive expressions
@reactive volume_db = 20 * log10(volume)
@simple_label db_display = "$(round(volume_db, digits=1)) dB"
```

### Advanced Widgets

#### Custom Widget Patterns
```julia
# Grouped controls
@window "Audio Settings" begin
    @simple_label title = "Volume Controls"
    @slider master_volume = 0.8 range(0.0, 1.0)
    @slider music_volume = 0.6 range(0.0, 1.0)
    @slider sfx_volume = 0.9 range(0.0, 1.0)
    
    # Mute all button
    @button mute_all = "Mute All"
    @onclick mute_all begin
        @var master_volume = 0.0
        @var music_volume = 0.0
        @var sfx_volume = 0.0
    end
end
```

## Control Flow

### @when - Conditional Rendering

Render widgets only when a condition is true:

```julia
@window "Conditional Demo" begin
    @checkbox show_advanced = false
    
    @when show_advanced begin
        @simple_label advanced_title = "Advanced Settings"
        @slider precision = 0.01 range(0.001, 0.1)
        @checkbox debug_mode = false
    end
end
```

**Complex conditions:**
```julia
@var user_level = "admin"
@var logged_in = true

@when logged_in && user_level == "admin" begin
    @button delete_all = "Delete All Users"
    @button backup_db = "Backup Database"
end
```

### @foreach - Dynamic Lists

Create widgets dynamically from collections:

```julia
@window "Dynamic Lists" begin
    @var fruits = ["Apple", "Banana", "Cherry"]
    
    @foreach fruit in fruits begin
        @simple_label "label_$(lowercase(fruit))" = "Fruit: $(fruit)"
        @button "btn_$(lowercase(fruit))" = "Select $(fruit)"
    end
end
```

**With indices:**
```julia
@var tasks = ["Task 1", "Task 2", "Task 3"]
@var completed = [false, true, false]

@foreach (i, task) in enumerate(tasks) begin
    @checkbox "done_$(i)" = completed[i]
    @simple_label "task_$(i)" = task
    
    @onclick "done_$(i)" begin
        # Note: This would need array update macros
        @popup "Task $(i) toggled!"
    end
end
```

**Dynamic collections:**
```julia
@window "Todo App" begin
    @var todos = []
    @var new_todo = ""
    
    # Add button (textbox needs implementation)
    @button add_todo = "Add Todo"
    
    @onclick add_todo begin
        if !isempty(new_todo)
            # Would need array manipulation
            @popup "Todo added!"
        end
    end
    
    # Dynamic list
    @foreach (i, todo) in enumerate(todos) begin
        @row [20, -1, 60] begin
            @checkbox "completed_$(i)" = false
            @simple_label "todo_$(i)" = todo
            @button "delete_$(i)" = "×"
        end
    end
end
```

## Layout System

### @column - Vertical Layout
```julia
@column begin
    @simple_label title = "Vertical Layout"
    @button btn1 = "First Button"
    @button btn2 = "Second Button"
    @slider value = 0.5 range(0.0, 1.0)
end
```

### @row - Horizontal Layout
```julia
# Equal spacing
@row [-1, -1, -1] begin
    @button left = "Left"
    @button center = "Center"
    @button right = "Right"
end

# Fixed and flexible widths
@row [100, 200, -1] begin
    @simple_label fixed1 = "100px"
    @simple_label fixed2 = "200px"
    @simple_label flexible = "Fills remaining space"
end
```

### @panel - Grouped Content
```julia
@panel "Graphics Settings" begin
    @checkbox vsync = true
    @slider brightness = 1.0 range(0.0, 2.0)
    @slider contrast = 1.0 range(0.0, 2.0)
end

@panel "Audio Settings" begin
    @slider master_volume = 0.8 range(0.0, 1.0)
    @checkbox mute = false
end
```

### Complex Layouts
```julia
@window "Complex Layout" begin
    @column begin
        # Header
        @simple_label title = "Application Settings"
        
        # Main content area
        @row [300, -1] begin
            # Left sidebar
            @column begin
                @panel "Categories" begin
                    @button cat1 = "General"
                    @button cat2 = "Graphics"
                    @button cat3 = "Audio"
                end
            end
            
            # Right content
            @column begin
                @panel "Settings" begin
                    @checkbox option1 = true
                    @slider setting1 = 0.5 range(0.0, 1.0)
                end
            end
        end
        
        # Footer
        @row [-1, 100, 100] begin
            @simple_label spacer = ""
            @button cancel = "Cancel"
            @button apply = "Apply"
        end
    end
end
```

## Event Handling

### @onclick - Button Events

Handle button clicks with automatic event detection:

```julia
@window "Events" begin
    @var click_count = 0
    
    @button my_button = "Click me!"
    
    @onclick my_button begin
        @var click_count = click_count + 1
        @popup "Clicked $(click_count) times!"
    end
end
```

### Complex Event Handling

```julia
@window "Advanced Events" begin
    @var mode = "idle"
    @var progress = 0.0
    
    @button start_btn = "Start Process"
    @button stop_btn = "Stop Process"
    @button reset_btn = "Reset"
    
    @onclick start_btn begin
        @var mode = "running"
        @var progress = 0.0
        @popup "Process started!"
    end
    
    @onclick stop_btn begin
        @when mode == "running" begin
            @var mode = "stopped"
            @popup "Process stopped!"
        end
    end
    
    @onclick reset_btn begin
        @var mode = "idle"
        @var progress = 0.0
        @popup "Reset complete!"
    end
    
    # Show different UI based on mode
    @when mode == "running" begin
        @simple_label status = "Running... $(round(progress * 100, digits=1))%"
        # Progress would update from external source
    end
    
    @when mode == "stopped" begin
        @simple_label status = "Stopped at $(round(progress * 100, digits=1))%"
    end
end
```

### @popup - Temporary Messages

Show temporary popup messages:

```julia
@button save_btn = "Save"
@onclick save_btn begin
    # Simulate save operation
    @popup "File saved successfully!"
end

@button error_btn = "Cause Error"
@onclick error_btn begin
    @popup "Error: Could not connect to server!"
end
```

## Advanced Patterns

### State Machines

Implement complex application states:

```julia
@window "State Machine Demo" begin
    @var state = "menu"  # menu, playing, paused, game_over
    @var score = 0
    @var level = 1
    
    @when state == "menu" begin
        @simple_label title = "Game Menu"
        @button start_game = "Start Game"
        @button settings = "Settings"
        
        @onclick start_game begin
            @var state = "playing"
            @var score = 0
            @var level = 1
        end
    end
    
    @when state == "playing" begin
        @simple_label game_info = "Level: $(level) | Score: $(score)"
        @button pause_btn = "Pause"
        @button quit_btn = "Quit to Menu"
        
        @onclick pause_btn begin
            @var state = "paused"
        end
        
        @onclick quit_btn begin
            @var state = "menu"
        end
    end
    
    @when state == "paused" begin
        @simple_label paused = "Game Paused"
        @button resume_btn = "Resume"
        @button quit_btn = "Quit to Menu"
        
        @onclick resume_btn begin
            @var state = "playing"
        end
        
        @onclick quit_btn begin
            @var state = "menu"
        end
    end
end
```

### Data Validation

Implement form validation patterns:

```julia
@window "Form Validation" begin
    @var name = ""
    @var email = ""
    @var age = 0
    
    # Validation rules
    @reactive name_valid = length(name) >= 2
    @reactive email_valid = contains(email, "@") && contains(email, ".")
    @reactive age_valid = age >= 18 && age <= 120
    @reactive form_valid = name_valid && email_valid && age_valid
    
    # Form fields with validation feedback
    @simple_label name_label = name_valid ? "Name: ✓" : "Name: ✗ (min 2 chars)"
    @simple_label email_label = email_valid ? "Email: ✓" : "Email: ✗ (invalid format)"
    @simple_label age_label = age_valid ? "Age: ✓" : "Age: ✗ (18-120)"
    
    # Submit button only enabled when form is valid
    @when form_valid begin
        @button submit = "Submit Form"
        @onclick submit begin
            @popup "Form submitted successfully!"
        end
    end
    
    @when !form_valid begin
        @simple_label disabled = "Please fix validation errors"
    end
end
```

### Multi-Window Applications

Coordinate between multiple windows:

```julia
# Global state (outside @context)
app_data = Dict("current_file" => nothing, "modified" => false)

ctx = @context begin
    @window "Main Editor" begin
        @var content = "Hello World"
        
        @button new_file = "New"
        @button open_file = "Open"
        @button save_file = "Save"
        
        @onclick new_file begin
            @var content = ""
            @open_window "Properties"
        end
        
        @onclick save_file begin
            app_data["modified"] = false
            @popup "File saved!"
        end
        
        @text editor = content
    end
    
    @window "Properties" begin
        @simple_label file_info = "File: $(app_data["current_file"])"
        @simple_label status = app_data["modified"] ? "Modified" : "Saved"
        
        @button close_props = "Close"
        @onclick close_props begin
            @close_window "Properties"
        end
    end
    
    @window "Tools" begin
        @button word_count = "Count Words"
        @onclick word_count begin
            # Would access content from Main Editor somehow
            @popup "Word count feature!"
        end
    end
end
```

## Best Practices

### 1. Naming Conventions

```julia
# Use descriptive names for widgets
@button save_document = "Save Document"      # Good
@button btn1 = "Save"                       # Poor

# Use consistent prefixes for related widgets
@button file_new = "New"
@button file_open = "Open"
@button file_save = "Save"

# Use snake_case for variable names
@var user_name = "John"                     # Good
@var userName = "John"                      # Inconsistent with Julia style
```

### 2. State Organization

```julia
# Group related state together
@window "Settings" begin
    # Graphics settings
    @var graphics_vsync = true
    @var graphics_resolution = "1920x1080"
    @var graphics_quality = "high"
    
    # Audio settings  
    @var audio_master_volume = 0.8
    @var audio_music_volume = 0.6
    @var audio_sfx_volume = 0.9
end
```

### 3. Reactive Programming

```julia
# Good: Simple reactive expressions
@reactive full_name = "$(first_name) $(last_name)"
@reactive percentage = "$(round(value * 100, digits=1))%"

# Avoid: Complex reactive expressions (use multiple steps)
@reactive complex_result = begin
    if mode == "advanced"
        result = compute_complex_value(a, b, c)
        format_result(result, precision)
    else
        "Simple: $(a + b)"
    end
end

# Better: Break into steps
@reactive is_advanced = mode == "advanced"
@reactive raw_result = is_advanced ? compute_complex_value(a, b, c) : (a + b)
@reactive formatted_result = is_advanced ? format_result(raw_result, precision) : "Simple: $(raw_result)"
```

### 4. Layout Patterns

```julia
# Use consistent spacing
@row [100, 150, -1, 80] begin  # Fixed, Fixed, Fill, Fixed
    @simple_label col1 = "Label"
    @simple_label col2 = "Value"
    @simple_label col3 = "Description"
    @button action = "Action"
end

# Group related controls
@panel "Connection Settings" begin
    @simple_label host_label = "Host:"
    # @textbox host = "localhost"  # When implemented
    @simple_label port_label = "Port:"
    # @number port = 8080          # When implemented
end
```

## Common Pitfalls

### 1. Dynamic Widget Names

**❌ WRONG:**
```julia
@foreach item in items begin
    widget_name = "btn_$(item)"     # Runtime variable
    @button widget_name = item      # Macro sees :widget_name symbol
end
```

**✅ CORRECT:**
```julia
@foreach item in items begin
    @button "btn_$(item)" = item    # Direct string interpolation
end
```

### 2. Variable Scoping

Variables are scoped to their window:

```julia
@context begin
    @window "Window 1" begin
        @var shared_name = "John"   # Only available in Window 1
    end
    
    @window "Window 2" begin
        @var shared_name = "Jane"   # Different variable, same name
        # Cannot access Window 1's shared_name
    end
end
```

### 3. Event Handler Timing

Events are processed after the widget is rendered:

```julia
@button my_btn = "Click"
@onclick my_btn begin
    @var counter = counter + 1  # This happens after button rendering
end
@simple_label display = "Count: $(counter)"  # Shows previous frame's value
```

### 4. Array and Collection Updates

Currently, updating collections requires external logic:

```julia
# This doesn't work as expected:
@var items = ["a", "b", "c"]
@onclick add_btn begin
    @var items = push!(items, "d")  # May not trigger updates correctly
end

# Better: Use external state management for complex collections
```

## Migration from Low-level API

### Before and After Examples

**Low-level API:**
```julia
function create_ui(ctx)
    # Manual state management
    static button_count = Ref(0)
    static slider_val = Ref(0.5)
    static checkbox_state = Ref(true)
    
    begin_frame(ctx)
    
    if begin_window(ctx, "My App", Rect(10, 10, 300, 200)) != 0
        layout_row!(ctx, 1, nothing, 0)
        
        if button(ctx, "Click me") != 0
            button_count[] += 1
        end
        
        label(ctx, "Clicked $(button_count[]) times")
        
        slider!(ctx, slider_val, 0.0, 1.0)
        label(ctx, "Value: $(round(slider_val[], digits=2))")
        
        checkbox!(ctx, "Enable feature", checkbox_state)
        
        end_window(ctx)
    end
    
    end_frame(ctx)
end
```

**Macro DSL:**
```julia
ctx = @context begin
    @window "My App" begin
        @var button_count = 0
        
        @button click_me = "Click me"
        @onclick click_me begin
            @var button_count = button_count + 1
        end
        
        @simple_label count_display = "Clicked $(button_count) times"
        
        @slider slider_val = 0.5 range(0.0, 1.0)
        @reactive value_display = "Value: $(round(slider_val, digits=2))"
        @simple_label value_label = value_display
        
        @checkbox enable_feature = true
    end
end
```

### Gradual Migration Strategy

1. **Start with @context wrapper:**
```julia
# Wrap existing low-level code
ctx = @context begin
    # Your existing low-level UI code here
    if begin_window(ctx, "App", rect) != 0
        # ...
        end_window(ctx)
    end
end
```

2. **Convert windows one by one:**
```julia
ctx = @context begin
    # New macro DSL window
    @window "Settings" begin
        @var volume = 0.8
        @slider volume_control = volume range(0.0, 1.0)
    end
    
    # Existing low-level window
    if begin_window(ctx, "Legacy", rect) != 0
        # Old code
        end_window(ctx)
    end
end
```

3. **Replace widgets incrementally within windows:**
```julia
@window "Mixed" begin
    # New macro widgets
    @var enabled = true
    @checkbox enable_feature = enabled
    
    # Old low-level widgets (using ctx from @context)
    layout_row!(ctx, 2, [100, -1], 0)
    label(ctx, "Old style label")
    if button(ctx, "Old button") != 0
        # Handle click
    end
end
```

## Examples

### Complete Todo Application

```julia
ctx = @context begin
    @window "Todo List Manager" begin
        @var todos = [
            Dict("text" => "Learn Julia", "done" => false),
            Dict("text" => "Build GUI", "done" => true),
            Dict("text" => "Deploy app", "done" => false)
        ]
        @var new_todo_text = ""
        @var filter_mode = "all"  # all, active, completed
        
        # Header
        @simple_label title = "My Todo List"
        
        # Add new todo section
        @row [200, 100, -1] begin
            # @textbox new_todo = new_todo_text  # When textbox is implemented
            @button add_todo = "Add Todo"
            @simple_label spacer = ""
        end
        
        # Filter buttons
        @row [-1, -1, -1] begin
            @button filter_all = "All"
            @button filter_active = "Active"
            @button filter_completed = "Completed"
        end
        
        @onclick filter_all begin
            @var filter_mode = "all"
        end
        
        @onclick filter_active begin
            @var filter_mode = "active"
        end
        
        @onclick filter_completed begin
            @var filter_mode = "completed"
        end
        
        # Todo list
        @foreach (i, todo) in enumerate(todos) begin
            # Filter logic (would need better collection support)
            @when (filter_mode == "all") || 
                  (filter_mode == "active" && !todo["done"]) ||
                  (filter_mode == "completed" && todo["done"]) begin
                
                @row [30, -1, 80] begin
                    @checkbox "todo_$(i)" = todo["done"]
                    @simple_label "text_$(i)" = todo["text"]
                    @button "delete_$(i)" = "Delete"
                end
                
                @onclick "delete_$(i)" begin
                    @popup "Todo deleted!"  # Would need collection manipulation
                end
            end
        end
        
        # Statistics
        @reactive total_count = length(todos)
        @reactive completed_count = sum(todo["done"] for todo in todos)
        @reactive active_count = total_count - completed_count
        
        @simple_label stats = "Total: $(total_count) | Active: $(active_count) | Completed: $(completed_count)"
    end
end
```

### Settings Panel with Validation

```julia
ctx = @context begin
    @window "Application Settings" begin
        # User settings
        @var user_name = "User"
        @var user_email = "user@example.com"
        @var user_age = 25
        
        # Graphics settings
        @var graphics_vsync = true
        @var graphics_quality = 0.8
        @var graphics_fullscreen = false
        
        # Audio settings
        @var audio_master = 0.8
        @var audio_music = 0.6
        @var audio_effects = 0.9
        @var audio_muted = false
        
        # Validation
        @reactive name_valid = length(user_name) >= 2
        @reactive email_valid = contains(user_email, "@")
        @reactive age_valid = user_age >= 13 && user_age <= 120
        @reactive settings_valid = name_valid && email_valid && age_valid
        
        # UI Layout
        @column begin
            @panel "User Information" begin
                @simple_label name_status = name_valid ? "Name: ✓" : "Name: ✗ (too short)"
                @simple_label email_status = email_valid ? "Email: ✓" : "Email: ✗ (invalid)"
                @simple_label age_status = age_valid ? "Age: ✓" : "Age: ✗ (13-120)"
            end
            
            @panel "Graphics" begin
                @checkbox vsync_toggle = graphics_vsync
                @slider quality_slider = graphics_quality range(0.0, 1.0)
                @checkbox fullscreen_toggle = graphics_fullscreen
                
                @reactive quality_text = "Quality: $(round(graphics_quality * 100))%"
                @simple_label quality_display = quality_text
            end
            
            @panel "Audio" begin
                @checkbox mute_all = audio_muted
                
                @when !audio_muted begin
                    @slider master_volume = audio_master range(0.0, 1.0)
                    @slider music_volume = audio_music range(0.0, 1.0)
                    @slider effects_volume = audio_effects range(0.0, 1.0)
                    
                    @reactive master_percent = "Master: $(round(audio_master * 100))%"
                    @reactive music_percent = "Music: $(round(audio_music * 100))%"
                    @reactive effects_percent = "Effects: $(round(audio_effects * 100))%"
                    
                    @simple_label master_display = master_percent
                    @simple_label music_display = music_percent
                    @simple_label effects_display = effects_percent
                end
                
                @when audio_muted begin
                    @simple_label muted_notice = "All audio is muted"
                end
            end
            
            # Action buttons
            @row [-1, 100, 100, 100] begin
                @simple_label spacer = ""
                
                @button reset_btn = "Reset"
                @onclick reset_btn begin
                    @var graphics_vsync = true
                    @var graphics_quality = 0.8
                    @var graphics_fullscreen = false
                    @var audio_master = 0.8
                    @var audio_music = 0.6
                    @var audio_effects = 0.9
                    @var audio_muted = false
                    @popup "Settings reset to defaults!"
                end
                
                @when settings_valid begin
                    @button save_btn = "Save"
                    @onclick save_btn begin
                        @popup "Settings saved successfully!"
                    end
                end
                
                @when !settings_valid begin
                    @simple_label save_disabled = "Fix errors to save"
                end
                
                @button cancel_btn = "Cancel"
                @onclick cancel_btn begin
                    @close_window "Application Settings"
                end
            end
        end
    end
end
```

---

This guide covers the complete Macro DSL system. For more examples and advanced patterns, see the [examples directory](../examples/) and the [main documentation](../README.md).