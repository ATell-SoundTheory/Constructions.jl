using Constructions
using PGA2D
using Plots

# Coordinate extractor for plotting
yx(P) = begin t = PGA2D.coords(P); (x = float(t[1]), y = float(t[2])) end

# Utility: circumcircle via PGA2D, but return nothing if degenerate
circ_ppp(A,B,C) = PGA2D.try_circumcircle_ppp(A,B,C)

# Choose points D,E,F on sides BC, CA, AB respectively (not vertices)
function choose_cevians(A,B,C)
    a, b, c = yx(A), yx(B), yx(C)
    D = PGA2D.point(0.6*b.x + 0.4*c.x, 0.6*b.y + 0.4*c.y) # on BC
    E = PGA2D.point(0.35*c.x + 0.65*a.x, 0.35*c.y + 0.65*a.y) # on CA
    F = PGA2D.point(0.25*a.x + 0.75*b.x, 0.25*a.y + 0.75*b.y) # on AB
    D,E,F
end

C = Construction()
@place C "A" point(-1.1, 0.3)
@place C "B" point( 1.2, 0.0)
@place C "C" point( 0.0, 1.35)

# Place D,E,F
let A=C["A"], B=C["B"], CC=C["C"]
    D,E,F = choose_cevians(A,B,CC)
    @place C "D" D
    @place C "E" E
    @place C "F" F
end

# Three circumcircles through (A,E,F), (B,F,D), (C,D,E)
@construct(C, "circ_A", circ_ppp, "A", "E", "F")
@construct(C, "circ_B", circ_ppp, "B", "F", "D")
@construct(C, "circ_C", circ_ppp, "C", "D", "E")

# The three circles are concurrent at the Miquel point M
# Compute M as the (robust) intersection of two circles; pick the solution near triangle interior
function miquel_point(c1, c2, A, B, C)
    c1 === nothing && return nothing
    c2 === nothing && return nothing
    O1, R1 = yx(c1.center), c1.radius
    O2, R2 = yx(c2.center), c2.radius
    d = hypot(O2.x - O1.x, O2.y - O1.y)
    if d == 0 || d > R1 + R2 + 1e-12 || d < abs(R1 - R2) - 1e-12
        return nothing
    end
    a = (R1^2 - R2^2 + d^2) / (2d)
    h2 = R1^2 - a^2
    h = h2 < 0 ? 0.0 : sqrt(h2)
    ex = (O2.x - O1.x) / d
    ey = (O2.y - O1.y) / d
    x0 = O1.x + a*ex
    y0 = O1.y + a*ey
    # two intersections
    xi1 = x0 + h * (-ey)
    yi1 = y0 + h * ( ex)
    xi2 = x0 - h * (-ey)
    yi2 = y0 - h * ( ex)
    # pick closer to triangle centroid
    axy, bxy, cxy = yx(A), yx(B), yx(C)
    G = (x = (axy.x+bxy.x+cxy.x)/3, y = (axy.y+bxy.y+cxy.y)/3)
    d1 = hypot(xi1 - G.x, yi1 - G.y)
    d2 = hypot(xi2 - G.x, yi2 - G.y)
    P = d1 < d2 ? (x = xi1, y = yi1) : (x = xi2, y = yi2)
    PGA2D.point(P.x, P.y)
end

@construct(C, "M", (c1,c2,A,B,C)->miquel_point(c1,c2,A,B,C), "circ_A", "circ_B", "A", "B", "C")

# Plot
plt = plot(size=(720,560), legend=false, aspect_ratio=1, xlim=(-2,2), ylim=(-2,2))
A,B,Cc = C["A"], C["B"], C["C"]
a,b,c = yx(A), yx(B), yx(Cc)
# triangle
plot!(plt, [a.x,b.x], [a.y,b.y], lw=2, color=:steelblue)
plot!(plt, [b.x,c.x], [b.y,c.y], lw=2, color=:steelblue)
plot!(plt, [c.x,a.x], [c.y,a.y], lw=2, color=:steelblue)
# D,E,F
for nm in ("D","E","F")
    p = yx(C[nm]); scatter!(plt, [p.x],[p.y], ms=6, color=:purple)
end
# Circles
for nm in ("circ_A","circ_B","circ_C")
    circ = C[nm]
    if circ !== nothing
        o = yx(circ.center); R = circ.radius
        θs = range(0,2π; length=256)
        plot!(plt, o.x .+ R .* cos.(θs), o.y .+ R .* sin.(θs), lw=2, alpha=0.7)
    end
end
# Miquel point
M = yx(C["M"])
scatter!(plt, [M.x], [M.y], ms=7, color=:red)

display(plt)
