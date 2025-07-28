# Backend OpenGL pour MicroUI.jl
# Utilise ModernGL et GLFW pour le rendu

using ModernGL
using GLFW
using LinearAlgebra
using Printf

# Include MicroUI (assumé être dans le même dossier ou installé)
include("../src/MicroUI.jl")
using .MicroUI

# Structure pour gérer les ressources OpenGL
mutable struct OpenGLBackend
    # Window
    window::GLFW.Window
    
    # Shaders
    rect_shader::GLuint
    text_shader::GLuint
    
    # Vertex Arrays
    rect_vao::GLuint
    rect_vbo::GLuint
    
    # Textures
    font_texture::GLuint
    icon_texture::GLuint
    
    # Uniforms
    projection_loc::GLint
    
    # Font metrics
    char_width::Int
    char_height::Int
    
    # État
    width::Int
    height::Int
end

# Shader sources
const RECT_VERTEX_SHADER = """
#version 330 core
layout(location = 0) in vec2 position;
layout(location = 1) in vec4 color;

out vec4 frag_color;

uniform mat4 projection;

void main() {
    gl_Position = projection * vec4(position, 0.0, 1.0);
    frag_color = color;
}
"""

const RECT_FRAGMENT_SHADER = """
#version 330 core
in vec4 frag_color;
out vec4 out_color;

void main() {
    out_color = frag_color;
}
"""

const TEXT_VERTEX_SHADER = """
#version 330 core
layout(location = 0) in vec2 position;
layout(location = 1) in vec2 texcoord;
layout(location = 2) in vec4 color;

out vec2 frag_texcoord;
out vec4 frag_color;

uniform mat4 projection;

void main() {
    gl_Position = projection * vec4(position, 0.0, 1.0);
    frag_texcoord = texcoord;
    frag_color = color;
}
"""

const TEXT_FRAGMENT_SHADER = """
#version 330 core
in vec2 frag_texcoord;
in vec4 frag_color;
out vec4 out_color;

uniform sampler2D text_texture;

void main() {
    float alpha = texture(text_texture, frag_texcoord).r;
    out_color = vec4(frag_color.rgb, frag_color.a * alpha);
}
"""

# Créer une texture de police bitmap simple (8x16 par caractère)
function create_font_texture()
    # Police bitmap 8x8 simple pour ASCII 32-127
    # En production, charger une vraie police TTF avec FreeType
    width = 128 * 8  # 128 caractères * 8 pixels de large
    height = 16      # 16 pixels de haut
    
    # Créer des données de test (damier pour visualiser)
    data = zeros(UInt8, width * height)
    
    # Générer une police bitmap basique
    # Pour chaque caractère ASCII imprimable
    for c in 32:127
        char_x = (c - 32) * 8
        # Dessiner un rectangle pour chaque caractère (placeholder)
        for y in 2:14, x in 1:6
            data[y * width + char_x + x + 1] = 255
        end
    end
    
    # Créer la texture OpenGL
    tex = GLuint[0]
    glGenTextures(1, tex)
    glBindTexture(GL_TEXTURE_2D, tex[1])
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, width, height, 0, GL_RED, GL_UNSIGNED_BYTE, data)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    
    return tex[1]
end

# Créer les icônes MicroUI
function create_icon_texture()
    # Texture 64x16 contenant 4 icônes de 16x16
    width, height = 64, 16
    data = zeros(UInt8, width * height)
    
    # Icône CLOSE (X)
    for i in 0:15
        data[i * width + i + 1] = 255
        data[i * width + (15-i) + 1] = 255
    end
    
    # Icône CHECK (✓)
    for i in 8:15
        data[i * width + (i-4) + 17] = 255
    end
    for i in 0:7
        data[(15-i) * width + i + 17] = 255
    end
    
    # Icône COLLAPSED (▶)
    for i in 0:15
        for j in 0:min(i, 15-i)
            data[i * width + j + 33] = 255
        end
    end
    
    # Icône EXPANDED (▼)
    for i in 0:15
        for j in 0:(15-i)÷2
            data[i * width + (i÷2) + j + 49] = 255
            data[i * width + (i÷2) - j + 49] = 255
        end
    end
    
    tex = GLuint[0]
    glGenTextures(1, tex)
    glBindTexture(GL_TEXTURE_2D, tex[1])
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, width, height, 0, GL_RED, GL_UNSIGNED_BYTE, data)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    
    return tex[1]
end

# Compiler un shader
function compile_shader(source::String, type::GLenum)
    shader = glCreateShader(type)
    glShaderSource(shader, 1, Ptr{GLchar}[pointer(source)], C_NULL)
    glCompileShader(shader)
    
    # Vérifier la compilation
    success = GLint[0]
    glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    if success[1] == GL_FALSE
        log_length = GLint[0]
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, log_length)
        log = zeros(GLchar, log_length[1])
        glGetShaderInfoLog(shader, log_length[1], C_NULL, log)
        error("Shader compilation failed: " * unsafe_string(pointer(log)))
    end
    
    return shader
end

# Créer un programme shader
function create_shader_program(vertex_src::String, fragment_src::String)
    vertex = compile_shader(vertex_src, GL_VERTEX_SHADER)
    fragment = compile_shader(fragment_src, GL_FRAGMENT_SHADER)
    
    program = glCreateProgram()
    glAttachShader(program, vertex)
    glAttachShader(program, fragment)
    glLinkProgram(program)
    
    # Vérifier le link
    success = GLint[0]
    glGetProgramiv(program, GL_LINK_STATUS, success)
    if success[1] == GL_FALSE
        log_length = GLint[0]
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, log_length)
        log = zeros(GLchar, log_length[1])
        glGetProgramInfoLog(program, log_length[1], C_NULL, log)
        error("Program linking failed: " * unsafe_string(pointer(log)))
    end
    
    glDeleteShader(vertex)
    glDeleteShader(fragment)
    
    return program
end

# Initialiser le backend OpenGL
function init_opengl_backend(width::Int, height::Int, title::String)
    # Initialiser GLFW
    GLFW.Init()
    
    # Configurer OpenGL 3.3 Core
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
    
    # Créer la fenêtre
    window = GLFW.CreateWindow(width, height, title)
    GLFW.MakeContextCurrent(window)
    
    # Activer VSync
    GLFW.SwapInterval(1)
    
    # Initialiser OpenGL
    glViewport(0, 0, width, height)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    
    # Créer les shaders
    rect_shader = create_shader_program(RECT_VERTEX_SHADER, RECT_FRAGMENT_SHADER)
    text_shader = create_shader_program(TEXT_VERTEX_SHADER, TEXT_FRAGMENT_SHADER)
    
    # Créer les VAO/VBO pour les rectangles
    vao = GLuint[0]
    vbo = GLuint[0]
    glGenVertexArrays(1, vao)
    glGenBuffers(1, vbo)
    
    glBindVertexArray(vao[1])
    glBindBuffer(GL_ARRAY_BUFFER, vbo[1])
    
    # Position (2 floats)
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), C_NULL)
    
    # Color (4 floats)
    glEnableVertexAttribArray(1)
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), Ptr{Cvoid}(2 * sizeof(GLfloat)))
    
    # Créer les textures
    font_texture = create_font_texture()
    icon_texture = create_icon_texture()
    
    # Obtenir les locations des uniforms
    projection_loc = glGetUniformLocation(rect_shader, "projection")
    
    backend = OpenGLBackend(
        window,
        rect_shader, text_shader,
        vao[1], vbo[1],
        font_texture, icon_texture,
        projection_loc,
        8, 16,  # char dimensions
        width, height
    )
    
    return backend
end

# Mettre à jour la matrice de projection
function update_projection(backend::OpenGLBackend)
    projection = Float32[
        2.0/backend.width  0.0  0.0  -1.0
        0.0  -2.0/backend.height  0.0  1.0
        0.0  0.0  -1.0  0.0
        0.0  0.0  0.0  1.0
    ]
    
    glUseProgram(backend.rect_shader)
    glUniformMatrix4fv(backend.projection_loc, 1, GL_FALSE, projection)
    
    text_proj_loc = glGetUniformLocation(backend.text_shader, "projection")
    glUseProgram(backend.text_shader)
    glUniformMatrix4fv(text_proj_loc, 1, GL_FALSE, projection)
end

# Dessiner un rectangle
function draw_rect_opengl(backend::OpenGLBackend, rect::MicroUI.Rect, color::MicroUI.Color)
    vertices = GLfloat[
        # Position        # Color
        rect.x,           rect.y,           color.r/255, color.g/255, color.b/255, color.a/255,
        rect.x + rect.w,  rect.y,           color.r/255, color.g/255, color.b/255, color.a/255,
        rect.x + rect.w,  rect.y + rect.h,  color.r/255, color.g/255, color.b/255, color.a/255,
        rect.x,           rect.y,           color.r/255, color.g/255, color.b/255, color.a/255,
        rect.x + rect.w,  rect.y + rect.h,  color.r/255, color.g/255, color.b/255, color.a/255,
        rect.x,           rect.y + rect.h,  color.r/255, color.g/255, color.b/255, color.a/255,
    ]
    
    glUseProgram(backend.rect_shader)
    glBindVertexArray(backend.rect_vao)
    glBindBuffer(GL_ARRAY_BUFFER, backend.rect_vbo)
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW)
    glDrawArrays(GL_TRIANGLES, 0, 6)
end

# Dessiner du texte
function draw_text_opengl(backend::OpenGLBackend, text::String, pos::MicroUI.Vec2, color::MicroUI.Color)
    glUseProgram(backend.text_shader)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, backend.font_texture)
    
    x = Float32(pos.x)
    for char in text
        if char >= ' ' && char <= '~'
            char_idx = Int(char) - 32
            u0 = char_idx * 8 / 1024.0
            u1 = (char_idx + 1) * 8 / 1024.0
            
            vertices = GLfloat[
                # Pos                          # UV      # Color
                x,     pos.y,                  u0, 0.0,  color.r/255, color.g/255, color.b/255, color.a/255,
                x + 8, pos.y,                  u1, 0.0,  color.r/255, color.g/255, color.b/255, color.a/255,
                x + 8, pos.y + 16,             u1, 1.0,  color.r/255, color.g/255, color.b/255, color.a/255,
                x,     pos.y,                  u0, 0.0,  color.r/255, color.g/255, color.b/255, color.a/255,
                x + 8, pos.y + 16,             u1, 1.0,  color.r/255, color.g/255, color.b/255, color.a/255,
                x,     pos.y + 16,             u0, 1.0,  color.r/255, color.g/255, color.b/255, color.a/255,
            ]
            
            # Configurer les attributs pour le texte
            glBindBuffer(GL_ARRAY_BUFFER, backend.rect_vbo)
            glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW)
            
            glEnableVertexAttribArray(0)
            glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), C_NULL)
            glEnableVertexAttribArray(1)
            glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), Ptr{Cvoid}(2 * sizeof(GLfloat)))
            glEnableVertexAttribArray(2)
            glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), Ptr{Cvoid}(4 * sizeof(GLfloat)))
            
            glDrawArrays(GL_TRIANGLES, 0, 6)
            
            x += 8
        end
    end
end

# Dessiner une icône
function draw_icon_opengl(backend::OpenGLBackend, id::MicroUI.IconId, rect::MicroUI.Rect, color::MicroUI.Color)
    glUseProgram(backend.text_shader)
    glActiveTexture(GL_TEXTURE0)
    glBindTexture(GL_TEXTURE_2D, backend.icon_texture)
    
    # Position UV de l'icône
    icon_idx = Int(id) - 1
    u0 = icon_idx * 0.25
    u1 = (icon_idx + 1) * 0.25
    
    # Centrer l'icône dans le rectangle
    size = min(rect.w, rect.h)
    x = rect.x + (rect.w - size) ÷ 2
    y = rect.y + (rect.h - size) ÷ 2
    
    vertices = GLfloat[
        x,        y,        u0, 0.0,  color.r/255, color.g/255, color.b/255, color.a/255,
        x + size, y,        u1, 0.0,  color.r/255, color.g/255, color.b/255, color.a/255,
        x + size, y + size, u1, 1.0,  color.r/255, color.g/255, color.b/255, color.a/255,
        x,        y,        u0, 0.0,  color.r/255, color.g/255, color.b/255, color.a/255,
        x + size, y + size, u1, 1.0,  color.r/255, color.g/255, color.b/255, color.a/255,
        x,        y + size, u0, 1.0,  color.r/255, color.g/255, color.b/255, color.a/255,
    ]
    
    glBindBuffer(GL_ARRAY_BUFFER, backend.rect_vbo)
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW)
    
    glEnableVertexAttribArray(0)
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), C_NULL)
    glEnableVertexAttribArray(1)
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), Ptr{Cvoid}(2 * sizeof(GLfloat)))
    glEnableVertexAttribArray(2)
    glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, 8 * sizeof(GLfloat), Ptr{Cvoid}(4 * sizeof(GLfloat)))
    
    glDrawArrays(GL_TRIANGLES, 0, 6)
end

# Exécuter les commandes de rendu MicroUI
function render_microui(backend::OpenGLBackend, ctx::MicroUI.Context)
    # Parcourir les commandes (simplifié pour la démo)
    # En production, il faudrait parser correctement le buffer de commandes
    
    # Pour cette démo, on utilise une approche simplifiée
    # où on intercepte les draw calls directement
end

# État de l'application
mutable struct AppState
    show_window::Bool
    show_message::Bool
    message_text::String
end

# Application principale
function main()
    # Initialiser le backend
    backend = init_opengl_backend(800, 600, "MicroUI OpenGL Demo")
    
    # Initialiser MicroUI
    ctx = MicroUI.Context()
    
    # Configurer les callbacks de mesure de texte
    ctx.text_width = (font, str) -> length(str) * backend.char_width
    ctx.text_height = font -> backend.char_height
    
    # Override des fonctions de dessin pour utiliser OpenGL
    ctx.draw_frame = function(ctx, rect, colorid)
        color = ctx.style.colors[Int(colorid)]
        draw_rect_opengl(backend, rect, color)
        # Dessiner la bordure si nécessaire
        if colorid != MicroUI.COLOR_SCROLLBASE && 
           colorid != MicroUI.COLOR_SCROLLTHUMB && 
           colorid != MicroUI.COLOR_TITLEBG
            if ctx.style.colors[Int(MicroUI.COLOR_BORDER)].a > 0
                border_rect = MicroUI.expand_rect(rect, Int32(1))
                draw_rect_opengl(backend, border_rect, ctx.style.colors[Int(MicroUI.COLOR_BORDER)])
            end
        end
    end
    
    # Intercepter les commandes de dessin
    original_draw_rect = MicroUI.draw_rect!
    draw_rect! = function(ctx, rect, color)
        draw_rect_opengl(backend, rect, color)
        original_draw_rect(ctx, rect, color)
    end
    
    original_draw_text = MicroUI.draw_text!
    draw_text! = function(ctx, font, str, pos, color)
        draw_text_opengl(backend, str, pos, color)
        original_draw_text(ctx, font, str, pos, color)
    end
    
    original_draw_icon = MicroUI.draw_icon!
    draw_icon! = function(ctx, id, rect, color)
        draw_icon_opengl(backend, id, rect, color)
        original_draw_icon(ctx, id, rect, color)
    end
    
    # État de l'application
    state = AppState(true, false, "Hello from Julia!")
    
    # Configurer les callbacks GLFW
    GLFW.SetCursorPosCallback(backend.window) do window, x, y
        MicroUI.input_mousemove!(ctx, Int(x), Int(y))
    end
    
    GLFW.SetMouseButtonCallback(backend.window) do window, button, action, mods
        x, y = GLFW.GetCursorPos(window)
        if button == GLFW.MOUSE_BUTTON_LEFT
            if action == GLFW.PRESS
                MicroUI.input_mousedown!(ctx, Int(x), Int(y), MicroUI.MOUSE_LEFT)
            else
                MicroUI.input_mouseup!(ctx, Int(x), Int(y), MicroUI.MOUSE_LEFT)
            end
        end
    end
    
    GLFW.SetScrollCallback(backend.window) do window, x, y
        MicroUI.input_scroll!(ctx, Int(x * 30), Int(y * -30))
    end
    
    GLFW.SetKeyCallback(backend.window) do window, key, scancode, action, mods
        if action == GLFW.PRESS || action == GLFW.REPEAT
            if key == GLFW.KEY_BACKSPACE
                MicroUI.input_keydown!(ctx, MicroUI.KEY_BACKSPACE)
            elseif key == GLFW.KEY_ENTER
                MicroUI.input_keydown!(ctx, MicroUI.KEY_RETURN)
            end
        else
            if key == GLFW.KEY_BACKSPACE
                MicroUI.input_keyup!(ctx, MicroUI.KEY_BACKSPACE)
            elseif key == GLFW.KEY_ENTER
                MicroUI.input_keyup!(ctx, MicroUI.KEY_RETURN)
            end
        end
    end
    
    GLFW.SetCharCallback(backend.window) do window, char
        MicroUI.input_text!(ctx, string(Char(char)))
    end
    
    # Boucle principale
    while !GLFW.WindowShouldClose(backend.window)
        # Clear
        glClear(GL_COLOR_BUFFER_BIT)
        glClearColor(0.1, 0.1, 0.1, 1.0)
        
        # Mettre à jour la taille si nécessaire
        width, height = GLFW.GetFramebufferSize(backend.window)
        if width != backend.width || height != backend.height
            backend.width = width
            backend.height = height
            glViewport(0, 0, width, height)
            update_projection(backend)
        end
        
        # Commencer la frame MicroUI
        MicroUI.begin_frame(ctx)
        
        # Interface principale
        if state.show_window
            if MicroUI.begin_window(ctx, "My Window", MicroUI.Rect(50, 50, 200, 150))
                # Layout en 2 colonnes
                MicroUI.layout_row!(ctx, 2, [50, -1], 0)
                
                MicroUI.label(ctx, "First:")
                if MicroUI.button(ctx, "Button1") != 0
                    state.show_message = true
                    state.message_text = "Button 1 clicked!"
                end
                
                MicroUI.label(ctx, "Second:")
                if MicroUI.button(ctx, "Button2") != 0
                    state.show_message = true
                    state.message_text = "Button 2 clicked!"
                end
                
                # Texte dans la zone sombre
                MicroUI.layout_row!(ctx, 1, [-1], -1)
                MicroUI.begin_panel(ctx, "content")
                MicroUI.text(ctx, "Hello world!")
                MicroUI.end_panel(ctx)
                
                MicroUI.end_window(ctx)
            end
        end
        
        # Message box
        if state.show_message
            if MicroUI.begin_window_ex(ctx, "Message", 
                MicroUI.Rect(300, 200, 200, 100), 
                UInt16(MicroUI.OPT_NOCLOSE))
                
                MicroUI.layout_row!(ctx, 1, [-1], -25)
                MicroUI.text(ctx, state.message_text)
                
                MicroUI.layout_row!(ctx, 1, [-1], 0)
                if MicroUI.button(ctx, "OK") != 0
                    state.show_message = false
                end
                
                MicroUI.end_window(ctx)
            end
        end
        
        # Terminer la frame
        MicroUI.end_frame(ctx)
        
        # Swap buffers
        GLFW.SwapBuffers(backend.window)
        GLFW.PollEvents()
    end
    
    # Nettoyer
    glDeleteProgram(backend.rect_shader)
    glDeleteProgram(backend.text_shader)
    glDeleteVertexArrays(1, [backend.rect_vao])
    glDeleteBuffers(1, [backend.rect_vbo])
    glDeleteTextures(1, [backend.font_texture])
    glDeleteTextures(1, [backend.icon_texture])
    
    GLFW.DestroyWindow(backend.window)
    GLFW.Terminate()
end

# Lancer l'application
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end