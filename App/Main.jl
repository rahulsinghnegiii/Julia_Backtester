module VectoriseBacktestService
include("BacktestUtils/Types.jl")
include("BacktestUtils/GlobalLRUCache.jl")
include("BacktestUtils/ErrorHandlers.jl")
include("Data&TA/StockData.jl")
include("Data&TA/TAFunctions.jl")
include("BacktestUtils/BacktestUtils.jl")
include("BacktestUtils/TimeCalculation.jl")
include("BacktestUtils/ReturnCalculations.jl")
include("BacktestUtils/FlowData.jl")
include("BacktestUtils/TASorting.jl")
include("NodeProcessors/SortNode.jl")
include("NodeProcessors/StockNode.jl")
include("BacktestUtils/GlobalCache.jl")
include("BacktestUtils/SubTreeCache.jl")
include("NodeProcessors/ConditonalNode.jl")
include("NodeProcessors/LockOnTriggerNode.jl")
include("NodeProcessors/AllocationNode.jl")
include("NodeProcessors/CloudNode.jl")

using JSON
using Dates
using DuckDB
using .Types
using Printf
using Profile
using Parquet2
using .FlowData
using .SortNode
using DataFrames
using .StockData
using .StockNode
using .CloudNode
using .LockOnTriggerNode
using .TASorting
using Base.Threads
using .GlobalCache
using .SubtreeCache
using Serialization
using .ErrorHandlers
using .AllocationNode
using .ConditionalNode
using .TimeCalculation
using .BacktestUtilites
using .GlobalServerCache
using .ReturnCalculations
using .StockData.StockDataUtils
using .MarketTechnicalsIndicators
using .StockData.DatabaseManager

export handle_backtesting,
    handle_backtesting_api, handle_flow_api, execute_backtest, post_order_dfs
# @time settings -- disable this when debugging to make life easier
HC_DEBUG_MODE = true

# Post-order DFS traversal
# REVIEW-COMMENT: rename `post_order_dfs` to `in_order_dfs`
# Internal implementation (renamed from original)
function post_order_dfs_internal(
    node::Dict{String,Any},
    active_mask::BitVector,
    common_data_span::Int,
    node_weight::Float32,
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    end_date::Date,
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
    indicator_cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    strategy_root::Dict{String,Any},
    global_cache_length::Int,
    live_execution::Bool=false,
)::Int
    try
        if !haskey(node, "type")
            throw(ValidationError("Node missing required 'type' field"))
        end
        node_type = node["type"]
        conditional_node_span::Int = common_data_span
        sort_node_span::Int = common_data_span
        allocation_node_span::Int = common_data_span
        folder_node_span::Int = common_data_span
        lot_node_span::Int = common_data_span

        if node["type"] == "stock"
            @maybe_time process_stock_node(
                node,
                active_mask,
                common_data_span,
                node_weight,
                portfolio_history,
                flow_count,
                flow_stocks,
            )
            # #println("^Time for process_stock_node")
        elseif node["type"] == "LockOnTrigger"
            @maybe_time lot_node_span = process_lock_on_trigger_node(
                node,
                active_mask,
                common_data_span,
                node_weight,
                portfolio_history,
                date_range,
                end_date,
                flow_count,
                flow_stocks,
                price_cache,
                indicator_cache,
                strategy_root,
                live_execution,
                global_cache_length,
            )
        elseif node["type"] == "CloudNode"
            throw(
                ServerError(400, "Bad request: Cloud node not supported with other nodes")
            )
        elseif node["type"] == "condition"
            conditional_node_span = @maybe_time process_condition_node(
                node,
                active_mask,
                common_data_span,
                node_weight,
                portfolio_history,
                date_range,
                end_date,
                flow_count,
                flow_stocks,
                indicator_cache,
                price_cache,
                strategy_root,
                global_cache_length,
                live_execution,
            )
            #println("^Time for process_condition_node")
        elseif node["type"] == "Sort"
            sort_node_span = @maybe_time process_sort_node(
                node,
                active_mask,
                common_data_span,
                node_weight,
                portfolio_history,
                date_range,
                end_date,
                flow_count,
                flow_stocks,
                indicator_cache,
                price_cache,
                strategy_root,
                live_execution,
                global_cache_length,
            )
            #println("^Time for process_sort_node")
        elseif node["type"] == "allocation"
            allocation_node_span = @maybe_time process_allocation_node(
                node,
                active_mask,
                common_data_span,
                node_weight,
                portfolio_history,
                date_range,
                end_date,
                flow_count,
                flow_stocks,
                indicator_cache,
                price_cache,
                strategy_root,
                live_execution,
                global_cache_length,
            )
            # println(
            #     "Processed allocation node with hash: ",
            #     node["nodeChildrenHash"],
            #     " and allocation_node span: ",
            #     allocation_node_span,
            # )
            #println("^Time for process_allocation_node")
        elseif node["type"] == "folder"
            if haskey(node, "hash")
                increment_flow_count(flow_count, node["hash"])
            end
            nodes_length = count(node -> node["type"] != "comment", node["sequence"])
            for j in 1:length(node["sequence"])
                folder_node_span = post_order_dfs(
                    node["sequence"][j],
                    active_mask,
                    common_data_span,
                    node_weight / nodes_length,
                    portfolio_history,
                    date_range,
                    end_date,
                    flow_count,
                    flow_stocks,
                    indicator_cache,
                    price_cache,
                    global_cache_length,
                    strategy_root,
                    live_execution,
                )
            end
            if haskey(node, "hash")
                set_flow_stocks(flow_stocks, portfolio_history, node["hash"])
            end
        elseif node["type"] == "comment" ||
            node["type"] == "icon" ||
            node["type"] == "interruptingIcon"
            return common_data_span
        else
            throw(ValidationError("Unknown node type", node_type))
        end
        return min(
            conditional_node_span,
            sort_node_span,
            allocation_node_span,
            folder_node_span,
            lot_node_span,
        )
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(
                ProcessingError(
                    "Failed to process node",
                    Dict(
                        "node_type" => get(node, "type", "unknown"),
                        "node_id" => get(node, "id", "unknown"),
                        "error" => e,
                    ),
                ),
            )
        end
    end
end

# Wrapper function

function create_subtree_context(
    backtest_period::Int, end_date::Date, active_mask::BitVector, live_execution::Bool
)::SubtreeContext
    trading_dates = populate_dates(backtest_period, end_date, String[], live_execution)

    adjusted_period = min(backtest_period, length(trading_dates))

    return SubtreeContext(
        adjusted_period,
        [DayData() for _ in 1:adjusted_period],
        Dict{String,Int}(),
        Dict{String,Vector{DayData}}(),
        trading_dates,
        BitVector(trues(adjusted_period)),
        adjusted_period,
    )
end

function handle_cached_data(
    cached_data::Tuple{Union{Nothing,Vector{DayData}},Date},
    node_hash::String,
    end_date::Date,
    portfolio_history::Vector{DayData},
    active_mask::BitVector,
    node_weight::Float32,
    common_data_span::Int,
)::Union{Int,Nothing}
    cached_history, cached_date = cached_data

    isnothing(cached_history) && return nothing

    if cached_date >= end_date
        @maybe_time set_portfolio_history(
            portfolio_history, cached_history, active_mask, node_weight, common_data_span
        )
        return min(common_data_span, length(cached_history))
    end

    trading_days = get_trading_days("KO", cached_date, end_date)
    if trading_days == 0
        set_portfolio_history(
            portfolio_history, cached_history, active_mask, node_weight, common_data_span
        )
        return min(common_data_span, length(cached_history))
    end

    return nothing
end

function process_subtree(
    node::Dict{String,Any},
    context::SubtreeContext,
    end_date::Date,
    indicator_cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    live_execution::Bool,
    global_cache_length::Int,
    strategy_root::Dict{String,Any}=Dict{String,Any}(),
)::Int
    subtree_span = post_order_dfs_internal(
        node,
        context.active_mask,
        context.common_data_span,
        1.0f0,
        context.profile_history,
        context.trading_dates,
        Date(context.trading_dates[end]),
        context.flow_count,
        context.flow_stocks,
        indicator_cache,
        price_cache,
        strategy_root,
        global_cache_length,
        live_execution,
    )
    return subtree_span
end

function process_outdated_cache(
    cached_history::Vector{DayData},
    cached_date::Date,
    node::Dict{String,Any},
    end_date::Date,
    common_data_span::Int,
    portfolio_history::Vector{DayData},
    active_mask::BitVector,
    node_weight::Float32,
    date_range::Vector{String},
    indicator_cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    live_execution::Bool,
    global_cache_length::Int,
    strategy_root::Dict{String,Any}=Dict{String,Any}(),
)::Int
    try
        trading_days = get_trading_days("KO", cached_date, end_date, live_execution)
        # println(
        #     "Processing node with outdated cache with trading days: ",
        #     trading_days,
        #     " and common_data_span: ",
        #     common_data_span,
        # )
        common_data_span_subtree = min(trading_days, common_data_span)

        context = SubtreeContext(
            common_data_span_subtree,
            [DayData() for _ in 1:common_data_span_subtree],
            Dict{String,Int}(),
            Dict{String,Vector{DayData}}(),
            populate_dates(common_data_span_subtree, end_date, String[], live_execution),
            BitVector(trues(common_data_span_subtree)),
            common_data_span_subtree,
        )
        subtree_span = process_subtree(
            node,
            context,
            end_date,
            indicator_cache,
            price_cache,
            live_execution,
            global_cache_length,
            strategy_root,
        )

        common_span = min(common_data_span, subtree_span)

        # Handle append logic
        if !live_execution
            @maybe_time if !append_subtree_portfolio_mmap(
                date_range,
                end_date,
                node["nodeChildrenHash"],
                common_span,
                context.profile_history,
                live_execution,
            )
                throw(
                    ServerError(
                        400,
                        "Internal server error: Failed to write subtree portfolio for hash $(node["nodeChildrenHash"])",
                    ),
                )
            end
        end

        # FIXME: VkyOaqv4R4vhMApHKOA4 -- What More Do You Need folder issue is because of this
        if length(portfolio_history) > length(context.profile_history)
            empty_slot_indices = length(portfolio_history) - length(context.profile_history)
            uptil::Int = min(empty_slot_indices, length(cached_history))
            for i in 1:uptil
                for stock in cached_history[end - i + 1].stockList
                    stockInfo = StockInfo(stock.ticker, stock.weightTomorrow * node_weight)
                    push!(
                        portfolio_history[(end - length(context.profile_history)) - i + 1].stockList,
                        stockInfo,
                    )
                end
            end
            # common_data_span = min(common_data_span, uptil)
        end

        set_portfolio_history(
            portfolio_history,
            context.profile_history,
            active_mask,
            node_weight,
            common_data_span,
        )
        return common_span
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(
                ProcessingError(
                    "Failed to process node with outdated cache",
                    Dict(
                        "node_type" => get(node, "type", "unknown"),
                        "node_id" => get(node, "id", "unknown"),
                        "error" => e,
                    ),
                ),
            )
        end
    end
end

function post_order_dfs(
    node::Dict{String,Any},
    active_mask::BitVector,
    common_data_span::Int,
    node_weight::Float32,
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    end_date::Date,
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
    indicator_cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    global_cache_length::Int,
    strategy_root::Dict{String,Any}=Dict{String,Any}(),
    live_execution::Bool=false,
)::Int
    try
        # println(
        #     "Processing node with hash: ",
        #     " and node type: ",
        #     node["type"],
        #     " and common data span: ",
        #     common_data_span,
        # )
        # Only process caching for folder nodes
        if haskey(node, "nodeChildrenHash")
            node_hash = node["nodeChildrenHash"]
            println("Processing folder node with nodeChildrenHash: ", node_hash)

            # Try to use cached data
            cached_data = @maybe_time read_subtree_portfolio_mmem(node_hash, end_date)
            cached_history, cached_date = cached_data

            if !isnothing(cached_history)
                if cached_date >= end_date
                    @maybe_time set_portfolio_history(
                        portfolio_history,
                        cached_history,
                        active_mask,
                        node_weight,
                        common_data_span,
                    )
                    return min(common_data_span, length(cached_history))
                else
                    return process_outdated_cache(
                        cached_history,
                        cached_date,
                        node,
                        end_date,
                        common_data_span,
                        portfolio_history,
                        active_mask,
                        node_weight,
                        date_range,
                        indicator_cache,
                        price_cache,
                        live_execution,
                        global_cache_length,
                        strategy_root,
                    )
                end
            end

            # Process new data for folder node
            context = create_subtree_context(30000, end_date, active_mask, live_execution)
            # println(
            #     "Processing folder node with nodeChildrenHash: ",
            #     node_hash,
            #     " and context portfolio_history length: ",
            #     length(context.profile_history),
            #     " and common_data_span: ",
            #     context.common_data_span,
            #     " and end_date: ",
            #     end_date,
            # )
            subtree_span = process_subtree(
                node,
                context,
                end_date,
                indicator_cache,
                price_cache,
                live_execution,
                global_cache_length,
                strategy_root,
            )

            common_span = min(common_data_span, subtree_span)

            try
                success = @maybe_time write_subtree_portfolio_mmap(
                    date_range,
                    end_date,
                    node_hash,
                    common_span,
                    context.profile_history,
                    live_execution,
                )

                !success &&
                    @warn "Failed to write subtree portfolio for folder hash $node_hash"
            catch e
                @error "Error in background write_subtree_portfolio task" exception = (
                    e, catch_backtrace()
                )
            end
            # println(
            #     "Processed folder subtree with span: ",
            #     subtree_span,
            #     " for node: ",
            #     node_hash,
            # )
            set_portfolio_history(
                portfolio_history,
                context.profile_history,
                active_mask,
                node_weight,
                common_data_span,
            )

            return common_span
        else
            # For non-folder nodes, just process them directly
            return post_order_dfs_internal(
                node,
                active_mask,
                common_data_span,
                node_weight,
                portfolio_history,
                date_range,
                end_date,
                flow_count,
                flow_stocks,
                indicator_cache,
                price_cache,
                strategy_root,
                global_cache_length,
                live_execution,
            )
        end
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(
                ProcessingError(
                    "Failed to process node",
                    Dict(
                        "node_type" => get(node, "type", "unknown"),
                        "node_id" => get(node, "id", "unknown"),
                        "error" => e,
                    ),
                ),
            )
        end
    end
end

function execute_backtest(
    strategy_data::Dict{String,Any},
    backtest_period::Int,
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    global_cache_length::Int,
    indicator_cache::Dict{String,Vector{Float32}}=Dict{String,Vector{Float32}}(),
    live_execution::Bool=false,
)::Tuple{Vector{DayData},Vector{String},Int,Dict{String,Int},Dict{String,Vector{DayData}}}
    try
        #println("Executing backtest with live execution: ", live_execution)
        if !haskey(strategy_data, "sequence")
            throw(ValidationError("Strategy data missing 'sequence' field"))
        end
        if live_execution
            backtest_period = backtest_period + 1
        end
        profile_history::Vector{DayData} = [DayData() for _ in 1:backtest_period]

        # TODO: Consider combining flow data into a single struct
        flow_count::Dict{String,Int} = Dict{String,Int}()
        flow_stocks::Dict{String,Vector{DayData}} = Dict{String,Vector{DayData}}()
        trading_dates::Vector{String} = []

        trading_dates = populate_dates(
            backtest_period, end_date, trading_dates, live_execution
        )
        # println("Backtest period: ", backtest_period)
        if live_execution
            end_date = Date(trading_dates[end])
        end
        active_mask::BitVector = BitVector(trues(backtest_period))
        common_data_span::Int = backtest_period
        if length(strategy_data["sequence"]) == 1 &&
            strategy_data["sequence"][1]["type"] == "CloudNode"
            cloud_node_span = @maybe_time process_cloud_node(
                strategy_data["sequence"][1],
                active_mask,
                common_data_span,
                1.0f0,
                profile_history,
                trading_dates,
                end_date,
                price_cache,
                live_execution,
            )
            common_data_span = min(common_data_span, cloud_node_span)
        else
            println("Running post_order_dfs in execute_backtest")
            nodes_length = count(
                node -> node["type"] != "comment", strategy_data["sequence"]
            )
            # println("Running post_order_dfs in execute_backtest")

            for i in 1:length(strategy_data["sequence"])
                branch_common_data_span = @maybe_time post_order_dfs(
                    strategy_data["sequence"][i],
                    active_mask,
                    backtest_period,
                    1.0f0 / nodes_length,
                    profile_history,
                    trading_dates,
                    Date(trading_dates[end]),
                    flow_count,
                    flow_stocks,
                    indicator_cache,
                    price_cache,
                    global_cache_length,
                    strategy_data,
                    live_execution,
                )
                common_data_span = min(common_data_span, branch_common_data_span)
            end
            # println("^Time for post_order_dfs")
        end
        profile_history = profile_history[(end - common_data_span + 1):end]
        trading_dates = trading_dates[(end - common_data_span + 1):end]
        return (profile_history, trading_dates, common_data_span, flow_count, flow_stocks)
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(
                BacktestExecutionError(
                    "Failed to execute backtest",
                    Dict(
                        "strategy_length" => length(get(strategy_data, "sequence", [])),
                        "backtest_period" => backtest_period,
                        "end_date" => string(end_date),
                        "error" => e,
                    ),
                ),
            )
        end
    end
end

function process_backtest_data(
    strategy_data::Dict{String,Any},
    adjusted_period::Int,
    end_date::Date,
    global_cache_present::Bool,
    global_cache_length::Int,
    yesterday_profile_history::DayData,
    live_execution::Bool=false,
)::Union{
    Dict{String,Float32},
    Tuple{Vector{Float32},Vector{String},Dict{String,Dict{String,Any}},Vector{DayData},Int},
}
    try
        cache_tickers = strategy_data["tickers"]
        indicator_cache::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()
        price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()

        if !global_cache_present
            # if global cache isn't present, then read metadata and update the period, end_date
            adjusted_period, end_date = read_metadata(cache_tickers)
        end
        # println("Adjusted period $adjusted_period")
        # set end date to 2024-10-31 
        # end_date = Date(2024, 10, 31)
        profile_history::Vector{DayData}, trading_dates::Vector{String}, min_days::Int, flow_count::Dict{String,Int}, flow_stocks::Dict{String,Vector{DayData}} = execute_backtest(
            strategy_data,
            adjusted_period,
            end_date,
            price_cache,
            global_cache_length,
            indicator_cache,
            live_execution,
        )
        if live_execution
            live_stocks = Dict{String,Float32}()
            for stocks in profile_history[end].stockList
                if haskey(live_stocks, stocks.ticker)
                    stocks.ticker = map_ticker(stocks.ticker)
                    live_stocks[stocks.ticker] += stocks.weightTomorrow
                else
                    live_stocks[stocks.ticker] = stocks.weightTomorrow
                end
            end
            return live_stocks
        end

        # println("Calculating final return curve")
        delta_curve = @maybe_time calculate_final_return_curve(
            profile_history,
            trading_dates,
            min_days,
            end_date,
            price_cache,
            yesterday_profile_history,
            global_cache_present,
            live_execution,
        )
        # println(delta_curve)

        flow_data = Dict{String,Dict{String,Any}}()
        # if global cache is present adjusted period is uncalculated trading days otherwise it is read from metadata
        result = (delta_curve, trading_dates, flow_data, profile_history, adjusted_period)
        #println("Return type from process_backtest_data: ", typeof(result))
        return result

    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(
                ProcessingError(
                    "Failed to process backtest data",
                    Dict(
                        "tickers_count" => length(get(strategy_data, "tickers", [])),
                        "indicators_count" => length(get(strategy_data, "indicators", [])),
                        "error" => e,
                    ),
                ),
            )
        end
    end
end

"""
    handle_backtesting_api(
        strategy_data::Dict{String,Any},
        backtest_period::Int,
        strategy_hash::String,
        end_date::Date,
        live_execution::Bool=false
    )::Union{Nothing,Dict{String,Any}}

Process a backtesting API request with caching support.

# Arguments
- `strategy_data`: Dictionary containing strategy parameters
- `backtest_period`: Number of periods to backtest
- `strategy_hash`: Unique identifier for the strategy
- `end_date`: End date for the backtest
- `live_execution`: Flag indicating if this is a live execution

# Returns
- `Nothing` or `Dict{String,Any}`: Processed backtest results or nothing if processing fails
"""
function handle_backtesting_api(
    strategy_data::Dict{String,Any},
    backtest_period::Int,
    strategy_hash::String,
    end_date::Date,
    live_execution::Bool=false,
)::Union{Nothing,Dict{String,Any}}
    try
        # println(
        #     "Runing backtest for strategy hash: ",
        #     strategy_hash,
        #     " and end date: ",
        #     end_date,
        #     " and live execution: ",
        #     live_execution,
        #     " and backtest period: ",
        #     backtest_period,
        # )
        return _process_backtest_request(
            strategy_data, backtest_period, strategy_hash, end_date, live_execution
        )
    catch e
        _handle_backtest_error(e, strategy_hash, backtest_period, end_date)
    end
end

function _process_backtest_request(
    strategy_data::Dict{String,Any},
    backtest_period::Int,
    strategy_hash::String,
    end_date::Date,
    live_execution::Bool,
)::Union{Nothing,Dict{String,Any}}
    DatabaseManager.init_connection()

    # Handle cache
    cached_data = _handle_cache_lookup(strategy_hash, end_date, live_execution)
    if _should_use_cache(cached_data)
        cached_data.response["ticker_dates"] = get_earliest_dates_of_tickers(
            strategy_data["tickers"]
        )
        return cached_data.response
    end
    # Adjust backtest period based on cache
    adjusted_period = _calculate_backtest_period(
        backtest_period, cached_data.uncalculated_days, live_execution
    )
    # println("Cache present: ", cached_data.cache_present)
    # println("Adjusted period: ", adjusted_period)
    # Process backtest
    result = _execute_backtest(
        strategy_data,
        adjusted_period,
        end_date,
        cached_data.cache_present,
        if cached_data.cache_present
            cached_data.response["days"][1]
        else
            0
        end,
        if cached_data.cache_present
            DayData([
                StockInfo(x["ticker"], x["weightTomorrow"]) for
                x in cached_data.response["profile_history"][end]["stockList"]
            ])
        else
            DayData()
        end,
        live_execution,
    )
    DatabaseManager.cleanup_connections()
    # Handle live execution separately
    if live_execution
        return result
    end

    # Package and cache results
    response = _prepare_response(result, cached_data)

    # result[5] = adjusted_period
    if cached_data.cache_present
        response["days"] = [result[5] + cached_data.response["days"][1]]
    else
        response["days"] = [result[5]]
    end

    #println("Response type from _prepare_response: ", typeof(response))
    cache_data(strategy_hash, response, end_date, result[3])

    # Add the ticker => earliest date records
    response["ticker_dates"] = get_earliest_dates_of_tickers(strategy_data["tickers"])

    return response
end

function _handle_cache_lookup(
    strategy_hash::String, end_date::Date, live_execution::Bool
)::CacheData
    cached_response, uncalculated_days, use_cached = get_cached_data(
        strategy_hash, end_date, live_execution
    )
    cache_present = !isnothing(cached_response) && uncalculated_days == 0

    return CacheData(cached_response, uncalculated_days, cache_present)
end

function _should_use_cache(cache_data::CacheData)::Bool
    return !isnothing(cache_data.response) &&
           cache_data.uncalculated_days == 0 &&
           cache_data.cache_present
end

function _calculate_backtest_period(
    original_period::Int, uncalculated_days::Int, live_execution::Bool
)::Int
    period = uncalculated_days > 0 ? uncalculated_days : original_period
    return live_execution ? period + 1 : period
end

function _execute_backtest(
    strategy_data::Dict{String,Any},
    adjusted_period::Int,
    end_date::Date,
    global_cache_present::Bool,
    global_cache_length::Int,
    yesterday_profile_history::DayData,
    live_execution::Bool,
)
    result = try
        process_backtest_data(
            strategy_data,
            adjusted_period,
            end_date,
            global_cache_present,
            global_cache_length,
            yesterday_profile_history,
            live_execution,
        )
    catch e
        rethrow(e)
    end
    #println("Result type from _execute_backtest: ", typeof(result))
    return result
end

function _prepare_response(result, cache_data::CacheData)::Dict{String,Vector}
    if result isa Tuple && length(result) == 5
        delta_curve, trading_dates, flow_data, profile_history, adjusted_period = result
    else
        throw(
            ProcessingError(
                "Unexpected result type or structure",
                Dict("type" => typeof(result), "length" => length(result)),
            ),
        )
    end

    local response
    if !isnothing(cache_data.response)
        response = update_cached_response(
            cache_data.response,
            delta_curve,
            trading_dates,
            cache_data.uncalculated_days,
            profile_history,
        )
    else
        response = package_response(delta_curve, trading_dates, profile_history)
    end

    return response
end

function _handle_backtest_error(
    error::Exception, strategy_hash::String, backtest_period::Int, end_date::Date
)
    if error isa BacktestError
        rethrow(error)
    else
        throw(
            ProcessingError(
                "Failed to handle backtest API request",
                Dict(
                    "strategy_hash" => strategy_hash,
                    "backtest_period" => backtest_period,
                    "end_date" => string(end_date),
                    "error" => error,
                ),
            ),
        )
    end
end

function handle_flow_api(strategy_hash::String, end_date::Date)::Dict{String,Any}
    flow_data = get_cached_flow_data(strategy_hash, end_date)
    if isnothing(flow_data)
        throw(
            ServerError(
                400, "Bad request: Flow data does not exist. Please run a backtest first."
            ),
        )
    end

    return flow_data
end

function handle_backtesting(
    strategy_path::String, backtest_period::Int, end_date::Date, live_execution::Bool=false
)::Vector{Float32}
    initialize_server_cache()
    #println("live execution: ", live_execution)
    strategy_data::Dict{String,Any} = read_json_file(strategy_path)

    price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()
    indicator_cache::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()
    profile_history, trading_dates, min_days, flow_count, flow_stocks = execute_backtest(
        strategy_data,
        backtest_period,
        end_date,
        price_cache,
        0,
        indicator_cache,
        live_execution,
    )
    if live_execution
        # print last day of trading with portfolio value
        #println("Last day of trading: ", trading_dates[end])
        #println("Portfolio value: ", profile_history[end])
    end
    return_curve::Vector{Float32} = @maybe_time calculate_final_return_curve(
        profile_history,
        trading_dates,
        min_days,
        end_date,
        price_cache,
        DayData(),
        live_execution,
    )
    #println("^Time for final_return_curve")
    #println("return curve $return_curve")
    close_connection()
    return return_curve
end

end
