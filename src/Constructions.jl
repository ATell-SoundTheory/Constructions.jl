"""
        Constructions

Minimal dependency-graph framework for named constructions.

Core concepts
- `Construction`: container of named elements (strings) mapped to either
    - `PlacedElement`: concrete values provided by the user
    - `ConstructedElement`: values produced by a rule (function) with dependencies

Updating
- Changing a placed element triggers recomputation of all downstream constructed elements
    in a safe topological order.
- Removing an element cascades removal of dependents.
- Cycles in dependencies are detected and reported via `ConstructionsError`.

Access and ergonomics
- Access a value by name with `C["S"]`.
- Macros provide a concise DSL: `@place`, `@construct`, `@modify`, `@replace`, `@remove`.

Error behavior
- Duplicate names: `ArgumentError`
- Unknown dependencies/names: `ArgumentError`
- Failed construction rule: `ArgumentError` (on creation) or `ConstructionsError` (on update)
- Cycles: `ConstructionsError`
"""
module Constructions
"""
    ConstructionsError(msg)

Custom exception type raised for construction-graph runtime errors like cycles
or stalled updates during recomputation.
"""
struct ConstructionsError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ConstructionsError) = print(io, e.msg)


export Construction
export dependency_order
export @place
export @modify
export @construct
export @replace
export @remove


"""
Abstract supertype for elements stored in a `Construction`.

- `PlacedElement`: user-provided value
- `ConstructedElement`: value computed from a rule and dependencies
"""
abstract type AbstractGeometricElement end

"""
    PlacedElement

Holds a concrete value bound to a name within a `Construction`.

Fields
- `name::String`
- `representation::Any` – user value
- `required_by::Set{String}` – names that depend on this element
"""
struct PlacedElement <: AbstractGeometricElement
    name::String
    representation::Any
    required_by::Set{String}
end

"""
    ConstructedElement

Holds a computed value along with its dependency set and construction rule.

Fields
- `name::String`
- `representation::Any`
- `required_by::Set{String}` – dependents
- `requires::Set{String}` – dependencies
- `construct::Function` – `C -> value` rule
"""
struct ConstructedElement <: AbstractGeometricElement
    name::String
    representation::Any
    required_by::Set{String}
    requires::Set{String}
    construct::Function
end

name(g::AbstractGeometricElement) = g.name
representation(g::AbstractGeometricElement) = g.representation
required_by(g::AbstractGeometricElement) = g.required_by

requires(g::ConstructedElement) = g.requires
requires(::PlacedElement) = Set{String}()

construct(g::ConstructedElement) = g.construct
construct(g::PlacedElement) = C -> representation(g)

replace_representation(g::PlacedElement, new_representation) = PlacedElement(name(g), new_representation, required_by(g))

replace_representation(g::ConstructedElement, new_representation) = ConstructedElement(name(g), new_representation, required_by(g), requires(g), construct(g))

replace_required_by(g::PlacedElement, new_required_by) = PlacedElement(name(g), representation(g), new_required_by)

replace_required_by(g::ConstructedElement, new_required_by) = ConstructedElement(name(g), representation(g), new_required_by, requires(g), construct(g))

"""
    Construction()

Container mapping names (`String`) to elements and providing dependency-aware
updates and access.
"""
struct Construction
    elements::Dict{String,AbstractGeometricElement}
end

Construction() = Construction(Dict{String,AbstractGeometricElement}())


"""
    dependency_order(C::Construction) -> Vector{String}

Return a topological ordering of element names such that all dependencies
precede their dependents. Throws `ConstructionsError` if a dependency cycle exists.
"""
function dependency_order(C::Construction)
    result = String[]
    elements = Set(keys(C.elements))
    while !isempty(elements)
        free_elements = filter(e -> isdisjoint(requires(C.elements[e]), elements), elements)
        if isempty(free_elements)
            throw(ConstructionsError("Dependency cycle detected among: $(collect(elements))"))
        end
        append!(result, free_elements)
        setdiff!(elements, free_elements)
    end
    result
end


import Base.show

"""
    show(io, C::Construction)

Pretty-print the construction in dependency order. Placed elements show as
`name: value;` and constructed elements as `{deps...} => name: value;`.
Non-throwing.
"""
function show(io::IO, C::Construction)
    for en in dependency_order(C)
        e = C.elements[en]
        if is_placed(e)
            println(io, name(e), ": ", representation(e), "; ")
        elseif is_constructed(e)
            r = requires(e)
            print(io, "{")
            for s in r
                print(io, s, ", ")
            end
            println(io, "} => ", name(e), ": ", representation(e), "; ")
        end
    end
end

import Base.getindex

"""
    C[ename::String]

Return the `representation` bound to the given name, or throw `ArgumentError`
if no such element exists.
"""
function getindex(C::Construction, ename::String)
    if !haskey(C.elements, ename)
        throw(ArgumentError("Element $ename not found."))
    else
        representation(C.elements[ename])
    end
end


function is_constructed(element)
    element isa ConstructedElement
end

function is_placed(element)
    element isa PlacedElement
end

## NOTE: representation(::String) without a Construction is ambiguous and was removed.


"""
    place_element!(C, ename::String, value) -> nothing

Insert a new placed element named `ename` with the given value. Throws
`ArgumentError` if `ename` already exists.
"""
function place_element!(C::Construction, ename::String, representation )
    if haskey(C.elements, ename)
        throw(ArgumentError("Name $ename is already used in the construction."))
    else
        C.elements[ename] = PlacedElement(ename, representation, Set{String}())
    end
    nothing
end


"""
    construct_element!(C, ename::String, rule::Function, deps::Set{String}) -> nothing

Insert a new constructed element named `ename`, produced by `rule(C)` and
depending on `deps`. Throws `ArgumentError` for duplicate names or unknown deps.
If `rule(C)` throws, the creation fails with `ArgumentError`.
"""
function construct_element!(C::Construction, ename::String, construct::Function, depends_on::Set{String})
    if haskey(C.elements, ename)
        throw(ArgumentError("Name $ename is already used in the construction."))
    else
        unknown_elements = filter(e -> !haskey(C.elements,e), depends_on)
        if !isempty(unknown_elements)
            throw(ArgumentError("Unknown dependencies: $unknown_elements"))
        end
        try
            representation = construct(C)
            C.elements[ename] = ConstructedElement(ename, representation, Set{String}(), depends_on, construct)
        catch err
            throw(ArgumentError("Construction rule failed with error $err."))
        end
        foreach( e -> push!(C.elements[e].required_by, ename) , depends_on)
    end
    nothing
end


"""
    collect_dependencies(C, ename, result::Set{String}) -> Set{String}

Populate `result` with all transitive dependents of `ename` (names that require
it), guarding against cycles.
"""
function collect_dependencies(C::Construction, ename::String, result::Set{String})
    if !haskey(C.elements, ename)
        throw(ArgumentError("Element $ename not found."))
    else
        followingelements = required_by(C.elements[ename])
        union!(result, followingelements)
        for e in followingelements
            # only recurse into nodes we haven't visited yet to avoid cycles
            if !(e in result)
                push!(result, e)
                collect_dependencies(C, e, result)
            end
        end
    end
    result
end


"""
    update_dependencies!(C, ename, requires_elements, required_by_elements) -> nothing

Recompute constructed elements affected by a change to `ename` in a safe order.
On deletion, detach `ename` from its prerequisites, remove its dependents, and
propagate recursively. Detects cycles during recomputation and throws
`ConstructionsError` if progress stalls or a rule fails during update.
"""
function update_dependencies!(C::Construction, ename::String, requires_elements::Set{String}, required_by_elements::Set{String})
    if haskey(C.elements, ename)
        # element has been updated but the dependencies have not changed
        affectedelements = collect_dependencies(C, ename, Set{String}() )
        while !isempty(affectedelements)
            progressed = false
            to_remove = String[]
            # iterate over a stable snapshot to avoid mutating during iteration
            for ae in copy(affectedelements)
                element = C.elements[ae]
                if isdisjoint(requires(element), affectedelements)
                    if element isa ConstructedElement
                        try
                            C.elements[ae] = replace_representation(element, element.construct(C))
                        catch err
                            throw(ConstructionsError("Construction rule failed with error $err."))
                        end
                    end
                    push!(to_remove, ae)
                    progressed = true
                end
            end
            for ae in to_remove
                delete!(affectedelements, ae)
            end
            if !progressed
                throw(ConstructionsError("Dependency update stalled (cycle or missing inputs) while updating $(ename): $(collect(affectedelements))"))
            end
        end
    else
        # element has been deleted
        for e in requires_elements
            if haskey(C.elements, e)
                delete!(C.elements[e].required_by, ename)
            end
        end
        for e in required_by_elements
            if haskey(C.elements, e)
                be = C.elements[e]
                delete!(C.elements, e)
                update_dependencies!(C, name(be), requires(be), required_by(be))
            end
        end
    end
    nothing
end


"""
    modify_placed_element!(C, ename::String, newvalue) -> nothing

Change the value of a placed element and trigger recomputation downstream.
Throws `ArgumentError` if `ename` is not found or is a constructed element.
"""
function modify_placed_element!(C::Construction, ename::String, newrepresentation)
    if !haskey(C.elements, ename)
        throw(ArgumentError("Element $ename not found."))
    else
        element = C.elements[ename]
        if element isa ConstructedElement
            throw(ArgumentError("Element $ename is a constructed element."))
        else
            C.elements[ename] = replace_representation(element, newrepresentation)
            update_dependencies!(C, ename, requires(element), required_by(element))
        end
    end
    nothing
end


"""
    remove_element!(C, ename::String) -> nothing

Remove an element and recursively remove all of its dependents.
Throws `ArgumentError` if the name is not found.
"""
function remove_element!(C::Construction, ename::String)
    if !haskey(C.elements, ename)
        throw(ArgumentError("Element $ename not found."))
    else
        element = C.elements[ename]
        delete!(C.elements, ename)
        update_dependencies!(C, ename, requires(element), required_by(element))
    end
    nothing
end


"""
    replace_element!(C, ename::String, value) -> nothing

Replace an element by a placed element with the given value, preserving
its dependents and triggering recomputation downstream.
"""
function replace_element!(C::Construction, ename::String, representation)
    if !haskey(C.elements, ename)
        throw(ArgumentError("Element $ename not found."))
    else
        element = C.elements[ename]
        re = requires(element)
        for e in re
            delete!(C.elements[e].required_by, ename)
        end
        delete!(C.elements, ename)
        place_element!(C, ename, representation)
        element = replace_required_by(C.elements[ename], required_by(element))
        C.elements[ename] = element
        update_dependencies!(C, ename, requires(element), required_by(element))
    end
    nothing
end


"""
    replace_element!(C, ename::String, rule::Function, deps::Set{String}) -> nothing

Replace an element by a constructed element produced by `rule(C)` depending on
`deps`, preserving its dependents and triggering recomputation.
Throws `ArgumentError` for unknown deps or if `rule(C)` throws.
"""
function replace_element!(C::Construction, ename::String, construct::Function, depends_on::Set{String})
    if !haskey(C.elements, ename)
        throw(ArgumentError("Element $ename not found."))
    else
        element = C.elements[ename]
        re = requires(element)
        for e in re
            delete!(C.elements[e].required_by, ename)
        end
        delete!(C.elements, ename)
        construct_element!(C, ename, construct, depends_on)
        element = replace_required_by(C.elements[ename], required_by(element))
        C.elements[ename] = element
        update_dependencies!(C, ename, requires(element), required_by(element))
    end
    nothing
end


"""
    @place C name value

Insert a placed element and return its value. Example:
`@place C "A" 42`.
"""
macro place(construction, name, representation)
    quote
        place_element!($(esc(construction)), $(esc(name)), $(esc(representation)))
        $(esc(construction))[$(esc(name))]
    end
end

"""
    @modify C name newvalue

Modify a placed element and return its new value. Example:
`@modify C "A" 7`.
"""
macro modify(construction, name, new_representation)
    quote
        modify_placed_element!($(esc(construction)), $(esc(name)), $(esc(new_representation)))
        $(esc(construction))[$(esc(name))]
    end
end

"""
    make_construct(rule, deps...)

Internal helper used by `@construct`/`@replace` to capture a `C -> rule(...)`
closure over named dependencies.
"""
function make_construct(rule, dependencies...)
    arguments = map( d ->:(C[$(esc(d))]) , dependencies )
    quote
        C -> $(esc(rule))($(arguments...))
    end    
end

"""
    @construct(C, name, rule, deps...)

Insert a constructed element produced by `rule` applied to the values of
`deps`. Returns the element's value. Example:
`@construct(C, "S", +, "A", "B")` defines `S = C["A"] + C["B"]`.
"""
macro construct(construction, name, rule, dependencies...)
    construct = make_construct(rule, dependencies...)
    quote
        construct_element!($(esc(construction)), $(esc(name)), $construct, Set{String}([$(map(e->esc(e), dependencies)...)]))
        $(esc(construction))[$(esc(name))]
    end
end

"""
    @remove C name

Remove an element and all of its dependents. Example: `@remove C "A"`.
"""
macro remove(construction, name)
    quote
        remove_element!($(esc(construction)), $(esc(name)))
    end
end

"""
    @replace C name value

Replace an element with a placed element holding `value`. Returns that value.
"""
macro replace(construction, name, representation)
    quote
        replace_element!($(esc(construction)), $(esc(name)), $(esc(representation)))
        $(esc(construction))[$(esc(name))]
    end
end

"""
    @replace(C, name, rule, deps...)

Replace an element with a constructed element produced by `rule` applied to
the values of `deps`. Returns the new value.
"""
macro replace(construction, name, rule, dependencies...)
    construct = make_construct(rule, dependencies...)
    quote
        replace_element!($(esc(construction)), $(esc(name)), $construct, Set{String}([$(map(e->esc(e), dependencies)...)]))
        $(esc(construction))[$(esc(name))]        
    end
end



end