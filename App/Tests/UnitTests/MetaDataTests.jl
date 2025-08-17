module MetaDataModule
include("../../Main.jl")
include("../../BacktestUtils/BacktestUtils.jl")
include("../BenchmarkTimes.jl")
using Test, Dates, BenchmarkTools
using .VectoriseBacktestService
using .VectoriseBacktestService.GlobalServerCache
initialize_server_cache()
using .BacktestUtilites

function test_small_strat()
    strategy_path = "./App/Tests/TestsJSON/UnitTestsJSON/first.json"
    strategy_data::Dict{String,Any} = BacktestUtilites.read_json_file(strategy_path)
    cache_tickers = strategy_data["tickers"]
    backtest_period, end_date = BacktestUtilites.read_metadata(cache_tickers)
    @testset "Small strategy test" begin
        @test backtest_period != nothing
        @test end_date == Date("2024-09-05")

        timing_data = @benchmark BacktestUtilites.read_metadata($cache_tickers)
        min_time = minimum(timing_data).time * 1e-9
        # range = get_range(MIN_READ_METADATA_SMALL_STRATEGY)
        # @test MIN_READ_METADATA_SMALL_STRATEGY - range <= min_time <= MIN_READ_METADATA_SMALL_STRATEGY + range
        println(
            "Minimum time taken for read_metadata with small strategy: ",
            min_time,
            " seconds",
        )
    end
end

function test_large_strat()
    strategy_path = "./App/Tests/TestsJSON/UnitTestsJSON/second.json"
    strategy_data::Dict{String,Any} = BacktestUtilites.read_json_file(strategy_path)
    cache_tickers = strategy_data["tickers"]
    backtest_period, end_date = BacktestUtilites.read_metadata(cache_tickers)
    @testset "Large strategy test" begin
        @test backtest_period != nothing
        @test end_date != nothing

        timing_data = @benchmark BacktestUtilites.read_metadata($cache_tickers)
        min_time = minimum(timing_data).time * 1e-9
        # range = get_range(MIN_READ_METADATA_LARGE_STRATEGY)
        # @test MIN_READ_METADATA_LARGE_STRATEGY - range <= min_time <= MIN_READ_METADATA_LARGE_STRATEGY + range
        println(
            "Minimum time taken for read_metadata with large strategy: ",
            min_time,
            " seconds",
        )
    end
end

end

MetaDataModule.test_small_strat()
MetaDataModule.test_large_strat()
