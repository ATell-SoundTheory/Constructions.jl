using Constructions
using Documenter

DocMeta.setdocmeta!(Constructions, :DocTestSetup, :(using Constructions); recursive=true)

makedocs(;
    modules=[Constructions],
    authors="Andreas Tell <atell@soundtheory.com> and contributors",
    repo="https://github.com/ATell-SoundTheory/Constructions.jl/blob/{commit}{path}#{line}",
    sitename="Constructions.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://ATell-SoundTheory.github.io/Constructions.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/ATell-SoundTheory/Constructions.jl",
    devbranch="main",
)
