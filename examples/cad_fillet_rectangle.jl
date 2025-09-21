#!/usr/bin/env julia

using Constructions
using Plots
using PGA2D

# 2D helpers (PGA2D points in/out; NamedTuple for plotting coords)
xy(p) = begin
    t = PGA2D.coords(p)
    (x = float(t[1]), y = float(t[2]))
end
pt(x, y) = PGA2D.point(float(x), float(y))
vadd(a, b) = (x = a.x + b.x, y = a.y + b.y)
vsub(a, b) = (x = a.x - b.x, y = a.y - b.y)
vmul(a, s) = (x = a.x * s, y = a.y * s)
norm2(a) = hypot(a.x, a.y)
normalize(a) = (n = norm2(a); n == 0 ? (x = 0.0, y = 0.0) : (x = a.x / n, y = a.y / n))
dot(a, b) = a.x * b.x + a.y * b.y
crossz(a, b) = a.x * b.y - a.y * b.x
perp_ccw(a) = (x = -a.y, y = a.x)
perp_cw(a)  = (x =  a.y, y = -a.x)

"""
    fillet_corner_pga2d(Pprev, V, Pnext, r) -> (T1, T2, O)

Compute tangent points T1, T2 on edges (Pprev->V) and (V->Pnext) and arc center O for a
fillet of radius r at corner V using inward normals and the internal bisector. For r≈0 or
degenerate corners, returns V.
"""
function fillet_corner_pga2d(Pprev, V, Pnext, r)
    if r <= 0
        return (V, V, V)
    end
    # work in Euclidean coordinates for stability
    Ap = xy(Pprev); Bp = xy(V); Cp = xy(Pnext)
    # rays from corner V along the two edges
    r1 = normalize(vsub(Ap, Bp))   # from V to Pprev
    r2 = normalize(vsub(Cp, Bp))   # from V to Pnext
    # interior wedge orientation
    z = crossz(r2, r1)
    # inward normals pointing into the wedge
    n1 = z > 0 ? perp_cw(r1) : perp_ccw(r1)
    n2 = z > 0 ? perp_ccw(r2) : perp_cw(r2)
    n1 = normalize(n1); n2 = normalize(n2)
    # half-angle sine using the wedge angle between r1 and r2
    cφ = clamp(dot(r1, r2), -1.0, 1.0)
    s_half = sqrt(0.5 * (1 - cφ))
    if s_half ≤ eps()
        return (V, V, V)
    end
    b = normalize(vadd(n1, n2))
    δ = r / s_half
    Oe = vadd(Bp, vmul(b, δ))
    T1e = vsub(Oe, vmul(n1, r))
    T2e = vsub(Oe, vmul(n2, r))
    return (pt(T1e.x, T1e.y), pt(T2e.x, T2e.y), pt(Oe.x, Oe.y))
end

"""
    draw_fillet_rect(C)

Plot a rectangle with filleted corners using values from construction C.
"""
function draw_fillet_rect(C)
    center = C["center"]
    w = float(C["w"]); h = float(C["h"]); r = float(C["r"])
    hw, hh = w / 2, h / 2
    A = pt(center.x - hw, center.y - hh)
    B = pt(center.x + hw, center.y - hh)
    Cc = pt(center.x + hw, center.y + hh)
    D = pt(center.x - hw, center.y + hh)

    # clamp r to feasible range
    r = min(r, hw - 1e-6, hh - 1e-6)

    corners = [(D, A, B), (A, B, Cc), (B, Cc, D), (Cc, D, A)]
    fillets = map(t -> fillet_corner_pga2d(t[1], t[2], t[3], r), corners)

    default(size=(700, 520), legend=false, aspect_ratio=1)
    plt = plot(xlim=(center.x - w, center.x + w), ylim=(center.y - h, center.y + h))

    # draw edges as straight segments between tangent points and arcs for corners
    # order: A->B, B->C, C->D, D->A
    # Extract tangent points and centers
    (TA1, TB1, O1) = fillets[1]  # corner at A
    (TA2, TB2, O2) = fillets[2]  # corner at B
    (TA3, TB3, O3) = fillets[3]  # corner at C
    (TA4, TB4, O4) = fillets[4]  # corner at D

    # edges between tangent points
    TA1n, TB1n, TA2n, TB2n, TA3n, TB3n, TA4n, TB4n = xy(TA1), xy(TB1), xy(TA2), xy(TB2), xy(TA3), xy(TB3), xy(TA4), xy(TB4)
    plot!(plt, [TB1n.x, TA2n.x], [TB1n.y, TA2n.y], lw=3, color=:steelblue) # A->B edge
    plot!(plt, [TB2n.x, TA3n.x], [TB2n.y, TA3n.y], lw=3, color=:steelblue) # B->C edge
    plot!(plt, [TB3n.x, TA4n.x], [TB3n.y, TA4n.y], lw=3, color=:steelblue) # C->D edge
    plot!(plt, [TB4n.x, TA1n.x], [TB4n.y, TA1n.y], lw=3, color=:steelblue) # D->A edge

    # arcs at each corner
    for (i, (T1, T2, O)) in enumerate(fillets)
        if T1 !== T2
            T1n, T2n, On = xy(T1), xy(T2), xy(O)
            θ1 = atan(T1n.y - On.y, T1n.x - On.x)
            θ2 = atan(T2n.y - On.y, T2n.x - On.x)
            # Respect polygon turn at this corner to pick CW/CCW arc
            Pprev, Vp, Pnext = corners[i]
            Ap, Bp, Cp = xy(Pprev), xy(Vp), xy(Pnext)
            t_in  = normalize(vsub(Bp, Ap))  # along boundary into V
            t_out = normalize(vsub(Cp, Bp))  # along boundary out of V
            sgn = crossz(t_in, t_out)        # >0 means CCW turn
            if sgn ≥ 0
                dθ = mod(θ2 - θ1, 2π)
                if dθ > π
                    # swap to take the short CCW arc
                    θ1, θ2 = θ2, θ1
                    dθ = mod(θ2 - θ1, 2π)
                end
                θs = range(θ1, θ1 + dθ; length=50)
            else
                dθ = mod(θ1 - θ2, 2π)
                if dθ > π
                    θ1, θ2 = θ2, θ1
                    dθ = mod(θ1 - θ2, 2π)
                end
                θs = range(θ1, θ1 - dθ; length=50)
            end
            rarc = hypot(T1n.x - On.x, T1n.y - On.y)
            plot!(plt, On.x .+ rarc .* cos.(θs), On.y .+ rarc .* sin.(θs), lw=3, color=:steelblue)
        end
    end

    # show driving dimensions
    annotate!(plt, center.x, center.y - hh - 0.2, text("w=$(round(w; digits=2))", 8))
    annotate!(plt, center.x + hw + 0.2, center.y, text("h=$(round(h; digits=2))", 8))
    annotate!(plt, center.x - hw + 0.2, center.y + hh - 0.2, text("r=$(round(r; digits=2))", 8, :red))

    plt
end

# Build construction
C = Construction()
@place C "center" (x=0.0, y=0.0)
@place C "w" 3.0
@place C "h" 2.0
@place C "r" 0.4

display(draw_fillet_rect(C))
