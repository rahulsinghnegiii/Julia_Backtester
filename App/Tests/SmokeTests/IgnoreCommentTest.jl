module IgnoreCommentTest
using Dates, DataFrames, Test, JSON, BenchmarkTools
include("../../Main.jl")
include("../../BacktestUtils/BacktestUtils.jl")
include("../BenchmarkTimes.jl")

using .VectoriseBacktestService
using .VectoriseBacktestService.GlobalServerCache
using .BacktestUtilites
initialize_server_cache()

if isdir("./Cache/")
    rm("./Cache/"; recursive=true)
end
if isdir("./IndicatorData/")
    rm("./IndicatorData/"; recursive=true)
end
if isdir("./SubtreeCache")
    rm("./SubtreeCache"; recursive=true)
    mkdir("./SubtreeCache")
end

strategy_data::Dict{String,Any} = read_json_file(
    "./App/Tests/TestsJSON/SmokeTestsJSON/Comment-strategy.json"
)
response = handle_backtesting_api(strategy_data, 0, "comment-strategy", Date("2024-05-30"))

@testset "Accumulated weights should equal 1.0 everyday" begin
    for day in response["profile_history"]
        if length(day.stockList) == 1
            @test day.stockList[1].weightTomorrow == 1.0
        else
            sum = 0
            for stock in day.stockList
                sum += stock.weightTomorrow
            end
            @test isapprox(sum, 1.0, atol=0.01)
        end
    end
end

@testset "Timing for Ignore Comments Test" begin
    timing_data = @benchmark handle_backtesting_api(
        $strategy_data, 0, "comment-strategy", Date("2024-05-30")
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_IGNORE_COMMENTS_STRATEGY)
    @test MIN_IGNORE_COMMENTS_STRATEGY - range <=
        min_time <=
        MIN_IGNORE_COMMENTS_STRATEGY + range
    println("Minimum time taken for Ignore Comments Test: ", min_time, " seconds")
end

end
