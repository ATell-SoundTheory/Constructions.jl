using Constructions
using PGA2D
using Plots

yx(P) = begin t = PGA2D.coords(P); (x = float(t[1]), y = float(t[2])) end

# Apollonius circle for vertex A: set of points X with XB:XC = k, for k>0
function apollonius_circle(B,C,k)
    b, c = yx(B), yx(C)
    # Center lies on BC; use section formula (internal for k>0)
    cx = (k^2 * c.x - b.x) / (k^2 - 1)
    cy = (k^2 * c.y - b.y) / (k^2 - 1)
    O = PGA2D.point(cx, cy)
    # Radius is |OB| * k / |k^2 - 1|
    R = abs(hypot(cx - b.x, cy - b.y) * k / abs(k^2 - 1))
    (center=O, radius=R)
end

C = Construction()
@place C "A" point(-1.1, 0.2)
@place C "B" point( 1.3, 0.0)
@place C "C" point( 0.0, 1.35)

kA, kB, kC = 1.5, 0.7, 1.2
@construct(C, "ApA", (B,C)->apollonius_circle(B,C,kA), "B","C")
@construct(C, "ApB", (C,A)->apollonius_circle(C,A,kB), "C","A")
@construct(C, "ApC", (A,B)->apollonius_circle(A,B,kC), "A","B")

plt = plot(size=(720,560), legend=false, aspect_ratio=1, xlim=(-2,2), ylim=(-2,2))
A,Bp,Cp = C["A"], C["B"], C["C"]
a,b,c = yx(A), yx(Bp), yx(Cp)
plot!(plt, [a.x,b.x], [a.y,b.y], lw=2, color=:steelblue)
plot!(plt, [b.x,c.x], [b.y,c.y], lw=2, color=:steelblue)
plot!(plt, [c.x,a.x], [c.y,a.y], lw=2, color=:steelblue)
for nm in ("ApA","ApB","ApC")
    ap = C[nm]
    if ap !== nothing
        o = yx(ap.center); R = ap.radius
        θ = range(0, 2π; length=256)
        plot!(plt, o.x .+ R .* cos.(θ), o.y .+ R .* sin.(θ), lw=2)
    end
end

display(plt)
