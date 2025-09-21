using Constructions
using PGA2D
using Plots

yx(P) = begin t = PGA2D.coords(P); (x = float(t[1]), y = float(t[2])) end

# Foot of perpendicular from P to line AB
function foot_on_line(P, A, B)
    p, a, b = yx(P), yx(A), yx(B)
    v = (x = b.x - a.x, y = b.y - a.y)
    w = (x = p.x - a.x, y = p.y - a.y)
    den = v.x^2 + v.y^2
    t = den == 0 ? 0.0 : (w.x * v.x + w.y * v.y) / den
    PGA2D.point(a.x + t*v.x, a.y + t*v.y)
end

C = Construction()
@place C "A" point(-1.1, 0.2)
@place C "B" point( 1.2, 0.0)
@place C "C" point( 0.0, 1.35)

# Altitude feet
@construct(C, "Ha", (A,B,C)->foot_on_line(A,B,C), "A","B","C")
@construct(C, "Hb", (B,C,A)->foot_on_line(B,C,A), "B","C","A")
@construct(C, "Hc", (C,A,B)->foot_on_line(C,A,B), "C","A","B")

# Orthocenter via intersection of, e.g., AH_a and BH_b
# We can compute as intersection of lines through A->Ha and B->Hb numerically for plotting (directly)

plt = plot(size=(720,560), legend=false, aspect_ratio=1, xlim=(-2,2), ylim=(-2,2))
A,Bp,Cp = C["A"], C["B"], C["C"]
a,b,c = yx(A), yx(Bp), yx(Cp)
plot!(plt, [a.x,b.x], [a.y,b.y], lw=2, color=:steelblue)
plot!(plt, [b.x,c.x], [b.y,c.y], lw=2, color=:steelblue)
plot!(plt, [c.x,a.x], [c.y,a.y], lw=2, color=:steelblue)
# Orthic triangle
Ha,Hb,Hc = yx(C["Ha"]), yx(C["Hb"]), yx(C["Hc"])
plot!(plt, [Ha.x,Hb.x], [Ha.y,Hb.y], lw=2, color=:orange)
plot!(plt, [Hb.x,Hc.x], [Hb.y,Hc.y], lw=2, color=:orange)
plot!(plt, [Hc.x,Ha.x], [Hc.y,Ha.y], lw=2, color=:orange)
# Nine-point circle center N: midpoint of orthocenter and circumcenter; draw nine-point through three midpoints
# Use PGA2D if available
O = PGA2D.try_circumcenter_ppp(C["A"],C["B"],C["C"])
H = PGA2D.try_orthocenter_ppp(C["A"],C["B"],C["C"])
N = begin 
    o, h = yx(O), yx(H)
    PGA2D.point((o.x+h.x)/2, (o.y+h.y)/2) 
end
circ = PGA2D.try_circumcircle_ppp(C["A"],C["B"],C["C"]) 
if circ !== nothing
    θ = range(0,2π; length=256)
    oc = yx(circ.center); R = circ.radius
    plot!(plt, oc.x .+ (R/2) .* cos.(θ), oc.y .+ (R/2) .* sin.(θ), color=:purple, lw=2)
end

scatter!(plt, [Ha.x,Hb.x,Hc.x], [Ha.y,Hb.y,Hc.y], ms=6, color=:orange)

display(plt)
