include("./../../Main.jl")
include("./../../NodeProcessors/LockOnTriggerNode.jl")
include("./../BenchmarkTimes.jl")

using Dates, DataFrames, Test, HTTP, JSON, BenchmarkTools
using .VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.BacktestUtilites
using ..LockOnTriggerNode
using .VectoriseBacktestService.GlobalServerCache
initialize_server_cache()

@testset "find_triggered_branch test" begin
    branch_data = Dict{String,Dict{String,Any}}()
    branch_data["a"] = Dict(
        "exit_mask" => [false, false, true, false, false, false, true, false, false],
        "entry_mask" => [false, true, false, false, true, false, false, false, false],
    )
    branch_data["b"] = Dict(
        "exit_mask" => [false, false, false, false, true, false, false, false, true],
        "entry_mask" => [false, true, true, true, true, false, true, false, true],
    )
    branch_data["c"] = Dict(
        "entry_mask" => [false, true, true, false, false, false, true, true, true]
    )

    result = Vector{String}()
    current_branch = "default"
    for day in 1:9
        current_branch = find_triggered_branch(
            branch_data, day, ["a", "b", "c"], current_branch
        )
        push!(result, current_branch)
    end
    @test result == ["default", "a", "default", "b", "a", "a", "default", "c", "c"]

    timing_data = @benchmark find_triggered_branch(
        $branch_data, 9, ["a", "b", "c"], "default"
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_LOT_FIND_TRIGGERED_BRANCH)
    @test MIN_LOT_FIND_TRIGGERED_BRANCH - range <=
        min_time <=
        MIN_LOT_FIND_TRIGGERED_BRANCH + range
    println("Minimum time taken for find_triggered_branch: ", min_time, " seconds")
end

@testset "smoke test" begin
    strategy_data = JSON.parse(
        read("./App/Tests/TestsJSON/SmokeTestsJSON/LockOnTriggerTest.json", String)
    )
    profile_history::Vector{DayData}, trading_dates::Vector{String}, min_days::Int, flow_count::Dict{String,Int}, flow_stocks::Dict{String,Vector{DayData}} = execute_backtest(
        strategy_data, 15772, Date("2024-08-30"), Dict{String,DataFrame}(), 0
    )

    expected_profile_history = DayData[
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("AAPL", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
        DayData(StockInfo[StockInfo("SPY", 1.0f0)]),
    ]
    @test profile_history[(end - 250):end] == expected_profile_history

    timing_data = @benchmark execute_backtest(
        $strategy_data, 15772, Date("2024-08-30"), Dict{String,DataFrame}(), 0
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_LOCK_ON_TRIGGER_NODE_SMOKE_TEST)
    @test MIN_LOCK_ON_TRIGGER_NODE_SMOKE_TEST - range <=
        min_time <=
        MIN_LOCK_ON_TRIGGER_NODE_SMOKE_TEST + range
    println(
        "Minimum time taken for Lock On Trigger Node Smoke Test: ", min_time, " seconds"
    )
end

@testset "smoke test with synthetic stock and modified branch names" begin
    strategy_data = JSON.parse(
        read("./App/Tests/TestsJSON/SmokeTestsJSON/LOTSS.json", String)
    )
    profile_history::Vector{DayData}, trading_dates::Vector{String}, min_days::Int, flow_count::Dict{String,Int}, flow_stocks::Dict{String,Vector{DayData}} = execute_backtest(
        strategy_data, 15772, Date("2024-08-30"), Dict{String,DataFrame}(), 0
    )

    expected_profile_history = [
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
        DayData(StockInfo[StockInfo("SPY", 1.0f0)])
    ]

    @test profile_history[(end - 249):end] == expected_profile_history[(end - 249):end]

    # timing_data = @benchmark execute_backtest(
    #     $strategy_data,
    #     15772,
    #     Date("2024-08-30"),
    #     Dict{String,DataFrame}(),
    #     0
    # )

    # min_time = minimum(timing_data).time * 1e-9
    # range = get_range(MIN_LOCK_ON_TRIGGER_NODE_SYNTHETIC_STOCK)
    # # @test MIN_LOCK_ON_TRIGGER_NODE_SYNTHETIC_STOCK - range <= min_time <= MIN_LOCK_ON_TRIGGER_NODE_SYNTHETIC_STOCK + range
    # println("Minimum time taken for Lock On Trigger Node with Synthetic Stock: ", min_time, " seconds")
end

@testset "Error throwing" begin
    strategy_data = JSON.parse(
        read("./App/Tests/TestsJSON/SmokeTestsJSON/LockOnTriggerTest.json", String)
    )
    delete!(strategy_data["sequence"][1], "branches")
    active_branch_mask::BitVector = BitVector()
    total_days::Int = 50000
    node_weight::Float32 = 1.0f0
    portfolio_history::Vector{DayData} = Vector{DayData}()
    date_range::Vector{String} = Vector{String}()
    end_date::Date = Date("2024-08-30")
    flow_count::Dict{String,Int} = Dict{String,Int}()
    flow_stocks::Dict{String,Vector{DayData}} = Dict{String,Vector{DayData}}()
    price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()
    indicator_cache::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()
    @testset "Throws error when branches are missing" begin
        @test_throws r"LockOnTriggerNode.*Branches missing" process_lock_on_trigger_node(
            strategy_data["sequence"][1],
            active_branch_mask,
            total_days,
            node_weight,
            portfolio_history,
            date_range,
            end_date,
            flow_count,
            flow_stocks,
            price_cache,
            indicator_cache,
            Dict{String,Any}(),
            false,
        )
    end

    @testset "Throws error when default branch is missing" begin
        strategy_data = JSON.parse(
            read("./App/Tests/TestsJSON/SmokeTestsJSON/LockOnTriggerTest.json", String)
        )
        delete!(strategy_data["sequence"][1]["branches"], "default")
        @test_throws r"LockOnTriggerNode.*Default branch missing" process_lock_on_trigger_node(
            strategy_data["sequence"][1],
            active_branch_mask,
            total_days,
            node_weight,
            portfolio_history,
            date_range,
            end_date,
            flow_count,
            flow_stocks,
            price_cache,
            indicator_cache,
            Dict{String,Any}(),
            false,
        )
    end

    @testset "Throws error when conditions are missing" begin
        strategy_data = JSON.parse(
            read("./App/Tests/TestsJSON/SmokeTestsJSON/LockOnTriggerTest.json", String)
        )
        delete!(strategy_data["sequence"][1]["properties"], "conditions")
        @test_throws r"LockOnTriggerNode.*Conditions missing in properties" process_lock_on_trigger_node(
            strategy_data["sequence"][1],
            active_branch_mask,
            total_days,
            node_weight,
            portfolio_history,
            date_range,
            end_date,
            flow_count,
            flow_stocks,
            price_cache,
            indicator_cache,
            Dict{String,Any}(),
            false,
        )
    end

    @testset "Length of one branch is zero" begin
        strategy_data = JSON.parse(
            read("./App/Tests/TestsJSON/SmokeTestsJSON/LockOnTriggerTest.json", String)
        )
        strategy_data["sequence"][1]["branches"]["a"] = []
        @test_throws r"LockOnTriggerNode.*Branch a sequence is empty" process_lock_on_trigger_node(
            strategy_data["sequence"][1],
            active_branch_mask,
            total_days,
            node_weight,
            portfolio_history,
            date_range,
            end_date,
            flow_count,
            flow_stocks,
            price_cache,
            indicator_cache,
            Dict{String,Any}(),
            false,
        )
    end
end
