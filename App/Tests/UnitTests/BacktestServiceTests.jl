include("../../BacktestUtils/Types.jl")
include("../../Main.jl")
include("../../BacktestUtils/FlowData.jl")
include("../../BacktestUtils/TASorting.jl")
include("../../NodeProcessors/SortNode.jl")
include("../../NodeProcessors/StockNode.jl")
include("../../BacktestUtils/GlobalCache.jl")
include("../../BacktestUtils/BacktestUtils.jl")
include("../../NodeProcessors/ConditonalNode.jl")
include("../../NodeProcessors/AllocationNode.jl")
include("../../BacktestUtils/ReturnCalculations.jl")

using Test
using JSON
using Dates
using ..SortNode
using DataFrames
using ..FlowData
using ..StockNode
using ..TASorting
using ..GlobalCache
using ..AllocationNode
using ..ConditionalNode
using ..BacktestUtilites
using .ReturnCalculations
using ..VectoriseBacktestService
using ..VectoriseBacktestService.GlobalServerCache
using .VectoriseBacktestService.Types
initialize_server_cache()

const json_path = "./App/Tests/TestsJSON/UnitTestsJSON/simpleQLDV2.json"
const end_date = Date("2024-5-30")
const numDays_param = 50

# This test set tests the entire handle_backtesting() function
# by calling execute_backtest() to get the inputs for final_return_curve(), this has been done to simulate an actual call to the function
@testset "handle_backtesting tests" begin
    @testset "execute_backtest tests" begin
        json_data::Dict{String,Any} = read_json_file(json_path)
        price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()
        dateVector, dates, min_days, flow_count, flow_stocks = execute_backtest(
            json_data, numDays_param, end_date, price_cache, 0
        )

        ans_dates = [
            "2024-03-20",
            "2024-03-21",
            "2024-03-22",
            "2024-03-25",
            "2024-03-26",
            "2024-03-27",
            "2024-03-28",
            "2024-04-01",
            "2024-04-02",
            "2024-04-03",
            "2024-04-04",
            "2024-04-05",
            "2024-04-08",
            "2024-04-09",
            "2024-04-10",
            "2024-04-11",
            "2024-04-12",
            "2024-04-15",
            "2024-04-16",
            "2024-04-17",
            "2024-04-18",
            "2024-04-19",
            "2024-04-22",
            "2024-04-23",
            "2024-04-24",
            "2024-04-25",
            "2024-04-26",
            "2024-04-29",
            "2024-04-30",
            "2024-05-01",
            "2024-05-02",
            "2024-05-03",
            "2024-05-06",
            "2024-05-07",
            "2024-05-08",
            "2024-05-09",
            "2024-05-10",
            "2024-05-13",
            "2024-05-14",
            "2024-05-15",
            "2024-05-16",
            "2024-05-17",
            "2024-05-20",
            "2024-05-21",
            "2024-05-22",
            "2024-05-23",
            "2024-05-24",
            "2024-05-28",
            "2024-05-29",
            "2024-05-30",
        ]
        @test min_days == 50
        @test dates == ans_dates

        @testset "final_return_curve tests" begin
            return_curve = calculate_final_return_curve(
                dateVector, dates, min_days, end_date, price_cache, DayData()
            )

            ans_return_curve = Float32[
                0.0,
                0.004732181,
                0.0011438312,
                -0.0036291948,
                -0.0032377013,
                0.0034061174,
                -0.0018434009,
                0.0021170694,
                -0.0086301835,
                0.0022443382,
                -0.015290658,
                0.011783893,
                0.0002951393,
                0.0036995006,
                -0.008728489,
                0.015968246,
                -0.0159418,
                -0.016451046,
                9.279451f-5,
                -0.0122013455,
                -0.0057063685,
                -0.020689167,
                0.0100566745,
                0.014922879,
                0.0033876773,
                -0.0048298985,
                0.015431735,
                0.0040603247,
                -0.018856153,
                -0.007230505,
                0.012763333,
                0.020098384,
                0.010953431,
                0.00015900057,
                -0.00059047964,
                0.0021815207,
                0.0023581698,
                0.0023073792,
                0.006432247,
                0.015630256,
                -0.0020313535,
                -0.0004867472,
                0.0069727288,
                0.001956431,
                -0.00019745503,
                -0.0044984748,
                0.009456421,
                0.003777705,
                -0.0070483815,
                -0.010713347,
            ]

            @test return_curve == ans_return_curve
        end
    end
end

@testset "conditionEval tests" begin
    node = Dict{String,Any}(
        "name" => "if((current price . QQQ < Moving Average of Price . QQQ 20))",
        "componentType" => "switch",
        "branches" => Dict{String,Any}(
            "true" => Any[Dict{String,Any}(
                "name" => "SortBy Relative Strength Index",
                "componentType" => "switch",
                "branches" => Dict{String,Any}(
                    "1" => Any[Dict{String,Any}(
                        "name" => "Buy Order PSQ",
                        "componentType" => "task",
                        "properties" => Dict{String,Any}("symbol" => "PSQ"),
                        "id" => "247d1615-ef71-42f9-a9cc-1452f0de5429",
                        "type" => "stock",
                    )],
                    "2" => Any[Dict{String,Any}(
                        "name" => "Buy Order SHY",
                        "componentType" => "task",
                        "properties" => Dict{String,Any}("symbol" => "SHY"),
                        "id" => "f7537348-f9d1-4619-98f6-6b5dee06e8da",
                        "type" => "stock",
                    )],
                ),
                "properties" => Dict{String,Any}(
                    "sortby" => Dict{String,Any}(
                        "function" => "Relative Strength Index",
                        "window" => "10",
                    ),
                    "select" => Dict{String,Any}("function" => "Top", "howmany" => "1"),
                ),
                "id" => "01686dff-09ba-4833-8cc7-9e8a07b35b40",
                "type" => "Sort",
            )],
            "false" => Any[Dict{String,Any}(
                "name" => "Buy Order QQQ",
                "componentType" => "task",
                "properties" => Dict{String,Any}("symbol" => "QQQ"),
                "id" => "d93d72fc-d907-4aa5-bff1-ad12c7f834c7",
                "type" => "stock",
            )],
        ),
        "properties" => Dict{String,Any}(
            "comparison" => "<",
            "x" => Dict{String,Any}("source" => "QQQ", "indicator" => "current price"),
            "y" => Dict{String,Any}(
                "source" => "QQQ",
                "period" => "20",
                "indicator" => "Moving Average of Price",
            ),
        ),
        "id" => "4a4673b9-6f24-4d40-b28b-92f4dafb40a6",
        "type" => "condition",
    )

    dates = [
        "2024-03-20",
        "2024-03-21",
        "2024-03-22",
        "2024-03-25",
        "2024-03-26",
        "2024-03-27",
        "2024-03-28",
        "2024-04-01",
        "2024-04-02",
        "2024-04-03",
        "2024-04-04",
        "2024-04-05",
        "2024-04-08",
        "2024-04-09",
        "2024-04-10",
        "2024-04-11",
        "2024-04-12",
        "2024-04-15",
        "2024-04-16",
        "2024-04-17",
        "2024-04-18",
        "2024-04-19",
        "2024-04-22",
        "2024-04-23",
        "2024-04-24",
        "2024-04-25",
        "2024-04-26",
        "2024-04-29",
        "2024-04-30",
        "2024-05-01",
        "2024-05-02",
        "2024-05-03",
        "2024-05-06",
        "2024-05-07",
        "2024-05-08",
        "2024-05-09",
        "2024-05-10",
        "2024-05-13",
        "2024-05-14",
        "2024-05-15",
        "2024-05-16",
        "2024-05-17",
        "2024-05-20",
        "2024-05-21",
        "2024-05-22",
        "2024-05-23",
        "2024-05-24",
        "2024-05-28",
        "2024-05-29",
        "2024-05-30",
    ]

    dateLength::Int = 50
    cache = Dict{String,Vector{Float32}}(
        "sma_SPY_200_50_2024-05-30" => [
            453.22644,
            453.73096,
            454.22598,
            454.72113,
            455.1988,
            455.6944,
            456.17035,
            456.62772,
            457.06598,
            457.48047,
            457.87073,
            458.29895,
            458.73965,
            459.17563,
            459.60193,
            460.0563,
            460.45175,
            460.81418,
            461.16354,
            461.4726,
            461.77396,
            462.0569,
            462.3796,
            462.7374,
            463.0885,
            463.41623,
            463.75015,
            464.07562,
            464.36218,
            464.63297,
            464.91052,
            465.2143,
            465.5593,
            465.90714,
            466.24524,
            466.5921,
            466.94196,
            467.30704,
            467.6622,
            468.04538,
            468.42957,
            468.84885,
            469.27756,
            469.72272,
            470.14105,
            470.54974,
            470.9906,
            471.43246,
            471.85715,
            472.25232,
        ],
    )

    ans_result = Bool[
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
        1,
        1,
        1,
        0,
        1,
        0,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        0,
        1,
        1,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
    ]

    price_cache = Dict{String,DataFrame}()
    result = conditionEval(
        node, dates, dateLength, end_date, cache, price_cache, Dict{String,Any}(), false
    )
    println(result)
    @test result == ans_result
end

@testset "post_order_dfs tests" begin
    numDays_param_post_order = 5000
    post_order_dfs_json_path = json_path
    json_data::Dict{String,Any} = read_json_file(post_order_dfs_json_path)
    isBranchActive::BitVector = BitVector(trues(numDays_param_post_order))
    dateVector::Vector{DayData} = [DayData() for _ in 1:numDays_param_post_order]
    dates::Vector{String} = []
    dates = populate_dates(numDays_param_post_order, end_date, dates)
    flow_count::Dict{String,Int} = Dict{String,Int}()
    flow_stocks::Dict{String,Vector{DayData}} = Dict{String,Vector{DayData}}()
    price_cache = Dict{String,DataFrame}()
    cache::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()

    effective_days = post_order_dfs(
        json_data["sequence"][1],
        isBranchActive,
        numDays_param_post_order,
        1.0f0,
        dateVector,
        dates,
        end_date,
        flow_count,
        flow_stocks,
        cache,
        price_cache,
        0,
    )

    @test effective_days == 4496
end

@testset "increment_flow_count" begin
    @testset "Increment count for existing node_id" begin
        flow_count = Dict("node1" => 2, "node2" => 3)
        node_id = "node1"
        increment_flow_count(flow_count, node_id)
        @test flow_count["node1"] == 3
    end

    @testset "Increment count for new node_id" begin
        flow_count = Dict("node1" => 2, "node2" => 3)
        node_id = "node3"
        increment_flow_count(flow_count, node_id)
        @test flow_count["node3"] == 1
    end

    @testset "increment_count_special_characters_node_id" begin
        flow_count = Dict("node#1" => 1, "node@2" => 4)
        node_id = "node#1"
        increment_flow_count(flow_count, node_id)
        @test flow_count["node#1"] == 2
    end
end

@testset "set_flow_stocks tests" begin
    @testset "test_assigns_date_vector_to_node_id" begin
        flow_stocks = Dict{String,Vector{DayData}}()
        dateVector = [DayData(), DayData()]
        node_id = "node_1"
        set_flow_stocks(flow_stocks, dateVector, node_id)
        @test flow_stocks[node_id] == dateVector
    end

    @testset "test_handles_empty_date_vector" begin
        flow_stocks = Dict{String,Vector{DayData}}()
        dateVector = Vector{DayData}()
        node_id = "node_2"
        set_flow_stocks(flow_stocks, dateVector, node_id)
        @test flow_stocks[node_id] == dateVector
    end
end

@testset "process_stock_node tests" begin
    @testset "test_process_stock_node_valid_symbol" begin
        node = Dict("properties" => Dict("symbol" => "AAPL"), "id" => "node1")
        isBranchActive = BitVector([true, false, true])
        dateLength = 3
        weightTomorrow = 0.5f0
        dateVector = [DayData() for _ in 1:3]
        flow_count = Dict{String,Int}()
        flow_stocks = Dict{String,Vector{DayData}}()

        process_stock_node(
            node,
            isBranchActive,
            dateLength,
            weightTomorrow,
            dateVector,
            flow_count,
            flow_stocks,
        )

        @test length(dateVector[1].stockList) == 1
        @test dateVector[1].stockList[1].ticker == "AAPL"
        @test dateVector[1].stockList[1].weightTomorrow == 0.5f0
    end

    @testset "throws error" begin
        node = Dict("properties" => Dict(), "id" => "node1")
        isBranchActive = BitVector([true, false, true])
        dateLength = 3
        weightTomorrow = 0.5f0
        dateVector = [DayData() for _ in 1:3]
        flow_count = Dict{String,Int}()
        flow_stocks = Dict{String,Vector{DayData}}()

        @test_throws r"ValidationError" process_stock_node(
            node,
            isBranchActive,
            dateLength,
            weightTomorrow,
            dateVector,
            flow_count,
            flow_stocks,
        )
    end
end

@testset "process_condition_node tests" begin
    @testset "valid data" begin
        node = Dict{String,Any}(
            "id" => "test_node",
            "type" => "condition",
            "name" => "if(current price . SPY > 14d Relative Strength Index . SPY)",
            "properties" => Dict{String,Any}(
                "comparison" => ">",
                "x" =>
                    Dict{String,Any}("indicator" => "current price", "source" => "SPY"),
                "y" => Dict{String,Any}(
                    "indicator" => "Relative Strength Index",
                    "source" => "SPY",
                    "period" => "14",
                ),
            ),
            "branches" => Dict{String,Any}(
                "true" => [
                    Dict{String,Any}(
                        "id" => "d93d72fc-d907-4aa5-bff1-ad12c7f834d7",
                        "componentType" => "task",
                        "type" => "stock",
                        "name" => "Buy Order SPY",
                        "properties" => Dict{String,Any}("symbol" => "SPY"),
                    ),
                ],
                "false" => [
                    Dict{String,Any}(
                        "id" => "d93d72fc-d907-4aa5-bff1-ad12c7f834c8",
                        "componentType" => "task",
                        "type" => "stock",
                        "name" => "Sell Order QQQ",
                        "properties" => Dict{String,Any}("symbol" => "QQQ"),
                    ),
                ],
            ),
        )
        # isBranchActive = trues(4)
        # dateLength = 4
        # weightTomorrow = 0.5f0
        # dateVector = [DayData() for _ in 1:4]
        # dates = ["2023-01-01", "2023-01-02", "2023-01-03", "2023-01-04"]
        # end_date_local = Date("2023-01-04")
        # flow_count = Dict{String,Int}()
        # flow_stocks = Dict{String,Vector{DayData}}()
        # cache = Dict{String,Vector{Float32}}()
        # price_cache = Dict{String,DataFrame}()

        # # Call the function under test
        # result = process_condition_node(
        #     node,
        #     isBranchActive,
        #     dateLength,
        #     weightTomorrow,
        #     dateVector,
        #     dates,
        #     end_date_local,
        #     flow_count,
        #     flow_stocks,
        #     cache,
        #     price_cache,
        # )

        # Assertions
        # @test result == 2
        # @test haskey(flow_count, "test_node")
        # @test flow_count["test_node"] == 1
        # @test haskey(flow_stocks, "test_node")
        # @test length(flow_stocks["test_node"]) == 4
    end

    @testset "empty branches" begin
        node = Dict{String,Any}(
            "id" => "test_node",
            "type" => "condition",
            "name" => "if(current price . SPY > 14d Relative Strength Index . SPY)",
            "properties" => Dict{String,Any}(
                "comparison" => ">",
                "x" =>
                    Dict{String,Any}("indicator" => "current price", "source" => "SPY"),
                "y" => Dict{String,Any}(
                    "indicator" => "Relative Strength Index",
                    "source" => "SPY",
                    "period" => "14",
                ),
            ),
            "branches" => Dict{String,Any}("true" => [], "false" => []),
        )
        isBranchActive = BitVector([true, true, false, true])
        dateLength = 4
        weightTomorrow = 0.5f0
        dateVector = Vector{DayData}(undef, 4)
        dates = ["2023-01-01", "2023-01-02", "2023-01-03", "2023-01-04"]
        end_date_local = Date("2023-01-04")
        flow_count = Dict{String,Int}()
        flow_stocks = Dict{String,Vector{DayData}}()
        cache = Dict{String,Vector{Float32}}()
        price_cache = Dict{String,DataFrame}()

        @test_throws r"ConditionNodeError" process_condition_node(
            node,
            isBranchActive,
            dateLength,
            weightTomorrow,
            dateVector,
            dates,
            end_date_local,
            flow_count,
            flow_stocks,
            cache,
            price_cache,
            Dict{String,Any}(),
            0,
            false,
        )
    end
end

@testset "package_response tests" begin
    @testset "valid input" begin
        return_curve = [0.1f0, 0.2f0, 0.3f0]
        dates = ["2023-01-01", "2023-01-02", "2023-01-03"]
        profile_history = [
            DayData([StockInfo("AAPL", 1.0)]),
            DayData([StockInfo("AAPL", 1.0)]),
            DayData([StockInfo("AAPL", 1.0)]),
        ]
        expected_response = Dict(
            "dates" => ["2023-01-01", "2023-01-02", "2023-01-03"],
            "returns" => Float32[0.1, 0.2, 0.3],
            "profile_history" => profile_history,
        )

        response = package_response(return_curve, dates, profile_history)

        @test response == expected_response
    end

    @testset "valid return type" begin
        return_curve = [0.1f0, 0.2f0, 0.3f0]
        dates = ["2023-01-01", "2023-01-02", "2023-01-03"]
        profile_history = [
            DayData([StockInfo("AAPL", 1.0)]),
            DayData([StockInfo("AAPL", 1.0)]),
            DayData([StockInfo("AAPL", 1.0)]),
        ]

        response = package_response(return_curve, dates, profile_history)

        @test typeof(response) == Dict{String,Vector}
    end
end

@testset "process_single_day tests" begin
    branch_dateVector = [StockInfo("SPY", 100.0f0)]
    dates = [
        "2024-05-16",
        "2024-05-17",
        "2024-05-20",
        "2024-05-21",
        "2024-05-22",
        "2024-05-23",
        "2024-05-24",
        "2024-05-28",
        "2024-05-29",
        "2024-05-30",
    ]
    end_date_local = "2024-05-30"
    price_cache = Dict{String,DataFrame}()
    min_data_length = 10
    dateLength = 10

    daily_return, all_stocks_have_data, min_data_length = process_single_day(
        branch_dateVector, dates, 2, end_date, price_cache, min_data_length, dateLength
    )
    @test isapprox(daily_return, 11.521390121752692, atol=1e-4)
    @test all_stocks_have_data == true
    @test min_data_length == 10
end

@testset "extract_delta tests" begin
    flow_stocks = Dict{String,Vector{DayData}}(
        "46d20311eb3c406283ac85b4f7feb129" => [
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
        ],
        "60114eb251d64be5a184d80ba4d27dcc" => [
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
            DayData(StockInfo[StockInfo("QQQ", 1.0f0)]),
        ],
    )
    dates = ["2024-05-24", "2024-05-28", "2024-05-29", "2024-05-30", "2024-05-31"]
    period = 5
    end_date_local = Date("2024-06-01")
    price_cache = Dict{String,DataFrame}()
    delta = extract_delta(flow_stocks, dates, period, end_date_local, price_cache)
    expected_delta = Dict{String,Vector{Float32}}(
        "46d20311eb3c406283ac85b4f7feb129" =>
            [0.0, 0.003777705, -0.0070483815, -0.010713347, -0.0018602591],
        "60114eb251d64be5a184d80ba4d27dcc" =>
            [0.0, 0.003777705, -0.0070483815, -0.010713347, -0.0018602591],
    )
    @test delta == expected_delta
end

# this testset sets the entirety of the process_sort_node function
# by testing the functions that are called within it as well
@testset "process_sort_node entire" begin
    branches = Dict{String,Any}(
        "1" => Dict{String,Any}[Dict(
            "name" => "Buy Order MSFT",
            "componentType" => "largeTask",
            "properties" => Dict{String,Any}("symbol" => "MSFT"),
            "id" => "b86567817630492f981f40fe14a3aef7",
            "type" => "stock",
        )],
        "2" => Dict{String,Any}[Dict(
            "name" => "Buy Order AAPL",
            "componentType" => "largeTask",
            "properties" => Dict{String,Any}("symbol" => "AAPL"),
            "id" => "de27becbabb84bdfa3fb3d74c49e90d6",
            "type" => "stock",
        )],
        "3" => Dict{String,Any}[Dict(
            "name" => "Buy Order NVDA",
            "componentType" => "largeTask",
            "properties" => Dict{String,Any}("symbol" => "NVDA"),
            "id" => "16570b5c6bf54b91a8d611babfd0b32e",
            "type" => "stock",
        )],
    )
    dates = [
        "2024-05-02",
        "2024-05-03",
        "2024-05-06",
        "2024-05-07",
        "2024-05-08",
        "2024-05-09",
        "2024-05-10",
        "2024-05-13",
        "2024-05-14",
        "2024-05-15",
        "2024-05-16",
        "2024-05-17",
        "2024-05-20",
        "2024-05-21",
        "2024-05-22",
        "2024-05-23",
        "2024-05-24",
        "2024-05-28",
        "2024-05-29",
        "2024-05-30",
    ]
    dateLength = 20
    has_folder_node = false
    top_n = 1
    dateVector = [DayData() for _ in 1:10]
    weightTomorrow = 1.0f0
    select_function = "Bottom"
    branch_keys = ["1", "2", "3"]
    isBranchActive = BitVector(trues(dateLength))
    sort_function = "Cumulative Return"
    sort_window = 14
    min_data_length = dateLength
    end_date_local = Date("2024-05-30")
    flow_count = Dict{String,Int}()
    flow_stocks = Dict{String,Vector{DayData}}()
    cache = Dict{String,Vector{Float32}}()
    price_cache = Dict{String,DataFrame}()

    temp_dateVectors, MIN_DATA_LENGTH = process_branches(
        branches,
        branch_keys,
        dateLength,
        weightTomorrow,
        dates,
        end_date_local,
        flow_count,
        flow_stocks,
        cache,
        price_cache,
        Dict{String,Any}(),
        false,
        0,
    )

    branch_metrics, min_data_length = apply_sort_ta_stock_function(
        temp_dateVectors,
        dates,
        end_date_local,
        price_cache,
        dateLength,
        sort_function,
        sort_window,
        cache,
    )
    expected_branch_metrics = Vector{Float32}[
        [
            -5.702773,
            -1.6874577,
            -0.25085628,
            -0.6070319,
            1.5509437,
            3.307276,
            3.4367518,
            1.5089432,
            1.8334719,
            6.21241,
            3.7941265,
            4.6500716,
            9.442891,
            8.8268,
            8.406191,
            5.1878595,
            4.2033544,
            5.311681,
            4.7232413,
            0.7482275,
        ],
        [
            -1.9937695,
            6.1902833,
            7.27949,
            8.571428,
            9.398947,
            11.860606,
            10.52822,
            11.764177,
            11.043653,
            11.824775,
            12.285454,
            9.5846195,
            12.311932,
            13.770054,
            10.478369,
            2.0477865,
            4.6939983,
            4.303442,
            4.2737703,
            3.7824423,
        ],
        [
            -2.6863675,
            3.2418227,
            5.405251,
            7.757482,
            6.7803617,
            16.46588,
            13.028497,
            9.67691,
            14.657931,
            14.519798,
            7.550009,
            5.3807673,
            9.696535,
            14.866151,
            10.642413,
            16.905247,
            15.551335,
            25.782406,
            27.00637,
            24.515589,
        ],
    ]
    expected_min_data_length = 20
    @test branch_metrics == expected_branch_metrics
    @test min_data_length == expected_min_data_length

    branch_metrics = [
        metric[(end - (MIN_DATA_LENGTH - sort_window) + 1):end] for metric in branch_metrics
    ]
    expected_sliced_branch_metrics = Vector{Float32}[
        [8.406191, 5.1878595, 4.2033544, 5.311681, 4.7232413, 0.7482275],
        [10.478369, 2.0477865, 4.6939983, 4.303442, 4.2737703, 3.7824423],
        [10.642413, 16.905247, 15.551335, 25.782406, 27.00637, 24.515589],
    ]
    @test branch_metrics == expected_sliced_branch_metrics
end

@testset "process_sort_node with folder" begin
    temp_dateVectors = Vector{DayData}[
        [
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
        ],
        [
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
            DayData(StockInfo[StockInfo("MSFT", 1.0f0)]),
        ],
        [
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
        ],
        [
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
            DayData(StockInfo[StockInfo("NVDA", 1.0f0)]),
        ],
    ]
    dates = [
        "2024-05-16",
        "2024-05-17",
        "2024-05-20",
        "2024-05-21",
        "2024-05-22",
        "2024-05-23",
        "2024-05-24",
        "2024-05-28",
        "2024-05-29",
        "2024-05-30",
    ]
    dateLength = 10
    end_date_local = Date("2024-05-30")
    price_cache = Dict{String,DataFrame}()
    branch_return_curves, min_data_length = calculate_branch_return_curves(
        temp_dateVectors,
        dates[(end - dateLength + 1):end],
        end_date_local,
        price_cache,
        dateLength,
        "Test",
    )
    expected_branch_return_curve = Vector{Float64}[
        [
            10100.0,
            10100.143752,
            10100.258968,
            10100.504229,
            10100.216274,
            10099.485836,
            10100.147449,
            10100.217335,
            10099.517068,
            10098.853729,
        ],
        [
            10100.0,
            10099.814722,
            10101.035517,
            10101.905499,
            10102.250521,
            10101.432721,
            10102.172874,
            10102.210077,
            10101.942775,
            10098.563504,
        ],
        [
            10100.0,
            10100.015803,
            10100.632015,
            10101.317778,
            10100.563845,
            10098.457911,
            10100.116473,
            10100.121737,
            10100.279642,
            10100.805171,
        ],
        [
            10100.0,
            10098.007609,
            10100.495245,
            10101.134652,
            10100.67751,
            10109.997783,
            10112.572634,
            10119.561846,
            10120.378183,
            10116.603907,
        ],
    ]
    @test branch_return_curves == expected_branch_return_curve

    branch_metrics = apply_sort_function(branch_return_curves, "Cumulative Return", 2)
    expected_branch_metrics = Vector{Float32}[
        [
            NaN,
            NaN,
            0.0025640396039613403,
            0.0035690284104005253,
            -0.00042270203303717673,
            -0.010082595649792758,
            -0.0006814210521160582,
            0.007242933074791537,
            -0.006241304923357981,
            -0.013500758991330963,
        ],
        [
            NaN,
            NaN,
            0.010252643564358954,
            0.020701142125379806,
            0.012028509334066136,
            -0.0046800873364733,
            -0.0007686109133668945,
            0.007695502424962488,
            -0.00227771790158673,
            -0.0360967844878048,
        ],
        [
            NaN,
            NaN,
            0.006257574257418101,
            0.012890821414493102,
            -0.0006749082621504149,
            -0.028311820921322086,
            -0.004429178478209415,
            0.016476040348572505,
            0.0016155160233613135,
            0.006766591708462777,
        ],
        [
            NaN,
            NaN,
            0.004903415841584833,
            0.030966930518188447,
            0.001804515477492916,
            0.08774391496944542,
            0.11776560521038335,
            0.0946000504182287,
            0.07718658033423832,
            -0.029229911778928384,
        ],
    ]
    for i in 1:4
        for j in 1:10
            if !isnan(branch_metrics[i][j])
                @test branch_metrics[i][j] ≈ expected_branch_metrics[i][j]
            end
        end
    end
end

# @testset "handle multiple nodes in sequences array" begin
#     # this was tested on the USED-IN-TEST-a2e-semi-med.json file, it still has 2.5% error on 5000 days but 
#     # the point of this test is to check if the function can handle multiple nodes in the sequences array
#     # the remaining error is probably cumulation of the errors in if-conditions
#     @testset "handles multiple nodes/folders in sequence array execute_backtest" begin
#         # reduced error from 22.5% to 2.5% here
#         json_path_local = "./App/Tests/TestsJSON/UnitTestsJSON/USED-IN-TEST-a2e-semi-med.json"
#         price_cache_local = Dict{String,DataFrame}()
#         dateVector, dates, min_days, flow_count, flow_stocks = execute_backtest(
#             read_json_file(json_path_local), 50, Date("2024-05-30"), price_cache_local, 0
#         )
#         return_curve = calculate_final_return_curve(
#             dateVector, dates, min_days, end_date, price_cache_local, DayData()
#         )
#         expected_return_curve = Float32[
#             0.0,
#             0.00044466183,
#             0.013111694,
#             -0.012854259,
#             0.0039998223,
#             -0.02664778,
#             0.017927038,
#             0.0018864535,
#             0.0046624225,
#             -0.008701473,
#             0.023227548,
#             0.009713711,
#             -0.020478496,
#             0.009363581,
#             -0.030845044,
#             -0.032648128,
#             -0.05972492,
#             0.03483802,
#             0.00013127865,
#             -0.009046121,
#             0.019996155,
#             -0.0027453199,
#             -0.005305834,
#             -0.019644655,
#             -0.029146621,
#             0.028979098,
#             -0.0026474744,
#             -0.009702029,
#             0.0031989154,
#             0.0030353826,
#             -0.006413731,
#             0.015092281,
#             -0.0012343226,
#             0.017110096,
#             -0.011079924,
#             0.004182386,
#             -0.0059148665,
#             0.02062975,
#             0.0015405577,
#             0.0040063886,
#             0.014617339,
#             0.003490354,
#             -0.016566303,
#             0.02463286,
#             -0.0074320277,
#         ]
#         @test return_curve == expected_return_curve
#     end

#     @testset "handles multiple nodes/folders in sequence array in process_branches" begin
#         # reduced error from 73.5% to 1.6% here
#         json_path_local = "./App/Tests/TestsJSON/UnitTestsJSON/USED-IN-TEST-if-2folders.json"
#         price_cache = Dict{String,DataFrame}()
#         dateVector, dates, min_days, flow_count, flow_stocks = execute_backtest(
#             read_json_file(json_path_local), 50, Date("2024-05-30"), price_cache, 0
#         )

#         return_curve = calculate_final_return_curve(
#             dateVector, dates, min_days, end_date, price_cache, DayData()
#         )
#         expected_return_curve = Float32[
#             0.0,
#             -0.016512387,
#             -0.005849151,
#             -0.028011424,
#             0.007649876,
#             0.005660451,
#             0.017927038,
#             0.0018864535,
#             0.0046624225,
#             -0.008701473,
#             0.023227548,
#             0.009713711,
#             -0.020478496,
#             0.009363581,
#             -0.030845044,
#             -0.032648128,
#             -0.05972492,
#             0.03483802,
#             0.00013127865,
#             -0.009046121,
#             0.019996155,
#             -0.0027453199,
#             -0.005305834,
#             -0.036886025,
#             -0.029146621,
#             0.028979098,
#             0.0331857,
#             0.0052981502,
#             -0.016909555,
#             -0.007757033,
#             -0.0028626206,
#             -0.013616623,
#             0.018972902,
#             0.019550769,
#             -0.003916397,
#             0.0027589246,
#             0.0075715785,
#             -0.003990961,
#             0.036723826,
#             -0.02115931,
#             -0.028212711,
#             0.024122342,
#             -0.0069196755,
#             -0.0007946432,
#             0.010005967,
#         ]
#         @test return_curve == expected_return_curve
#     end
# end

@testset "ensure composer stays wrong" begin
    @testset "manual allocation 75% sortby rsi 63d top4, 25% buy order" begin
        json_data_local::Dict{String,Any} = read_json_file(
            "./App/Tests/TestsJSON/UnitTestsJSON/Composer-ManAl-SortByFolder.json"
        )

        price_cache_local::Dict{String,DataFrame} = Dict{String,DataFrame}()

        dateVector, dates, min_days, flow_count, flow_stocks = execute_backtest(
            json_data_local, 100, end_date, price_cache_local, 0
        )

        return_curve = calculate_final_return_curve(
            dateVector, dates, min_days, end_date, price_cache_local, DayData()
        )
        expected_return_curve = Float32[
            0.0,
            0.00031502277,
            0.012752516,
            -0.027766112,
            -0.019449566,
            0.00078937825,
            -0.014682865,
            0.0026650191,
            -0.028404694,
            0.014741501,
            0.022325847,
            -0.0060431883,
            -0.024472905,
            0.017447192,
            -0.004748647,
            -0.012310575,
            -0.0038987673,
            0.011636812,
            0.017279688,
            0.02012214,
            -0.0018605259,
            0.0057548154,
            0.0013011334,
            0.004689042,
            -0.0027926727,
            0.008725413,
            0.0176644,
            -0.0052839187,
            -0.0021063325,
            -0.003870128,
            0.0035578378,
            -0.00087616214,
            0.012878212,
            0.01812236,
            0.013686021,
            -0.005309607,
            -0.013012851,
        ]
        @test return_curve == expected_return_curve
    end

    @testset "rsi 20d sortby bottom 1" begin
        json_data_local::Dict{String,Any} = read_json_file(
            "./App/Tests/TestsJSON/UnitTestsJSON/Composer-SortBy2.json"
        )

        price_cache_local::Dict{String,DataFrame} = Dict{String,DataFrame}()

        dateVector, dates, min_days, flow_count, flow_stocks = execute_backtest(
            json_data_local, 100, end_date, price_cache_local, 0
        )

        return_curve = calculate_final_return_curve(
            dateVector, dates, min_days, end_date, price_cache_local, DayData()
        )
        expected_return_curve = Float32[
            0.0,
            -0.013625592,
            -0.005105105,
            -0.00996076,
            0.013719512,
            -0.06406015,
            0.012853471,
            0.02823604,
            0.00061709346,
            -0.00030835645,
            -0.0052436767,
            -0.015503876,
            0.017952755,
            -0.012066832,
            -0.008455997,
            -0.014529374,
            0.021794872,
            0.042659976,
            0.045427196,
            -0.005941266,
            -0.0025614754,
            -0.0008560178,
            -0.0005140507,
            0.0015429453,
            0.0047928793,
            0.002044293,
            0.00800068,
            -0.000458373,
            0.01502007,
            0.013418803,
            0.047802992,
            0.06705069,
            0.0006084205,
            0.0030748206,
            -0.01155136,
            0.01331993,
            0.0017431506,
            0.010567197,
            -0.0029342724,
            0.0014714538,
            -0.0027710844,
            0.03283701,
            0.004079724,
            0.0136933215,
            -0.03542755,
            -0.0007302305,
            -0.000994734,
            -0.012833948,
            -0.0059854793,
            0.0015913368,
            0.0018348764,
            0.0034098334,
            0.025661588,
            0.042845972,
            0.014544909,
            -0.006946497,
            0.032445304,
            0.011964826,
            -0.065669514,
            -0.029730141,
            0.04132621,
            0.08223932,
            0.059789583,
            -0.02276029,
            0.0012388503,
            -0.011135858,
            0.026776778,
            0.0058493786,
            0.047007512,
            -0.0070093456,
            0.002352941,
            0.0030181087,
            0.0019759277,
            -0.0026393852,
            0.0020073603,
            0.0046744575,
            0.024429316,
            -0.0179828,
            -0.0055993944,
            0.022948109,
        ]
        @test return_curve == expected_return_curve
    end
end
