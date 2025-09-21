using Constructions
using Plots
using PGA2D

# Extract plotting coordinates from a PGA2D point
yx(P) = begin t = PGA2D.coords(P); (x = float(t[1]), y = float(t[2])) end

# Foot of perpendicular from point P to the (infinite) line AB using Euclidean math on coordinates
function foot_on_line(P, A, B)
    p, a, b = yx(P), yx(A), yx(B)
    v = (x = b.x - a.x, y = b.y - a.y)
    w = (x = p.x - a.x, y = p.y - a.y)
    den = v.x^2 + v.y^2
    t = den == 0 ? 0.0 : (w.x * v.x + w.y * v.y) / den
    F = (x = a.x + t * v.x, y = a.y + t * v.y)
    PGA2D.point(F.x, F.y)
end

# Construct triangle
C = Construction()
@place C "A" point(-1.1, 0.2)
@place C "B" point( 1.2, 0.0)
@place C "C" point( 0.0, 1.3)

# Circumcircle and a point P on it
@construct(C, "circ", PGA2D.try_circumcircle_ppp, "A", "B", "C")

# Pick a deterministic point P on the circumcircle by angle theta
θ = 0.7 * π
let cc = C["circ"]
    if cc === nothing
        error("Degenerate triangle: no circumcircle; Simson line undefined.")
    end
    O = yx(cc.center); R = cc.radius
    P = PGA2D.point(O.x + R * cos(θ), O.y + R * sin(θ))
    @place C "P" P
end

# Feet of perpendiculars from P to the triangle sides
@construct(C, "F_ab", (P,A,B)->foot_on_line(P,A,B), "P", "A", "B")
@construct(C, "F_bc", (P,B,C)->foot_on_line(P,B,C), "P", "B", "C")
@construct(C, "F_ca", (P,C,A)->foot_on_line(P,C,A), "P", "C", "A")

# Plot
plt = plot(size=(700,540), legend=false, aspect_ratio=1, xlim=(-2,2), ylim=(-2,2))
A,B,Cc = C["A"], C["B"], C["C"]
a,b,c = yx(A), yx(B), yx(Cc)
# triangle
plot!(plt, [a.x,b.x], [a.y,b.y], lw=2, color=:steelblue)
plot!(plt, [b.x,c.x], [b.y,c.y], lw=2, color=:steelblue)
plot!(plt, [c.x,a.x], [c.y,a.y], lw=2, color=:steelblue)
# circumcircle
cc = C["circ"]
if cc !== nothing
    o = yx(cc.center); R = cc.radius
    θs = range(0,2π; length=300)
    plot!(plt, o.x .+ R .* cos.(θs), o.y .+ R .* sin.(θs), color=:orange, lw=2, alpha=0.7)
end
# P and feet
P = yx(C["P"]) ; Fab = yx(C["F_ab"]) ; Fbc = yx(C["F_bc"]) ; Fca = yx(C["F_ca"]) 
scatter!(plt, [P.x],[P.y], ms=6, color=:red)
scatter!(plt, [Fab.x,Fbc.x,Fca.x], [Fab.y,Fbc.y,Fca.y], ms=6, color=:purple)
# Simson line through the three feet
# Draw the line through Fab and Fbc to show collinearity
v = (x = Fbc.x - Fab.x, y = Fbc.y - Fab.y)
if hypot(v.x,v.y) > 0
    v = (x = v.x / hypot(v.x,v.y), y = v.y / hypot(v.x,v.y))
    Plo = (x = Fab.x - 3v.x, y = Fab.y - 3v.y)
    Phi = (x = Fab.x + 3v.x, y = Fab.y + 3v.y)
    plot!(plt, [Plo.x, Phi.x], [Plo.y, Phi.y], color=:purple, lw=2)
end

# Show the plot
display(plt)
