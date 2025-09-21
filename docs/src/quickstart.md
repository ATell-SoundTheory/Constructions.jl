# Quickstart

```@meta
CurrentModule = Constructions
```

This page shows the basics of defining a construction, placing elements, and creating dependencies.

## Basic usage

```julia
julia> using Constructions

julia> C = Constructions.Construction()
Constructions.Construction(Dict{String, Constructions.AbstractGeometricElement}())

julia> @place C "A" 1
1

julia> @place C "B" 2
2

julia> @construct C "S" + "A" "B"   # defines S = A + B
3

julia> C["S"]
3

julia> @modify C "A" 10  # propagates to S
10

julia> C["S"]
12
```

## Replacement and removal

```julia
julia> @replace C "S" * "A" "B"  # new rule S = A*B
20

julia> @remove C "B"

julia> C["S"]  # removed because it depended on B
ERROR: ArgumentError: Element S not found.
```

## Plotting (optional)

If Plots.jl is available, a recipe is provided via the ConstructionsPlotsExt extension. Load Plots before plotting:

```julia
using Plots
plot(C)
```

The plotting extension loads automatically on Julia ≥ 1.9 when Plots is in the environment.
