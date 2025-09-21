#!/usr/bin/env julia

using Constructions
using PGA2D
using Plots

# Build construction using PGA2D primitives
C = Construction()
@place C "A" point( -1.0, 0.2)
@place C "B" point(  1.0, 0.0)
@place C "C" point(  0.0, 1.2)

# Centers and circle via PGA2D API
@construct(C, "I", incenter_ppp,       "A", "B", "C")
@construct(C, "circ", circumcircle_ppp, "A", "B", "C")

# A small plotting helper using PGA2D’s plot recipes (if extension is loaded)
default(size=(600, 520), legend=false, aspect_ratio=1)

plt = plot(xlim=(-2,2), ylim=(-2,2), title="PGA2D triangle construction")
scatter!(plt, [C["A"], C["B"], C["C"]], label="A,B,C")
scatter!(plt, [C["I"]], ms=7, color=:red, label="I (incenter)")

let cc = C["circ"]
    if cc !== nothing
        # cc is NamedTuple (center, radius); plot a circle
        O, r = cc.center, cc.radius
        θ = range(0, 2π; length=200)
        xs = real.(O.x) .+ r .* cos.(θ)
        ys = real.(O.y) .+ r .* sin.(θ)
        plot!(plt, xs, ys, color=:orange, lw=2)
        scatter!(plt, [O.x], [O.y], ms=6, color=:orange)
    end
end

display(plt)
