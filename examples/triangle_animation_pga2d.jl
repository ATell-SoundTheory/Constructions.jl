#!/usr/bin/env julia

using Constructions
using PGA2D
using Plots
using FFMPEG
using Printf

C = Construction()
@place C "A" point(-1.0, 0.2)
@place C "B" point( 1.0, 0.0)
@place C "C" point( 0.0, 1.2)

@construct(C, "I", incenter_ppp,       "A", "B", "C")
@construct(C, "circ", circumcircle_ppp, "A", "B", "C")

function draw(C)
    plt = plot(xlim=(-2,2), ylim=(-2,2), legend=false, aspect_ratio=1)
    scatter!(plt, [C["A"], C["B"], C["C"]])
    scatter!(plt, [C["I"]], ms=7, color=:red)
    cc = C["circ"]
    if cc !== nothing
        O, r = cc.center, cc.radius
        θ = range(0, 2π; length=200)
        plot!(plt, real.(O.x) .+ r .* cos.(θ), real.(O.y) .+ r .* sin!(similar(θ), θ), color=:orange, lw=2)
    end
    plt
end

framesdir = joinpath(@__DIR__, "triangle_frames_pga2d")
mkpath(framesdir)
fps = 30
framecount = 90
for (i, t) in enumerate(range(0, 2π; length=framecount))
    x = 0.8 * cos(t)
    y = 1.2 * sin(t)
    @modify C "C" point(x, y)
    framepath = joinpath(framesdir, @sprintf("frame_%03d.png", i))
    savefig(draw(C), framepath)
end
apngpath = joinpath(@__DIR__, "triangle_construction_pga2d.apng")
run(`$(FFMPEG.ffmpeg()) -y -framerate $fps -i $(joinpath(framesdir, "frame_%03d.png")) -plays 0 -f apng $apngpath`)
println("Saved animation to examples/triangle_construction_pga2d.apng")
try
    for f in readdir(framesdir)
        rm(joinpath(framesdir, f))
    end
    rm(framesdir)
catch
    # ignore cleanup errors
end
