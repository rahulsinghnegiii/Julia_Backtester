module ConditionalNode

using Dates, DataFrames, JSON
using ..VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.FlowData
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.TimeCalculation
using ..VectoriseBacktestService.BacktestUtilites
using ..VectoriseBacktestService.SubtreeCache
using ..VectoriseBacktestService.ReturnCalculations

export process_condition_node, process_branch, conditionEval

### Validation Functions
function validate_condition_node(node::Dict{String,Any})
    required_fields = ["branches", "type", "properties"]
    for field in required_fields
        if !haskey(node, field)
            throw(
                ValidationError(
                    "Missing required field: $field",
                    Dict("node_id" => get(node, "id", "unknown")),
                ),
            )
        end
    end

    if !haskey(node["branches"], "true") || !haskey(node["branches"], "false")
        throw(
            ValidationError(
                "Missing true/false branches", Dict("node_id" => get(node, "id", "unknown"))
            ),
        )
    end
end

function validate_condition_properties(properties::Dict{String,Any})
    required_props = ["x", "y", "comparison"]
    for prop in required_props
        if !haskey(properties, prop)
            throw(
                ValidationError(
                    "Missing condition property: $prop",
                    Dict("properties" => keys(properties)),
                ),
            )
        end
    end
end

### Main Functions
function process_condition_node(
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
        # Validate input node
        validate_condition_node(node)

        node_id = get(node, "id", "unknown")

        # Flow count handling with error checking
        if haskey(node, "hash")
            try
                increment_flow_count(flow_count, node["hash"])
            catch e
                @warn "Failed to increment flow count" node_hash = node["hash"] error = e
            end
        end

        true_branch = node["branches"]["true"]
        false_branch = node["branches"]["false"]

        # Evaluate condition with error handling
        condition_result = try
            @maybe_time conditionEval(
                node,
                date_range,
                common_data_span,
                end_date,
                indicator_cache,
                price_cache,
                strategy_root,
                live_execution,
            )
        catch e
            throw(
                ConditionEvalError(
                    "Failed to evaluate condition",
                    get(node["properties"], "comparison", "unknown"),
                    Dict("node_id" => node_id, "error" => e),
                ),
            )
        end

        effective_days = length(condition_result)
        if effective_days == 0
            throw(
                ConditionNodeError(
                    "No effective days after condition evaluation",
                    node_id,
                    Dict("common_data_span" => common_data_span),
                ),
            )
        end

        # Create branch masks
        true_branch_mask = BitVector(
            condition_result .& active_mask[(end - effective_days + 1):end]
        )
        false_branch_mask = BitVector(
            .!condition_result .& active_mask[(end - effective_days + 1):end]
        )

        # Process branches with error handling
        true_branch_span = try
            process_branch(
                true_branch,
                true_branch_mask,
                effective_days,
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
        catch e
            throw(
                ConditionNodeError(
                    "Failed to process true branch", node_id, Dict("error" => e)
                ),
            )
        end

        false_branch_span = try
            process_branch(
                false_branch,
                false_branch_mask,
                effective_days,
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
        catch e
            throw(
                ConditionNodeError(
                    "Failed to process false branch", node_id, Dict("error" => e)
                ),
            )
        end

        # Set flow stocks with error handling
        if haskey(node, "hash")
            try
                set_flow_stocks(flow_stocks, portfolio_history, node["hash"])
            catch e
                @warn "Failed to set flow stocks" node_hash = node["hash"] error = e
            end
        end

        return min(true_branch_span, false_branch_span, effective_days)
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(
                ConditionNodeError(
                    "Unexpected error in condition node",
                    get(node, "id", "unknown"),
                    Dict("error" => e),
                ),
            )
        end
    end
end

function process_branch(
    nodes::Vector{Any},
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
        if isempty(nodes)
            throw(
                ValidationError(
                    "Empty branch provided", Dict("common_data_span" => common_data_span)
                ),
            )
        end

        if !any(active_mask)
            return common_data_span
        end

        min_data_span = common_data_span
        node_length = count(node -> node["type"] != "comment", nodes)
        node_weight_per_node = node_weight / node_length

        for (index, node) in enumerate(nodes)
            try
                node_min_span = post_order_dfs(
                    node,
                    active_mask,
                    common_data_span,
                    node_weight_per_node,
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
                min_data_span = min(min_data_span, node_min_span)
            catch e
                throw(
                    ProcessingError(
                        "Failed to process branch node",
                        Dict("node_index" => index, "error" => e),
                    ),
                )
            end
        end

        return min_data_span
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(ProcessingError("Unexpected error in branch processing", e))
        end
    end
end
function conditionEval(
    node::Dict{String,Any},
    dates::Vector{String},
    dateLength::Int,
    end_date::Date,
    cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    strategy_root::Dict{String,Any},
    live_execution::Bool=false,
)::Vector{Bool}
    try
        # Validate node type
        if node["type"] != "condition"
            throw(
                ValidationError(
                    "Invalid node type",
                    Dict("expected" => "condition", "actual" => node["type"]),
                ),
            )
        end
        # Validate properties
        validate_condition_properties(node["properties"])

        # Get indicator values with error handling
        x =
            if haskey(node["properties"]["x"], "uses_synthetic_stock") &&
                node["properties"]["x"]["uses_synthetic_stock"] === true
                if !haskey(node, "path") || isempty(node["path"])
                    throw(ArgumentError("Synthetic stock used without path"))
                end
                path = node["path"]
                path_split = split(path, "/")

                folder_id_x = node["properties"]["x"]["source"]
                if folder_id_x in path_split
                    throw(
                        ArgumentError(
                            "Synthetic Folder used in one of its own children. Path: $path"
                        ),
                    )
                end
                try
                    get_synthetic_value(
                        node["properties"]["x"],
                        dateLength,
                        end_date,
                        price_cache,
                        strategy_root,
                    )
                catch e
                    throw(
                        ConditionEvalError(
                            "Failed to get X synthetic value",
                            get(node["properties"], "comparison", "unknown"),
                            Dict("indicator" => node["properties"]["x"], "error" => e),
                        ),
                    )
                end
            else
                try
                    get_indicator_value(
                        node["properties"]["x"],
                        dates,
                        dateLength,
                        end_date,
                        cache,
                        price_cache,
                        live_execution,
                    )
                catch e
                    throw(
                        ConditionEvalError(
                            "Failed to get X indicator value",
                            get(node["properties"], "comparison", "unknown"),
                            Dict("indicator" => node["properties"]["x"], "error" => e),
                        ),
                    )
                end
            end

        y =
            if haskey(node["properties"]["y"], "uses_synthetic_stock") &&
                node["properties"]["y"]["uses_synthetic_stock"] === true
                if !haskey(node, "path") || isempty(node["path"])
                    throw(ArgumentError("Synthetic stock used without path"))
                end
                path = node["path"]
                path_split = split(path, "/")

                folder_id_y = node["properties"]["y"]["source"]
                if folder_id_y in path_split
                    throw(
                        ArgumentError(
                            "Synthetic Folder used in one of its own children. Path: $path"
                        ),
                    )
                end
                try
                    get_synthetic_value(
                        node["properties"]["y"],
                        dateLength,
                        end_date,
                        price_cache,
                        strategy_root,
                    )
                catch e
                    throw(
                        ConditionEvalError(
                            "Failed to get Y synthetic value",
                            get(node["properties"], "comparison", "unknown"),
                            Dict("indicator" => node["properties"]["y"], "error" => e),
                        ),
                    )
                end
            else
                try
                    get_indicator_value(
                        node["properties"]["y"],
                        dates,
                        dateLength,
                        end_date,
                        cache,
                        price_cache,
                        live_execution,
                    )
                catch e
                    throw(
                        ConditionEvalError(
                            "Failed to get Y indicator value",
                            get(node["properties"], "comparison", "unknown"),
                            Dict("indicator" => node["properties"]["y"], "error" => e),
                        ),
                    )
                end
            end

        # Validate indicator lengths
        if isempty(x) || isempty(y)
            throw(
                ConditionEvalError(
                    "Empty indicator values",
                    get(node["properties"], "comparison", "unknown"),
                    Dict("x_length" => length(x), "y_length" => length(y)),
                ),
            )
        end

        # Align indicator lengths
        x_length = length(x)
        y_length = length(y)

        if x_length != y_length
            if x_length > y_length
                x = try
                    x[(x_length - y_length + 1):end]
                catch e
                    throw(
                        ConditionEvalError(
                            "Failed to align X indicator",
                            get(node["properties"], "comparison", "unknown"),
                            Dict(
                                "x_length" => x_length,
                                "y_length" => y_length,
                                "error" => e,
                            ),
                        ),
                    )
                end
            else
                y = try
                    y[(y_length - x_length + 1):end]
                catch e
                    throw(
                        ConditionEvalError(
                            "Failed to align Y indicator",
                            get(node["properties"], "comparison", "unknown"),
                            Dict(
                                "x_length" => x_length,
                                "y_length" => y_length,
                                "error" => e,
                            ),
                        ),
                    )
                end
            end
        end

        # Get comparison operator
        comparison = node["properties"]["comparison"]

        # Compare values with error handling
        try
            return compare_values(x, y, comparison)
        catch e
            throw(
                ConditionEvalError(
                    "Failed to compare values",
                    comparison,
                    Dict(
                        "x_sample" => length(x) > 0 ? x[1] : nothing,
                        "y_sample" => length(y) > 0 ? y[1] : nothing,
                        "error" => e,
                    ),
                ),
            )
        end
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(
                ConditionEvalError(
                    "Unexpected error in condition evaluation",
                    get(get(node, "properties", Dict()), "comparison", "unknown"),
                    Dict("error" => e),
                ),
            )
        end
    end
end

### Helper Functions
# Define an abstract type for comparisons
abstract type ComparisonOperator end

# Define concrete types for each comparison
struct GreaterThan <: ComparisonOperator end
struct LessThan <: ComparisonOperator end
struct Equal <: ComparisonOperator end
struct GreaterThanEqual <: ComparisonOperator end
struct LessThanEqual <: ComparisonOperator end

# Implement comparison methods
compare_values(x::Vector{Float32}, y::Vector{Float32}, ::GreaterThan) = x .> y
compare_values(x::Vector{Float32}, y::Vector{Float32}, ::LessThan) = x .< y
compare_values(x::Vector{Float32}, y::Vector{Float32}, ::Equal) = x .== y
compare_values(x::Vector{Float32}, y::Vector{Float32}, ::GreaterThanEqual) = x .>= y
compare_values(x::Vector{Float32}, y::Vector{Float32}, ::LessThanEqual) = x .<= y

# String to operator conversion
function get_comparison_operator(comparison::String)
    ops = Dict{String,ComparisonOperator}(
        ">" => GreaterThan(),
        "<" => LessThan(),
        "==" => Equal(),
        ">=" => GreaterThanEqual(),
        "<=" => LessThanEqual(),
    )

    haskey(ops, comparison) || throw(
        ValidationError("Invalid comparison operator", Dict("operator" => comparison))
    )

    return ops[comparison]
end

# Main function
function compare_values(
    x::Vector{Float32}, y::Vector{Float32}, comparison::String
)::Vector{Bool}
    length(x) == length(y) || throw(
        ProcessingError(
            "Vector lengths must match",
            Dict("x_length" => length(x), "y_length" => length(y)),
        ),
    )

    op = get_comparison_operator(comparison)
    return compare_values(x, y, op)
end

# TODO: Get folder's path from frontend and use it to find the node in O(n)
function extract_folder_json(strategy_root::Any, target_folder_id::String)
    for node in strategy_root
        if get(node, "id", "") == target_folder_id
            return node
        end

        if haskey(node, "sequence")
            result = extract_folder_json(node["sequence"], target_folder_id)
            if result !== nothing
                return result
            end
        end

        if haskey(node, "branches")
            for sub_branch_nodes in values(node["branches"])
                result = extract_folder_json(sub_branch_nodes, target_folder_id)
                if result !== nothing
                    return result
                end
            end
        end
    end

    return nothing
end

function get_synthetic_value(
    node::Dict{String,Any},
    dateLength::Int,
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    strategy_root::Dict{String,Any},
)

    # Don't allow "Price" indicators with synthetic stock...(obviously)
    if haskey(node, "indicator")
        if node["indicator"] == "current price" ||
            node["indicator"] == "Simple Moving Average of Price" ||
            node["indicator"] == "Exponential Moving Average of Price" ||
            node["indicator"] == "Standard Deviation of Price"
            throw(ArgumentError("Synthetic stock used but indicator $(node["indicator"])"))
        end
    end

    # TODO: Should probably import constants like these from a centralized area
    subtree_cache_path::String = "./SubtreeCache"
    folder_id::String = node["source"]
    try
        folder_json = extract_folder_json(strategy_root["sequence"], folder_id)
        if isnothing(folder_json)
            throw(ArgumentError("Folder not found"))
        end
        folder_hash::String = folder_json["nodeChildrenHash"]

        local synthetic_profile_history::Vector{DayData}, date_range::Vector{String}, strategy_len::Int
        if isdir(subtree_cache_path)
            # Even if file exists, we will re-execute the backtest incase sparse subtree cache has NULLSTOCK on some days
            if isfile(joinpath(subtree_cache_path, folder_hash * ".mmap"))
                rm(joinpath(subtree_cache_path, folder_hash * ".mmap"))
            end
            temp_strategy = Dict{String,Any}("sequence" => [folder_json])
            synthetic_profile_history, date_range, strategy_len, flow_count, flow_stocks = execute_backtest(
                temp_strategy, dateLength, end_date, price_cache, 0
            )
        end

        # Read the subtree cache after executing backtest
        # synthetic_profile_history, date_range, end_date = read_subtree_portfolio_with_dates_mmem(
        # folder_hash, end_date
        # )

        synthetic_return_curves::Vector{Float64}, min_data_length::Int = process_single_branch(
            synthetic_profile_history,
            date_range,
            end_date,
            price_cache,
            length(synthetic_profile_history),
        )

        synthetic_return_curves = synthetic_return_curves[(end - min_data_length + 1):end]

        synthetic_portfolio_values::Vector{Float64} = calculate_portfolio_values_single_curve(
            synthetic_return_curves
        )

        synthetic_indicator_data = apply_sort_function(
            [synthetic_portfolio_values], node["indicator"], parse(Int, node["period"])
        )

        # Multiply every value by 100 if indicator is one of the following
        # because of how sort function is applied to synthetic stock values compared to normal stock functions
        # We have to do this because synthetic stock uses portfolio values and not actual stock prices
        multiply_by_hundred::Vector{String} = [
            "Cumulative Return",
            "Max Drawdown",
            "Moving Average of Return",
            "Standard Deviation of Return",
        ]
        if node["indicator"] in multiply_by_hundred
            return Float32.(
                synthetic_indicator_data[1][max(1, parse(Int, node["period"]) - 1):end] .*
                100
            )
        else
            return Float32.(
                synthetic_indicator_data[1][max(1, parse(Int, node["period"]) - 1):end]
            )
        end

    catch e
        rethrow("MethodError: Failed to get synthetic value: $e")
    end
end

end
