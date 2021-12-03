module Constructions

export Construction
export dependency_order
export place, modify
export construct
export replace, remove


abstract type AbstractGeometricElement end

struct PlacedElement <: AbstractGeometricElement
    name::String
    representation::Any
    required_by::Set{String}
end

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

struct Construction
    elements::Dict{String,AbstractGeometricElement}
end

Construction() = Construction(Dict{String,AbstractGeometricElement}())


function dependency_order(C::Construction)
    result = String[]
    elements = Set(keys(C.elements))
    while !isempty(elements)
        free_elements = filter(e -> isdisjoint(requires(C.elements[e]), elements), elements)
        append!(result, free_elements)
        setdiff!(elements, free_elements)
    end
    result
end


import Base.show

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

function representation(ename::String)
    if !haskey(C.elements, ename)
        throw(ArgumentError("Element $ename not found."))
    else
        representation(C.elements[ename])
    end
end


function place_element!(C::Construction, ename::String, representation )
    if haskey(C.elements, ename)
        throw(ArgumentError("Name $ename is already used in the construction."))
    else
        C.elements[ename] = PlacedElement(ename, representation, Set{String}())
    end
    nothing
end


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


function collect_dependencies(C::Construction, ename::String, result::Set{String})
    if !haskey(C.elements, ename)
        throw(ArgumentError("Element $ename not found."))
    else
        followingelements = required_by(C.elements[ename])
        union!(result, followingelements)
        for e in followingelements
            push!(result, e)
            collect_dependencies(C, e, result)
        end
    end
    result
end


function update_dependencies!(C::Construction, ename::String, requires_elements::Set{String}, required_by_elements::Set{String})
    if haskey(C.elements, ename)
        # element has been updated but the dependencies have not changed
        affectedelements = collect_dependencies(C, ename, Set{String}() )
        while !isempty(affectedelements)
            for ae in affectedelements
                element = C.elements[ae]
                if isdisjoint(requires(element), affectedelements)
                    if element isa ConstructedElement
                        try
                            C.elements[ae] = replace_representation(element, element.construct(C))
                        catch err
                            throw(ErrorException("Construction rule failed with error $err."))
                        end
                    end
                    delete!(affectedelements, ae)
                end
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


macro place(construction, name, representation)
    quote
        place_element!($(esc(construction)), $(esc(name)), $(esc(representation)))
        $(esc(construction))[$(esc(name))]
    end
end

macro modify(construction, name, new_representation)
    quote
        modify_placed_element!($(esc(construction)), $(esc(name)), $(esc(new_representation)))
        $(esc(construction))[$(esc(name))]
    end
end

function make_construct(rule, dependencies...)
    arguments = map( d ->:(C[$(esc(d))]) , dependencies )
    quote
        C -> $(esc(rule))($(arguments...))
    end    
end

macro construct(construction, name, rule, dependencies...)
    construct = make_construct(rule, dependencies...)
    quote
        construct_element!($(esc(construction)), $(esc(name)), $construct, Set{String}([$(map(e->esc(e), dependencies)...)]))
        $(esc(construction))[$(esc(name))]
    end
end

macro remove(construction, name)
    quote
        remove_element!($(esc(construction)), $(esc(name)))
    end
end

macro replace(construction, name, representation)
    quote
        replace_element!($(esc(construction)), $(esc(name)), $(esc(representation)))
        $(esc(construction))[$(esc(name))]
    end
end

macro replace(construction, name, rule, dependencies...)
    construct = make_construct(rule, dependencies...)
    quote
        replace_element!($(esc(construction)), $(esc(name)), $construct, Set{String}([$(map(e->esc(e), dependencies)...)]))
        $(esc(construction))[$(esc(name))]        
    end
end


using Plots

@recipe function construction_plot_recipe(C::Construction)
    plotorder = dependency_order(C)
    for en in plotorder
        label := en
        @series C[en]
    end
end

end