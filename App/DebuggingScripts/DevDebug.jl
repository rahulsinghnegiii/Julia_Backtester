include("../Main.jl")
include("../BacktestUtils/BacktestUtils.jl")
using Dates, JSON
using ..VectoriseBacktestService
using .VectoriseBacktestService.GlobalServerCache
using ..BacktestUtilites

GlobalServerCache.initialize_server_cache()

strategy_data::Dict{String,Any} = read_json_file(
    "../Tests/SmokeTests/OneDayRun/JSONs/short-min.json"
)
handle_backtesting_api(strategy_data, 20000, "short", Date("2025-01-22"))
