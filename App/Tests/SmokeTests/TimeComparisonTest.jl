include("../../Main.jl")
include("../../BacktestUtils/BacktestUtils.jl")
include("../BenchmarkTimes.jl")
using Dates, JSON, BenchmarkTools, Test
using ..VectoriseBacktestService
using .VectoriseBacktestService.GlobalServerCache
using ..BacktestUtilites

GlobalServerCache.initialize_server_cache()

@testset "Time Comparison of Everything" begin
    strategy_data::Dict{String,Any} = read_json_file(
        "./App/Tests/TestsJSON/SmokeTestsJSON/Everything.json"
    )

    timing_data = @benchmark handle_backtesting_api(
        $strategy_data, 20000, "everything", Date("2025-03-13")
    )

    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_EVERYTHING_STRATEGY)
    @test MIN_EVERYTHING_STRATEGY - range <= min_time <= MIN_EVERYTHING_STRATEGY + range
    println("Minimum time taken for Strategy with Everything: ", min_time, " seconds")

    rm("Cache/"; force=true, recursive=true)
end
