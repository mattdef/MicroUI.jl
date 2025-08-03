using Documenter
using MicroUI
using MicroUI.Macros

makedocs(
    sitename = "MicroUI.jl",
    authors = "Mattdef",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://github.com/mattdef/MicroUI.jl",
        sidebar_sitename = false
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "manual/getting_started.md",
            "API Reference" => "manual/api_reference.md",
        ],
    ],
    modules = [MicroUI],
    checkdocs = :none,
    linkcheck = false,
    clean = true,
)

# Deploy to GitHub Pages
deploydocs(
    repo = "github.com/mattdef/MicroUI.jl.git",
    target = "build",
    branch = "gh-pages",
    devbranch = "main"
)