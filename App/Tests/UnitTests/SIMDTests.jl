using Test
include("../../BacktestUtils/SIMDOperations.jl")

@testset "compare_greater! tests" begin
    # Test case 1: Arrays of equal length, operation :>
    xs1 = Float32[1.0, 2.0, 3.0, 4.0]
    ys1 = Float32[0.5, 2.0, 2.5, 4.5]
    result1 = compare_greater!(xs1, ys1, :>)
    @test result1 == BitVector([true, false, true, false])

    # Test case 2: Arrays of equal length, operation :>=
    xs2 = Float32[1.0, 2.0, 3.0, 4.0]
    ys2 = Float32[0.5, 2.0, 2.5, 4.0]
    result2 = compare_greater!(xs2, ys2, :>=)
    @test result2 == BitVector([true, true, true, true])

    # Test case 3: Arrays of different lengths, operation :>
    xs3 = Float32[1.0, 2.0, 3.0, 4.0, 5.0]
    ys3 = Float32[0.5, 2.0, 2.5]
    result3 = compare_greater!(xs3, ys3, :>)
    @test result3 == BitVector([true, false, true])

    # Test case 4: Arrays of different lengths, operation :>=
    xs4 = Float32[1.0, 2.0, 3.0, 4.0, 5.0]
    ys4 = Float32[0.5, 2.0, 2.5]
    result4 = compare_greater!(xs4, ys4, :>=)
    @test result4 == BitVector([true, true, true])

    # Test case 5: Edge case with empty arrays
    xs5 = Float32[]
    ys5 = Float32[]
    result5 = compare_greater!(xs5, ys5, :>)
    @test result5 == BitVector([])

    # Test case 6: Edge case with one element arrays
    xs6 = Float32[1.0]
    ys6 = Float32[0.5]
    result6 = compare_greater!(xs6, ys6, :>)
    @test result6 == BitVector([true])

    # Test case 7: Unsupported operation
    xs7 = Float32[1.0, 2.0, 3.0]
    ys7 = Float32[0.5, 2.0, 2.5]
    @test_throws ErrorException compare_greater!(xs7, ys7, :<)
end

@testset "compare_lower! tests" begin
    # Test case 1: Arrays of equal length, operation :<
    xs1 = Float32[1.0, 2.0, 3.0, 4.0]
    ys1 = Float32[1.5, 2.0, 3.5, 4.5]
    result1 = compare_lower!(xs1, ys1, :<)
    @test result1 == BitVector([true, false, true, true])

    # Test case 2: Arrays of equal length, operation :<=
    xs2 = Float32[1.0, 2.0, 3.0, 4.0]
    ys2 = Float32[1.0, 2.0, 3.5, 4.0]
    result2 = compare_lower!(xs2, ys2, :<=)
    @test result2 == BitVector([true, true, true, true])

    # Test case 3: Arrays of different lengths, operation :<
    xs3 = Float32[1.0, 2.0, 3.0, 4.0, 5.0]
    ys3 = Float32[1.5, 2.0, 3.5]
    result3 = compare_lower!(xs3, ys3, :<)
    @test result3 == BitVector([true, false, true])

    # Test case 4: Arrays of different lengths, operation :<=
    xs4 = Float32[1.0, 2.0, 3.0, 4.0, 5.0]
    ys4 = Float32[1.0, 2.0, 3.5]
    result4 = compare_lower!(xs4, ys4, :<=)
    @test result4 == BitVector([true, true, true])

    # Test case 5: Edge case with empty arrays
    xs5 = Float32[]
    ys5 = Float32[]
    result5 = compare_lower!(xs5, ys5, :<)
    @test result5 == BitVector([])

    # Test case 6: Edge case with one element arrays
    xs6 = Float32[1.0]
    ys6 = Float32[1.5]
    result6 = compare_lower!(xs6, ys6, :<)
    @test result6 == BitVector([true])

    # Test case 7: Unsupported operation
    xs7 = Float32[1.0, 2.0, 3.0]
    ys7 = Float32[1.5, 2.0, 3.5]
    @test_throws ErrorException compare_lower!(xs7, ys7, :>)
end
