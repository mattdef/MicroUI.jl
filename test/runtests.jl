using MicroUI
using Test

include("utils_tests.jl")

@testset "All Tests" begin

    include("basic_tests.jl")  # Inclure les tests de base

    include("controls_tests.jl")  # Inclure les tests des contrôles

    include("graphics_tests.jl")  # Inclure les tests graphiques

    include("commands_tests.jl")  # Inclure les tests des commandes

    include("perf_tests.jl")  # Inclure les tests de performance

end