#!/usr/bin/env julia

using Constructions
using Plots
using FFMPEG
using Printf

include(joinpath(@__DIR__, "triangle_construction.jl")) # reuse helpers: point, midpoint, circumcenter, draw

# Build construction anew to avoid double plotting
C = Construction()
@place C "A" point(-1.0, 0.2)
@place C "B" point(1.0, 0.0)
@place C "C" point(0.0, 1.2)

@construct(C, "M_ab", midpoint, "A", "B")
@construct(C, "M_bc", midpoint, "B", "C")
@construct(C, "M_ca", midpoint, "C", "A")
@construct(C, "G", (A,B,C) -> point((A.x+B.x+C.x)/3, (A.y+B.y+C.y)/3), "A", "B", "C")
@construct(C, "circ", circumcenter, "A", "B", "C")

framesdir = joinpath(@__DIR__, "triangle_frames")
mkpath(framesdir)
fps = 30
framecount = 90
for (i, t) in enumerate(range(0, 2π; length=framecount))
    # Animate point C along an ellipse
    x = 0.8 * cos(t)
    y = 1.2 * sin(t)
    @modify C "C" point(x, y)
    framepath = joinpath(framesdir, @sprintf("frame_%03d.png", i))
    savefig(draw(C), framepath)
end
apngpath = joinpath(@__DIR__, "triangle_construction.apng")
run(`$(FFMPEG.ffmpeg()) -y -framerate $fps -i $(joinpath(framesdir, "frame_%03d.png")) -plays 0 -f apng $apngpath`)
println("Saved animation to examples/triangle_construction.apng")
try
    for f in readdir(framesdir)
        rm(joinpath(framesdir, f))
    end
    rm(framesdir)
catch
    # ignore cleanup errors
end
