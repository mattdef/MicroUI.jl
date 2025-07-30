using Test
using BenchmarkTools

include("../src/MicroUI.jl")
using .MicroUI

include("utils_tests.jl")

@time @testset "MicroUI.jl Test Suite" begin

    include("basic_tests.jl")  # Inclure les tests de base

    include("id_tests.jl") # Inclure les tests de collision d'Id

    include("controls_tests.jl")  # Inclure les tests des contrôles

    include("graphics_tests.jl")  # Inclure les tests graphiques

    include("commands_tests.jl")  # Inclure les tests des commandes

    include("regression_tests.jl")  # Inclure les tests de régression

    #include("perf_tests.jl")  # Inclure les tests de performance

end

