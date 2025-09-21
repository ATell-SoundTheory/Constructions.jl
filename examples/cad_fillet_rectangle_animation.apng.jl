#!/usr/bin/env julia

using Constructions
using Plots
using FFMPEG
using Printf

include(joinpath(@__DIR__, "cad_fillet_rectangle.jl"))

# Build a fresh construction
C = Construction()
@place C "center" (x=0.0, y=0.0)
@place C "w" 3.0
@place C "h" 2.0
@place C "r" 0.2

fps = 30
frames = 90
framesdir = joinpath(@__DIR__, "fillet_frames")
mkpath(framesdir)

for i in 1:frames
    t = 2π * (i-1) / frames
    # Vary r between 0 and min(w,h)/2 with some margin
    rmax = min(C["w"], C["h"]) / 2 - 0.05
    r = 0.05 + 0.5 * rmax * (1 + sin(t))
    @modify C "r" r
    savefig(draw_fillet_rect(C), joinpath(framesdir, @sprintf("frame_%03d.png", i)))
end

apngpath = joinpath(@__DIR__, "cad_fillet_rectangle.apng")
run(`$(FFMPEG.ffmpeg()) -y -framerate $fps -i $(joinpath(framesdir, "frame_%03d.png")) -plays 0 -f apng $apngpath`)
println("Saved animation to examples/cad_fillet_rectangle.apng")

try
    for f in readdir(framesdir)
        rm(joinpath(framesdir, f))
    end
    rm(framesdir)
catch
end
