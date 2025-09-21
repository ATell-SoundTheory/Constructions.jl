module ConstructionsPlotsExt

using Constructions
using Plots

@recipe function construction_plot_recipe(C::Constructions.Construction)
    plotorder = Constructions.dependency_order(C)
    for en in plotorder
        label := en
        @series C[en]
    end
end

end
