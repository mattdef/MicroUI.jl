using SimpleDraw

include("../src/MicroUI.jl")
using .MicroUI


# Structure pour gérer les glyphes
mutable struct Glyph
    texture_id::GLuint
    width::Int
    height::Int
    bearing_x::Int
    bearing_y::Int
    advance::Int
end

# Structure pour gérer les polices
mutable struct Font
    glyphs::Dict{Char, Glyph}
    size::Int
    
    Font() = new()
end

# Cache pour les textures de texte rendu
mutable struct TextCache
    cache::Dict{String, GLuint}
    max_size::Int
    
    TextCache(max_size::Int = 100) = new(Dict{String, GLuint}(), max_size)
end

# Structure pour gérer l'état de l'application
mutable struct AppState
    window::GLFW.Window
    ctx::MicroUI.Context
    textbox_content::String
    show_popup::Bool
    prev_mouse_pressed::Bool
    font::Font
    text_cache::TextCache
    
    AppState() = new()
end

# Backend de rendu avec support de texte
mutable struct GLRenderer
    shader_program::GLuint
    text_shader_program::GLuint
    vao::GLuint
    vbo::GLuint
    text_vao::GLuint
    text_vbo::GLuint
    
    GLRenderer() = new()
end

# Variable globale pour l'état de l'application
global_app_state = nothing

# Vertex shader pour rectangles
const VERTEX_SHADER = """
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec4 aColor;

uniform mat4 projection;
out vec4 vertexColor;

void main()
{
    gl_Position = projection * vec4(aPos, 0.0, 1.0);
    vertexColor = aColor;
}
"""

# Fragment shader pour rectangles
const FRAGMENT_SHADER = """
#version 330 core
in vec4 vertexColor;
out vec4 FragColor;

void main()
{
    FragColor = vertexColor;
}
"""

# Vertex shader pour texte
const TEXT_VERTEX_SHADER = """
#version 330 core
layout (location = 0) in vec4 vertex; // <vec2 pos, vec2 tex>
out vec2 TexCoords;

uniform mat4 projection;

void main()
{
    gl_Position = projection * vec4(vertex.xy, 0.0, 1.0);
    TexCoords = vertex.zw;
}
"""

# Fragment shader pour texte
const TEXT_FRAGMENT_SHADER = """
#version 330 core
in vec2 TexCoords;
out vec4 color;

uniform sampler2D text;
uniform vec4 textColor;

void main()
{
    vec4 sampled = vec4(1.0, 1.0, 1.0, texture(text, TexCoords).r);
    color = textColor * sampled;
}
"""

function create_shader(shader_type::GLenum, source::String)
    shader = glCreateShader(shader_type)
    glShaderSource(shader, 1, [pointer(source)], C_NULL)
    glCompileShader(shader)
    
    # Vérifier la compilation
    success = GLint[0]
    glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    if success[1] == GL_FALSE
        info_log = Vector{GLchar}(undef, 512)
        glGetShaderInfoLog(shader, 512, C_NULL, info_log)
        error("Shader compilation failed: $(String(info_log))")
    end
    
    return shader
end

function create_shader_program(vertex_source::String, fragment_source::String)
    vertex_shader = create_shader(GL_VERTEX_SHADER, vertex_source)
    fragment_shader = create_shader(GL_FRAGMENT_SHADER, fragment_source)
    
    program = glCreateProgram()
    glAttachShader(program, vertex_shader)
    glAttachShader(program, fragment_shader)
    glLinkProgram(program)
    
    # Vérifier le linkage
    success = GLint[0]
    glGetProgramiv(program, GL_LINK_STATUS, success)
    if success[1] == GL_FALSE
        error("Shader program linking failed")
    end
    
    # Nettoyer les shaders
    glDeleteShader(vertex_shader)
    glDeleteShader(fragment_shader)
    
    return program
end

# Version simplifiée sans FreeType pour éviter les problèmes de compatibilité
function init_simple_font(size::Int)
    font = Font()
    font.size = size
    font.glyphs = Dict{Char, Glyph}()
    
    # Créer des glyphes simples avec des mesures fixes
    # Dans une vraie implémentation, on chargerait une bitmap font
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    
    # Créer une texture simple pour tous les caractères
    char_width = size ÷ 2
    char_height = size
    
    for c in Char(32):Char(126)  # Caractères imprimables ASCII
        # Créer une texture simple (un rectangle blanc)
        texture = GLuint[0]
        glGenTextures(1, texture)
        glBindTexture(GL_TEXTURE_2D, texture[1])
        
        # Données de texture simple - rectangle blanc
        if c == ' '
            # Espace = texture transparente
            bitmap_data = zeros(UInt8, char_width * char_height)
        else
            # Autres caractères = rectangle blanc simple
            bitmap_data = fill(UInt8(255), char_width * char_height)
        end
        
        glTexImage2D(
            GL_TEXTURE_2D, 0, GL_RED, char_width, char_height, 0,
            GL_RED, GL_UNSIGNED_BYTE, bitmap_data
        )
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        
        glyph = Glyph(
            texture[1],
            char_width,
            char_height,
            0,
            char_height,
            char_width
        )
        
        font.glyphs[c] = glyph
    end
    
    return font
end

function load_glyph!(font::Font, char::Char)
    # Dans cette version simplifiée, tous les glyphes sont pré-chargés
    # Si le caractère n'existe pas, on utilise un glyphe par défaut
    if !haskey(font.glyphs, char)
        char_width = font.size ÷ 2
        char_height = font.size
        
        texture = GLuint[0]
        glGenTextures(1, texture)
        glBindTexture(GL_TEXTURE_2D, texture[1])
        
        bitmap_data = fill(UInt8(255), char_width * char_height)
        glTexImage2D(
            GL_TEXTURE_2D, 0, GL_RED, char_width, char_height, 0,
            GL_RED, GL_UNSIGNED_BYTE, bitmap_data
        )
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        
        glyph = Glyph(texture[1], char_width, char_height, 0, char_height, char_width)
        font.glyphs[char] = glyph
    end
end

function measure_text(font::Font, text::String)
    width = 0
    height = font.size
    
    for char in text
        if haskey(font.glyphs, char)
            glyph = font.glyphs[char]
            width += glyph.advance
            height = max(height, glyph.height)
        else
            # Caractère non trouvé, utiliser une largeur par défaut
            width += font.size ÷ 2
        end
    end
    
    return (width, height)
end

function init_renderer(renderer::GLRenderer, width::Int, height::Int)
    # Créer le programme shader pour les rectangles
    renderer.shader_program = create_shader_program(VERTEX_SHADER, FRAGMENT_SHADER)
    
    # Créer le programme shader pour le texte
    renderer.text_shader_program = create_shader_program(TEXT_VERTEX_SHADER, TEXT_FRAGMENT_SHADER)
    
    # VAO et VBO pour les rectangles
    vao = GLuint[0]
    vbo = GLuint[0]
    glGenVertexArrays(1, vao)
    glGenBuffers(1, vbo)
    
    renderer.vao = vao[1]
    renderer.vbo = vbo[1]
    
    glBindVertexArray(renderer.vao)
    glBindBuffer(GL_ARRAY_BUFFER, renderer.vbo)
    
    # Configuration des attributs de vertex pour rectangles
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), Ptr{Cvoid}(0))
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), Ptr{Cvoid}(2 * sizeof(GLfloat)))
    glEnableVertexAttribArray(1)
    
    # VAO et VBO pour le texte
    text_vao = GLuint[0]
    text_vbo = GLuint[0]
    glGenVertexArrays(1, text_vao)
    glGenBuffers(1, text_vbo)
    
    renderer.text_vao = text_vao[1]
    renderer.text_vbo = text_vbo[1]
    
    glBindVertexArray(renderer.text_vao)
    glBindBuffer(GL_ARRAY_BUFFER, renderer.text_vbo)
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat) * 6 * 4, C_NULL, GL_DYNAMIC_DRAW)
    
    # Configuration des attributs de vertex pour le texte
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), Ptr{Cvoid}(0))
    glEnableVertexAttribArray(0)
    
    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindVertexArray(0)
    
    # Configurer la matrice de projection pour les deux shaders
    left, right = 0.0f0, Float32(width)
    bottom, top = Float32(height), 0.0f0
    near, far = -1.0f0, 1.0f0
    
    projection = [
        2.0f0/(right-left)  0.0f0               0.0f0   -(right+left)/(right-left);
        0.0f0               2.0f0/(top-bottom)  0.0f0   -(top+bottom)/(top-bottom);
        0.0f0               0.0f0               -2.0f0/(far-near)  -(far+near)/(far-near);
        0.0f0               0.0f0               0.0f0   1.0f0
    ]
    
    # Projection pour rectangles
    glUseProgram(renderer.shader_program)
    projection_loc = glGetUniformLocation(renderer.shader_program, "projection")
    glUniformMatrix4fv(projection_loc, 1, GL_FALSE, projection)
    
    # Projection pour texte
    glUseProgram(renderer.text_shader_program)
    projection_loc = glGetUniformLocation(renderer.text_shader_program, "projection")
    glUniformMatrix4fv(projection_loc, 1, GL_FALSE, projection)
    
    # Activer le blending pour la transparence
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

function render_rect(renderer::GLRenderer, rect::MicroUI.Rect, color::MicroUI.Color)
    x1, y1 = Float32(rect.x), Float32(rect.y)
    x2, y2 = Float32(rect.x + rect.w), Float32(rect.y + rect.h)
    
    r = Float32(color.r) / 255.0f0
    g = Float32(color.g) / 255.0f0
    b = Float32(color.b) / 255.0f0
    a = Float32(color.a) / 255.0f0
    
    # Données de vertex : position (x, y) + couleur (r, g, b, a)
    vertices = Float32[
        x1, y1, r, g, b, a,  # Coin inférieur gauche
        x2, y1, r, g, b, a,  # Coin inférieur droit
        x2, y2, r, g, b, a,  # Coin supérieur droit
        x1, y1, r, g, b, a,  # Coin inférieur gauche
        x2, y2, r, g, b, a,  # Coin supérieur droit
        x1, y2, r, g, b, a   # Coin supérieur gauche
    ]
    
    glBindBuffer(GL_ARRAY_BUFFER, renderer.vbo)
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW)
    
    glUseProgram(renderer.shader_program)
    glBindVertexArray(renderer.vao)
    glDrawArrays(GL_TRIANGLES, 0, 6)
end

function render_text(renderer::GLRenderer, font::Font, text::String, pos::MicroUI.Vec2, color::MicroUI.Color)
    # Utiliser le shader de texte
    glUseProgram(renderer.text_shader_program)
    
    # Définir la couleur du texte
    text_color_loc = glGetUniformLocation(renderer.text_shader_program, "textColor")
    glUniform4f(text_color_loc, 
                Float32(color.r)/255.0f0, 
                Float32(color.g)/255.0f0, 
                Float32(color.b)/255.0f0, 
                Float32(color.a)/255.0f0)
    
    glActiveTexture(GL_TEXTURE0)
    glBindVertexArray(renderer.text_vao)
    
    x = Float32(pos.x)
    y = Float32(pos.y)
    
    # Rendre chaque caractère
    for char in text
        if !haskey(font.glyphs, char)
            # Charger le glyphe s'il n'existe pas
            load_glyph!(font, char)
        end
        
        if haskey(font.glyphs, char)
            glyph = font.glyphs[char]
            
            xpos = x + Float32(glyph.bearing_x)
            ypos = y - Float32(glyph.height - glyph.bearing_y)
            
            w = Float32(glyph.width)
            h = Float32(glyph.height)
            
            # Créer les vertices pour ce caractère
            vertices = Float32[
                xpos,     ypos + h,   0.0, 0.0,
                xpos,     ypos,       0.0, 1.0,
                xpos + w, ypos,       1.0, 1.0,
                xpos,     ypos + h,   0.0, 0.0,
                xpos + w, ypos,       1.0, 1.0,
                xpos + w, ypos + h,   1.0, 0.0
            ]
            
            # Lier la texture du glyphe
            glBindTexture(GL_TEXTURE_2D, glyph.texture_id)
            
            # Mettre à jour le VBO
            glBindBuffer(GL_ARRAY_BUFFER, renderer.text_vbo)
            glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertices), vertices)
            glBindBuffer(GL_ARRAY_BUFFER, 0)
            
            # Rendre le glyphe
            glDrawArrays(GL_TRIANGLES, 0, 6)
            
            # Avancer à la position du prochain caractère
            x += Float32(glyph.advance)
        end
    end
    
    glBindVertexArray(0)
    glBindTexture(GL_TEXTURE_2D, 0)
end

function render_icon(renderer::GLRenderer, icon::MicroUI.IconId, rect::MicroUI.Rect, color::MicroUI.Color)
    # Rendu simplifié des icônes comme des rectangles colorés
    render_rect(renderer, rect, color)
end

function process_commands(renderer::GLRenderer, ctx::MicroUI.Context, font::Font)
    iter = MicroUI.CommandIterator(ctx.command_list)
    
    while true
        has_command, cmd_type, cmd_offset = MicroUI.next_command!(iter)
        if !has_command
            break
        end
        
        if cmd_type == MicroUI.COMMAND_RECT
            cmd = MicroUI.read_command(ctx.command_list, cmd_offset, MicroUI.RectCommand)
            render_rect(renderer, cmd.rect, cmd.color)
        elseif cmd_type == MicroUI.COMMAND_TEXT
            cmd = MicroUI.read_command(ctx.command_list, cmd_offset, MicroUI.TextCommand)
            text = MicroUI.get_string(ctx.command_list, cmd.str_index)
            render_text(renderer, font, text, cmd.pos, cmd.color)
        elseif cmd_type == MicroUI.COMMAND_ICON
            cmd = MicroUI.read_command(ctx.command_list, cmd_offset, MicroUI.IconCommand)
            render_icon(renderer, cmd.id, cmd.rect, cmd.color)
        elseif cmd_type == MicroUI.COMMAND_CLIP
            # Pour simplifier, on ignore le clipping dans cet exemple
            continue
        end
    end
end

# Callbacks GLFW vers MicroUI (version simplifiée)
function mouse_callback(window, x::Float64, y::Float64)
    if global_app_state !== nothing
        MicroUI.input_mousemove!(global_app_state.ctx, Int(x), Int(y))
    end
    return nothing
end

function mouse_button_callback(window, button, action, mods)
    if global_app_state !== nothing
        x, y = GLFW.GetCursorPos(window)
        
        # Bouton gauche de la souris (button == 0)
        if Int(button) == 0
            if Int(action) == 1  # PRESS
                MicroUI.input_mousedown!(global_app_state.ctx, Int(x), Int(y), MicroUI.MOUSE_LEFT)
            elseif Int(action) == 0  # RELEASE
                MicroUI.input_mouseup!(global_app_state.ctx, Int(x), Int(y), MicroUI.MOUSE_LEFT)
            end
        end
    end
    return nothing
end

function key_callback(window, key, scancode, action, mods)
    if global_app_state !== nothing
        if Int(action) == 1 || Int(action) == 2  # PRESS or REPEAT
            if Int(key) == 259  # BACKSPACE
                MicroUI.input_keydown!(global_app_state.ctx, MicroUI.KEY_BACKSPACE)
            elseif Int(key) == 257  # ENTER
                MicroUI.input_keydown!(global_app_state.ctx, MicroUI.KEY_RETURN)
            end
        elseif Int(action) == 0  # RELEASE
            if Int(key) == 259  # BACKSPACE
                MicroUI.input_keyup!(global_app_state.ctx, MicroUI.KEY_BACKSPACE)
            elseif Int(key) == 257  # ENTER
                MicroUI.input_keyup!(global_app_state.ctx, MicroUI.KEY_RETURN)
            end
        end
    end
    return nothing
end

function char_callback(window, codepoint)
    if global_app_state !== nothing
        # Filtrer les caractères de contrôle
        if codepoint >= 32 && codepoint < 127
            char_str = string(Char(codepoint))
            MicroUI.input_text!(global_app_state.ctx, char_str)
        end
    end
    return nothing
end

# Fonction principale pour configurer MicroUI
function setup_microui_callbacks(ctx::MicroUI.Context, font::Font)
    # Fonction pour mesurer la largeur du texte
    ctx.text_width = function(font_ref, text::String)
        width, height = measure_text(font, text)
        return width
    end
    
    # Fonction pour obtenir la hauteur du texte
    ctx.text_height = function(font_ref)
        return font.size
    end
    
    # Utiliser la fonction de dessin par défaut
    ctx.draw_frame = MicroUI.default_draw_frame
end

function poll_input(app_state::AppState)
    # Méthode alternative de polling des inputs si les callbacks ne fonctionnent pas
    window = app_state.window
    
    # Position de la souris
    x, y = GLFW.GetCursorPos(window)
    MicroUI.input_mousemove!(app_state.ctx, Int(x), Int(y))
    
    # État du bouton gauche de la souris
    try
        left_pressed = GLFW.GetMouseButton(window, 0) == 1  # 0 = left button, 1 = pressed
        
        # Détecter les changements d'état
        if left_pressed && !app_state.prev_mouse_pressed
            # Bouton vient d'être pressé
            MicroUI.input_mousedown!(app_state.ctx, Int(x), Int(y), MicroUI.MOUSE_LEFT)
        elseif !left_pressed && app_state.prev_mouse_pressed
            # Bouton vient d'être relâché
            MicroUI.input_mouseup!(app_state.ctx, Int(x), Int(y), MicroUI.MOUSE_LEFT)
        end
        
        app_state.prev_mouse_pressed = left_pressed
    catch e
        # Si GetMouseButton ne fonctionne pas, on ignore silencieusement
        println("Warning: Mouse input polling failed: ", e)
    end
end

function init_app()
    # Initialiser GLFW
    if !GLFW.Init()
        error("Failed to initialize GLFW")
    end
    
    # Configurer GLFW
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
    
    # Créer la fenêtre
    window = GLFW.CreateWindow(800, 600, "MicroUI.jl with Simple Text Rendering")
    if window == C_NULL
        GLFW.Terminate()
        error("Failed to create GLFW window")
    end
    
    GLFW.MakeContextCurrent(window)
    GLFW.SwapInterval(1)  # V-sync
    
    # Créer l'état de l'application
    app_state = AppState()
    app_state.window = window
    app_state.ctx = MicroUI.Context()
    app_state.textbox_content = "Hello World!"
    app_state.show_popup = false
    app_state.prev_mouse_pressed = false
    app_state.text_cache = TextCache()
    
    # Initialiser une police simple (sans FreeType pour éviter les problèmes)
    try
        app_state.font = init_simple_font(16)
        println("Simple font initialized successfully")
    catch e
        println("Error initializing font: ", e)
        # Créer une police complètement par défaut
        app_state.font = Font()
        app_state.font.size = 16
        app_state.font.glyphs = Dict{Char, Glyph}()
    end
    
    # Configurer MicroUI
    setup_microui_callbacks(app_state.ctx, app_state.font)
    MicroUI.init!(app_state.ctx)
    
    # Assigner la variable globale
    global global_app_state = app_state
    
    # Configurer les callbacks GLFW
    try
        GLFW.SetCursorPosCallback(window, mouse_callback)
        GLFW.SetMouseButtonCallback(window, mouse_button_callback)
        GLFW.SetKeyCallback(window, key_callback)
        GLFW.SetCharCallback(window, char_callback)
    catch e
        println("Warning: Could not set some GLFW callbacks: ", e)
    end
    
    return app_state
end

function render_ui(app_state::AppState)
    ctx = app_state.ctx
    
    # Commencer la frame UI
    MicroUI.begin_frame(ctx)
    
    # Fenêtre principale
    if MicroUI.begin_window(ctx, "Main Window", MicroUI.Rect(50, 50, 400, 300)) != 0
        
        # Header
        MicroUI.header(ctx, "Application Example with Text Rendering")
        
        # Layout pour label et textbox sur la même ligne
        MicroUI.layout_row!(ctx, 2, [100, 200], 0)
        
        # Label
        MicroUI.label(ctx, "Input:")
        
        # Textbox
        textbox_ref = Ref(app_state.textbox_content)
        if (MicroUI.textbox!(ctx, textbox_ref, 100) & Int(MicroUI.RES_CHANGE)) != 0
            app_state.textbox_content = textbox_ref[]
        end
        
        # Ligne avec du texte de démo
        MicroUI.layout_row!(ctx, 1, [-1], 0)
        MicroUI.text(ctx, "This text is rendered using simple bitmap textures!")
        
        # Bouton centré
        MicroUI.layout_row!(ctx, 1, [-1], 0)  # Pleine largeur
        if (MicroUI.button(ctx, "Show Popup") & Int(MicroUI.RES_SUBMIT)) != 0
            app_state.show_popup = true
            MicroUI.open_popup!(ctx, "popup")
        end
        
        MicroUI.end_window(ctx)
    end
    
    # Popup
    if app_state.show_popup
        if MicroUI.begin_popup(ctx, "popup") != 0
            MicroUI.label(ctx, "This is a popup with text rendering!")
            MicroUI.text(ctx, "Content: " * app_state.textbox_content)
            MicroUI.text(ctx, "Rendered with simple bitmap glyphs!")
            
            if (MicroUI.button(ctx, "Close") & Int(MicroUI.RES_SUBMIT)) != 0
                app_state.show_popup = false
            end
            
            MicroUI.end_popup(ctx)
        else
            app_state.show_popup = false
        end
    end
    
    # Terminer la frame UI
    MicroUI.end_frame(ctx)
end

function main()
    app_state = init_app()
    renderer = GLRenderer()
    
    # Initialiser le renderer OpenGL
    width, height = GLFW.GetWindowSize(app_state.window)
    init_renderer(renderer, Int(width), Int(height))
    
    println("Application démarrée avec rendu de texte simple. Utilisez la souris pour interagir avec l'interface.")
    
    # Boucle principale
    while !GLFW.WindowShouldClose(app_state.window)
        GLFW.PollEvents()
        
        # Polling alternatif des inputs (au cas où les callbacks ne fonctionnent pas)
        poll_input(app_state)
        
        # Clear screen
        glClearColor(0.2f0, 0.3f0, 0.3f0, 1.0f0)
        glClear(GL_COLOR_BUFFER_BIT)
        
        # Rendre l'UI
        render_ui(app_state)
        
        # Traiter les commandes de rendu
        process_commands(renderer, app_state.ctx, app_state.font)
        
        GLFW.SwapBuffers(app_state.window)
        
        # Petite pause pour éviter une utilisation CPU excessive
        sleep(0.016)  # ~60 FPS
    end
    
    # Nettoyage
    GLFW.Terminate()
end

# Lancer l'application
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end