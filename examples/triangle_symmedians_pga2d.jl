#!/usr/bin/env julia

using Constructions
using PGA2D
using Plots

# Helpers to go between PGA2D points and numeric coords
xy(p) = begin t = PGA2D.coords(p); (x = float(t[1]), y = float(t[2])) end
pt(x, y) = PGA2D.point(float(x), float(y))
normalize2(v) = begin n = hypot(v.x, v.y); n == 0 ? (x=0.0,y=0.0) : (x=v.x/n, y=v.y/n) end
vsub(a,b) = (x = a.x - b.x, y = a.y - b.y)
vadd(a,b) = (x = a.x + b.x, y = a.y + b.y)
vmul(a,s) = (x = a.x * s, y = a.y * s)
dot2(a,b) = a.x*b.x + a.y*b.y

# Build triangle
C = Construction()
@place C "A" point(-1.1, 0.2)
@place C "B" point( 1.2, 0.0)
@place C "C" point( 0.0, 1.3)

# Extract numeric coords
A = xy(C["A"]); B = xy(C["B"]); Cc = xy(C["C"])

# Side lengths
a = hypot(B.x - Cc.x, B.y - Cc.y)  # |BC|
b = hypot(Cc.x - A.x, Cc.y - A.y)  # |CA|
c = hypot(A.x - B.x, A.y - B.y)    # |AB|

# Lemoine point K (symmedian point) in barycentric a^2:b^2:c^2
wA, wB, wC = a^2, b^2, c^2
S = wA + wB + wC
K = (x = (wA*A.x + wB*B.x + wC*Cc.x)/S,
     y = (wA*A.y + wB*B.y + wC*Cc.y)/S)
Kp = pt(K.x, K.y)

# Symmedian directions via isogonal conjugate: reflect medians across angle bisectors
# At vertex A
M_bc = (x = (B.x + Cc.x)/2, y = (B.y + Cc.y)/2)
AB = normalize2(vsub(B, A)); AC = normalize2(vsub(Cc, A))
uA = normalize2(vadd(AB, AC)) # internal angle bisector direction
mA = normalize2(vsub(M_bc, A))
refA = normalize2(vsub(vmul(uA, 2*dot2(mA, uA)), mA))
LAs = (A1 = pt(A.x, A.y), A2 = pt(A.x + refA.x, A.y + refA.y))

# At vertex B
M_ca = (x = (Cc.x + A.x)/2, y = (Cc.y + A.y)/2)
BA = normalize2(vsub(A, B)); BC = normalize2(vsub(Cc, B))
uB = normalize2(vadd(BA, BC))
mB = normalize2(vsub(M_ca, B))
refB = normalize2(vsub(vmul(uB, 2*dot2(mB, uB)), mB))
LBs = (B1 = pt(B.x, B.y), B2 = pt(B.x + refB.x, B.y + refB.y))

# At vertex C
M_ab = (x = (A.x + B.x)/2, y = (A.y + B.y)/2)
CA = normalize2(vsub(A, Cc)); CB = normalize2(vsub(B, Cc))
uC = normalize2(vadd(CA, CB))
mC = normalize2(vsub(M_ab, Cc))
refC = normalize2(vsub(vmul(uC, 2*dot2(mC, uC)), mC))
LCs = (C1 = pt(Cc.x, Cc.y), C2 = pt(Cc.x + refC.x, Cc.y + refC.y))

# Plot
default(size=(720, 560), legend=false, aspect_ratio=1)
plt = plot(xlim=(-2, 2), ylim=(-2, 2), title="Triangle symmedians (Lemoine point)")
# Triangle
plot!(plt, [A.x, B.x], [A.y, B.y], lw=2, color=:steelblue)
plot!(plt, [B.x, Cc.x], [B.y, Cc.y], lw=2, color=:steelblue)
plot!(plt, [Cc.x, A.x], [Cc.y, A.y], lw=2, color=:steelblue)
# Symmedians (draw long enough)
for seg in (LAs, LBs, LCs)
    P1 = xy(seg[1]); P2 = xy(seg[2])
    dir = normalize2(vsub(P2, P1))
    Plo = (x = P1.x - 3*dir.x, y = P1.y - 3*dir.y)
    Phi = (x = P1.x + 3*dir.x, y = P1.y + 3*dir.y)
    plot!(plt, [Plo.x, Phi.x], [Plo.y, Phi.y], color=:orange, lw=2, alpha=0.9)
end
# Points
scatter!(plt, [A.x, B.x, Cc.x], [A.y, B.y, Cc.y], ms=6, color=:black)
scatter!(plt, [K.x], [K.y], ms=7, color=:red, label="K (Lemoine)")

display(plt)
