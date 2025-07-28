using Test
using BenchmarkTools

include("../src/MicroUI.jl")
using .MicroUI
using .MicroUI: MOUSE_LEFT, MOUSE_RIGHT
using .MicroUI: OPT_NOTITLE, OPT_NOCLOSE
using .MicroUI: CLIP_NONE, CLIP_ALL, CLIP_PART
using .MicroUI: RES_SUBMIT, RES_ACTIVE, RES_CHANGE

println("=== Exécution des tests MicroUI.jl ===")

include("utils_tests.jl")

@time @testset "MicroUI.jl Test Suite" begin

    include("basic_tests.jl")  # Inclure les tests de base

    include("controls_tests.jl")  # Inclure les tests des contrôles

    include("graphics_tests.jl")  # Inclure les tests graphiques

    include("commands_tests.jl")  # Inclure les tests des commandes

    include("perf_tests.jl")  # Inclure les tests de performance

    include("regression_tests.jl")  # Inclure les tests de régression

end

