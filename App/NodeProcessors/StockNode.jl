module StockNode

using ..VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.FlowData
using ..VectoriseBacktestService.ErrorHandlers

export process_stock_node

"""
Validates the stock node structure and properties
"""
function validate_stock_node(stock_node::Dict{String,Any})
    if !haskey(stock_node, "properties")
        throw(ValidationError("Missing properties in stock node"))
    end

    properties = stock_node["properties"]
    if !haskey(properties, "symbol")
        throw(ValidationError("Missing symbol in stock node properties"))
    end

    if !isa(properties["symbol"], String)
        throw(
            ValidationError(
                "Invalid symbol type",
                Dict("expected" => "String", "got" => typeof(properties["symbol"])),
            ),
        )
    end

    if isempty(properties["symbol"])
        throw(ValidationError("Empty symbol in stock node properties"))
    end
end

"""
Validates input parameters for stock node processing
"""
function validate_inputs(
    active_branch_mask::BitVector,
    total_days::Int,
    node_weight::Float32,
    portfolio_history::Vector{DayData},
)
    if isempty(active_branch_mask)
        throw(ValidationError("Empty active branch mask"))
    end

    if total_days <= 0
        throw(ValidationError("Invalid total days", total_days))
    end

    if node_weight <= 0 || node_weight > 1
        throw(ValidationError("Invalid node weight", node_weight))
    end

    if isempty(portfolio_history)
        throw(ValidationError("Empty portfolio history"))
    end

    if length(portfolio_history) < total_days
        throw(
            ValidationError(
                "Portfolio history shorter than total days",
                Dict(
                    "portfolio_length" => length(portfolio_history),
                    "total_days" => total_days,
                ),
            ),
        )
    end
end

"""
Updates portfolio with stock information
"""
function update_portfolio(
    portfolio_history::Vector{DayData},
    symbol::String,
    node_weight::Float32,
    active_days::Vector{Int},
    total_days::Int,
)
    try
        for day in active_days
            if day > length(portfolio_history) || day <= 0
                throw(
                    StockProcessingError(
                        "Invalid day index",
                        Dict("day" => day, "portfolio_length" => length(portfolio_history)),
                    ),
                )
            end

            portfolio_idx = length(portfolio_history) - total_days + day
            if portfolio_idx <= 0 || portfolio_idx > length(portfolio_history)
                throw(
                    StockProcessingError(
                        "Invalid portfolio index",
                        Dict(
                            "calculated_index" => portfolio_idx,
                            "portfolio_length" => length(portfolio_history),
                        ),
                    ),
                )
            end

            push!(
                portfolio_history[portfolio_idx].stockList, StockInfo(symbol, node_weight)
            )
        end
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(
                StockProcessingError(
                    "Failed to update portfolio", Dict("symbol" => symbol, "error" => e)
                ),
            )
        end
    end
end

"""
Processes a stock node in the trading strategy
"""
function process_stock_node(
    stock_node::Dict{String,Any},
    active_branch_mask::BitVector,
    total_days::Int,
    node_weight::Float32,
    portfolio_history::Vector{DayData},
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
)
    try
        # Validate inputs
        validate_stock_node(stock_node)
        validate_inputs(active_branch_mask, total_days, node_weight, portfolio_history)

        # Extract symbol
        symbol::String = stock_node["properties"]["symbol"]
        active_days::Vector{Int} = findall(active_branch_mask)

        # Update flow count if hash exists
        if haskey(stock_node, "hash")
            try
                increment_flow_count(flow_count, stock_node["hash"])
            catch e
                throw(
                    StockProcessingError(
                        "Failed to increment flow count",
                        Dict("hash" => stock_node["hash"], "error" => e),
                    ),
                )
            end
        end

        # Update portfolio
        update_portfolio(portfolio_history, symbol, node_weight, active_days, total_days)

        # Set flow stocks if hash exists
        if haskey(stock_node, "hash")
            try
                set_flow_stocks(flow_stocks, portfolio_history, stock_node["hash"])
            catch e
                throw(
                    StockProcessingError(
                        "Failed to set flow stocks",
                        Dict("hash" => stock_node["hash"], "error" => e),
                    ),
                )
            end
        end

        return total_days  # Successful processing
    catch e
        if e isa BacktestError
            rethrow(e)
        else
            throw(
                StockNodeError(
                    "Failed to process stock node",
                    Dict(
                        "symbol" =>
                            get(get(stock_node, "properties", Dict()), "symbol", "unknown"),
                        "node_id" => get(stock_node, "id", "unknown"),
                        "error" => e,
                    ),
                ),
            )
        end
    end
end

end
