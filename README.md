# Constructions.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ATell-SoundTheory.github.io/Constructions.jl/dev)
[![Build Status](https://github.com/ATell-SoundTheory/Constructions.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ATell-SoundTheory/Constructions.jl/actions/workflows/CI.yml?query=branch%3Amain)

A tiny dependency-graph framework for named constructions. You define placed elements (given values) and constructed elements (rules with dependencies). When inputs change, all affected results update automatically in a safe order. It’s type-agnostic and works for numbers, geometric objects, and more.

See the [Quickstart](https://ATell-SoundTheory.github.io/Constructions.jl/dev/quickstart/) and [API](https://ATell-SoundTheory.github.io/Constructions.jl/dev/api/) docs.

## Quick example

```julia
using Constructions

C = Construction()
@place C "A" 1
@place C "B" 2
@construct(C, "S", +, "A", "B")   # S = A + B = 3

@modify C "A" 5                      # S updates to 7
S = C["S"]
```

## Optional plotting extension

Plotting is not part of the core package to keep CI and docs deterministic. If you have Plots.jl loaded, the optional extension `ConstructionsPlotsExt` can provide recipes for your domain types. Enable by simply `using Plots` before plotting code; the extension will load automatically.

## Project goals

- Minimal, declarative graph of named elements
- Deterministic updates with cycle detection
- No heavy dependencies by default (Plots optional)
