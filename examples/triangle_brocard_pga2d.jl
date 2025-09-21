using Constructions
using PGA2D
using Plots

# Coordinates for plotting
yx(P) = begin t = PGA2D.coords(P); (x = float(t[1]), y = float(t[2])) end

# Side lengths
a_len(A,B,C) = hypot(yx(B).x - yx(C).x, yx(B).y - yx(C).y) # a = |BC|
b_len(A,B,C) = hypot(yx(C).x - yx(A).x, yx(C).y - yx(A).y) # b = |CA|
c_len(A,B,C) = hypot(yx(A).x - yx(B).x, yx(A).y - yx(B).y) # c = |AB|

# Convert trilinears (α:β:γ relative to distances to sides) to Cartesian
function trilinears_to_point(A,B,C, α,β,γ)
    # Barycentrics are (aα : bβ : cγ), where a=|BC|, b=|CA|, c=|AB|
    a = a_len(A,B,C); b = b_len(A,B,C); c = c_len(A,B,C)
    wA, wB, wC = a*α, b*β, c*γ
    Axy, Bxy, Cxy = yx(A), yx(B), yx(C)
    S = wA + wB + wC
    PGA2D.point((wA*Axy.x + wB*Bxy.x + wC*Cxy.x)/S, (wA*Axy.y + wB*Bxy.y + wC*Cxy.y)/S)
end

# Brocard points trilinears
# Ω1: (c/b : a/c : b/a), Ω2: (b/c : c/a : a/b)
function brocard_points(A,B,C)
    a = a_len(A,B,C); b = b_len(A,B,C); c = c_len(A,B,C)
    Ω1 = trilinears_to_point(A,B,C, c/b, a/c, b/a)
    Ω2 = trilinears_to_point(A,B,C, b/c, c/a, a/b)
    Ω1, Ω2
end

C = Construction()
@place C "A" point(-1.15, 0.25)
@place C "B" point( 1.25, 0.0)
@place C "C" point( 0.0, 1.35)

@construct(C, "Ω1", (A,B,C)->brocard_points(A,B,C)[1], "A","B","C")
@construct(C, "Ω2", (A,B,C)->brocard_points(A,B,C)[2], "A","B","C")

plt = plot(size=(720,560), legend=false, aspect_ratio=1, xlim=(-2,2), ylim=(-2,2))
A,Bp,Cp = C["A"], C["B"], C["C"]
a,b,c = yx(A), yx(Bp), yx(Cp)
plot!(plt, [a.x,b.x], [a.y,b.y], lw=2, color=:steelblue)
plot!(plt, [b.x,c.x], [b.y,c.y], lw=2, color=:steelblue)
plot!(plt, [c.x,a.x], [c.y,a.y], lw=2, color=:steelblue)
Ω1, Ω2 = yx(C["Ω1"]), yx(C["Ω2"]) 
scatter!(plt, [Ω1.x,Ω2.x], [Ω1.y,Ω2.y], ms=7, color=[:red,:purple])
# Rays A->Ω1, B->Ω1, C->Ω1 to suggest equal angles
for V in (a,b,c)
    plot!(plt, [V.x, Ω1.x], [V.y, Ω1.y], color=:orange, lw=1.8, alpha=0.9)
end
# Rays for Ω2
for V in (a,b,c)
    plot!(plt, [V.x, Ω2.x], [V.y, Ω2.y], color=:green, lw=1.4, alpha=0.8)
end

display(plt)
