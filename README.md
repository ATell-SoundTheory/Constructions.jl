# Constructions

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ATell-SoundTheory.github.io/Constructions.jl/dev)
[![Build Status](https://github.com/ATell-SoundTheory/Constructions.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ATell-SoundTheory/Constructions.jl/actions/workflows/CI.yml?query=branch%3Amain)

#= Example for additional structures

struct Triangle
    A
    B
    C
end

@recipe function triangle_plot_recipe(t::Triangle)
    if is_point(t.A) && is_point(t.B) && is_point(t.C)
        opacity --> 0.25
        (xa,ya) = point_coordinates(t.A)
        (xb,yb) = point_coordinates(t.B)
        (xc,yc) = point_coordinates(t.C)
        Shape([xa,xb,xc],[ya,yb,yc])
    else
        nothing
    end
end

=#