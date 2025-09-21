# Interactive triangle demo with Makie
# - Move vertex C with sliders and watch midpoints, centroid, and circumcircle update
# - Requires GLMakie (or switch to WGLMakie for browser-based)

using GLMakie

# Basic Euclidean helpers
struct Circumcircle
    center::Point2f
    radius::Float64
end

function try_circumcircle(A::Point2f, B::Point2f, C::Point2f)
    ax, ay = A
    bx, by = B
    cx, cy = C
    d = 2f0 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    if iszero(d)
        return nothing
    end
    ux = ((ax^2 + ay^2) * (by - cy) + (bx^2 + by^2) * (cy - ay) + (cx^2 + cy^2) * (ay - by)) / d
    uy = ((ax^2 + ay^2) * (cx - bx) + (bx^2 + by^2) * (ax - cx) + (cx^2 + cy^2) * (bx - ax)) / d
    O = Point2f(ux, uy)
    r = sqrt((O[1]-ax)^2 + (O[2]-ay)^2)
    Circumcircle(O, r)
end

midpoint(A::Point2f, B::Point2f) = Point2f((A[1]+B[1]) / 2, (A[2]+B[2]) / 2)

# Observables for vertices
A = Observable(Point2f(-1.0, 0.2))
B = Observable(Point2f( 1.0, 0.0))
C = Observable(Point2f( 0.0, 1.2))

# Derived geometry (reactive)
Mab = @lift midpoint($A, $B)
Mbc = @lift midpoint($B, $C)
Mca = @lift midpoint($C, $A)
G   = @lift Point2f(($A[1]+$B[1]+$C[1])/3, ($A[2]+$B[2]+$C[2])/3)
Circ = @lift try_circumcircle($A, $B, $C)

fig = Figure(resolution=(900, 640))
ax = Axis(fig[1, 1], aspect=DataAspect(), xgridvisible=false, ygridvisible=false,
          limits=((-2, 2), (-2, 2)))

# Triangle edges
lines!(ax, @lift([($A[1],$A[2]), ($B[1],$B[2])]), color=:steelblue, linewidth=2)
lines!(ax, @lift([($B[1],$B[2]), ($C[1],$C[2])]), color=:steelblue, linewidth=2)
lines!(ax, @lift([($C[1],$C[2]), ($A[1],$A[2])]), color=:steelblue, linewidth=2)

# Points
scatter!(ax, A, color=:black, markersize=10)
scatter!(ax, B, color=:black, markersize=10)
scatter!(ax, C, color=:black, markersize=10)
scatter!(ax, G, color=:red, markersize=12)

# Mid-segment dashed helpers
lines!(ax, @lift([($A[1],$A[2]), ($Mbc[1],$Mbc[2])]), color=:gray, linestyle=:dash)
lines!(ax, @lift([($B[1],$B[2]), ($Mca[1],$Mca[2])]), color=:gray, linestyle=:dash)
lines!(ax, @lift([($C[1],$C[2]), ($Mab[1],$Mab[2])]), color=:gray, linestyle=:dash)

# Circumcircle (if non-degenerate)
θ = range(0, 2pi; length=256)
lines!(ax,
    @lift begin
        cc = $Circ
        if cc === nothing
            Point2f[]
        else
            [Point2f(cc.center[1] + cc.radius * cos(t), cc.center[2] + cc.radius * sin(t)) for t in θ]
        end
    end,
    color=:orange, linewidth=2)

# Sliders to move C
sx = Slider(fig[2, 1], range=-1.8:0.01:1.8, startvalue=C[].x, width=600, label="C.x")
sy = Slider(fig[3, 1], range=-1.8:0.01:1.8, startvalue=C[].y, width=600, label="C.y")

on(sx.value) do x
    C[] = Point2f(x, C[].y)
end
on(sy.value) do y
    C[] = Point2f(C[].x, y)
end

fig

# Notes:
# - If you prefer browser-based interactivity, set WGLMakie as backend:
#     using WGLMakie; WGLMakie.activate!(); fig  # then save("interactive.html", fig)
# - To move A and B as well, add additional sliders and update A[] and B[] similarly.
