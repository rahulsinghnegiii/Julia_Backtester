module AllocationNode

using Dates, DataFrames
using ..VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.SortNode
using ..VectoriseBacktestService.FlowData
using ..VectoriseBacktestService.StockNode
using ..VectoriseBacktestService.BacktestUtilites
using ..VectoriseBacktestService.StockData
using ..VectoriseBacktestService.GlobalCache
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.ConditionalNode
using ..VectoriseBacktestService.TimeCalculation
using ..VectoriseBacktestService.BacktestUtilites
using ..VectoriseBacktestService.ReturnCalculations
using ..VectoriseBacktestService.MarketTechnicalsIndicators

export process_allocation_node

# Process allocation node
# NOTE: we should not multi-thread children of this node, as other children will be writing to the same 'day'
#       of the dateVector, which will cause race conditions.
# TODO: each dateVector child should be a new copy, hence allowing multi-threading of children.
function process_allocation_node(
    allocation_node::Dict{String,Any},
    active_branch_mask::BitVector,
    total_days::Int,
    node_weight::Float32,
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    end_date::Date,
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
    indicator_cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    strategy_root::Dict{String,Any},
    live_execution::Bool=false,
    global_cache_length::Int=0,
)::Int
    try
        if !haskey(allocation_node, "function")
            throw(
                ValidationError(
                    "Missing function field in allocation node",
                    Dict("node" => allocation_node),
                ),
            )
        end
        min_days_inv_vol::Int = total_days
        min_days_market_cap::Int = total_days
        min_days_manual::Int = total_days

        if haskey(allocation_node, "hash")
            increment_flow_count(flow_count, allocation_node["hash"])
        end

        if allocation_node["function"] == "Inverse Volatility"
            min_days_inv_vol = process_inverse_volatility(
                allocation_node,
                active_branch_mask,
                total_days,
                portfolio_history,
                date_range,
                end_date,
                flow_count,
                flow_stocks,
                indicator_cache,
                price_cache,
                node_weight,
                strategy_root,
                global_cache_length,
                live_execution,
            )
        elseif allocation_node["function"] == "Market Cap"
            min_days_market_cap = process_market_cap(
                allocation_node,
                active_branch_mask,
                total_days,
                portfolio_history,
                date_range,
                node_weight,
                end_date,
                flow_count,
                flow_stocks,
                indicator_cache,
                price_cache,
                strategy_root,
                live_execution,
            )
        elseif allocation_node["function"] == "Allocation" ||
            allocation_node["function"] == "Equal Allocation"
            min_days_manual = process_allocation(
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
                strategy_root,
                global_cache_length,
                live_execution,
            )
        else
            throw(
                ValidationError(
                    "Invalid allocation function", Dict("function" => function_type)
                ),
            )
        end

        if haskey(allocation_node, "hash")
            set_flow_stocks(flow_stocks, portfolio_history, allocation_node["hash"])
        end
        return min(min_days_inv_vol, min_days_market_cap, min_days_manual)

    catch e
        handle_allocation_error(e, allocation_node)
    end
end

function process_inverse_volatility(
    node::Dict{String,Any},
    active_branch_mask::BitVector,
    total_days::Int,
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    end_date::Date,
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
    indicator_cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    node_weight::Float32,
    strategy_root::Dict{String,Any},
    global_cache_length::Int,
    live_execution::Bool,
)::Int
    try
        if !haskey(node, "properties") || !haskey(node["properties"], "period")
            throw(
                ValidationError(
                    "Missing required properties for inverse volatility calculation",
                    Dict("node" => node),
                ),
            )
        end
        inverse_volatility_period::Int = parse(Int, node["properties"]["period"])
        flag::Bool = false
        global_case::Bool = false
        original_total_days::Int = total_days
        """
            For N-day backtests, there exist two cases:
            1. The total number of days in the entire backtest is less than the inverse volatility period.
                In this case we simply pad the total days by adding the inverse volatility period to the total number of days. 
                This is done to ensure that the inverse volatility calculation has enough data to work with.
                For e.g, 
                    - total_days = 1, inverse_volatility_period = 5
                    - total_days += inverse_volatility_period = 6
                This allows backtest to extract the last 1 day of allocations etc...
            2. The total number of days is strictly speaking greater than the inverse volatility period.
                In this case, we need to check if the expected number of values to extract is less than the total number of days.
                If it is, we pad the total days by adding the inverse volatility period + 1 to the total number of days.
                This is done to ensure that the inverse volatility calculation has enough data to work with.
                For e.g, 
                    - total_days = 6, inverse_volatility_period = 5
                    - expected_extracted_values = 6 - 5 = 1
                    - num_values_to_extract = 6
                    - expected_extracted_values <= num_values_to_extract
                    - total_days += inverse_volatility_period + 1 = 11
                This allows backtest to extract the last 5 days of allocations etc...
        """
        if total_days <= inverse_volatility_period
            total_days += inverse_volatility_period
            date_range = populate_dates(total_days, end_date, String[], live_execution)
            new_active_branch_mask = BitVector(trues(total_days))
            for day in eachindex(active_branch_mask)
                new_active_branch_mask[(end - day + 1)] = active_branch_mask[(end - day + 1)]
            end
            active_branch_mask = new_active_branch_mask
            flag = true
        elseif global_cache_length > 0
            expected_extracted_values = original_total_days - inverse_volatility_period
            num_values_to_extract::Int = original_total_days
            if expected_extracted_values <= num_values_to_extract
                total_days += inverse_volatility_period + 1
                date_range = populate_dates(
                    total_days + 1, end_date, String[], live_execution
                )
                new_active_branch_mask = BitVector(trues(total_days))
                for day in eachindex(active_branch_mask)
                    new_active_branch_mask[(end - day + 1)] = active_branch_mask[(end - day + 1)]
                end
                active_branch_mask = new_active_branch_mask
                flag = true
                global_case = true
            end
        end
        min_days_inv_vol::Int = total_days
        temp_active_branch_mask = BitVector(trues(total_days))
        branch_index::Int = 1
        temp_portfolio_vectors::Vector{Vector{DayData}} = [
            [DayData() for _ in 1:total_days] for _ in 1:length(node["branches"])
        ]
        branches_min_length::Int = total_days
        for (branch_name::String, branch_node::Vector{Dict{String,Any}}) in node["branches"]
            branches_min_length = post_order_dfs(
                branch_node[1],
                temp_active_branch_mask,
                total_days,
                Float32(1.0),
                temp_portfolio_vectors[branch_index][(end - total_days + 1):end],
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
            min_days_inv_vol = min(min_days_inv_vol, branches_min_length)
            branch_index += 1
        end
        """
            When calculating branch_return_curves, each portfolio value at index i depends on a variable that is modified in each previous iteration. 
            Therefore, the entire previous portfolio values are required to calculate the correct portfolio values.
            So, we cache the entire portfolio values for each branch.
        """

        cached_portfolio_values::Dict{String,Vector{Float64}}, use = read_portfolio_values(
            node["nodeChildrenHash"]
        )
        cached_mapping::Dict{String,Float64} = Dict{String,Float64}()
        if use && (flag)
            for (key, value) in cached_portfolio_values
                cached_mapping[key] = value[end - (total_days - 1)]
            end
        end

        """
            To align the percentages of the entire backtest with an N-day backtest (where N < total number of days in the entire backtest),
            we converted branch return curves to Float64 and subsequently calculated inverse volatility weights.
            As a result, we needed to adjust the parameters of all other functions that were using Float32.
        """
        branch_return_curves::Vector{Vector{Float64}}, min_days = calculate_branch_return_curves(
            temp_portfolio_vectors,
            date_range[(end - total_days + 1):end],
            end_date,
            price_cache,
            total_days,
            "Allocation",
            cached_mapping,
            live_execution,
        )
        fresh_portfolio_values = Dict{String,Vector{Float64}}()
        for (i, ret) in enumerate(branch_return_curves)
            append_val = ret .- 100.0
            if haskey(cached_portfolio_values, string(i))
                # if we have cached values, append the new values to the cached values
                fresh_portfolio_values[string(i)] = append!(
                    cached_portfolio_values[string(i)],
                    append_val[max(1, (end - original_total_days + 1)):end],
                )
            else
                # if we don't have cached values, create a new array
                fresh_portfolio_values[string(i)] = append_val[max(
                    1, (end - original_total_days + 1)
                ):end]
            end
        end
        cache_portfolio_values(
            fresh_portfolio_values, node["nodeChildrenHash"], Date(end_date)
        )
        percentages::Dict{Date,Dict{String,Float64}} = Dict{Date,Dict{String,Float64}}()
        try
            percentages = calculate_inverse_volatility_for_data_f32(
                branch_return_curves,
                Date.(date_range[((end - min_days) + 1):end]),
                parse(Int, node["properties"]["period"]),
            )
        catch e
            if isa(e, ServerError)
                rethrow(e)
            else
                throw(
                    WeightCalculationError(
                        "Failed to calculate inverse volatility weights",
                        "Inverse Volatility",
                        Dict("error" => e),
                    ),
                )
            end
        end
        min_days = min_days - parse(Int, node["properties"]["period"])
        min_days = min(min_days, branches_min_length)
        min_days_inv_vol = min(min_days, min_days_inv_vol)
        temp_portfolio_vectors = [
            [day for day in days[(end - min_days_inv_vol + 1):end]] for
            days in temp_portfolio_vectors
        ]
        if flag == true
            min_days_inv_vol = original_total_days
        end
        for day in 1:min_days_inv_vol
            for (branch_index, branch_name) in enumerate(keys(node["branches"]))
                for stock in temp_portfolio_vectors[branch_index][day].stockList
                    date_key = Date(date_range[end - (min_days_inv_vol) + day])
                    if haskey(percentages, date_key) &&
                        haskey(percentages[date_key], "$branch_index")
                        stock.weightTomorrow *= (percentages[date_key]["$branch_index"])
                        stock.weightTomorrow *= node_weight
                        stock.weightTomorrow = round(stock.weightTomorrow; digits=6)
                    else
                        stock.weightTomorrow *= 0.0
                    end

                    if (active_branch_mask[end - (min_days_inv_vol) + day])
                        push!(
                            portfolio_history[end - (min_days_inv_vol) + day].stockList,
                            stock,
                        )
                    end
                end
            end
        end

        return min_days_inv_vol
    catch e
        if isa(e, BacktestError)
            rethrow(e)
        else
            throw(
                AllocationNodeError(
                    "Failed to process inverse volatility allocation",
                    "Inverse Volatility",
                    Dict("error" => e, "node_id" => get(node, "id", "unknown")),
                ),
            )
        end
    end
end
function process_market_cap(
    node::Dict{String,Any},
    active_branch_mask::BitVector,
    total_days::Int,
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    node_weight::Float32,
    end_date::Date,
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
    indicator_cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    strategy_root::Dict{String,Any},
    live_execution::Bool=false,
)::Int
    try
        min_days_market_cap::Int = total_days
        branch_date_vectors = Dict{Any,Vector{DayData}}()
        branch_returns = Dict{Any,Vector{Float32}}()

        for (branch_name::String, branch_node::Vector{Dict{String,Any}}) in node["branches"]
            if branch_node[1]["type"] == "stock"
                new_branch_vector::Vector{DayData} = [DayData() for _ in 1:total_days]
                post_order_dfs(
                    branch_node[1],
                    active_branch_mask,
                    total_days,
                    Float32(100.0),
                    new_branch_vector[(end - total_days + 1):end],
                    date_range,
                    end_date,
                    flow_count,
                    flow_stocks,
                    indicator_cache,
                    price_cache,
                    strategy_root,
                    live_execution,
                )

                market_cap_df = try
                    get_market_cap(branch_node[1]["properties"]["symbol"], end_date, total_days)
                catch e
                    throw(
                        DataError(
                            "Failed to get market cap data",
                            Dict(
                                "symbol" => branch_node[1]["properties"]["symbol"],
                                "error" => e,
                            ),
                        ),
                    )
                end
                market_cap_vector::Vector{Float32} = vec(Float32.(market_cap_df.marketCap))

                branch_date_vectors[branch_name] = new_branch_vector
                branch_returns[branch_name] = market_cap_vector
            else
                throw(
                    ValidationError(
                        "Invalid node type in market cap branch",
                        Dict("type" => branch_node[1]["type"]),
                    ),
                )
            end
        end

        branch_weights::Dict{Any,Vector{Float32}}, min_length::Int = calculate_market_cap_weighting_f32(
            branch_returns
        )
        min_days_market_cap = min(min_length, min_days_market_cap)

        for (branch_name::String, branch_weight_vector::Vector{Float32}) in branch_weights
            for day in 1:min_days_market_cap
                for stock in branch_date_vectors[branch_name][day].stockList
                    stock.weightTomorrow *= branch_weight_vector[day]
                    stock.weightTomorrow *= node_weight
                    if active_branch_mask[end - (min_days_market_cap) + day]
                        push!(
                            portfolio_history[end - (min_days_market_cap) + day].stockList,
                            stock,
                        )
                    end
                end
            end
        end

        return min_days_market_cap
    catch e
        if isa(e, BacktestError)
            rethrow(e)
        else
            throw(
                AllocationNodeError(
                    "Failed to process market cap allocation",
                    "Market Cap",
                    Dict("error" => e, "node_id" => node["id"]),
                ),
            )
        end
    end
end

function process_allocation(
    allocation_node::Dict{String,Any},
    active_branch_mask::BitVector,
    total_days::Int,
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
    min_days_manual::Int = total_days
    total_weight = sum(values(allocation_node["properties"]["values"]))
    if !isapprox(total_weight, 100.0f0; rtol=1e-2)
        throw(
            ValidationError(
                "Total allocation weight must be 100%", Dict("total_weight" => total_weight)
            ),
        )
    end

    for (branch_name::String, branch_weight::Float32) in
        allocation_node["properties"]["values"]
        branch_key, branch = find_matching_branch(
            allocation_node["branches"], branch_name, branch_weight
        )
        new_weight_at_level::Float32 = node_weight * (branch_weight / 100.0f0)
        min_days_manual_branch = post_order_dfs(
            branch[1],
            active_branch_mask,
            total_days,
            new_weight_at_level,
            portfolio_history[(end - total_days + 1):end],
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
        # correctly update the min days manual as we were directly assigning it before
        min_days_manual = min(min_days_manual, min_days_manual_branch)
    end

    return min_days_manual
end
function handle_allocation_error(e::Exception, node::Dict{String,Any})
    node_type = get(node, "function", "unknown")
    if isa(e, BacktestError)
        rethrow(e)
    elseif isa(e, ArgumentError)
        throw(
            AllocationError(
                "Invalid allocation parameters",
                node_type,
                Dict("error" => e, "node_id" => get(node, "id", "unknown")),
            ),
        )
    else
        throw(
            AllocationNodeError(
                "Failed to process allocation node",
                node_type,
                Dict("error" => e, "node" => node),
            ),
        )
    end
end

end
