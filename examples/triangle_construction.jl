#!/usr/bin/env julia

using Constructions
using Plots

# Simple 2D geometry helpers (NamedTuple points)
point(x, y) = (x = float(x), y = float(y))
midpoint(P, Q) = point((P.x + Q.x) / 2, (P.y + Q.y) / 2)

function circumcenter(A, B, C)
    ax, ay = A.x, A.y
    bx, by = B.x, B.y
    cx, cy = C.x, C.y
    d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    if iszero(d)
        return nothing
    end
    ux = ((ax^2 + ay^2) * (by - cy) + (bx^2 + by^2) * (cy - ay) + (cx^2 + cy^2) * (ay - by)) / d
    uy = ((ax^2 + ay^2) * (cx - bx) + (bx^2 + by^2) * (ax - cx) + (cx^2 + cy^2) * (bx - ax)) / d
    O = point(ux, uy)
    r = hypot(O.x - ax, O.y - ay)
    (center = O, radius = r)
end

# Build construction
C = Construction()
@place C "A" point(-1.0, 0.2)
@place C "B" point(1.0, 0.0)
@place C "C" point(0.0, 1.2)

# Midpoints
@construct(C, "M_ab", midpoint, "A", "B")
@construct(C, "M_bc", midpoint, "B", "C")
@construct(C, "M_ca", midpoint, "C", "A")

# Centroid
@construct(C, "G", (A,B,C) -> point((A.x+B.x+C.x)/3, (A.y+B.y+C.y)/3), "A", "B", "C")

# Circumcircle (NamedTuple center, radius)
@construct(C, "circ", circumcenter, "A", "B", "C")

# Plot
default(size=(600, 520), legend=false, aspect_ratio=1)

function draw(C)
    A, B, Cpt = C["A"], C["B"], C["C"]
    Mab, Mbc, Mca = C["M_ab"], C["M_bc"], C["M_ca"]
    G = C["G"]
    circ = C["circ"]

    plt = plot(xlim=(-2,2), ylim=(-2,2), title="Triangle construction")

    # triangle edges
    plot!(plt, [A.x, B.x], [A.y, B.y], lw=2, color=:steelblue)
    plot!(plt, [B.x, Cpt.x], [B.y, Cpt.y], lw=2, color=:steelblue)
    plot!(plt, [Cpt.x, A.x], [Cpt.y, A.y], lw=2, color=:steelblue)

    # medians
    plot!(plt, [A.x, Mbc.x], [A.y, Mbc.y], ls=:dash, color=:gray)
    plot!(plt, [B.x, Mca.x], [B.y, Mca.y], ls=:dash, color=:gray)
    plot!(plt, [Cpt.x, Mab.x], [Cpt.y, Mab.y], ls=:dash, color=:gray)

    # points
    scatter!(plt, [A.x,B.x,Cpt.x], [A.y,B.y,Cpt.y], ms=6, color=:black, label="A,B,C")
    scatter!(plt, [G.x], [G.y], ms=7, color=:red, label="G (centroid)")

    # circumcircle if defined
    if circ !== nothing
        O, r = circ.center, circ.radius
        θ = range(0, 2π; length=200)
        plot!(plt, O.x .+ r .* cos.(θ), O.y .+ r .* sin.(θ), color=:orange, lw=2)
        scatter!(plt, [O.x], [O.y], ms=6, color=:orange)
    end
    plt
end

display(draw(C))
