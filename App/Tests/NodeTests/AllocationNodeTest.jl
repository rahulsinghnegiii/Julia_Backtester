include("./../../Main.jl")
include("./../../NodeProcessors/AllocationNode.jl")
include("./../BenchmarkTimes.jl")
# include("./../../BacktestUtils/Types.jl")

using Dates, DataFrames, Test, BenchmarkTools
using .VectoriseBacktestService
using ..VectoriseBacktestService.Types
using .VectoriseBacktestService.GlobalServerCache
using ..AllocationNode
initialize_server_cache()
@testset "Allocation Node Test 1 Manual Allocation" begin
    allocation_node::Dict{String,Any} = Dict{String,Any}(
        "name" => "Manual Allocation",
        "componentType" => "switch",
        "function" => "Allocation",
        "branches" => Dict{String,Any}(
            "b-(30%)" => Any[Dict{String,Any}(
                "name" => "SortBy: 1d Exponential Moving Average of Price",
                "componentType" => "switch",
                "branches" => Dict{String,Any}(
                    "Bottom-2" => Any[
                        Dict{String,Any}(
                            "name" => "BUY AAPL",
                            "componentType" => "largeTask",
                            "properties" => Dict{String,Any}(
                                "isInvalid" => false, "symbol" => "AAPL"
                            ),
                            "id" => "0980962f4f24f103cbb13745017d151f",
                            "parentHash" => "b530c7608ab7f0fbdf4d2a93490855e5",
                            "type" => "stock",
                        ),
                        Dict{String,Any}(
                            "name" => "BUY TQQQ",
                            "componentType" => "largeTask",
                            "properties" => Dict{String,Any}(
                                "isInvalid" => false, "symbol" => "TQQQ"
                            ),
                            "id" => "de6de174b8b2ba43ba590a6cc9ccb265",
                            "parentHash" => "b530c7608ab7f0fbdf4d2a93490855e5",
                            "type" => "stock",
                        ),
                        Dict{String,Any}(
                            "name" => "BUY TSLA",
                            "componentType" => "largeTask",
                            "properties" => Dict{String,Any}(
                                "isInvalid" => false, "symbol" => "TSLA"
                            ),
                            "id" => "6254d3fa0ade1b5d1ae2bef518abaef2",
                            "parentHash" => "b530c7608ab7f0fbdf4d2a93490855e5",
                            "type" => "stock",
                        ),
                        Dict{String,Any}(
                            "name" => "Interrupting icon",
                            "componentType" => "icon",
                            "properties" => Dict{String,Any}(),
                            "id" => "b8947beb6ffcdcd2392eed3fe66f8fd9",
                            "type" => "icon",
                        ),
                    ],
                ),
                "properties" => Dict{String,Any}(
                    "sortby" => Dict{String,Any}(
                        "function" => "Exponential Moving Average of Price",
                        "window" => "1",
                    ),
                    "select" => Dict{String,Any}("function" => "Bottom", "howmany" => "2"),
                ),
                "id" => "7e9df393348d56a98220dce413c9332c",
                "parentHash" => "d0e7bc5227f36c7d1c3baac9bc446081",
                "type" => "Sort",
                "nodeChildrenHash" => "33c0f19839b48aa675c349d6e7245f24",
            )],
            "a-(50%)" => Any[Dict{String,Any}(
                "name" => "folder1",
                "componentType" => "folder",
                "sequence" => Any[Dict{String,Any}(
                    "name" => "if(2d Cumulative Return   of AAPL > 175%)",
                    "componentType" => "switch",
                    "branches" => Dict{String,Any}(
                        "true" => Any[Dict{String,Any}(
                            "name" => "BUY TSLA",
                            "componentType" => "largeTask",
                            "properties" => Dict{String,Any}(
                                "isInvalid" => false,
                                "symbol" => "TSLA",
                            ),
                            "id" => "35c732b774ff43b20c987f6f00bcdd44",
                            "parentHash" => "b9ec77159db6f61ca00737cc18d28a13",
                            "type" => "stock",
                        )],
                        "false" => Any[Dict{String,Any}(
                            "name" => "BUY QQQ",
                            "componentType" => "largeTask",
                            "properties" => Dict{String,Any}(
                                "isInvalid" => false,
                                "symbol" => "QQQ",
                            ),
                            "id" => "9f15556ae998296d396bc3aea6284f7d",
                            "parentHash" => "64d6a2fb5f8d31213defb622fc6b252b",
                            "type" => "stock",
                        )],
                    ),
                    "properties" => Dict{String,Any}(
                        "comparison" => ">",
                        "x" => Dict{String,Any}(
                            "source" => "AAPL",
                            "period" => "2",
                            "indicator" => "Cumulative Return",
                        ),
                        "y" => Dict{String,Any}(
                            "source" => "",
                            "period" => "175",
                            "indicator" => "Fixed-Value",
                            "denominator" => "",
                            "numerator" => "",
                        ),
                    ),
                    "id" => "9b9026c504d1f1b82be60328546d3bd7",
                    "parentHash" => "ef58bc0f50b6c6a9232f8219fa7e7def",
                    "type" => "condition",
                    "nodeChildrenHash" => "d41d8cd98f00b204e9800998ecf8427e",
                )],
                "properties" => Dict{String,Any}(
                    "author_history" => Dict{String,Any}(),
                    "author_id" => "",
                    "folder_id" => "",
                    "isCloudFolder" => false,
                ),
                "id" => "071b9941f13b2f0e259ad0a9a156b3c1",
                "parentHash" => "6ef078c51205d98c11a33f6ac5835037",
                "type" => "folder",
                "nodeChildrenHash" => "3ea1057227c1d376d19b2f6462db11f9",
            )],
            "c-(20%)" => Any[Dict{String,Any}(
                "name" => "BUY SPY",
                "componentType" => "largeTask",
                "properties" =>
                    Dict{String,Any}("isInvalid" => false, "symbol" => "SPY"),
                "id" => "21dd046aee5f01697ebed568c4b0a5c1",
                "parentHash" => "7872af14f3d2c874366276b434d2ebc2",
                "type" => "stock",
            )],
        ),
        "properties" =>
            Dict{String,Any}("values" => Dict{String,Any}("c" => 20, "b" => 30, "a" => 50)),
        "id" => "66906abde05024dbfbd29d4fa3e7b2ad",
        "parentHash" => "b4b147bc522828731f1a016bfa72c073",
        "type" => "allocation",
        "nodeChildrenHash" => "f590dd90400e7c829d6b4c5445ca8cb7",
    )
    active_branch_mask::BitVector = BitVector(trues(251))
    total_days::Int = 251
    node_weight::Float32 = 1.0f0
    portfolio_history::Vector{DayData} = [DayData() for _ in 1:251]
    date_range::Vector{String} = [
        "2023-06-01",
        "2023-06-02",
        "2023-06-05",
        "2023-06-06",
        "2023-06-07",
        "2023-06-08",
        "2023-06-09",
        "2023-06-12",
        "2023-06-13",
        "2023-06-14",
        "2023-06-15",
        "2023-06-16",
        "2023-06-20",
        "2023-06-21",
        "2023-06-22",
        "2023-06-23",
        "2023-06-26",
        "2023-06-27",
        "2023-06-28",
        "2023-06-29",
        "2023-06-30",
        "2023-07-03",
        "2023-07-05",
        "2023-07-06",
        "2023-07-07",
        "2023-07-10",
        "2023-07-11",
        "2023-07-12",
        "2023-07-13",
        "2023-07-14",
        "2023-07-17",
        "2023-07-18",
        "2023-07-19",
        "2023-07-20",
        "2023-07-21",
        "2023-07-24",
        "2023-07-25",
        "2023-07-26",
        "2023-07-27",
        "2023-07-28",
        "2023-07-31",
        "2023-08-01",
        "2023-08-02",
        "2023-08-03",
        "2023-08-04",
        "2023-08-07",
        "2023-08-08",
        "2023-08-09",
        "2023-08-10",
        "2023-08-11",
        "2023-08-14",
        "2023-08-15",
        "2023-08-16",
        "2023-08-17",
        "2023-08-18",
        "2023-08-21",
        "2023-08-22",
        "2023-08-23",
        "2023-08-24",
        "2023-08-25",
        "2023-08-28",
        "2023-08-29",
        "2023-08-30",
        "2023-08-31",
        "2023-09-01",
        "2023-09-05",
        "2023-09-06",
        "2023-09-07",
        "2023-09-08",
        "2023-09-11",
        "2023-09-12",
        "2023-09-13",
        "2023-09-14",
        "2023-09-15",
        "2023-09-18",
        "2023-09-19",
        "2023-09-20",
        "2023-09-21",
        "2023-09-22",
        "2023-09-25",
        "2023-09-26",
        "2023-09-27",
        "2023-09-28",
        "2023-09-29",
        "2023-10-02",
        "2023-10-03",
        "2023-10-04",
        "2023-10-05",
        "2023-10-06",
        "2023-10-09",
        "2023-10-10",
        "2023-10-11",
        "2023-10-12",
        "2023-10-13",
        "2023-10-16",
        "2023-10-17",
        "2023-10-18",
        "2023-10-19",
        "2023-10-20",
        "2023-10-23",
        "2023-10-24",
        "2023-10-25",
        "2023-10-26",
        "2023-10-27",
        "2023-10-30",
        "2023-10-31",
        "2023-11-01",
        "2023-11-02",
        "2023-11-03",
        "2023-11-06",
        "2023-11-07",
        "2023-11-08",
        "2023-11-09",
        "2023-11-10",
        "2023-11-13",
        "2023-11-14",
        "2023-11-15",
        "2023-11-16",
        "2023-11-17",
        "2023-11-20",
        "2023-11-21",
        "2023-11-22",
        "2023-11-24",
        "2023-11-27",
        "2023-11-28",
        "2023-11-29",
        "2023-11-30",
        "2023-12-01",
        "2023-12-04",
        "2023-12-05",
        "2023-12-06",
        "2023-12-07",
        "2023-12-08",
        "2023-12-11",
        "2023-12-12",
        "2023-12-13",
        "2023-12-14",
        "2023-12-15",
        "2023-12-18",
        "2023-12-19",
        "2023-12-20",
        "2023-12-21",
        "2023-12-22",
        "2023-12-26",
        "2023-12-27",
        "2023-12-28",
        "2023-12-29",
        "2024-01-02",
        "2024-01-03",
        "2024-01-04",
        "2024-01-05",
        "2024-01-08",
        "2024-01-09",
        "2024-01-10",
        "2024-01-11",
        "2024-01-12",
        "2024-01-16",
        "2024-01-17",
        "2024-01-18",
        "2024-01-19",
        "2024-01-22",
        "2024-01-23",
        "2024-01-24",
        "2024-01-25",
        "2024-01-26",
        "2024-01-29",
        "2024-01-30",
        "2024-01-31",
        "2024-02-01",
        "2024-02-02",
        "2024-02-05",
        "2024-02-06",
        "2024-02-07",
        "2024-02-08",
        "2024-02-09",
        "2024-02-12",
        "2024-02-13",
        "2024-02-14",
        "2024-02-15",
        "2024-02-16",
        "2024-02-20",
        "2024-02-21",
        "2024-02-22",
        "2024-02-23",
        "2024-02-26",
        "2024-02-27",
        "2024-02-28",
        "2024-02-29",
        "2024-03-01",
        "2024-03-04",
        "2024-03-05",
        "2024-03-06",
        "2024-03-07",
        "2024-03-08",
        "2024-03-11",
        "2024-03-12",
        "2024-03-13",
        "2024-03-14",
        "2024-03-15",
        "2024-03-18",
        "2024-03-19",
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
    end_date::Date = Date("2024-05-30")
    flow_count::Dict{String,Int} = Dict{String,Int}()
    flow_stocks::Dict{String,Vector{DayData}} = Dict{String,Vector{DayData}}()
    indicator_cache::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()
    price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()

    result::Int = process_allocation_node(
        allocation_node,
        active_branch_mask,
        total_days,
        node_weight,
        portfolio_history,
        date_range,
        end_date,
        flow_count,
        flow_stocks,
        indicator_cache,
        price_cache,
        Dict{String,Any}(),
        false,
    )

    expected_portfolio_history::Vector{DayData} = DayData[
        DayData(StockInfo[StockInfo("SPY", 0.2f0), StockInfo("QQQ", 0.5f0)]),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("AAPL", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("SPY", 0.2f0),
                StockInfo("TQQQ", 0.15f0),
                StockInfo("TSLA", 0.15f0),
                StockInfo("QQQ", 0.5f0),
            ],
        ),
    ]

    @test result == 250
    for i in 1:250
        @test portfolio_history[i] == expected_portfolio_history[i]
    end

    timing_data = @benchmark process_allocation_node(
        $allocation_node,
        $active_branch_mask,
        $total_days,
        $node_weight,
        $portfolio_history,
        $date_range,
        $end_date,
        $flow_count,
        $flow_stocks,
        $indicator_cache,
        $price_cache,
        Dict{String,Any}(),
        false,
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_MANUAL_ALLOCATION)
    @test MIN_MANUAL_ALLOCATION - range <= min_time <= MIN_MANUAL_ALLOCATION + range
    println("Minimum time taken for Manual Allocation: ", min_time, " seconds")
end

@testset "Allocation Node Test 2 Inverse Volatility" begin
    allocation_node::Dict{String,Any} = Dict{String,Any}(
        "id" => "d5838c4978eb0d04fcf8cb04cc2915c5",
        "componentType" => "switch",
        "type" => "allocation",
        "name" => "Allocate by 10d Inverse Volatility",
        "function" => "Inverse Volatility",
        "properties" => Dict{String,Any}("period" => "10", "isInvalid" => false),
        "branches" => Dict{String,Any}(
            "a" => [
                Dict{String,Any}(
                    "id" => "66e40cc6eff3e937bd2f67f62bfc1894",
                    "componentType" => "largeTask",
                    "type" => "stock",
                    "name" => "BUY QQQ",
                    "properties" => Dict{String,Any}("symbol" => "QQQ"),
                    "parentHash" => "6ef078c51205d98c11a33f6ac5835037",
                ),
            ],
            "b" => [
                Dict{String,Any}(
                    "id" => "0e4b0299a96356d26474175c465c7301",
                    "componentType" => "largeTask",
                    "type" => "stock",
                    "name" => "BUY SPY",
                    "properties" =>
                        Dict{String,Any}("isInvalid" => false, "symbol" => "SPY"),
                    "parentHash" => "d0e7bc5227f36c7d1c3baac9bc446081",
                ),
            ],
            "c" => [
                Dict{String,Any}(
                    "id" => "932097f6f9289665f385de25daac4749",
                    "componentType" => "largeTask",
                    "type" => "stock",
                    "name" => "BUY AAPL",
                    "properties" =>
                        Dict{String,Any}("isInvalid" => false, "symbol" => "AAPL"),
                    "parentHash" => "7872af14f3d2c874366276b434d2ebc2",
                ),
            ],
        ),
        "parentHash" => "b4b147bc522828731f1a016bfa72c073",
        "nodeChildrenHash" => "4756f1dc200b6a5ec5166513fd3ebdb8",
    )
    active_branch_mask::BitVector = BitVector(trues(250))
    total_days::Int = 250
    node_weight::Float32 = 1.0f0
    portfolio_history::Vector{DayData} = [DayData() for _ in 1:250]
    date_range::Vector{String} = [
        "2023-06-02",
        "2023-06-05",
        "2023-06-06",
        "2023-06-07",
        "2023-06-08",
        "2023-06-09",
        "2023-06-12",
        "2023-06-13",
        "2023-06-14",
        "2023-06-15",
        "2023-06-16",
        "2023-06-20",
        "2023-06-21",
        "2023-06-22",
        "2023-06-23",
        "2023-06-26",
        "2023-06-27",
        "2023-06-28",
        "2023-06-29",
        "2023-06-30",
        "2023-07-03",
        "2023-07-05",
        "2023-07-06",
        "2023-07-07",
        "2023-07-10",
        "2023-07-11",
        "2023-07-12",
        "2023-07-13",
        "2023-07-14",
        "2023-07-17",
        "2023-07-18",
        "2023-07-19",
        "2023-07-20",
        "2023-07-21",
        "2023-07-24",
        "2023-07-25",
        "2023-07-26",
        "2023-07-27",
        "2023-07-28",
        "2023-07-31",
        "2023-08-01",
        "2023-08-02",
        "2023-08-03",
        "2023-08-04",
        "2023-08-07",
        "2023-08-08",
        "2023-08-09",
        "2023-08-10",
        "2023-08-11",
        "2023-08-14",
        "2023-08-15",
        "2023-08-16",
        "2023-08-17",
        "2023-08-18",
        "2023-08-21",
        "2023-08-22",
        "2023-08-23",
        "2023-08-24",
        "2023-08-25",
        "2023-08-28",
        "2023-08-29",
        "2023-08-30",
        "2023-08-31",
        "2023-09-01",
        "2023-09-05",
        "2023-09-06",
        "2023-09-07",
        "2023-09-08",
        "2023-09-11",
        "2023-09-12",
        "2023-09-13",
        "2023-09-14",
        "2023-09-15",
        "2023-09-18",
        "2023-09-19",
        "2023-09-20",
        "2023-09-21",
        "2023-09-22",
        "2023-09-25",
        "2023-09-26",
        "2023-09-27",
        "2023-09-28",
        "2023-09-29",
        "2023-10-02",
        "2023-10-03",
        "2023-10-04",
        "2023-10-05",
        "2023-10-06",
        "2023-10-09",
        "2023-10-10",
        "2023-10-11",
        "2023-10-12",
        "2023-10-13",
        "2023-10-16",
        "2023-10-17",
        "2023-10-18",
        "2023-10-19",
        "2023-10-20",
        "2023-10-23",
        "2023-10-24",
        "2023-10-25",
        "2023-10-26",
        "2023-10-27",
        "2023-10-30",
        "2023-10-31",
        "2023-11-01",
        "2023-11-02",
        "2023-11-03",
        "2023-11-06",
        "2023-11-07",
        "2023-11-08",
        "2023-11-09",
        "2023-11-10",
        "2023-11-13",
        "2023-11-14",
        "2023-11-15",
        "2023-11-16",
        "2023-11-17",
        "2023-11-20",
        "2023-11-21",
        "2023-11-22",
        "2023-11-24",
        "2023-11-27",
        "2023-11-28",
        "2023-11-29",
        "2023-11-30",
        "2023-12-01",
        "2023-12-04",
        "2023-12-05",
        "2023-12-06",
        "2023-12-07",
        "2023-12-08",
        "2023-12-11",
        "2023-12-12",
        "2023-12-13",
        "2023-12-14",
        "2023-12-15",
        "2023-12-18",
        "2023-12-19",
        "2023-12-20",
        "2023-12-21",
        "2023-12-22",
        "2023-12-26",
        "2023-12-27",
        "2023-12-28",
        "2023-12-29",
        "2024-01-02",
        "2024-01-03",
        "2024-01-04",
        "2024-01-05",
        "2024-01-08",
        "2024-01-09",
        "2024-01-10",
        "2024-01-11",
        "2024-01-12",
        "2024-01-16",
        "2024-01-17",
        "2024-01-18",
        "2024-01-19",
        "2024-01-22",
        "2024-01-23",
        "2024-01-24",
        "2024-01-25",
        "2024-01-26",
        "2024-01-29",
        "2024-01-30",
        "2024-01-31",
        "2024-02-01",
        "2024-02-02",
        "2024-02-05",
        "2024-02-06",
        "2024-02-07",
        "2024-02-08",
        "2024-02-09",
        "2024-02-12",
        "2024-02-13",
        "2024-02-14",
        "2024-02-15",
        "2024-02-16",
        "2024-02-20",
        "2024-02-21",
        "2024-02-22",
        "2024-02-23",
        "2024-02-26",
        "2024-02-27",
        "2024-02-28",
        "2024-02-29",
        "2024-03-01",
        "2024-03-04",
        "2024-03-05",
        "2024-03-06",
        "2024-03-07",
        "2024-03-08",
        "2024-03-11",
        "2024-03-12",
        "2024-03-13",
        "2024-03-14",
        "2024-03-15",
        "2024-03-18",
        "2024-03-19",
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
    end_date::Date = Date("2024-05-30")
    flow_count::Dict{String,Int} = Dict{String,Int}()
    flow_stocks::Dict{String,Vector{DayData}} = Dict{String,Vector{DayData}}()
    indicator_cache::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()
    price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()

    result::Int = process_allocation_node(
        allocation_node,
        active_branch_mask,
        total_days,
        node_weight,
        portfolio_history,
        date_range,
        end_date,
        flow_count,
        flow_stocks,
        indicator_cache,
        price_cache,
        Dict{String,Any}(),
        false,
    )

    expected_portfolio_history::Vector{DayData} = DayData[
        DayData(StockInfo[]),
        DayData(StockInfo[]),
        DayData(StockInfo[]),
        DayData(StockInfo[]),
        DayData(StockInfo[]),
        DayData(StockInfo[]),
        DayData(StockInfo[]),
        DayData(StockInfo[]),
        DayData(StockInfo[]),
        DayData(StockInfo[]),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.278005f0),
                StockInfo("SPY", 0.469483f0),
                StockInfo("QQQ", 0.252513f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.303492f0),
                StockInfo("SPY", 0.442379f0),
                StockInfo("QQQ", 0.254129f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.317059f0),
                StockInfo("SPY", 0.440216f0),
                StockInfo("QQQ", 0.242725f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.292836f0),
                StockInfo("SPY", 0.433846f0),
                StockInfo("QQQ", 0.273318f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.326683f0),
                StockInfo("SPY", 0.407266f0),
                StockInfo("QQQ", 0.266051f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.322654f0),
                StockInfo("SPY", 0.422431f0),
                StockInfo("QQQ", 0.254915f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.330602f0),
                StockInfo("SPY", 0.411944f0),
                StockInfo("QQQ", 0.257455f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.326064f0),
                StockInfo("SPY", 0.417961f0),
                StockInfo("QQQ", 0.255975f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.325813f0),
                StockInfo("SPY", 0.412596f0),
                StockInfo("QQQ", 0.261591f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.287151f0),
                StockInfo("SPY", 0.446135f0),
                StockInfo("QQQ", 0.266715f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.279073f0),
                StockInfo("SPY", 0.451721f0),
                StockInfo("QQQ", 0.269206f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.266213f0),
                StockInfo("SPY", 0.466776f0),
                StockInfo("QQQ", 0.267011f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.275668f0),
                StockInfo("SPY", 0.44032f0),
                StockInfo("QQQ", 0.284012f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.281545f0),
                StockInfo("SPY", 0.426679f0),
                StockInfo("QQQ", 0.291777f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.251971f0),
                StockInfo("SPY", 0.44912f0),
                StockInfo("QQQ", 0.298909f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.240999f0),
                StockInfo("SPY", 0.428867f0),
                StockInfo("QQQ", 0.330134f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.237356f0),
                StockInfo("SPY", 0.422511f0),
                StockInfo("QQQ", 0.340133f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.257731f0),
                StockInfo("SPY", 0.436093f0),
                StockInfo("QQQ", 0.306175f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.258464f0),
                StockInfo("SPY", 0.430106f0),
                StockInfo("QQQ", 0.31143f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.260864f0),
                StockInfo("SPY", 0.442242f0),
                StockInfo("QQQ", 0.296894f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.278998f0),
                StockInfo("SPY", 0.424004f0),
                StockInfo("QQQ", 0.296998f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.278595f0),
                StockInfo("SPY", 0.430093f0),
                StockInfo("QQQ", 0.291312f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.277779f0),
                StockInfo("SPY", 0.499989f0),
                StockInfo("QQQ", 0.222232f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.270049f0),
                StockInfo("SPY", 0.512985f0),
                StockInfo("QQQ", 0.216966f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.293255f0),
                StockInfo("SPY", 0.495913f0),
                StockInfo("QQQ", 0.210832f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.294236f0),
                StockInfo("SPY", 0.500025f0),
                StockInfo("QQQ", 0.205739f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.288507f0),
                StockInfo("SPY", 0.509002f0),
                StockInfo("QQQ", 0.20249f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.274844f0),
                StockInfo("SPY", 0.485726f0),
                StockInfo("QQQ", 0.23943f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.288201f0),
                StockInfo("SPY", 0.478944f0),
                StockInfo("QQQ", 0.232855f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.327668f0),
                StockInfo("SPY", 0.448126f0),
                StockInfo("QQQ", 0.224206f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.312041f0),
                StockInfo("SPY", 0.461659f0),
                StockInfo("QQQ", 0.2263f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.332993f0),
                StockInfo("SPY", 0.430545f0),
                StockInfo("QQQ", 0.236462f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.318127f0),
                StockInfo("SPY", 0.413376f0),
                StockInfo("QQQ", 0.268497f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.187752f0),
                StockInfo("SPY", 0.49049f0),
                StockInfo("QQQ", 0.321758f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.197131f0),
                StockInfo("SPY", 0.477909f0),
                StockInfo("QQQ", 0.32496f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.195991f0),
                StockInfo("SPY", 0.479088f0),
                StockInfo("QQQ", 0.324921f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.205309f0),
                StockInfo("SPY", 0.47662f0),
                StockInfo("QQQ", 0.318071f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.202322f0),
                StockInfo("SPY", 0.483885f0),
                StockInfo("QQQ", 0.313793f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.181775f0),
                StockInfo("SPY", 0.477249f0),
                StockInfo("QQQ", 0.340976f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.19033f0),
                StockInfo("SPY", 0.488542f0),
                StockInfo("QQQ", 0.321128f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.20233f0),
                StockInfo("SPY", 0.466084f0),
                StockInfo("QQQ", 0.331586f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.178213f0),
                StockInfo("SPY", 0.46764f0),
                StockInfo("QQQ", 0.354147f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.182841f0),
                StockInfo("SPY", 0.465728f0),
                StockInfo("QQQ", 0.351431f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.290879f0),
                StockInfo("SPY", 0.403764f0),
                StockInfo("QQQ", 0.305358f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.312176f0),
                StockInfo("SPY", 0.428786f0),
                StockInfo("QQQ", 0.259038f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.302839f0),
                StockInfo("SPY", 0.432402f0),
                StockInfo("QQQ", 0.26476f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.284244f0),
                StockInfo("SPY", 0.430648f0),
                StockInfo("QQQ", 0.285107f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.263294f0),
                StockInfo("SPY", 0.447221f0),
                StockInfo("QQQ", 0.289485f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.262916f0),
                StockInfo("SPY", 0.440491f0),
                StockInfo("QQQ", 0.296593f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.262367f0),
                StockInfo("SPY", 0.434744f0),
                StockInfo("QQQ", 0.30289f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.265439f0),
                StockInfo("SPY", 0.442693f0),
                StockInfo("QQQ", 0.291868f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.250006f0),
                StockInfo("SPY", 0.452474f0),
                StockInfo("QQQ", 0.297519f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.255931f0),
                StockInfo("SPY", 0.44702f0),
                StockInfo("QQQ", 0.29705f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.256767f0),
                StockInfo("SPY", 0.447239f0),
                StockInfo("QQQ", 0.295993f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.254093f0),
                StockInfo("SPY", 0.434559f0),
                StockInfo("QQQ", 0.311348f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.203466f0),
                StockInfo("SPY", 0.465642f0),
                StockInfo("QQQ", 0.330892f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.185201f0),
                StockInfo("SPY", 0.481031f0),
                StockInfo("QQQ", 0.333768f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.160001f0),
                StockInfo("SPY", 0.485128f0),
                StockInfo("QQQ", 0.354871f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.16381f0),
                StockInfo("SPY", 0.491832f0),
                StockInfo("QQQ", 0.344359f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.168233f0),
                StockInfo("SPY", 0.503755f0),
                StockInfo("QQQ", 0.328012f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.132734f0),
                StockInfo("SPY", 0.537376f0),
                StockInfo("QQQ", 0.32989f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.155935f0),
                StockInfo("SPY", 0.499905f0),
                StockInfo("QQQ", 0.34416f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.188241f0),
                StockInfo("SPY", 0.477984f0),
                StockInfo("QQQ", 0.333775f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.177925f0),
                StockInfo("SPY", 0.486836f0),
                StockInfo("QQQ", 0.335239f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.173885f0),
                StockInfo("SPY", 0.490507f0),
                StockInfo("QQQ", 0.335608f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.206151f0),
                StockInfo("SPY", 0.475223f0),
                StockInfo("QQQ", 0.318626f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.274246f0),
                StockInfo("SPY", 0.415571f0),
                StockInfo("QQQ", 0.310183f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.270629f0),
                StockInfo("SPY", 0.419577f0),
                StockInfo("QQQ", 0.309794f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.257855f0),
                StockInfo("SPY", 0.416943f0),
                StockInfo("QQQ", 0.325202f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.256796f0),
                StockInfo("SPY", 0.405871f0),
                StockInfo("QQQ", 0.337333f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.257948f0),
                StockInfo("SPY", 0.403989f0),
                StockInfo("QQQ", 0.338063f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.259472f0),
                StockInfo("SPY", 0.413675f0),
                StockInfo("QQQ", 0.326853f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.244637f0),
                StockInfo("SPY", 0.416186f0),
                StockInfo("QQQ", 0.339177f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.254314f0),
                StockInfo("SPY", 0.424571f0),
                StockInfo("QQQ", 0.321115f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.275386f0),
                StockInfo("SPY", 0.418121f0),
                StockInfo("QQQ", 0.306492f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.308105f0),
                StockInfo("SPY", 0.395044f0),
                StockInfo("QQQ", 0.296851f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.276808f0),
                StockInfo("SPY", 0.416417f0),
                StockInfo("QQQ", 0.306775f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.289165f0),
                StockInfo("SPY", 0.405405f0),
                StockInfo("QQQ", 0.30543f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.29026f0),
                StockInfo("SPY", 0.40182f0),
                StockInfo("QQQ", 0.30792f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.323944f0),
                StockInfo("SPY", 0.390534f0),
                StockInfo("QQQ", 0.285522f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.358874f0),
                StockInfo("SPY", 0.37075f0),
                StockInfo("QQQ", 0.270376f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.371661f0),
                StockInfo("SPY", 0.358781f0),
                StockInfo("QQQ", 0.269558f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.33885f0),
                StockInfo("SPY", 0.392449f0),
                StockInfo("QQQ", 0.268701f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.369584f0),
                StockInfo("SPY", 0.36653f0),
                StockInfo("QQQ", 0.263887f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.309586f0),
                StockInfo("SPY", 0.413662f0),
                StockInfo("QQQ", 0.276752f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.337542f0),
                StockInfo("SPY", 0.367472f0),
                StockInfo("QQQ", 0.294987f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.357627f0),
                StockInfo("SPY", 0.351874f0),
                StockInfo("QQQ", 0.290499f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.360379f0),
                StockInfo("SPY", 0.341554f0),
                StockInfo("QQQ", 0.298067f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.377562f0),
                StockInfo("SPY", 0.339622f0),
                StockInfo("QQQ", 0.282816f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.37979f0),
                StockInfo("SPY", 0.340757f0),
                StockInfo("QQQ", 0.279453f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.413332f0),
                StockInfo("SPY", 0.335447f0),
                StockInfo("QQQ", 0.251221f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.379178f0),
                StockInfo("SPY", 0.358338f0),
                StockInfo("QQQ", 0.262484f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.348722f0),
                StockInfo("SPY", 0.381006f0),
                StockInfo("QQQ", 0.270273f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.31969f0),
                StockInfo("SPY", 0.392675f0),
                StockInfo("QQQ", 0.287635f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.327604f0),
                StockInfo("SPY", 0.383659f0),
                StockInfo("QQQ", 0.288736f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.308812f0),
                StockInfo("SPY", 0.403667f0),
                StockInfo("QQQ", 0.28752f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.307519f0),
                StockInfo("SPY", 0.391322f0),
                StockInfo("QQQ", 0.301159f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.306811f0),
                StockInfo("SPY", 0.394356f0),
                StockInfo("QQQ", 0.298833f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.297853f0),
                StockInfo("SPY", 0.401479f0),
                StockInfo("QQQ", 0.300669f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.291407f0),
                StockInfo("SPY", 0.406434f0),
                StockInfo("QQQ", 0.302159f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.263888f0),
                StockInfo("SPY", 0.400878f0),
                StockInfo("QQQ", 0.335235f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.31214f0),
                StockInfo("SPY", 0.338848f0),
                StockInfo("QQQ", 0.349012f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.300752f0),
                StockInfo("SPY", 0.37335f0),
                StockInfo("QQQ", 0.325897f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.278593f0),
                StockInfo("SPY", 0.39567f0),
                StockInfo("QQQ", 0.325737f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.301056f0),
                StockInfo("SPY", 0.375557f0),
                StockInfo("QQQ", 0.323387f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.306947f0),
                StockInfo("SPY", 0.370632f0),
                StockInfo("QQQ", 0.322421f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.305624f0),
                StockInfo("SPY", 0.385699f0),
                StockInfo("QQQ", 0.308678f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.315156f0),
                StockInfo("SPY", 0.381926f0),
                StockInfo("QQQ", 0.302918f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.325733f0),
                StockInfo("SPY", 0.378445f0),
                StockInfo("QQQ", 0.295821f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.330323f0),
                StockInfo("SPY", 0.378788f0),
                StockInfo("QQQ", 0.290889f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.328615f0),
                StockInfo("SPY", 0.379977f0),
                StockInfo("QQQ", 0.291408f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.297214f0),
                StockInfo("SPY", 0.408946f0),
                StockInfo("QQQ", 0.29384f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.324395f0),
                StockInfo("SPY", 0.377789f0),
                StockInfo("QQQ", 0.297816f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.349591f0),
                StockInfo("SPY", 0.361039f0),
                StockInfo("QQQ", 0.28937f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.240088f0),
                StockInfo("SPY", 0.470611f0),
                StockInfo("QQQ", 0.289301f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.246552f0),
                StockInfo("SPY", 0.465178f0),
                StockInfo("QQQ", 0.28827f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.269682f0),
                StockInfo("SPY", 0.435405f0),
                StockInfo("QQQ", 0.294914f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.276258f0),
                StockInfo("SPY", 0.429796f0),
                StockInfo("QQQ", 0.293946f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.174695f0),
                StockInfo("SPY", 0.460957f0),
                StockInfo("QQQ", 0.364347f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.177767f0),
                StockInfo("SPY", 0.446608f0),
                StockInfo("QQQ", 0.375625f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.209082f0),
                StockInfo("SPY", 0.475299f0),
                StockInfo("QQQ", 0.315618f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.220727f0),
                StockInfo("SPY", 0.464977f0),
                StockInfo("QQQ", 0.314296f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.201552f0),
                StockInfo("SPY", 0.491021f0),
                StockInfo("QQQ", 0.307427f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.203484f0),
                StockInfo("SPY", 0.49389f0),
                StockInfo("QQQ", 0.302626f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.226791f0),
                StockInfo("SPY", 0.448153f0),
                StockInfo("QQQ", 0.325056f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.224591f0),
                StockInfo("SPY", 0.446314f0),
                StockInfo("QQQ", 0.329095f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.224279f0),
                StockInfo("SPY", 0.442146f0),
                StockInfo("QQQ", 0.333576f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.196942f0),
                StockInfo("SPY", 0.435858f0),
                StockInfo("QQQ", 0.367201f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.222612f0),
                StockInfo("SPY", 0.425082f0),
                StockInfo("QQQ", 0.352306f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.278919f0),
                StockInfo("SPY", 0.382524f0),
                StockInfo("QQQ", 0.338557f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.288245f0),
                StockInfo("SPY", 0.36816f0),
                StockInfo("QQQ", 0.343595f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.293773f0),
                StockInfo("SPY", 0.366433f0),
                StockInfo("QQQ", 0.339794f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.31562f0),
                StockInfo("SPY", 0.352652f0),
                StockInfo("QQQ", 0.331729f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.327287f0),
                StockInfo("SPY", 0.344306f0),
                StockInfo("QQQ", 0.328407f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.402714f0),
                StockInfo("SPY", 0.314638f0),
                StockInfo("QQQ", 0.282648f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.410676f0),
                StockInfo("SPY", 0.312369f0),
                StockInfo("QQQ", 0.276955f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.253172f0),
                StockInfo("SPY", 0.431646f0),
                StockInfo("QQQ", 0.315182f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.259688f0),
                StockInfo("SPY", 0.423811f0),
                StockInfo("QQQ", 0.3165f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.260786f0),
                StockInfo("SPY", 0.427165f0),
                StockInfo("QQQ", 0.312048f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.223397f0),
                StockInfo("SPY", 0.478435f0),
                StockInfo("QQQ", 0.298167f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.206697f0),
                StockInfo("SPY", 0.490996f0),
                StockInfo("QQQ", 0.302307f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.206598f0),
                StockInfo("SPY", 0.491292f0),
                StockInfo("QQQ", 0.30211f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.205158f0),
                StockInfo("SPY", 0.489455f0),
                StockInfo("QQQ", 0.305387f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.205497f0),
                StockInfo("SPY", 0.489962f0),
                StockInfo("QQQ", 0.304541f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.205788f0),
                StockInfo("SPY", 0.489784f0),
                StockInfo("QQQ", 0.304428f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.20339f0),
                StockInfo("SPY", 0.488154f0),
                StockInfo("QQQ", 0.308456f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.253441f0),
                StockInfo("SPY", 0.426016f0),
                StockInfo("QQQ", 0.320543f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.192212f0),
                StockInfo("SPY", 0.460308f0),
                StockInfo("QQQ", 0.34748f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.21264f0),
                StockInfo("SPY", 0.448854f0),
                StockInfo("QQQ", 0.338506f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.21532f0),
                StockInfo("SPY", 0.447693f0),
                StockInfo("QQQ", 0.336987f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.200164f0),
                StockInfo("SPY", 0.456697f0),
                StockInfo("QQQ", 0.343139f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.196489f0),
                StockInfo("SPY", 0.462158f0),
                StockInfo("QQQ", 0.341353f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.194641f0),
                StockInfo("SPY", 0.465028f0),
                StockInfo("QQQ", 0.340331f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.195347f0),
                StockInfo("SPY", 0.479598f0),
                StockInfo("QQQ", 0.325055f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.198477f0),
                StockInfo("SPY", 0.473975f0),
                StockInfo("QQQ", 0.327548f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.186634f0),
                StockInfo("SPY", 0.506252f0),
                StockInfo("QQQ", 0.307115f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.22384f0),
                StockInfo("SPY", 0.457764f0),
                StockInfo("QQQ", 0.318396f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.272465f0),
                StockInfo("SPY", 0.41435f0),
                StockInfo("QQQ", 0.313184f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.287835f0),
                StockInfo("SPY", 0.402605f0),
                StockInfo("QQQ", 0.30956f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.297434f0),
                StockInfo("SPY", 0.393175f0),
                StockInfo("QQQ", 0.309391f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.293629f0),
                StockInfo("SPY", 0.395575f0),
                StockInfo("QQQ", 0.310796f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.298605f0),
                StockInfo("SPY", 0.393228f0),
                StockInfo("QQQ", 0.308167f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.297419f0),
                StockInfo("SPY", 0.394636f0),
                StockInfo("QQQ", 0.307945f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.296888f0),
                StockInfo("SPY", 0.394322f0),
                StockInfo("QQQ", 0.30879f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.289866f0),
                StockInfo("SPY", 0.399554f0),
                StockInfo("QQQ", 0.31058f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.338125f0),
                StockInfo("SPY", 0.363352f0),
                StockInfo("QQQ", 0.298523f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.339475f0),
                StockInfo("SPY", 0.363718f0),
                StockInfo("QQQ", 0.296806f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.365197f0),
                StockInfo("SPY", 0.355932f0),
                StockInfo("QQQ", 0.278871f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.345625f0),
                StockInfo("SPY", 0.359186f0),
                StockInfo("QQQ", 0.295189f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.394274f0),
                StockInfo("SPY", 0.335153f0),
                StockInfo("QQQ", 0.270573f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.429503f0),
                StockInfo("SPY", 0.317343f0),
                StockInfo("QQQ", 0.253154f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.434318f0),
                StockInfo("SPY", 0.325748f0),
                StockInfo("QQQ", 0.239934f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.423459f0),
                StockInfo("SPY", 0.332868f0),
                StockInfo("QQQ", 0.243673f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.432158f0),
                StockInfo("SPY", 0.323029f0),
                StockInfo("QQQ", 0.244814f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.407879f0),
                StockInfo("SPY", 0.336333f0),
                StockInfo("QQQ", 0.255788f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.389328f0),
                StockInfo("SPY", 0.358469f0),
                StockInfo("QQQ", 0.252203f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.383183f0),
                StockInfo("SPY", 0.365749f0),
                StockInfo("QQQ", 0.251068f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.390122f0),
                StockInfo("SPY", 0.367892f0),
                StockInfo("QQQ", 0.241986f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.306074f0),
                StockInfo("SPY", 0.418335f0),
                StockInfo("QQQ", 0.275591f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.279899f0),
                StockInfo("SPY", 0.440691f0),
                StockInfo("QQQ", 0.27941f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.288289f0),
                StockInfo("SPY", 0.433063f0),
                StockInfo("QQQ", 0.278648f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.257414f0),
                StockInfo("SPY", 0.465766f0),
                StockInfo("QQQ", 0.276821f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.24934f0),
                StockInfo("SPY", 0.477418f0),
                StockInfo("QQQ", 0.273242f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.228944f0),
                StockInfo("SPY", 0.495961f0),
                StockInfo("QQQ", 0.275095f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.252455f0),
                StockInfo("SPY", 0.474728f0),
                StockInfo("QQQ", 0.272817f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.251061f0),
                StockInfo("SPY", 0.477648f0),
                StockInfo("QQQ", 0.271292f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.237513f0),
                StockInfo("SPY", 0.481008f0),
                StockInfo("QQQ", 0.281479f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.230468f0),
                StockInfo("SPY", 0.479164f0),
                StockInfo("QQQ", 0.290368f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.264614f0),
                StockInfo("SPY", 0.460554f0),
                StockInfo("QQQ", 0.274831f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.314477f0),
                StockInfo("SPY", 0.428955f0),
                StockInfo("QQQ", 0.256568f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.326125f0),
                StockInfo("SPY", 0.419783f0),
                StockInfo("QQQ", 0.254091f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.182126f0),
                StockInfo("SPY", 0.506544f0),
                StockInfo("QQQ", 0.31133f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.16828f0),
                StockInfo("SPY", 0.499578f0),
                StockInfo("QQQ", 0.332143f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.172313f0),
                StockInfo("SPY", 0.492052f0),
                StockInfo("QQQ", 0.335635f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.152198f0),
                StockInfo("SPY", 0.505494f0),
                StockInfo("QQQ", 0.342308f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.147433f0),
                StockInfo("SPY", 0.475911f0),
                StockInfo("QQQ", 0.376656f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.145626f0),
                StockInfo("SPY", 0.479891f0),
                StockInfo("QQQ", 0.374483f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.119724f0),
                StockInfo("SPY", 0.46106f0),
                StockInfo("QQQ", 0.419216f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.131936f0),
                StockInfo("SPY", 0.450088f0),
                StockInfo("QQQ", 0.417976f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.133702f0),
                StockInfo("SPY", 0.458773f0),
                StockInfo("QQQ", 0.407525f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.15566f0),
                StockInfo("SPY", 0.447844f0),
                StockInfo("QQQ", 0.396497f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.258581f0),
                StockInfo("SPY", 0.392038f0),
                StockInfo("QQQ", 0.349381f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.260668f0),
                StockInfo("SPY", 0.3904f0),
                StockInfo("QQQ", 0.348932f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.258319f0),
                StockInfo("SPY", 0.395305f0),
                StockInfo("QQQ", 0.346376f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.266543f0),
                StockInfo("SPY", 0.381552f0),
                StockInfo("QQQ", 0.351905f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.199453f0),
                StockInfo("SPY", 0.457539f0),
                StockInfo("QQQ", 0.343008f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.226193f0),
                StockInfo("SPY", 0.440133f0),
                StockInfo("QQQ", 0.333675f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.223015f0),
                StockInfo("SPY", 0.443924f0),
                StockInfo("QQQ", 0.333061f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.211496f0),
                StockInfo("SPY", 0.44944f0),
                StockInfo("QQQ", 0.339064f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.211251f0),
                StockInfo("SPY", 0.455974f0),
                StockInfo("QQQ", 0.332775f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.200897f0),
                StockInfo("SPY", 0.462992f0),
                StockInfo("QQQ", 0.33611f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.18335f0),
                StockInfo("SPY", 0.507436f0),
                StockInfo("QQQ", 0.309215f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.202937f0),
                StockInfo("SPY", 0.481297f0),
                StockInfo("QQQ", 0.315766f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.225885f0),
                StockInfo("SPY", 0.458112f0),
                StockInfo("QQQ", 0.316004f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.220738f0),
                StockInfo("SPY", 0.469352f0),
                StockInfo("QQQ", 0.30991f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.286822f0),
                StockInfo("SPY", 0.41866f0),
                StockInfo("QQQ", 0.294518f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.302131f0),
                StockInfo("SPY", 0.42428f0),
                StockInfo("QQQ", 0.273589f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.254332f0),
                StockInfo("SPY", 0.464239f0),
                StockInfo("QQQ", 0.281429f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.293769f0),
                StockInfo("SPY", 0.421799f0),
                StockInfo("QQQ", 0.284432f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.291686f0),
                StockInfo("SPY", 0.42118f0),
                StockInfo("QQQ", 0.287134f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.279981f0),
                StockInfo("SPY", 0.427052f0),
                StockInfo("QQQ", 0.292968f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.195083f0),
                StockInfo("SPY", 0.461796f0),
                StockInfo("QQQ", 0.343121f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.189988f0),
                StockInfo("SPY", 0.463526f0),
                StockInfo("QQQ", 0.346486f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.182469f0),
                StockInfo("SPY", 0.471592f0),
                StockInfo("QQQ", 0.345939f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.182213f0),
                StockInfo("SPY", 0.473417f0),
                StockInfo("QQQ", 0.34437f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.178313f0),
                StockInfo("SPY", 0.475515f0),
                StockInfo("QQQ", 0.346172f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.170116f0),
                StockInfo("SPY", 0.473676f0),
                StockInfo("QQQ", 0.356208f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.173274f0),
                StockInfo("SPY", 0.471102f0),
                StockInfo("QQQ", 0.355624f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.132993f0),
                StockInfo("SPY", 0.522195f0),
                StockInfo("QQQ", 0.344811f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.131813f0),
                StockInfo("SPY", 0.510631f0),
                StockInfo("QQQ", 0.357556f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.138805f0),
                StockInfo("SPY", 0.498898f0),
                StockInfo("QQQ", 0.362297f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.237738f0),
                StockInfo("SPY", 0.416127f0),
                StockInfo("QQQ", 0.346136f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.2485f0),
                StockInfo("SPY", 0.421392f0),
                StockInfo("QQQ", 0.330107f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.246266f0),
                StockInfo("SPY", 0.420905f0),
                StockInfo("QQQ", 0.332829f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.226636f0),
                StockInfo("SPY", 0.416524f0),
                StockInfo("QQQ", 0.356841f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.195881f0),
                StockInfo("SPY", 0.422508f0),
                StockInfo("QQQ", 0.381611f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.197855f0),
                StockInfo("SPY", 0.422967f0),
                StockInfo("QQQ", 0.379178f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.212812f0),
                StockInfo("SPY", 0.415097f0),
                StockInfo("QQQ", 0.372091f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.232819f0),
                StockInfo("SPY", 0.409819f0),
                StockInfo("QQQ", 0.357362f0),
            ],
        ),
        DayData(
            StockInfo[
                StockInfo("AAPL", 0.211254f0),
                StockInfo("SPY", 0.450432f0),
                StockInfo("QQQ", 0.338314f0),
            ],
        ),
    ]
    for i in 1:250
        @test portfolio_history[i] == expected_portfolio_history[i]
    end

    timing_data = @benchmark process_allocation_node(
        $allocation_node,
        $active_branch_mask,
        $total_days,
        $node_weight,
        $portfolio_history,
        $date_range,
        $end_date,
        $flow_count,
        $flow_stocks,
        $indicator_cache,
        $price_cache,
        Dict{String,Any}(),
        false,
    )

    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_INVERSE_VOLATILITY)
    @test MIN_INVERSE_VOLATILITY - range <= min_time <= MIN_INVERSE_VOLATILITY + range
    println("Minimum time taken for Inverse Volatility: ", min_time, " seconds")
end

@testset "Allocation Node Error Test" begin
    allocation_node::Dict{String,Any} = Dict{String,Any}(
        "id" => "d5838c4978eb0d04fcf8cb04cc2915c5",
        "componentType" => "switch",
        "type" => "allocation",
        "name" => "Allocate by Market Cap",
        "function" => "market Cap",
        "properties" => Dict{String,Any}(),
        "branches" => Dict{String,Any}(
            "a" => [
                Dict{String,Any}(
                    "id" => "ff979d6e6d582408edbf1604e6d69ea8",
                    "componentType" => "largeTask",
                    "type" => "stock",
                    "name" => "BUY TSLA",
                    "properties" =>
                        Dict{String,Any}("isInvalid" => false, "symbol" => "TSlA"),
                    "parentHash" => "6ef078c51205d98c11a33f6ac5835037",
                ),
            ],
            "b" => [
                Dict{String,Any}(
                    "id" => "d3d6a8935cedf139435b05fe4d0cdb30",
                    "componentType" => "largeTask",
                    "type" => "stock",
                    "name" => "BUY KLAC",
                    "properties" =>
                        Dict{String,Any}("isInvalid" => false, "symbol" => "KLAC"),
                    "parentHash" => "d0e7bc5227f36c7d1c3baac9bc446081",
                ),
            ],
            "c" => [
                Dict{String,Any}(
                    "id" => "37bd992b06d7a964002fee2e23c6a516",
                    "componentType" => "largeTask",
                    "type" => "stock",
                    "name" => "BUY AAPL",
                    "properties" =>
                        Dict{String,Any}("isInvalid" => false, "symbol" => "AAPL"),
                    "parentHash" => "7872af14f3d2c874366276b434d2ebc2",
                ),
            ],
        ),
        "parentHash" => "b4b147bc522828731f1a016bfa72c073",
        "nodeChildrenHash" => "84f6ec20b62c591cb4cc4623d1d72610",
    )

    active_branch_mask::BitVector = BitVector(trues(250))
    total_days::Int = 250
    node_weight::Float32 = 1.0f0
    portfolio_history::Vector{DayData} = [DayData() for _ in 1:250]
    date_range::Vector{String} = [
        "2023-06-02",
        "2023-06-05",
        "2023-06-06",
        "2023-06-07",
        "2023-06-08",
        "2023-06-09",
        "2023-06-12",
        "2023-06-13",
        "2023-06-14",
        "2023-06-15",
        "2023-06-16",
        "2023-06-20",
        "2023-06-21",
        "2023-06-22",
        "2023-06-23",
        "2023-06-26",
        "2023-06-27",
        "2023-06-28",
        "2023-06-29",
        "2023-06-30",
        "2023-07-03",
        "2023-07-05",
        "2023-07-06",
        "2023-07-07",
        "2023-07-10",
        "2023-07-11",
        "2023-07-12",
        "2023-07-13",
        "2023-07-14",
        "2023-07-17",
        "2023-07-18",
        "2023-07-19",
        "2023-07-20",
        "2023-07-21",
        "2023-07-24",
        "2023-07-25",
        "2023-07-26",
        "2023-07-27",
        "2023-07-28",
        "2023-07-31",
        "2023-08-01",
        "2023-08-02",
        "2023-08-03",
        "2023-08-04",
        "2023-08-07",
        "2023-08-08",
        "2023-08-09",
        "2023-08-10",
        "2023-08-11",
        "2023-08-14",
        "2023-08-15",
        "2023-08-16",
        "2023-08-17",
        "2023-08-18",
        "2023-08-21",
        "2023-08-22",
        "2023-08-23",
        "2023-08-24",
        "2023-08-25",
        "2023-08-28",
        "2023-08-29",
        "2023-08-30",
        "2023-08-31",
        "2023-09-01",
        "2023-09-05",
        "2023-09-06",
        "2023-09-07",
        "2023-09-08",
        "2023-09-11",
        "2023-09-12",
        "2023-09-13",
        "2023-09-14",
        "2023-09-15",
        "2023-09-18",
        "2023-09-19",
        "2023-09-20",
        "2023-09-21",
        "2023-09-22",
        "2023-09-25",
        "2023-09-26",
        "2023-09-27",
        "2023-09-28",
        "2023-09-29",
        "2023-10-02",
        "2023-10-03",
        "2023-10-04",
        "2023-10-05",
        "2023-10-06",
        "2023-10-09",
        "2023-10-10",
        "2023-10-11",
        "2023-10-12",
        "2023-10-13",
        "2023-10-16",
        "2023-10-17",
        "2023-10-18",
        "2023-10-19",
        "2023-10-20",
        "2023-10-23",
        "2023-10-24",
        "2023-10-25",
        "2023-10-26",
        "2023-10-27",
        "2023-10-30",
        "2023-10-31",
        "2023-11-01",
        "2023-11-02",
        "2023-11-03",
        "2023-11-06",
        "2023-11-07",
        "2023-11-08",
        "2023-11-09",
        "2023-11-10",
        "2023-11-13",
        "2023-11-14",
        "2023-11-15",
        "2023-11-16",
        "2023-11-17",
        "2023-11-20",
        "2023-11-21",
        "2023-11-22",
        "2023-11-24",
        "2023-11-27",
        "2023-11-28",
        "2023-11-29",
        "2023-11-30",
        "2023-12-01",
        "2023-12-04",
        "2023-12-05",
        "2023-12-06",
        "2023-12-07",
        "2023-12-08",
        "2023-12-11",
        "2023-12-12",
        "2023-12-13",
        "2023-12-14",
        "2023-12-15",
        "2023-12-18",
        "2023-12-19",
        "2023-12-20",
        "2023-12-21",
        "2023-12-22",
        "2023-12-26",
        "2023-12-27",
        "2023-12-28",
        "2023-12-29",
        "2024-01-02",
        "2024-01-03",
        "2024-01-04",
        "2024-01-05",
        "2024-01-08",
        "2024-01-09",
        "2024-01-10",
        "2024-01-11",
        "2024-01-12",
        "2024-01-16",
        "2024-01-17",
        "2024-01-18",
        "2024-01-19",
        "2024-01-22",
        "2024-01-23",
        "2024-01-24",
        "2024-01-25",
        "2024-01-26",
        "2024-01-29",
        "2024-01-30",
        "2024-01-31",
        "2024-02-01",
        "2024-02-02",
        "2024-02-05",
        "2024-02-06",
        "2024-02-07",
        "2024-02-08",
        "2024-02-09",
        "2024-02-12",
        "2024-02-13",
        "2024-02-14",
        "2024-02-15",
        "2024-02-16",
        "2024-02-20",
        "2024-02-21",
        "2024-02-22",
        "2024-02-23",
        "2024-02-26",
        "2024-02-27",
        "2024-02-28",
        "2024-02-29",
        "2024-03-01",
        "2024-03-04",
        "2024-03-05",
        "2024-03-06",
        "2024-03-07",
        "2024-03-08",
        "2024-03-11",
        "2024-03-12",
        "2024-03-13",
        "2024-03-14",
        "2024-03-15",
        "2024-03-18",
        "2024-03-19",
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
    end_date::Date = Date("2024-05-30")
    flow_count::Dict{String,Int} = Dict{String,Int}()
    flow_stocks::Dict{String,Vector{DayData}} = Dict{String,Vector{DayData}}()
    indicator_cache::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()
    price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()

    @test_throws r"AllocationNodeError" process_allocation_node(
        allocation_node,
        active_branch_mask,
        total_days,
        node_weight,
        portfolio_history,
        date_range,
        end_date,
        flow_count,
        flow_stocks,
        indicator_cache,
        price_cache,
        Dict{String,Any}(),
        false,
    )
end
