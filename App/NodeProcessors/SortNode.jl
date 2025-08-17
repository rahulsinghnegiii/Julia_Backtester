module SortNode

using Dates, DataFrames
using ..VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.FlowData
using ..VectoriseBacktestService.TASorting
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.BacktestUtilites
using ..VectoriseBacktestService.ReturnCalculations
using ..VectoriseBacktestService.TimeCalculation

export process_sort_node,
    process_branches, calculate_selection_indices, update_portfolio_history

function update_portfolio_history(
    portfolio_history::Vector{DayData},
    temp_portfolio_vectors::Vector{Vector{DayData}},
    selection_indices::Vector{Vector{Int}},
    daily_weight::Float32,
    common_data_span::Int,
    sort_window::Int,
    selection_count::Int,
)::Nothing
    try
        if isempty(portfolio_history) ||
            isempty(temp_portfolio_vectors) ||
            isempty(selection_indices)
            throw(
                PortfolioUpdateError(
                    "Empty input arrays",
                    Dict(
                        "portfolio_history_length" => length(portfolio_history),
                        "temp_vectors_length" => length(temp_portfolio_vectors),
                        "selection_indices_length" => length(selection_indices),
                    ),
                ),
            )
        end

        for day in 1:(common_data_span)
            try
                for branch_index in selection_indices[day]
                    if branch_index > length(temp_portfolio_vectors)
                        throw(
                            PortfolioUpdateError(
                                "Branch index out of bounds",
                                Dict(
                                    "branch_index" => branch_index,
                                    "available_branches" => length(temp_portfolio_vectors),
                                ),
                            ),
                        )
                    end

                    for stock in temp_portfolio_vectors[branch_index][day].stockList
                        stock.weightTomorrow /= selection_count
                        stock.weightTomorrow *= daily_weight
                        push!(
                            portfolio_history[end - (common_data_span) + day].stockList,
                            stock,
                        )
                    end
                end
            catch e
                throw(
                    PortfolioUpdateError(
                        "Failed to process day $day", Dict("day" => day, "error" => e)
                    ),
                )
            end
        end
        return nothing
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(PortfolioUpdateError("Unexpected error in portfolio update", e))
        end
    end
end

function calculate_selection_indices(
    branch_metrics::Vector{Vector{Float64}},
    active_branch_mask::BitVector,
    data_span::Int,
    sort_window::Int,
    select_function::String,
    selection_count::Int,
    sort_node::Dict{String,Any},
    flow_count::Dict{String,Int},
)::Vector{Vector{Int}}
    try
        if isempty(branch_metrics)
            throw(SelectionError("Empty branch metrics", nothing))
        end

        if selection_count > length(branch_metrics)
            throw(
                SelectionError(
                    "Selection count exceeds available branches",
                    Dict(
                        "selection_count" => selection_count,
                        "available_branches" => length(branch_metrics),
                    ),
                ),
            )
        end

        selection_indices = [Int[] for _ in 1:(data_span)]
        active_days = findall(active_branch_mask[(end - (data_span) + 1):end])

        for day in active_days
            if haskey(sort_node, "hash")
                increment_flow_count(flow_count, sort_node["hash"])
            end

            day_metrics = [metric[day] for metric in branch_metrics]
            if any(isnan, day_metrics) || any(isinf, day_metrics)
                # replace NaN and Inf with 0
                day_metrics = [
                    if isnan(metric) || isinf(metric)
                        0.0f0
                    else
                        metric
                    end for metric in day_metrics
                ]
            end

            selection_indices[day] = if select_function == "Top"
                partialsortperm(day_metrics, 1:selection_count; rev=true)
            elseif select_function == "Bottom"
                partialsortperm(day_metrics, 1:selection_count; rev=false)
            else
                throw(SelectionError("Invalid select function", select_function))
            end
        end

        return selection_indices
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(SelectionError("Failed to calculate selection indices", e))
        end
    end
end
function process_branches(
    branches::Dict{String,Any},
    branch_keys::Vector{String},
    total_days::Int,
    daily_weight::Float32,
    date_range::Vector{String},
    end_date::Date,
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
    indicator_cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    strategy_root::Dict{String,Any},
    live_execution::Bool,
    global_cache_length::Int,
)::Tuple{Vector{Vector{DayData}},Int}
    try
        if isempty(branches) || isempty(branch_keys)
            throw(
                BranchProcessingError(
                    "Empty branches or branch keys",
                    Dict(
                        "branches_count" => length(branches),
                        "branch_keys_count" => length(branch_keys),
                    ),
                ),
            )
        end

        temp_portfolio_vectors = [
            [DayData() for _ in 1:total_days] for _ in 1:length(branch_keys)
        ]
        min_data_length = total_days

        for (current_branch_idx, branch_key) in enumerate(branch_keys)
            if !haskey(branches, branch_key)
                throw(BranchProcessingError("Branch key not found", branch_key))
            end

            if isempty(branches[branch_key])
                throw(BranchProcessingError("Empty branch", branch_key))
            end

            temp_active_branch_mask = BitVector(trues(total_days))
            branch_data_length = post_order_dfs(
                branches[branch_key][1],
                temp_active_branch_mask,
                total_days,
                1.0f0,
                temp_portfolio_vectors[current_branch_idx],
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
            min_data_length = min(min_data_length, branch_data_length)
        end

        return temp_portfolio_vectors, min_data_length
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(BranchProcessingError("Failed to process branches", e))
        end
    end
end
function validate_sort_node(
    sort_node::Dict{String,Any}, portfolio_history::Vector{DayData}, total_days::Int
)
    if !haskey(sort_node, "branches")
        throw(ValidationError("Sort node missing 'branches' field"))
    end

    if isempty(portfolio_history) || total_days <= 0
        throw(
            ValidationError(
                "Invalid input parameters",
                Dict(
                    "portfolio_history_length" => length(portfolio_history),
                    "total_days" => total_days,
                ),
            ),
        )
    end
end

function process_sort_node(
    sort_node::Dict{String,Any},
    active_branch_mask::BitVector,
    total_days::Int,
    daily_weight::Float32,
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    end_date::Date,
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
    indicator_cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    strategy_root::Dict{String,Any},
    live_execution::Bool,
    global_cache_length::Int,
)::Int
    node_id = get(sort_node, "id", "unknown")
    # Initial validation
    validate_sort_node(sort_node, portfolio_history, total_days)
    # Get branches and properties in one block
    local branches, has_folder_node, selection_count, select_function, sort_function, sort_window
    branches, has_folder_node = get_branches(sort_node)
    isempty(branches) && throw(ValidationError("Sort node has no branches"))

    selection_count, select_function = parse_select_properties(sort_node)
    selection_count <= 0 &&
        throw(ValidationError("Invalid selection count", selection_count))

    sort_function, sort_window = parse_sort_properties(sort_node)

    # Process branches
    branch_keys = collect(keys(branches))
    branch_metrics = Vector{Vector{Float32}}(undef, length(branch_keys))

    # Process branches and calculate metrics
    local temp_portfolio_vectors, common_data_span, flag, original_total_days
    flag = false
    original_total_days = total_days
    uses_delta_in_sort_function::Bool =
        sort_function in ["Standard Deviation of Return", "Moving Average of Return"]
    pad_252_days =
        sort_function in ["Relative Strength Index", "Exponential Moving Average of price"]
    """
        Refer to AllocationNode.jl for a detailed explanation of this if-else block as well as cached_mapping/cached_portfolio_values.

        The variable 'uses_delta_in_sort_function' is utilized when the sort function computes the deltas
        of the returns. In such cases, the total days should be incremented by the sort window and an additional day
        to ensure sufficient data is available for calculating the branch_return_curves and subsequently the branch_metrics.
    """
    try
        new_date_range = date_range
        if has_folder_node
            total_days += sort_window + uses_delta_in_sort_function + pad_252_days * 252
            new_date_range = populate_dates(total_days, end_date, String[], live_execution)
            total_days = min(total_days, length(new_date_range))
            new_active_branch_mask = BitVector(trues(total_days))
            for day in eachindex(active_branch_mask)
                new_active_branch_mask[(end - day + 1)] = active_branch_mask[(end - day + 1)]
            end
            active_branch_mask = new_active_branch_mask
            flag = true
        end
        temp_portfolio_vectors, common_data_span = process_branches(
            branches,
            branch_keys,
            total_days,
            daily_weight,
            new_date_range,
            end_date,
            flow_count,
            flow_stocks,
            indicator_cache,
            price_cache,
            strategy_root,
            live_execution,
            global_cache_length,
        )
        if has_folder_node
            folder_min_data_length::Int = total_days
            cached_portfolio_values::Dict{String,Vector{Float64}}, use::Bool, cached_end_date::Union{Date,Nothing} = read_portfolio_values(
                sort_node["nodeChildrenHash"]
            )
            cached_mapping::Dict{String,Float64} = Dict{String,Float64}()
            branch_return_curves::Vector{Vector{Float64}} = Vector{Vector{Float64}}()
            if use && (flag) && cached_end_date >= end_date
                for (key, value) in cached_portfolio_values
                    # Push the current array to the 2D vector
                    push!(branch_return_curves, value)
                    folder_min_data_length = min(folder_min_data_length, length(value))
                end
                common_data_span = min(common_data_span, folder_min_data_length)
                branch_metrics = apply_sort_function(
                    branch_return_curves, sort_function, sort_window
                )
            else
                if use && (flag)
                    for (key, value) in cached_portfolio_values
                        cached_mapping[key] = value[max(1, end - original_total_days + 1)]
                    end
                end

                branch_return_curves, folder_min_data_length = calculate_branch_return_curves(
                    temp_portfolio_vectors,
                    new_date_range[max(1, (end - total_days + 1)):end],
                    end_date,
                    price_cache,
                    total_days,
                    sort_function,
                    cached_mapping,
                    live_execution,
                )
                fresh_portfolio_values = Dict{String,Vector{Float64}}()
                for (i, ret) in enumerate(branch_return_curves)
                    append_val = ret .- 100.0f0
                    if haskey(cached_portfolio_values, string(i))
                        fresh_portfolio_values[string(i)] = append!(
                            cached_portfolio_values[string(i)],
                            append_val[max(1, (end - original_total_days + 1)):end],
                        )
                    else
                        fresh_portfolio_values[string(i)] = append_val[max(
                            1, (end - original_total_days + 1)
                        ):end]
                    end
                end
                cache_portfolio_values(
                    fresh_portfolio_values,
                    sort_node["nodeChildrenHash"],
                    Date(end_date),
                    live_execution,
                )

                common_data_span = min(folder_min_data_length, common_data_span)
                branch_metrics = apply_sort_function(
                    branch_return_curves, sort_function, sort_window
                )
            end
        else
            branch_metrics, stock_min_data_length = apply_sort_ta_stock_function(
                temp_portfolio_vectors,
                date_range,
                end_date,
                price_cache,
                total_days,
                sort_function,
                sort_window,
                indicator_cache,
                live_execution,
            )
            common_data_span = min(stock_min_data_length, common_data_span)
        end
    catch e
        throw(
            ProcessingError(
                "Failed to process branches and metrics",
                Dict("node_id" => node_id, "error" => e),
            ),
        )
    end

    # Adjust data spans and calculate final results
    try
        # Adjust branch metrics
        # Flag indicates N-day backtest, in which case the data_span is the padded total_days
        data_span = if has_folder_node
            (common_data_span - pad_252_days * 252) - sort_window
        else
            common_data_span
        end
        # If the sort function uses deltas, the data span should be decremented by 1 in order to adjust the 1 we added earlier
        data_span -= (uses_delta_in_sort_function && flag)
        if data_span < 0
            data_span = if has_folder_node
                (total_days - pad_252_days * 252) - sort_window -
                (uses_delta_in_sort_function && flag)
            else
                common_data_span
            end
        end

        branch_metrics = [
            metric[max(1, (end - data_span + 1)):end] for metric in branch_metrics
        ]
        data_span = min(data_span, length(branch_metrics[1]))
        # Calculate selection indices
        selection_indices = calculate_selection_indices(
            branch_metrics,
            active_branch_mask,
            data_span,
            sort_window,
            select_function,
            selection_count,
            sort_node,
            flow_count,
        )
        # Adjust portfolio vectors
        temp_portfolio_vectors = [
            days[(end - data_span + 1):end] for days in temp_portfolio_vectors
        ]

        # Update portfolio history
        update_portfolio_history(
            portfolio_history,
            temp_portfolio_vectors,
            selection_indices,
            daily_weight,
            data_span,
            sort_window,
            selection_count,
        )
        # Set flow stocks if needed
        if haskey(sort_node, "hash")
            set_flow_stocks(flow_stocks, portfolio_history, sort_node["hash"])
        end
        return if flag
            original_total_days
        else
            if has_folder_node
                min((total_days - sort_window), (common_data_span - sort_window))
            else
                min(common_data_span, total_days)
            end
        end
    catch e
        throw(
            ProcessingError(
                "Failed to finalize sort node processing",
                Dict("node_id" => node_id, "error" => e),
            ),
        )
    end
end

end
