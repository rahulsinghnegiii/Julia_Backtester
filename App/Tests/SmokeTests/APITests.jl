include("../../Main.jl")
include("../../BacktestUtils/Types.jl")
include("../../BacktestUtils/BacktestUtils.jl")
include("../BenchmarkTimes.jl")
using .VectoriseBacktestService
using .VectoriseBacktestService.GlobalServerCache
initialize_server_cache()
using .BacktestUtilites
using .Types
using Test, Dates
using Base, BenchmarkTools

@testset "Profile History Test Simple Stock: AAPL" begin
    if isdir("./Cache/hash")
        rm("./Cache/hash"; recursive=true)
    end
    json_path = "./App/Tests/TestsJSON/DevJSON/AAPL.json"
    json_data = BacktestUtilites.read_json_file(json_path)
    response = handle_backtesting_api(json_data, 50000, "hash", Date("2024-05-30"))
    expected_profile_history = [DayData([StockInfo("AAPL", 1.0f0)]) for _ in 1:50]
    @test haskey(response, "profile_history")
    @test haskey(response, "returns")
    @test haskey(response, "dates")
    for i in 1:50
        @test response["profile_history"][i].stockList[1].ticker ==
            expected_profile_history[i].stockList[1].ticker
    end

    timing_data = @benchmark handle_backtesting_api(
        $json_data, 50000, "hash", Date("2024-05-30")
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_API_TEST_AAPL)
    @test MIN_API_TEST_AAPL - range <= min_time <= MIN_API_TEST_AAPL + range
    println("Minimum time taken for API Test AAPL: ", min_time, " seconds")
end

@testset "Profile History Test Sort Node" begin
    if isdir("./Cache/hash2")
        rm("./Cache/hash2"; recursive=true)
    end
    json_path = "./App/Tests/TestsJSON/UnitTestsJSON/IF/CNSTvsCP.json"
    json_data = BacktestUtilites.read_json_file(json_path)
    response = handle_backtesting_api(json_data, 50000, "hash2", Date("2024-05-30"))
    expected_profile_history = [DayData([StockInfo("AAPL", 1.0f0)]) for _ in 1:50]
    @test haskey(response, "profile_history")
    @test haskey(response, "returns")
    @test haskey(response, "dates")
    for i in 1:50
        @test response["profile_history"][(end - i)].stockList[1].ticker ==
            expected_profile_history[i].stockList[1].ticker
    end

    timing_data = @benchmark handle_backtesting_api(
        $json_data, 50000, "hash2", Date("2024-05-30")
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_API_TEST_SORT_NODE)
    @test MIN_API_TEST_SORT_NODE - range <= min_time <= MIN_API_TEST_SORT_NODE + range
    println("Minimum time taken for API Test Sort Node: ", min_time, " seconds")
end
