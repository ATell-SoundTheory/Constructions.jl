using Constructions
using Documenter
using Plots
using FFMPEG
using Printf

# Optional PGA2D support for docs rendering (fallback to Euclidean if unavailable)
const HAVE_PGA2D = let ok = false
    try
        @eval import PGA2D
        ok = true
    catch
        ok = false
    end
    ok
end
# Keep docs deterministic and self-contained; examples may use PGA2D,
# but we avoid requiring it in the docs environment.

DocMeta.setdocmeta!(Constructions, :DocTestSetup, :(using Constructions); recursive=true)

# --- Unified geometry helpers (PGA2D if available, else Euclidean fallback) ---
# Define these once at top level to avoid method redefinition and scoping issues.
if HAVE_PGA2D
    pt(x, y) = PGA2D.point(float(x), float(y))
    xy(p) = begin t = PGA2D.coords(p); (x = float(t[1]), y = float(t[2])) end
    midpoint(P, Q) = begin Pn, Qn = xy(P), xy(Q); pt((Pn.x+Qn.x)/2, (Pn.y+Qn.y)/2) end
    circumcircle(A, B, C) = PGA2D.circumcircle_ppp(A, B, C)
else
    pt(x, y) = (x = float(x), y = float(y))
    xy(p) = p
    midpoint(P, Q) = pt((P.x+Q.x)/2, (P.y+Q.y)/2)
    function circumcircle(A, B, C)
        ax, ay = A.x, A.y; bx, by = B.x, B.y; cx, cy = C.x, C.y
        d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
        iszero(d) && return nothing
        ux = ((ax^2 + ay^2) * (by - cy) + (bx^2 + by^2) * (cy - ay) + (cx^2 + cy^2) * (ay - by)) / d
        uy = ((ax^2 + ay^2) * (cx - bx) + (bx^2 + by^2) * (ax - cx) + (cx^2 + cy^2) * (bx - ax)) / d
        O = pt(ux, uy); r = hypot(O.x - ax, O.y - ay)
        (center = O, radius = r)
    end
end

# Render demo assets (PNG + MP4) into docs/src/assets so they are copied to the site
function render_demo_assets()
    assetsdir = joinpath(@__DIR__, "src", "assets")
    mkpath(assetsdir)

    # Build construction
    C = Construction()
    @place C "A" pt(-1.0, 0.2)
    @place C "B" pt(1.0, 0.0)
    @place C "C" pt(0.0, 1.2)
    @construct(C, "M_ab", midpoint, "A", "B")
    @construct(C, "M_bc", midpoint, "B", "C")
    @construct(C, "M_ca", midpoint, "C", "A")
    @construct(C, "G", (A,B,C) -> pt((A.x+B.x+C.x)/3, (A.y+B.y+C.y)/3), "A", "B", "C")
    @construct(C, "circ", circumcircle, "A", "B", "C")

    default(size=(640, 560), legend=false, aspect_ratio=1)

    # draw function
    function draw(C)
        A, B, Cpt = C["A"], C["B"], C["C"]
        Mab, Mbc, Mca = C["M_ab"], C["M_bc"], C["M_ca"]
        G = C["G"]
        circ = C["circ"]

    Axy, Bxy, Cxy = xy(A), xy(B), xy(Cpt)
    Mxy = (xy(Mab), xy(Mbc), xy(Mca))
    Gxy = xy(G)
    plt = plot(xlim=(-2,2), ylim=(-2,2))
    plot!(plt, [Axy.x, Bxy.x], [Axy.y, Bxy.y], lw=2, color=:steelblue)
    plot!(plt, [Bxy.x, Cxy.x], [Bxy.y, Cxy.y], lw=2, color=:steelblue)
    plot!(plt, [Cxy.x, Axy.x], [Cxy.y, Axy.y], lw=2, color=:steelblue)
    plot!(plt, [Axy.x, Mxy[2].x], [Axy.y, Mxy[2].y], ls=:dash, color=:gray)
    plot!(plt, [Bxy.x, Mxy[3].x], [Bxy.y, Mxy[3].y], ls=:dash, color=:gray)
    plot!(plt, [Cxy.x, Mxy[1].x], [Cxy.y, Mxy[1].y], ls=:dash, color=:gray)
    scatter!(plt, [Axy.x,Bxy.x,Cxy.x], [Axy.y,Bxy.y,Cxy.y], ms=6, color=:black)
    scatter!(plt, [Gxy.x], [Gxy.y], ms=7, color=:red)
        if circ !== nothing
            O, r = circ.center, circ.radius
            θ = range(0, 2π; length=200)
            plot!(plt, O.x .+ r .* cos.(θ), O.y .+ r .* sin.(θ), color=:orange, lw=2)
            scatter!(plt, [O.x], [O.y], ms=6, color=:orange)
        end
        plt
    end

    # Save figure (SVG for crisp scaling)
    figpath = joinpath(assetsdir, "triangle.svg")
    savefig(draw(C), figpath)

    # Save animation as APNG using ffmpeg
    framesdir = joinpath(assetsdir, "triangle_frames")
    mkpath(framesdir)
    nframes = 60
    fps = 30
    for (i, t) in enumerate(range(0, 2π; length=nframes))
        x = 0.8 * cos(t)
        y = 1.2 * sin(t)
        @modify C "C" pt(x, y)
        framepath = joinpath(framesdir, @sprintf("frame_%03d.png", i))
        savefig(draw(C), framepath)
    end
    apngpath = joinpath(assetsdir, "triangle.apng")
    # ffmpeg: -framerate input rate, -i frames, -plays 0 (loop), -f apng format
    run(`$(FFMPEG.ffmpeg()) -y -framerate $fps -i $(joinpath(framesdir, "frame_%03d.png")) -plays 0 -f apng $apngpath`)
    # Optionally clean up frames to keep repo tidy (kept if debugging is needed)
    try
        for f in readdir(framesdir)
            rm(joinpath(framesdir, f))
        end
        rm(framesdir)
    catch
        # ignore
    end
end

# Also render a CAD-style filleted rectangle demo
function render_cad_assets()
    assetsdir = joinpath(@__DIR__, "src", "assets")
    mkpath(assetsdir)

    # Vector helpers (work on the NamedTuple produced by xy/pt)
    vadd(a, b) = (x = a.x + b.x, y = a.y + b.y)
    vsub(a, b) = (x = a.x - b.x, y = a.y - b.y)
    vmul(a, s) = (x = a.x * s, y = a.y * s)
    norm2(a) = hypot(a.x, a.y)
    normalize(a) = (n = norm2(a); n == 0 ? (x = 0.0, y = 0.0) : (x = a.x / n, y = a.y / n))
    dot(a, b) = a.x * b.x + a.y * b.y
    crossz(a, b) = a.x * b.y - a.y * b.x
    perp_ccw(a) = (x = -a.y, y = a.x)
    perp_cw(a)  = (x =  a.y, y = -a.x)

    function fillet_corner_docs(Pprev, V, Pnext, r)
        if r <= 0
            return (V, V, V)
        end
        Ap = xy(Pprev); Bp = xy(V); Cp = xy(Pnext)
        # rays from corner V to prev/next
        r1 = normalize(vsub(Ap, Bp))
        r2 = normalize(vsub(Cp, Bp))
        # interior wedge orientation
        z = crossz(r2, r1)
        # inward normals
        n1 = z > 0 ? perp_cw(r1) : perp_ccw(r1)
        n2 = z > 0 ? perp_ccw(r2) : perp_cw(r2)
        n1 = normalize(n1); n2 = normalize(n2)
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

    function draw_fillet(center, w, h, r)
            hw, hh = w / 2, h / 2
            A = pt(center.x - hw, center.y - hh)
            B = pt(center.x + hw, center.y - hh)
            Cc = pt(center.x + hw, center.y + hh)
            D = pt(center.x - hw, center.y + hh)
        r = min(r, hw - 1e-6, hh - 1e-6)
            corners = [(D, A, B), (A, B, Cc), (B, Cc, D), (Cc, D, A)]
            fillets = map(t -> fillet_corner_docs(t[1], t[2], t[3], r), corners)
        default(size=(700, 520), legend=false, aspect_ratio=1)
        plt = plot(xlim=(center.x - w, center.x + w), ylim=(center.y - h, center.y + h))
            (TA1, TB1, O1) = fillets[1]; (TA2, TB2, O2) = fillets[2]; (TA3, TB3, O3) = fillets[3]; (TA4, TB4, O4) = fillets[4]
            plot!(plt, [TB1.x, TA2.x], [TB1.y, TA2.y], lw=3, color=:steelblue)
            plot!(plt, [TB2.x, TA3.x], [TB2.y, TA3.y], lw=3, color=:steelblue)
            plot!(plt, [TB3.x, TA4.x], [TB3.y, TA4.y], lw=3, color=:steelblue)
            plot!(plt, [TB4.x, TA1.x], [TB4.y, TA1.y], lw=3, color=:steelblue)
        for (i, (T1, T2, O)) in enumerate(fillets)
            if T1 !== T2
                θ1 = atan(T1.y - O.y, T1.x - O.x); θ2 = atan(T2.y - O.y, T2.x - O.x)
                # Determine polygon turn at this corner to select CW/CCW sweep
                Pprev, Vp, Pnext = corners[i]
                t_in  = normalize(vsub(Vp, Pprev))
                t_out = normalize(vsub(Pnext, Vp))
                sgn = crossz(t_in, t_out)  # >0 => CCW turn
                if sgn ≥ 0
                    dθ = mod(θ2 - θ1, 2π)
                    if dθ > π
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
                rarc = hypot(T1.x - O.x, T1.y - O.y)
                plot!(plt, O.x .+ rarc .* cos.(θs), O.y .+ rarc .* sin.(θs), lw=3, color=:steelblue)
            end
        end
        plt
    end

    svg = joinpath(assetsdir, "fillet_rect.svg")
    savefig(draw_fillet((x=0.0, y=0.0), 3.0, 2.0, 0.4), svg)

    # Animation varying r
    framesdir = joinpath(assetsdir, "fillet_frames")
    mkpath(framesdir)
    fps = 30
    frames = 90
    for i in 1:frames
        t = 2π * (i-1) / frames
        rmax = min(3.0, 2.0) / 2 - 0.05
        r = 0.05 + 0.5 * rmax * (1 + sin(t))
        savefig(draw_fillet((x=0.0, y=0.0), 3.0, 2.0, r), joinpath(framesdir, @sprintf("frame_%03d.png", i)))
    end
    apng = joinpath(assetsdir, "fillet_rect.apng")
    run(`$(FFMPEG.ffmpeg()) -y -framerate $fps -i $(joinpath(framesdir, "frame_%03d.png")) -plays 0 -f apng $apng`)
    try
        for f in readdir(framesdir); rm(joinpath(framesdir, f)); end; rm(framesdir)
    catch; end
end

render_cad_assets()

# Render a static IMO-style symmedian construction (deterministic, Euclidean helpers)
function render_symmedian_asset()
    assetsdir = joinpath(@__DIR__, "src", "assets")
    mkpath(assetsdir)
    pt(x, y) = (x = float(x), y = float(y))
    vadd(a, b) = (x = a.x + b.x, y = a.y + b.y)
    vsub(a, b) = (x = a.x - b.x, y = a.y - b.y)
    vmul(a, s) = (x = a.x * s, y = a.y * s)
    norm2(a) = hypot(a.x, a.y)
    normalize(a) = (n = norm2(a); n == 0 ? (x = 0.0, y = 0.0) : (x = a.x / n, y = a.y / n))
    dot2(a, b) = a.x * b.x + a.y * b.y

    A = pt(-1.1, 0.2); B = pt(1.2, 0.0); C = pt(0.0, 1.3)
    a = hypot(B.x - C.x, B.y - C.y)
    b = hypot(C.x - A.x, C.y - A.y)
    c = hypot(A.x - B.x, A.y - B.y)
    wA, wB, wC = a^2, b^2, c^2
    S = wA + wB + wC
    K = pt((wA*A.x + wB*B.x + wC*C.x)/S, (wA*A.y + wB*B.y + wC*C.y)/S)

    # Reflect medians across angle bisectors to get symmedians
    M_bc = pt((B.x + C.x)/2, (B.y + C.y)/2)
    AB = normalize(vsub(B, A)); AC = normalize(vsub(C, A)); uA = normalize(vadd(AB, AC))
    mA = normalize(vsub(M_bc, A))
    refA = normalize(vsub(vmul(uA, 2*dot2(mA, uA)), mA))

    M_ca = pt((C.x + A.x)/2, (C.y + A.y)/2)
    BA = normalize(vsub(A, B)); BC = normalize(vsub(C, B)); uB = normalize(vadd(BA, BC))
    mB = normalize(vsub(M_ca, B))
    refB = normalize(vsub(vmul(uB, 2*dot2(mB, uB)), mB))

    M_ab = pt((A.x + B.x)/2, (A.y + B.y)/2)
    CA = normalize(vsub(A, C)); CB = normalize(vsub(B, C)); uC = normalize(vadd(CA, CB))
    mC = normalize(vsub(M_ab, C))
    refC = normalize(vsub(vmul(uC, 2*dot2(mC, uC)), mC))

    default(size=(700, 540), legend=false, aspect_ratio=1)
    plt = plot(xlim=(-2, 2), ylim=(-2, 2))
    # triangle
    plot!(plt, [A.x, B.x], [A.y, B.y], lw=2, color=:steelblue)
    plot!(plt, [B.x, C.x], [B.y, C.y], lw=2, color=:steelblue)
    plot!(plt, [C.x, A.x], [C.y, A.y], lw=2, color=:steelblue)
    # symmedians (extend lines for visibility)
    function draw_ray(P, d)
        Plo = pt(P.x - 3*d.x, P.y - 3*d.y)
        Phi = pt(P.x + 3*d.x, P.y + 3*d.y)
        plot!(plt, [Plo.x, Phi.x], [Plo.y, Phi.y], color=:orange, lw=2, alpha=0.9)
    end
    draw_ray(A, refA); draw_ray(B, refB); draw_ray(C, refC)
    scatter!(plt, [K.x], [K.y], ms=7, color=:red)
    savefig(plt, joinpath(assetsdir, "symmedians.svg"))
end

render_symmedian_asset()

# Generate assets before building pages so links resolve
render_demo_assets()

# Render Euler line and nine-point circle (deterministic, fallback helpers)
function render_euler_ninepoint_asset()
    assetsdir = joinpath(@__DIR__, "src", "assets")
    mkpath(assetsdir)
    # Basic vector helpers using xy/pt
    vadd(a, b) = (x = a.x + b.x, y = a.y + b.y)
    vsub(a, b) = (x = a.x - b.x, y = a.y - b.y)
    vmul(a, s) = (x = a.x * s, y = a.y * s)
    norm2(a) = hypot(a.x, a.y)
    normalize(a) = (n = norm2(a); n == 0 ? (x = 0.0, y = 0.0) : (x = a.x / n, y = a.y / n))

    # Fixed triangle
    A = pt(-1.1, 0.2); B = pt(1.2, 0.0); C = pt(0.0, 1.3)
    # Centers (circumcenter and orthocenter via PGA2D if available, else Euclidean fallback)
    O = HAVE_PGA2D ? PGA2D.try_circumcenter_ppp(A,B,C) : (circumcircle(A,B,C) === nothing ? nothing : circumcircle(A,B,C).center)
    # Orthocenter via vector formula in fallback if needed (intersection of altitudes)
    function orthocenter_fallback(A,B,C)
        ax, ay = A.x, A.y; bx, by = B.x, B.y; cx, cy = C.x, C.y
        # lines through vertices with direction perpendicular to opposite side
        u1 = normalize((x = cy - by, y = bx - cx))
        u2 = normalize((x = ay - cy, y = cx - ax))
        # param eq: A + t*u1 and B + s*u2; solve for intersection
        denom = u1.x * (-u2.y) - u1.y * (-u2.x)
        if iszero(denom)
            return nothing
        end
        rhs = (x = B.x - A.x, y = B.y - A.y)
        t = (rhs.x * (-u2.y) - rhs.y * (-u2.x)) / denom
        H = (x = A.x + t*u1.x, y = A.y + t*u1.y)
        pt(H.x, H.y)
    end
    H = HAVE_PGA2D ? PGA2D.try_orthocenter_ppp(A,B,C) : orthocenter_fallback(xy(A),xy(B),xy(C))
    # Centroid
    Axy, Bxy, Cxy = xy(A), xy(B), xy(C)
    G = pt((Axy.x+Bxy.x+Cxy.x)/3, (Axy.y+Bxy.y+Cxy.y)/3)
    # Nine-point center N = midpoint of O and H
    if O === nothing || H === nothing
        return
    end
    Oxy, Hxy = xy(O), xy(H)
    N = pt((Oxy.x+Hxy.x)/2, (Oxy.y+Hxy.y)/2)
    # Circumradius for nine-point circle radius R/2
    circ = HAVE_PGA2D ? PGA2D.try_circumcircle_ppp(A,B,C) : circumcircle(A,B,C)
    circ === nothing && return
    R = circ.radius

    default(size=(700, 540), legend=false, aspect_ratio=1)
    plt = plot(xlim=(-2,2), ylim=(-2,2))
    # triangle
    plot!(plt, [Axy.x, Bxy.x], [Axy.y, Bxy.y], lw=2, color=:steelblue)
    plot!(plt, [Bxy.x, Cxy.x], [Bxy.y, Cxy.y], lw=2, color=:steelblue)
    plot!(plt, [Cxy.x, Axy.x], [Cxy.y, Axy.y], lw=2, color=:steelblue)
    scatter!(plt, [Axy.x,Bxy.x,Cxy.x], [Axy.y,Bxy.y,Cxy.y], ms=5, color=:black)
    # centers
    Oxy2, Hxy2, Gxy, Nxy = xy(O), xy(H), xy(G), xy(N)
    scatter!(plt, [Oxy2.x, Hxy2.x, Gxy.x, Nxy.x], [Oxy2.y, Hxy2.y, Gxy.y, Nxy.y], ms=6, color=[:orange,:red,:green,:purple])
    # Euler line through O and H
    d = normalize(vsub(Hxy2, Oxy2))
    Plo = vsub(Oxy2, vmul(d, 3.0)); Phi = vadd(Oxy2, vmul(d, 3.0))
    plot!(plt, [Plo.x, Phi.x], [Plo.y, Phi.y], color=:gray, ls=:dash, lw=2)
    # circumcircle and nine-point circle
    θ = range(0, 2π; length=256)
    plot!(plt, circ.center.x .+ R .* cos.(θ), circ.center.y .+ R .* sin.(θ), color=:orange, lw=2)
    plot!(plt, Nxy.x .+ (R/2) .* cos.(θ), Nxy.y .+ (R/2) .* sin.(θ), color=:purple, lw=2)
    savefig(plt, joinpath(assetsdir, "euler_ninepoint.svg"))
end

render_euler_ninepoint_asset()

# Simson line: From a point P on the circumcircle, the feet of perpendiculars to the sides are collinear.
function render_simson_line_asset()
    assetsdir = joinpath(@__DIR__, "src", "assets")
    mkpath(assetsdir)
    # helpers
    vadd(a, b) = (x = a.x + b.x, y = a.y + b.y)
    vsub(a, b) = (x = a.x - b.x, y = a.y - b.y)
    vmul(a, s) = (x = a.x * s, y = a.y * s)
    norm2(a) = hypot(a.x, a.y)
    normalize(a) = (n = norm2(a); n == 0 ? (x = 0.0, y = 0.0) : (x = a.x / n, y = a.y / n))

    # Triangle and circumcircle
    A = pt(-1.1, 0.2); B = pt(1.2, 0.0); C = pt(0.0, 1.3)
    circ = HAVE_PGA2D ? PGA2D.try_circumcircle_ppp(A,B,C) : circumcircle(A,B,C)
    circ === nothing && return
    O, R = circ.center, circ.radius
    Oxy = xy(O)
    # Deterministic point P on circumcircle
    θ = 0.7 * π
    P = pt(Oxy.x + R * cos(θ), Oxy.y + R * sin(θ))
    # Foot from point P to infinite line through A,B
    function foot_on_line_xy(P, A, B)
        p, a, b = xy(P), xy(A), xy(B)
        v = vsub(b, a)
        w = vsub(p, a)
        den = v.x^2 + v.y^2
        t = den == 0 ? 0.0 : (w.x * v.x + w.y * v.y) / den
        F = (x = a.x + t * v.x, y = a.y + t * v.y)
        pt(F.x, F.y)
    end
    Fab = foot_on_line_xy(P, A, B)
    Fbc = foot_on_line_xy(P, B, C)
    Fca = foot_on_line_xy(P, C, A)

    default(size=(700, 540), legend=false, aspect_ratio=1)
    plt = plot(xlim=(-2,2), ylim=(-2,2))
    Axy, Bxy, Cxy = xy(A), xy(B), xy(C)
    plot!(plt, [Axy.x,Bxy.x], [Axy.y,Bxy.y], lw=2, color=:steelblue)
    plot!(plt, [Bxy.x,Cxy.x], [Bxy.y,Cxy.y], lw=2, color=:steelblue)
    plot!(plt, [Cxy.x,Axy.x], [Cxy.y,Axy.y], lw=2, color=:steelblue)
    # circumcircle
    θs = range(0, 2π; length=256)
    plot!(plt, Oxy.x .+ R .* cos.(θs), Oxy.y .+ R .* sin.(θs), color=:orange, lw=2, alpha=0.7)
    Pxy = xy(P); Fabxy = xy(Fab); Fbcxy = xy(Fbc); Fcaxy = xy(Fca)
    scatter!(plt, [Pxy.x], [Pxy.y], ms=6, color=:red)
    scatter!(plt, [Fabxy.x,Fbcxy.x,Fcaxy.x], [Fabxy.y,Fbcxy.y,Fcaxy.y], ms=6, color=:purple)
    # Simson line through Fab and Fbc
    v = vsub(Fbcxy, Fabxy)
    n = norm2(v)
    if n > 0
        v̂ = (x = v.x / n, y = v.y / n)
        Plo = vsub(Fabxy, vmul(v̂, 3.0))
        Phi = vadd(Fabxy, vmul(v̂, 3.0))
        plot!(plt, [Plo.x, Phi.x], [Plo.y, Phi.y], color=:purple, lw=2)
    end
    savefig(plt, joinpath(assetsdir, "simson_line.svg"))
end

render_simson_line_asset()

# Miquel point: Given triangle ABC and points D,E,F on BC,CA,AB, the circumcircles of (A,E,F), (B,F,D), (C,D,E) concur.
function render_miquel_asset()
    assetsdir = joinpath(@__DIR__, "src", "assets")
    mkpath(assetsdir)
    # helpers
    vadd(a, b) = (x = a.x + b.x, y = a.y + b.y)
    vsub(a, b) = (x = a.x - b.x, y = a.y - b.y)
    vmul(a, s) = (x = a.x * s, y = a.y * s)

    A = pt(-1.1, 0.3); B = pt(1.2, 0.0); C = pt(0.0, 1.35)
    # Choose D on BC, E on CA, F on AB (avoid vertices)
    Bxy, Cxy, Axy = xy(B), xy(C), xy(A)
    D = pt(0.6*Bxy.x + 0.4*Cxy.x, 0.6*Bxy.y + 0.4*Cxy.y)
    E = pt(0.35*Cxy.x + 0.65*Axy.x, 0.35*Cxy.y + 0.65*Axy.y)
    F = pt(0.25*Axy.x + 0.75*Bxy.x, 0.25*Axy.y + 0.75*Bxy.y)

    circA = HAVE_PGA2D ? PGA2D.try_circumcircle_ppp(A,E,F) : circumcircle(A,E,F)
    circB = HAVE_PGA2D ? PGA2D.try_circumcircle_ppp(B,F,D) : circumcircle(B,F,D)
    circC = HAVE_PGA2D ? PGA2D.try_circumcircle_ppp(C,D,E) : circumcircle(C,D,E)
    (circA === nothing || circB === nothing || circC === nothing) && return

    # Circle-circle intersection helper
    function circle_intersections(c1, c2)
        O1, R1 = xy(c1.center), c1.radius
        O2, R2 = xy(c2.center), c2.radius
        dx, dy = O2.x - O1.x, O2.y - O1.y
        d = hypot(dx, dy)
        if d == 0 || d > R1 + R2 + 1e-12 || d < abs(R1 - R2) - 1e-12
            return nothing, nothing
        end
        a = (R1^2 - R2^2 + d^2) / (2d)
        h2 = R1^2 - a^2
        h = h2 < 0 ? 0.0 : sqrt(h2)
        ex, ey = dx/d, dy/d
        x0 = O1.x + a*ex
        y0 = O1.y + a*ey
        P1 = (x = x0 + h * (-ey), y = y0 + h * (ex))
        P2 = (x = x0 - h * (-ey), y = y0 - h * (ex))
        pt(P1.x, P1.y), pt(P2.x, P2.y)
    end

    P1, P2 = circle_intersections(circA, circB)
    (P1 === nothing && P2 === nothing) && return
    # pick the intersection that lies on the third circle best
    function on_circle_err(P, circ)
        Pxy = xy(P); Oxy = xy(circ.center)
        abs(hypot(Pxy.x - Oxy.x, Pxy.y - Oxy.y) - circ.radius)
    end
    cand = filter(!isnothing, [P1, P2])
    M = cand[argmin([on_circle_err(P, circC) for P in cand])]

    default(size=(720, 560), legend=false, aspect_ratio=1)
    plt = plot(xlim=(-2,2), ylim=(-2,2))
    Axy2, Bxy2, Cxy2 = xy(A), xy(B), xy(C)
    plot!(plt, [Axy2.x,Bxy2.x], [Axy2.y,Bxy2.y], lw=2, color=:steelblue)
    plot!(plt, [Bxy2.x,Cxy2.x], [Bxy2.y,Cxy2.y], lw=2, color=:steelblue)
    plot!(plt, [Cxy2.x,Axy2.x], [Cxy2.y,Axy2.y], lw=2, color=:steelblue)
    for P in (D,E,F)
        Pxy = xy(P); scatter!(plt, [Pxy.x],[Pxy.y], ms=6, color=:purple)
    end
    for circ in (circA, circB, circC)
        θ = range(0, 2π; length=256)
        Oxy = xy(circ.center)
        plot!(plt, Oxy.x .+ circ.radius .* cos.(θ), Oxy.y .+ circ.radius .* sin.(θ), lw=2, alpha=0.7)
    end
    Mxy = xy(M)
    scatter!(plt, [Mxy.x], [Mxy.y], ms=7, color=:red)
    savefig(plt, joinpath(assetsdir, "miquel.svg"))
end

render_miquel_asset()

# Brocard points asset
function render_brocard_asset()
    assetsdir = joinpath(@__DIR__, "src", "assets"); mkpath(assetsdir)
    A = pt(-1.15, 0.25); B = pt(1.25, 0.0); C = pt(0.0, 1.35)
    # side lengths
    a = hypot(xy(B).x - xy(C).x, xy(B).y - xy(C).y)
    b = hypot(xy(C).x - xy(A).x, xy(C).y - xy(A).y)
    c = hypot(xy(A).x - xy(B).x, xy(A).y - xy(B).y)
    # trilinears -> Cartesian (barycentrics aα : bβ : cγ)
    trito(A,B,C, α,β,γ) = begin
        wA, wB, wC = a*α, b*β, c*γ
        Ax, Bx, Cx = xy(A), xy(B), xy(C)
        S = wA + wB + wC
        pt((wA*Ax.x + wB*Bx.x + wC*Cx.x)/S, (wA*Ax.y + wB*Bx.y + wC*Cx.y)/S)
    end
    Ω1 = trito(A,B,C, c/b, a/c, b/a)
    Ω2 = trito(A,B,C, b/c, c/a, a/b)
    default(size=(720,560), legend=false, aspect_ratio=1)
    plt = plot(xlim=(-2,2), ylim=(-2,2))
    Ax, Bx, Cx = xy(A), xy(B), xy(C)
    plot!(plt, [Ax.x,Bx.x], [Ax.y,Bx.y], lw=2, color=:steelblue)
    plot!(plt, [Bx.x,Cx.x], [Bx.y,Cx.y], lw=2, color=:steelblue)
    plot!(plt, [Cx.x,Ax.x], [Cx.y,Ax.y], lw=2, color=:steelblue)
    Ω1x, Ω2x = xy(Ω1), xy(Ω2)
    scatter!(plt, [Ω1x.x,Ω2x.x], [Ω1x.y,Ω2x.y], ms=7, color=[:red,:purple])
    savefig(plt, joinpath(assetsdir, "brocard.svg"))
end

render_brocard_asset()

# Apollonius circles asset
function render_apollonius_asset()
    assetsdir = joinpath(@__DIR__, "src", "assets"); mkpath(assetsdir)
    A = pt(-1.1, 0.2); B = pt(1.3, 0.0); C = pt(0.0, 1.35)
    function apollonius(B,C,k)
        b, c = xy(B), xy(C)
        cx = (k^2 * c.x - b.x) / (k^2 - 1)
        cy = (k^2 * c.y - b.y) / (k^2 - 1)
        O = pt(cx, cy)
        R = abs(hypot(cx - b.x, cy - b.y) * k / abs(k^2 - 1))
        (center=O, radius=R)
    end
    ApA = apollonius(B,C, 1.5)
    ApB = apollonius(C,A, 0.7)
    ApC = apollonius(A,B, 1.2)
    default(size=(720,560), legend=false, aspect_ratio=1)
    plt = plot(xlim=(-2,2), ylim=(-2,2))
    Ax, Bx, Cx = xy(A), xy(B), xy(C)
    plot!(plt, [Ax.x,Bx.x], [Ax.y,Bx.y], lw=2, color=:steelblue)
    plot!(plt, [Bx.x,Cx.x], [Bx.y,Cx.y], lw=2, color=:steelblue)
    plot!(plt, [Cx.x,Ax.x], [Cx.y,Ax.y], lw=2, color=:steelblue)
    for ap in (ApA,ApB,ApC)
        θ = range(0, 2π; length=256)
        Ox = xy(ap.center)
        plot!(plt, Ox.x .+ ap.radius .* cos.(θ), Ox.y .+ ap.radius .* sin.(θ), lw=2)
    end
    savefig(plt, joinpath(assetsdir, "apollonius.svg"))
end

render_apollonius_asset()

# Orthic triangle asset
function render_orthic_asset()
    assetsdir = joinpath(@__DIR__, "src", "assets"); mkpath(assetsdir)
    A = pt(-1.1, 0.2); B = pt(1.2, 0.0); C = pt(0.0, 1.35)
    # foot helper
    function foot_on_line_xy(P, A, B)
        p, a, b = xy(P), xy(A), xy(B)
        v = (x = b.x - a.x, y = b.y - a.y)
        w = (x = p.x - a.x, y = p.y - a.y)
        den = v.x^2 + v.y^2
        t = den == 0 ? 0.0 : (w.x * v.x + w.y * v.y) / den
        pt(a.x + t*v.x, a.y + t*v.y)
    end
    Ha = foot_on_line_xy(A,B,C)
    Hb = foot_on_line_xy(B,C,A)
    Hc = foot_on_line_xy(C,A,B)
    default(size=(720,560), legend=false, aspect_ratio=1)
    plt = plot(xlim=(-2,2), ylim=(-2,2))
    Ax, Bx, Cx = xy(A), xy(B), xy(C)
    plot!(plt, [Ax.x,Bx.x], [Ax.y,Bx.y], lw=2, color=:steelblue)
    plot!(plt, [Bx.x,Cx.x], [Bx.y,Cx.y], lw=2, color=:steelblue)
    plot!(plt, [Cx.x,Ax.x], [Cx.y,Ax.y], lw=2, color=:steelblue)
    Hax, Hbx, Hcx = xy(Ha), xy(Hb), xy(Hc)
    plot!(plt, [Hax.x,Hbx.x], [Hax.y,Hbx.y], lw=2, color=:orange)
    plot!(plt, [Hbx.x,Hcx.x], [Hbx.y,Hcx.y], lw=2, color=:orange)
    plot!(plt, [Hcx.x,Hax.x], [Hcx.y,Hax.y], lw=2, color=:orange)
    # nine-point circle
    circ = HAVE_PGA2D ? PGA2D.try_circumcircle_ppp(A,B,C) : circumcircle(A,B,C)
    circ === nothing || begin
        θ = range(0,2π; length=256)
        Ox = xy(circ.center); R = circ.radius
        plot!(plt, Ox.x .+ (R/2) .* cos.(θ), Ox.y .+ (R/2) .* sin.(θ), color=:purple, lw=2)
    end
    savefig(plt, joinpath(assetsdir, "orthic.svg"))
end

render_orthic_asset()

# Optionally render an interactive HTML asset using WGLMakie if available
function render_interactive_assets()
    assetsdir = joinpath(@__DIR__, "src", "assets")
    mkpath(assetsdir)
    # Compute output path up front for interpolation into @eval block
    out_path = joinpath(assetsdir, "interactive_triangle.html")
    try
        # Wrap everything in @eval so that no Makie names/macros are resolved
        # at parse time; only if Makie/WGLMakie load successfully will this run.
        @eval begin
            import WGLMakie
            using Makie
            WGLMakie.activate!()

            # Minimal reactive triangle demo
            A = Makie.Observable(Makie.Point2f(-1.0, 0.2))
            B = Makie.Observable(Makie.Point2f( 1.0, 0.0))
            C = Makie.Observable(Makie.Point2f( 0.0, 1.2))
            Mab = Makie.lift((a,b) -> Makie.Point2f((a[1]+b[1])/2, (a[2]+b[2])/2), A, B)
            Mbc = Makie.lift((b,c) -> Makie.Point2f((b[1]+c[1])/2, (b[2]+c[2])/2), B, C)
            Mca = Makie.lift((c,a) -> Makie.Point2f((c[1]+a[1])/2, (c[2]+a[2])/2), C, A)
            G   = Makie.lift((a,b,c) -> Makie.Point2f((a[1]+b[1]+c[1])/3, (a[2]+b[2]+c[2])/3), A, B, C)

            fig = Makie.Figure(resolution=(800, 560))
            ax = Makie.Axis(fig[1, 1], aspect=Makie.DataAspect(),
                            xgridvisible=false, ygridvisible=false,
                            limits=((-2,2),(-2,2)))
            lineAB = Makie.lift((a,b) -> [a,b], A, B)
            lineBC = Makie.lift((b,c) -> [b,c], B, C)
            lineCA = Makie.lift((c,a) -> [c,a], C, A)
            Makie.lines!(ax, lineAB; color=:steelblue, linewidth=2)
            Makie.lines!(ax, lineBC; color=:steelblue, linewidth=2)
            Makie.lines!(ax, lineCA; color=:steelblue, linewidth=2)
            Makie.scatter!(ax, A; color=:black, markersize=10)
            Makie.scatter!(ax, B; color=:black, markersize=10)
            Makie.scatter!(ax, C; color=:black, markersize=10)
            Makie.scatter!(ax, G; color=:red, markersize=12)

            # Save a self-contained HTML (pan/zoom interactivity)
            Makie.save($out_path, fig)
        end
    catch e
        # Makie/WGLMakie not available or render failed; log and skip
        @warn "Interactive asset generation skipped" exception=e
        return
    end
end

render_interactive_assets()
makedocs(;
    modules=[Constructions],
    authors="Andreas Tell <atell@soundtheory.com> and contributors",
    repo="https://github.com/ATell-SoundTheory/Constructions.jl/blob/{commit}{path}#{line}",
    sitename="Constructions.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://ATell-SoundTheory.github.io/Constructions.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Quickstart" => "quickstart.md",
        "Demo" => "demo.md",
        "Interactivity" => "interactive.md",
        "API" => "api.md",
    ],
)

deploydocs(;
    repo="github.com/ATell-SoundTheory/Constructions.jl",
    devbranch="main",
)
