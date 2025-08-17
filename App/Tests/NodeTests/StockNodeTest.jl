using Dates, DataFrames, Test, BenchmarkTools
include("./../../Main.jl")
include("./../../NodeProcessors/StockNode.jl")
include("./../BenchmarkTimes.jl")

using Main.VectoriseBacktestService
using ..VectoriseBacktestService.Types
using .VectoriseBacktestService.GlobalServerCache
using ..StockNode
initialize_server_cache()

@testset "Stock Node Test" begin
    stock_node::Dict{String,Any} = Dict(
        "id" => "75655862ba5e5f99d0871b0d897443a1",
        "componentType" => "largeTask",
        "type" => "stock",
        "name" => "BUY AAPL",
        "properties" => Dict("isInvalid" => false, "symbol" => "AAPL"),
        "parentHash" => "b4b147bc522828731f1a016bfa72c073",
    )
    active_branch_mask::BitVector = BitVector(trues(10))
    total_days::Int = 10
    node_weight::Float32 = 1.0f0
    portfolio_history::Vector{DayData} = [DayData() for _ in 1:10]
    flow_count::Dict{String,Int} = Dict{String,Int}()
    flow_stocks::Dict{String,Vector{DayData}} = Dict{String,Vector{DayData}}()

    process_stock_node(
        stock_node,
        active_branch_mask,
        total_days,
        node_weight,
        portfolio_history,
        flow_count,
        flow_stocks,
    )

    expected_portfolio_history = [DayData([StockInfo("AAPL", 1.0f0)]) for _ in 1:10]

    for i in 1:10
        @test portfolio_history[i] == expected_portfolio_history[i]
    end

    timing_data = @benchmark process_stock_node(
        $stock_node,
        $active_branch_mask,
        $total_days,
        $node_weight,
        $portfolio_history,
        $flow_count,
        $flow_stocks,
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_STOCK_NODE)
    @test MIN_STOCK_NODE - range <= min_time <= MIN_STOCK_NODE + range
    println("Minimum time taken for Stock Node: ", min_time, " seconds")
end

@testset "Stock Node Error Test" begin
    stock_node::Dict{String,Any} = Dict(
        "id" => "75655862ba5e5f99d0871b0d897443a1",
        "componentType" => "largeTask",
        "type" => "stock",
        "name" => "BUY AAPL",
        "." => Dict("isInvalid" => false, "symbol" => "AAPL"), # missing properties
        "parentHash" => "b4b147bc522828731f1a016bfa72c073",
    )
    active_branch_mask::BitVector = BitVector(trues(10))
    total_days::Int = 10
    node_weight::Float32 = 1.0f0
    portfolio_history::Vector{DayData} = [DayData() for _ in 1:10]
    flow_count::Dict{String,Int} = Dict{String,Int}()
    flow_stocks::Dict{String,Vector{DayData}} = Dict{String,Vector{DayData}}()

    @test_throws r"ValidationError" process_stock_node(
        stock_node,
        active_branch_mask,
        total_days,
        node_weight,
        portfolio_history,
        flow_count,
        flow_stocks,
    )
end
