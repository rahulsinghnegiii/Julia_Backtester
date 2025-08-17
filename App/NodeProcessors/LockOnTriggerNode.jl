module LockOnTriggerNode
using Dates, DataFrames
using ..VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.FlowData
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.TimeCalculation
using ..VectoriseBacktestService.BacktestUtilites
using ..VectoriseBacktestService.ConditionalNode
using ..VectoriseBacktestService.SortNode

export process_lock_on_trigger_node, find_triggered_branch

# TODO:
# - Implement support for exit condition
# - Clean up code/performance improvements

function format_condition(condition::Dict{String,Any}, path::String)
    return Dict(
        "type" => "condition",
        "properties" => Dict{String,Any}(
            "x" => condition["x"],
            "y" => condition["y"],
            "comparison" => condition["comparison"],
        ),
        "path" => path,
    )
end

function process_lock_on_trigger_node(
    lot_node::Dict{String,Any},
    active_branch_mask::BitVector,
    total_days::Int,
    node_weight::Float32,
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    end_date::Date,
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
    price_cache::Dict{String,DataFrame},
    indicator_cache::Dict{String,Vector{Float32}},
    strategy_root::Dict{String,Any},
    live_execution::Bool=false,
    global_cache_length::Int=0,
)
    # Evaluate the condition for each branch
    branch_data::Dict{String,Dict{String,Any}} = Dict()
    min_data_length = typemax(Int)
    if !haskey(lot_node, "branches")
        throw(
            LockOnTriggerError(
                "LockOnTriggerNode",
                Dict("error" => "Branches missing", "node_id" => lot_node["id"]),
            ),
        )
    end
    branch_keys = sort(collect(keys(lot_node["branches"])))

    if !haskey(lot_node["branches"], "default")
        throw(
            LockOnTriggerError(
                "LockOnTriggerNode",
                Dict("error" => "Default branch missing", "node_id" => lot_node["id"]),
            ),
        )
    end

    if !haskey(lot_node["properties"], "conditions")
        throw(
            LockOnTriggerError(
                "LockOnTriggerNode",
                Dict(
                    "error" => "Conditions missing in properties",
                    "node_id" => lot_node["id"],
                ),
            ),
        )
    end

    if (length(lot_node["properties"]["conditions"])) != (length(branch_keys) - 1)
        throw(
            LockOnTriggerError(
                "LockOnTriggerNode",
                Dict(
                    "error" => "Number of branches and conditions do not match",
                    "node_id" => lot_node["id"],
                ),
            ),
        )
    end

    for key in branch_keys
        if !haskey(branch_data, key)
            branch_data[key] = Dict(
                "portfolio" => [DayData() for _ in 1:total_days],
                "entry_mask" => [false for _ in 1:total_days],
            )
        end

        current_branch_sequence = lot_node["branches"][key]

        if length(current_branch_sequence) == 0
            throw(
                LockOnTriggerError(
                    "LockOnTriggerNode",
                    Dict(
                        "error" => "Branch $key sequence is empty",
                        "node_id" => lot_node["id"],
                    ),
                ),
            )
        end

        nodes_length = count(node -> node["type"] != "comment", current_branch_sequence)
        for i in eachindex(current_branch_sequence)
            branch_data_length = try
                post_order_dfs(
                    current_branch_sequence[i],
                    active_branch_mask,
                    total_days,
                    node_weight / nodes_length,
                    branch_data[key]["portfolio"],
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
            catch e
                throw(
                    LockOnTriggerError(
                        "LockOnTriggerNode",
                        Dict(
                            "error" => "Error in post order dfs on branch $key sequence",
                            "node_id" => lot_node["id"],
                        ),
                    ),
                )
            end
            min_data_length = minimum([min_data_length, branch_data_length])
        end
        # Skip the default branch
        if key === "default"
            continue
        end

        branch_conditions = try
            lot_node["properties"]["conditions"][key]
        catch e
            throw(
                LockOnTriggerError(
                    "LockOnTriggerNode",
                    Dict(
                        "error" => "Error in fetching conditions for branch $key",
                        "node_id" => lot_node["id"],
                    ),
                ),
            )
        end

        if !haskey(branch_conditions, "entry_condition")
            throw(
                LockOnTriggerError(
                    "LockOnTriggerNode",
                    Dict(
                        "error" => "Entry condition missing in branch $key",
                        "node_id" => lot_node["id"],
                    ),
                ),
            )
        end

        branch_data[key]["entry_mask"] = conditionEval(
            format_condition(branch_conditions["entry_condition"], lot_node["path"]),
            date_range,
            total_days,
            end_date,
            indicator_cache,
            price_cache,
            strategy_root,
            live_execution,
        )
        min_data_length = minimum([length(branch_data[key]["entry_mask"]), min_data_length])

        if haskey(branch_conditions, "exit_condition")
            branch_data[key]["exit_mask"] = conditionEval(
                format_condition(branch_conditions["exit_condition"], lot_node["path"]),
                date_range,
                total_days,
                end_date,
                indicator_cache,
                price_cache,
                strategy_root,
                live_execution,
            )
            min_data_length = minimum([
                length(branch_data[key]["exit_mask"]), min_data_length
            ])
        end
    end
    # Truncate all masks to the minimum length
    for key in branch_keys
        branch_data[key]["entry_mask"] = branch_data[key]["entry_mask"][max(
            1, (end - min_data_length + 1)
        ):end]
        branch_data[key]["portfolio"] = branch_data[key]["portfolio"][max(
            1, (end - min_data_length + 1)
        ):end]
        if haskey(branch_data[key], "exit_mask")
            branch_data[key]["exit_mask"] = branch_data[key]["exit_mask"][max(
                1, (end - min_data_length + 1)
            ):end]
        end
    end

    current_branch = "default"
    for day in findall(active_branch_mask[max(1, (end - min_data_length + 1)):end])
        current_branch = find_triggered_branch(
            branch_data, day, branch_keys, current_branch
        )
        for stock in branch_data[current_branch]["portfolio"][day].stockList
            push!(portfolio_history[(end - min_data_length) + day].stockList, stock)
        end
    end

    return min_data_length
end

"""
Conditions:
1. If no branch has been triggered, default branch is automatically triggered
2. If a branch has been triggered on a previous day, the same branch is triggered on the current day iff [no other branch of higher priority has been triggered AND exit condition of current branch is not met]
3. A triggered branch will change only if [branch of higher priority is triggered OR exit condition of current branch is met in which case default branch is triggered]


Priority Levels:
—
A’
A
B’
B
C’
C
Yesterday -- this will be triggered if all branches are FALSE and some branch other than default was triggered yesterday
Default
—


Example:
Day [1, 2, 3, 4, 5, 6, 7, 8, 9]
A': [0, 0, 1, 0, 0, 0, 1, 0, 0]
A:  [0, 1, 0, 0, 1, 0, 0, 0, 0]
B': [0, 0, 0, 0, 1, 0, 0, 0, 1]
B:  [0, 1, 1, 1, 1, 0, 1, 0, 1]
C:  [0, 1, 1, 0, 0, 0, 1, 1, 1]

Day 1: default  // no branch is active
Day 2: A        // branch A is active && exit cond. not met && no higher priority branch is active
Day 3: default  // exit condition of A is met
Day 4: B        // branch B is active && no higher priority branch is active
Day 5: A        // branch A is active and higher priority than B' && no higher priority branch is active
Day 6: A        // no branch is active but A was active yesterday
Day 7: default  // exit condition of A is met
Day 8: C        // branch C is active && no higher priority branch is active
Day 9: C        // current branch is C. even though exit cond. of B is met, since B isn't the current branch we don't switch to default

"""

function find_triggered_branch(
    branch_data::Dict{String,Dict{String,Any}},
    day::Int,
    branch_keys::Vector{String},
    current_branch::String,
)
    branch_triggered = "default"
    for key in branch_keys
        # Skip the default branch
        if key === "default"
            continue
        end

        # Check exit condition of current branch. If exit condition is met, switch to default
        if haskey(branch_data[key], "exit_mask")
            if key === current_branch && branch_data[key]["exit_mask"][day] === true
                return "default"
            end
        end

        # entry condition should be met
        if branch_data[key]["entry_mask"][day] === true
            if haskey(branch_data[key], "exit_mask")
                # if the branch has an exit condition, it should NOT be met
                if !branch_data[key]["exit_mask"][day] === true
                    branch_triggered = key
                    break
                end
            else
                # branch does not have exit condition, so it is triggered
                branch_triggered = key
                break
            end
        end
    end

    # this means that no condition was met on the current day BUT a branch was triggered on any of the previous days
    if current_branch != "default" && branch_triggered === "default"
        branch_triggered = current_branch
    end

    return branch_triggered
end

end
