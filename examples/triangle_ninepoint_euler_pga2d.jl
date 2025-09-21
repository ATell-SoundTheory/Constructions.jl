using Constructions
using Plots
using PGA2D

# Helpers to extract coordinates from PGA2D points for plotting
yx(P) = begin t = PGA2D.coords(P); (x = float(t[1]), y = float(t[2])) end

# Geo helpers
midpoint_xy(P, Q) = begin Pn, Qn = yx(P), yx(Q); PGA2D.point((Pn.x+Qn.x)/2, (Pn.y+Qn.y)/2) end

# Nine-point circle and Euler line construction with PGA2D
C = Construction()
@place C "A" point(-1.1, 0.2)
@place C "B" point( 1.2, 0.0)
@place C "C" point( 0.0, 1.3)

# Key triangle centers
@construct(C, "O", PGA2D.try_circumcenter_ppp, "A", "B", "C")
@construct(C, "H", PGA2D.try_orthocenter_ppp, "A", "B", "C")
@construct(C, "G", (A,B,C)-> begin a=yx(A); b=yx(B); c=yx(C); point((a.x+b.x+c.x)/3, (a.y+b.y+c.y)/3) end, "A", "B", "C")

# Midpoints of sides
@construct(C, "M_ab", midpoint_xy, "A", "B")
@construct(C, "M_bc", midpoint_xy, "B", "C")
@construct(C, "M_ca", midpoint_xy, "C", "A")

# Nine-point circle center N is midpoint of O and H; radius is half of circumradius
@construct(C, "N", (O,H) -> begin o=yx(O); h=yx(H); point((o.x+h.x)/2, (o.y+h.y)/2) end, "O", "H")

# Circumcircle for radius; then nine-point circle radius = R/2
@construct(C, "circ", PGA2D.try_circumcircle_ppp, "A", "B", "C")

# Plotting
plt = plot(size=(700,540), legend=false, aspect_ratio=1, xlim=(-2,2), ylim=(-2,2))

function draw_triangle!(plt, C)
    A, B, Cc = C["A"], C["B"], C["C"]
    a, b, c = yx(A), yx(B), yx(Cc)
    plot!(plt, [a.x,b.x], [a.y,b.y], lw=2, color=:steelblue)
    plot!(plt, [b.x,c.x], [b.y,c.y], lw=2, color=:steelblue)
    plot!(plt, [c.x,a.x], [c.y,a.y], lw=2, color=:steelblue)
    scatter!(plt, [a.x,b.x,c.x], [a.y,b.y,c.y], ms=5, color=:black)
end

function draw_centers!(plt, C)
    O = C["O"]; H = C["H"]; G = C["G"]; N = C["N"]
    o, h, g, n = yx(O), yx(H), yx(G), yx(N)
    scatter!(plt, [o.x, h.x, g.x, n.x], [o.y, h.y, g.y, n.y], ms=6, color=[:orange,:red,:green,:purple])
    # Euler line: line through O and H (extend for visibility)
    d = (x = h.x - o.x, y = h.y - o.y);
    norm = hypot(d.x, d.y)
    if norm > 0
        d = (x=d.x/norm, y=d.y/norm)
        Plo = (x=o.x - 3d.x, y=o.y - 3d.y)
        Phi = (x=o.x + 3d.x, y=o.y + 3d.y)
        plot!(plt, [Plo.x, Phi.x], [Plo.y, Phi.y], color=:gray, ls=:dash, lw=2)
    end
end

function draw_circles!(plt, C)
    circ = C["circ"]
    if circ !== nothing
        oc = yx(circ.center); R = circ.radius
        θ = range(0, 2π; length=256)
        plot!(plt, oc.x .+ R .* cos.(θ), oc.y .+ R .* sin.(θ), color=:orange, lw=2)
        # Nine-point circle
        N = C["N"]; n = yx(N)
        plot!(plt, n.x .+ (R/2) .* cos.(θ), n.y .+ (R/2) .* sin.(θ), color=:purple, lw=2)
    end
    # midpoints
    for name in ("M_ab","M_bc","M_ca")
        m = yx(C[name]); scatter!(plt, [m.x], [m.y], ms=5, color=:purple)
    end
end

# Compose
begin
    draw_triangle!(plt, C)
    draw_centers!(plt, C)
    draw_circles!(plt, C)
    display(plt)
end
