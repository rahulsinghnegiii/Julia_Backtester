module IgnoreCommentTest
using Dates, DataFrames, Test, JSON, BenchmarkTools
include("../../Main.jl")
include("../../BacktestUtils/BacktestUtils.jl")
include("../BenchmarkTimes.jl")

using .VectoriseBacktestService
using .VectoriseBacktestService.GlobalServerCache
using .BacktestUtilites
initialize_server_cache()

const ticker_list = ["UVXY", "UUP", "GLD", "SHY", "TQQQ", "SPXL", "QQQ", "SPY"]
@testset "Ensure strategy returns earliest date tickers" begin
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
    response = handle_backtesting_api(
        strategy_data, 0, "comment-strategy", Date("2024-05-30")
    )

    @test haskey(response, "ticker_dates")
    for item in response["ticker_dates"]
        @test item[1] in ticker_list
    end

    timing_data = @benchmark handle_backtesting_api(
        $strategy_data, 0, "comment-strategy", Date("2024-05-30")
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_EARLIEST_TICKER_DATES_STRATEGY)
    @test MIN_EARLIEST_TICKER_DATES_STRATEGY - range <=
        min_time <=
        MIN_EARLIEST_TICKER_DATES_STRATEGY + range
    println("Minimum time taken for Earliest Ticker Dates Test: ", min_time, " seconds")
end

@testset "Unit test of function returning earliest dates" begin
    ticker_dates = get_earliest_dates_of_tickers(Vector{Any}(ticker_list))
    for item in ticker_dates
        @test item[1] in ticker_list
    end

    timing_data = @benchmark get_earliest_dates_of_tickers(Vector{Any}($ticker_list))
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_EARLIEST_TICKER_DATES_FUNCTION)
    @test MIN_EARLIEST_TICKER_DATES_FUNCTION - range <=
        min_time <=
        MIN_EARLIEST_TICKER_DATES_FUNCTION + range
    println("Minimum time taken for Unit Test of Function: ", min_time, " seconds")
end
end
