module FlowMap
using ..VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.SubtreeCache
using ..VectoriseBacktestService.ConditionalNode
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.ReturnCalculations
using Dates, DataFrames, JSON

export get_flow_graph, find_path_to_id

function prepare_condition_node(properties::Dict{String,Any})::Dict{String,Any}
    return Dict{String,Any}("type" => "condition", "properties" => properties)
end

function find(current_nodes::Vector{Any}, id::SubString{String})
    for i in 1:length(current_nodes)
        if current_nodes[i]["id"] == id
            return current_nodes[i]
        end
    end
    return nothing
end

function find_path_to_id(
    data::Dict{String,Any}, path::Vector{SubString{String}}
)::Vector{Tuple{Dict{String,Any},String}}
    result::Vector{Tuple{Dict{String,Any},String}} = Vector{Tuple{Dict{String,Any},String}}()
    current_nodes = data["sequence"]
    for i in 1:(length(path) - 1)
        if find(current_nodes, path[end]) !== nothing
            return result
        end
        node = find(current_nodes, path[i])
        if node !== nothing
            if node["type"] == "condition"
                # select one of the branches of the condition node
                x = if find(node["branches"]["true"], path[i + 1]) !== nothing
                    "true"
                else
                    "false"
                end
                push!(result, (node["properties"], x))
                current_nodes = node["branches"][x]
            elseif node["type"] == "allocation" || node["type"] == "LockOnTrigger"
                # select the branches of allocation or lock on trigger containing next id
                x = nothing
                for key in keys(node["branches"])
                    if find(node["branches"][key], path[i + 1]) !== nothing
                        x = key
                        break
                    end
                end
                current_nodes = node["branches"][x]
            elseif node["type"] == "Sort"
                # sort has only one branch that has next coming nodes
                current_nodes = node["branches"][first(keys(node["branches"]))]
            elseif node["type"] == "folder"
                # folder is a sequence so directly update current nodes
                current_nodes = node["sequence"]
            end
        else
            break
        end
    end
    return result
end

function get_flow_graph(
    strategy_json::Dict{String,Any},
    path::String,
    node_children_hash::String,
    end_date::Date,
)
    try
        # create dummy values for rest of parameters of condition eval
        cache::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()
        price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()
        strategy_root::Dict{String,Any} = Dict{String,Any}()
        live_execution::Bool = false

        # first we will get the file from where we need to get the data
        cached_portfolio, date_range, cached_end_date = read_subtree_portfolio_with_dates_mmem(
            node_children_hash, end_date
        )

        # check if cached portfolio is valid
        if isnothing(cached_portfolio) || length(date_range) == 0
            return [], [], 0
        end

        # create total days
        total_days::Int = length(date_range)

        # now create active mask from the cached portfolio history
        active_mask::BitVector = BitVector(trues(length(cached_portfolio)))

        # next, we will get all if nodes from root to the subtree
        if_nodes::Vector{Tuple{Dict{String,Any},String}} = find_path_to_id(
            strategy_json, split(path, "/")
        )

        # now we need to call conditionEval for all the nodes in the if_nodes and update active mask
        for (i, if_node) in enumerate(if_nodes)
            node = prepare_condition_node(if_node[1])
            condition_result = conditionEval(
                node,
                date_range,
                total_days,
                end_date,
                cache,
                price_cache,
                strategy_root,
                live_execution,
            )

            effective_days = length(condition_result)
            if effective_days == 0
                throw(
                    ConditionNodeError(
                        "No effective days after condition evaluation",
                        "",
                        Dict("common_data_span" => total_days),
                    ),
                )
            end
            total_days = min(total_days, effective_days)

            active_mask = if if_node[2] == "true"
                BitVector(condition_result .& active_mask[(end - effective_days + 1):end])
            else
                BitVector(.!condition_result .& active_mask[(end - effective_days + 1):end])
            end
        end

        # truncate dates
        date_range = date_range[(end - total_days + 1):end]

        # now create profile_history
        profile_history::Vector{DayData} = [DayData() for _ in 1:total_days]

        trade_count = 0
        # now from cached portfolio, we will get only those days where active mask is a 1
        for i in 1:total_days
            if active_mask[i]
                trade_count += 1
                profile_history[i] = cached_portfolio[end - total_days + i]
            end
        end
        println("Profile history length: ", length(profile_history))
        # now we will calculate the delta curve
        delta_curve::Vector{Float32} = calculate_final_return_curve(
            profile_history,
            date_range,
            total_days,
            end_date,
            price_cache,
            DayData(),
            false,
            false,
        )

        return delta_curve, date_range, trade_count

    catch e
        throw(ServerError(400, "Failed to generate Flow Graph due to exception $(e)"))
    end
end

end
# try
#     json_str::String = read("./strat2.json", String)
#     data::Dict{String, Any} = (JSON.parse(json_str))

#     end_date = Date("2025-01-12")
#     path = "34c3c3fc2482a9267a1d7fa059304126/4df18e92bd444de5a6f532e32129ad6f"

#     nodeChildrenHash::String = "421fdb8dda515d2e4a66ea88e25068aa"

#     @time delta_curve::Vector{Float32}, date_range = get_flow_graph(data, path, nodeChildrenHash, end_date)
#     println(delta_curve)
# catch e
#     @error "Error in main execution: $(typeof(e)) - $(e)"
# end
