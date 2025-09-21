using Constructions
using Test

@testset "Constructions.jl" begin
    @testset "place/construct basics" begin
        C = Constructions.Construction()
        vA = @place C "A" 1
        vB = @place C "B" 2
        @test vA == 1
        @test vB == 2
        # Construct S = A + B
    vS = @construct(C, "S", +, "A", "B")
        @test vS == 3
        # Topological order: A,B before S
        order = Constructions.dependency_order(C)
        iA = findfirst(==("A"), order)
        iB = findfirst(==("B"), order)
        iS = findfirst(==("S"), order)
        @test iA < iS
        @test iB < iS
    end

    @testset "modify propagates" begin
        C = Constructions.Construction()
        @place C "A" 1
        @place C "B" 2
    @construct(C, "S", +, "A", "B")  # S=3
        @modify C "A" 5                 # S should become 7
        @test C["S"] == 7
    end

    @testset "replace placed and constructed" begin
        C = Constructions.Construction()
        @place C "A" 1
        @place C "B" 2
    @construct(C, "S", +, "A", "B")  # 3
        # Replace placed B -> 10
        rB = @replace C "B" 10
        @test rB == 10
        @test C["S"] == 11
        # Replace constructed S rule: S = A*B
    rS = @replace(C, "S", *, "A", "B")
        @test rS == 10
        @test C["S"] == 10
    end

    @testset "remove cascades" begin
        C = Constructions.Construction()
        @place C "A" 1
        @place C "B" 2
    @construct(C, "S", +, "A", "B")
        # Removing A removes S as dependent
        @remove C "A"
        @test_throws ArgumentError C["A"]
        @test_throws ArgumentError C["S"]
        # B still exists
        @test C["B"] == 2
    end

    @testset "errors" begin
        C = Constructions.Construction()
        @place C "A" 1
        @test_throws ArgumentError @place C "A" 99
    @test_throws ArgumentError @construct(C, "S", +, "A", "ZzzUnknown")
    @construct(C, "S", +, "A") # construct S=A
        # modifying constructed should error
        @test_throws ArgumentError @modify C "S" 123
    end

    @testset "cycles are detected" begin
        C = Constructions.Construction()
        @place C "A" 1
        # Build a valid chain first: X <- A, Y <- X
        @construct(C, "X", x->x+1, "A")
        @construct(C, "Y", y->y+1, "X")
        # Now introduce a cycle by making X depend on Y
        @replace(C, "X", y->y+1, "Y")
    @test_throws Constructions.ConstructionsError Constructions.dependency_order(C)
        # Break the cycle by restoring X to depend on A
        @replace(C, "X", x->x+1, "A")
        # Dependency order should work again and values be consistent
        order = Constructions.dependency_order(C)
        @test findfirst(==("A"), order) < findfirst(==("X"), order) < findfirst(==("Y"), order)
        @test C["Y"] == (C["X"] + 1)
    end

    @testset "show is non-throwing" begin
        C = Constructions.Construction()
        @place C "A" 1
        @place C "B" 2
        @construct(C, "S", +, "A", "B")
        str = sprint(show, C)
        @test occursin("A", str)
        @test occursin("S", str)
    end
end
