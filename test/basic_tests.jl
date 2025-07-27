using Test

@testset "Basic Tests" begin

    @testset "Types et Constructeurs" begin
        # Test des constructeurs paramétriques
        @test MicroUI.vec2(10, 20) isa MicroUI.Vec2{Int}
        @test MicroUI.vec2(10.0, 20.0) isa MicroUI.Vec2{Float64}
        @test MicroUI.vec2(Float32, 10, 20) isa MicroUI.Vec2{Float32}
        
        @test MicroUI.rect(0, 0, 100, 50) isa MicroUI.Rect{Int}
        @test MicroUI.rect(Float32, 0, 0, 100, 50) isa MicroUI.Rect{Float32}
        
        # Test des couleurs - CORRECTION: utilisation des champs corrects
        c = MicroUI.color(255, 128, 64, 255)
        @test c.r == 255 && c.g == 128 && c.b == 64 && c.a == 255
        
        # Test des enums
        @test MicroUI.COLOR_BUTTON isa MicroUI.UIColor
        @test MicroUI.ICON_CLOSE isa MicroUI.UIIcon
        @test MicroUI.CLIP_ALL isa MicroUI.ClipResult
    end

    @testset "Conversion de Types" begin
        # Test de conversion Vec2 - utilisation de convert explicite si nécessaire
        v_int = MicroUI.vec2(10, 20)
        v_float = MicroUI.vec2(Float32, v_int[1], v_int[2])  # Conversion manuelle
        @test v_float isa MicroUI.Vec2{Float32}
        @test v_float[1] == 10.0f0 && v_float[2] == 20.0f0
        
        # Test de conversion Rect - CORRECTION: utilisation du convert implémenté
        r_int = MicroUI.rect(0, 0, 100, 50)
        r_float = convert(MicroUI.Rect{Float64}, r_int)
        @test r_float isa MicroUI.Rect{Float64}
        @test r_float.w == 100.0 && r_float.h == 50.0
    end

    @testset "Context et Initialisation" begin
        # Test de création de contexte avec différents types
        ctx_f32, renderer = MicroUI.create_context_with_buffer_renderer(Float32; w=400, h=300)
        @test ctx_f32 isa MicroUI.Context{Float32}
        @test renderer isa MicroUI.BufferRenderer
        
        ctx_f64, _ = MicroUI.create_context_with_buffer_renderer(Float64; w=400, h=300)
        @test ctx_f64 isa MicroUI.Context{Float64}
        
        # Test d'initialisation - CORRECTION: vérification avec haskey sur Dict
        MicroUI.init!(ctx_f32)
        @test !isempty(ctx_f32.style.colors)
        @test haskey(ctx_f32.style.colors, MicroUI.COLOR_BUTTON)
    end

    @testset "Gestion des Entrées" begin
        ctx, _ = MicroUI.create_context_with_buffer_renderer(Float32; w=200, h=200)
        
        # Test de mouvement de souris
        MicroUI.input_mousemove!(ctx, 50.0f0, 75.0f0)
        @test ctx.mouse_pos[1] == 50.0f0 && ctx.mouse_pos[2] == 75.0f0
        
        # Test avec Vec2
        pos = MicroUI.vec2(Float32, 100, 120)
        MicroUI.input_mousemove!(ctx, pos)
        @test ctx.mouse_pos == pos
        
        # Test des entrées clavier
        MicroUI.input_keydown!(ctx, :backspace)
        @test ctx.key_pressed == :backspace
        
        MicroUI.input_keyup!(ctx, :backspace)
        @test ctx.key_pressed === nothing
        
        # Test d'entrée de texte
        MicroUI.input_text!(ctx, "Hello")
        @test ctx.input_buffer == "Hello"
    end

    @testset "Gestion des ID" begin
        ctx, _ = MicroUI.create_context_with_buffer_renderer()
        
        # Test de génération d'ID
        id1 = MicroUI.get_id!(ctx, "button1")
        id2 = MicroUI.get_id!(ctx, "button2")
        @test id1 != id2
        
        # Test de pile d'ID
        initial_stack_size = length(ctx.id_stack)
        MicroUI.push_id!(ctx, "window1")
        @test length(ctx.id_stack) == initial_stack_size + 1
        
        MicroUI.pop_id!(ctx)
        @test length(ctx.id_stack) == initial_stack_size
        
        # Test de focus
        MicroUI.set_focus!(ctx, id1)
        @test ctx.focus_id == id1
        @test ctx.updated_focus == true
    end

    @testset "Clipping" begin
        ctx, _ = MicroUI.create_context_with_buffer_renderer(Float32; w=400, h=300)
        
        # Test de clipping initial
        initial_clip = MicroUI.current_clip_rect(ctx)
        @test initial_clip.w > 1000000  # Rectangle "infini"
        
        # Test d'ajout de zone de clipping
        test_rect = MicroUI.rect(Float32, 10, 10, 100, 100)
        MicroUI.push_clip_rect!(ctx, test_rect)
        
        current_clip = MicroUI.current_clip_rect(ctx)
        @test current_clip.x == 10.0f0
        @test current_clip.w == 100.0f0
        
        # Test de vérification de clipping
        visible_rect = MicroUI.rect(Float32, 20, 20, 50, 50)
        @test MicroUI.check_clip(ctx, visible_rect) == MicroUI.CLIP_NONE
        
        outside_rect = MicroUI.rect(Float32, 200, 200, 50, 50)
        @test MicroUI.check_clip(ctx, outside_rect) == MicroUI.CLIP_ALL
        
        MicroUI.pop_clip_rect!(ctx)
        @test MicroUI.current_clip_rect(ctx) == initial_clip
    end

    @testset "Hachage et ID" begin
        # Test de l'algorithme de hachage FNV-1a
        data1 = Vector{UInt8}("test")
        data2 = Vector{UInt8}("test")
        data3 = Vector{UInt8}("different")
        
        seed = MicroUI.HASH_INITIAL
        hash1 = MicroUI.fnv1a_hash(data1, seed)
        hash2 = MicroUI.fnv1a_hash(data2, seed)
        hash3 = MicroUI.fnv1a_hash(data3, seed)
        
        @test hash1 == hash2  # Même données = même hash
        @test hash1 != hash3  # Données différentes = hash différents
        
        # Test de génération d'ID avec différents types
        ctx, _ = MicroUI.create_context_with_buffer_renderer()
        
        id_string = MicroUI.get_id!(ctx, "button")
        id_different = MicroUI.get_id!(ctx, "different_button")
        id_symbol = MicroUI.get_id!(ctx, :button)
        id_number = MicroUI.get_id!(ctx, 42)
        
        @test id_string isa UInt32
        @test id_symbol isa UInt32
        @test id_number isa UInt32
        @test id_string == id_symbol  
        @test id_string != id_number  
        @test id_symbol != id_number  
        @test id_string != id_different
        @test id_symbol != id_different
    end

end