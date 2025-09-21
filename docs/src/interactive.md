# Interactivity options

Want to see how constructions react when you move inputs? Here are a few lightweight options you can pick from, depending on your workflow.

## Makie.jl (sliders, native or web)

Makie makes it easy to bind geometry to reactive Observables and add sliders/draggers. A minimal example is provided in `examples/interactive_triangle_makie.jl`:

- Move vertex C with sliders and watch midpoints, centroid, and the circumcircle update.
- Run it with GLMakie (native window) or WGLMakie (browser-based):
  - Native: `using GLMakie; include("examples/interactive_triangle_makie.jl")`
  - Web: `using WGLMakie; WGLMakie.activate!(); include("examples/interactive_triangle_makie.jl")`
- You can save a self-contained HTML via WGLMakie: `save("interactive_triangle.html", fig)`.

## Pluto.jl notebooks

Pluto gives you reactive cells and sliders (PlutoUI.jl) with no callbacks. A Pluto version mirrors the same triangle example:

- Create a new notebook and add cells for the points A, B, C, derived midpoints and centroid, and a plotting cell.
- Use `@bind` with `Slider(…)` to change coordinates live and re-render the figure.
- Tip: keep geometry pure (return NamedTuples or plain numbers) and plot from a final cell.

## Constructions.jl + Makie draggers

For richer scenes, wire Constructions.jl into Makie’s draggers:

- Keep a `Construction` instance in scope and call `@modify` when draggers move the placed points.
- Recompute derived elements automatically thanks to Constructions’ dependency graph.
- Plot either via Plots.jl or Makie (the provided interactive demo uses raw Euclidean math for simplicity, but the same idea applies with your PGA2D helpers).

## Tips

- Determinism in docs: the main docs are kept deterministic (SVG/APNG). Interactivity is offered as external examples or exported HTML with WGLMakie.
- Performance: keep geometry small per frame; cache static elements; use Observables for reactive dependencies.
- Cross-platform: GLMakie works natively; WGLMakie runs in the browser (great for sharing).