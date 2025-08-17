module TASorting

using Dates, DataFrames
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.BacktestUtilites
using ..VectoriseBacktestService.ErrorHandlers: ServerError
using ..VectoriseBacktestService.MarketTechnicalsIndicators

export apply_sort_ta_stock_function

# Helper function to pad indicator values
function pad_indicator_values(
    indicator_values::Vector{Float32}, total_days::Int
)::Tuple{Vector{Float32},Int}
    actual_data_length::Int = length(indicator_values)
    if actual_data_length == total_days
        return indicator_values, actual_data_length
    else
        padding_length::Int = total_days - actual_data_length
        return [fill(NaN32, padding_length); indicator_values], actual_data_length
    end
end
# Indicator calculation functions
function calculate_rsi(
    indicator_cache::Dict{String,Vector{Float32}},
    ticker::String,
    sort_window_str::String,
    total_days::Int,
    end_date::Date,
    live_execution::Bool,
)::Vector{Float32}
    return get_cached_indicator(
        indicator_cache,
        "rsi",
        ticker,
        sort_window_str,
        total_days,
        end_date,
        live_execution,
        get_rsi,
    )
end

function calculate_sma(
    indicator_cache::Dict{String,Vector{Float32}},
    ticker::String,
    sort_window_str::String,
    total_days::Int,
    end_date::Date,
    live_execution::Bool,
)::Vector{Float32}
    return get_cached_indicator(
        indicator_cache,
        "sma",
        ticker,
        sort_window_str,
        total_days,
        end_date,
        live_execution,
        get_sma,
    )
end

function calculate_ema(
    indicator_cache::Dict{String,Vector{Float32}},
    ticker::String,
    sort_window_str::String,
    total_days::Int,
    end_date::Date,
    live_execution::Bool,
)::Vector{Float32}
    return get_cached_indicator(
        indicator_cache,
        "ema",
        ticker,
        sort_window_str,
        total_days,
        end_date,
        live_execution,
        get_ema,
    )
end

function calculate_cumulative_return(
    indicator_cache::Dict{String,Vector{Float32}},
    ticker::String,
    sort_window_str::String,
    total_days::Int,
    end_date::Date,
    live_execution::Bool,
)::Vector{Float32}
    return get_cached_indicator(
        indicator_cache,
        "cumulative_return",
        ticker,
        sort_window_str,
        total_days,
        end_date,
        live_execution,
        get_cumulative_return,
    )
end

function calculate_max_drawdown(
    indicator_cache::Dict{String,Vector{Float32}},
    ticker::String,
    sort_window_str::String,
    total_days::Int,
    end_date::Date,
    live_execution::Bool,
)::Vector{Float32}
    return get_cached_indicator(
        indicator_cache,
        "max_drawdown",
        ticker,
        sort_window_str,
        total_days,
        end_date,
        live_execution,
        get_max_drawdown,
    )
end

function calculate_sma_returns(
    indicator_cache::Dict{String,Vector{Float32}},
    ticker::String,
    sort_window_str::String,
    total_days::Int,
    end_date::Date,
    live_execution::Bool,
)::Vector{Float32}
    return get_cached_indicator(
        indicator_cache,
        "sma_return",
        ticker,
        sort_window_str,
        total_days,
        end_date,
        live_execution,
        get_sma_returns,
    )
end

function calculate_sd_returns(
    indicator_cache::Dict{String,Vector{Float32}},
    ticker::String,
    sort_window_str::String,
    total_days::Int,
    end_date::Date,
    live_execution::Bool,
)::Vector{Float32}
    return get_cached_indicator(
        indicator_cache,
        "sd_return",
        ticker,
        sort_window_str,
        total_days,
        end_date,
        live_execution,
        get_sd_returns,
    )
end

function calculate_sd(
    indicator_cache::Dict{String,Vector{Float32}},
    ticker::String,
    sort_window_str::String,
    total_days::Int,
    end_date::Date,
    live_execution::Bool,
)::Vector{Float32}
    return get_cached_indicator(
        indicator_cache,
        "sd",
        ticker,
        sort_window_str,
        total_days,
        end_date,
        live_execution,
        get_sd,
    )
end

function calculate_current_price(
    ticker::String,
    date_range::Vector{String},
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    total_days::Int,
    live_execution::Bool,
)::Vector{Float32}
    return get_current_price(
        ticker, date_range, end_date, price_cache, total_days, live_execution
    )
end

# Main function to calculate TA stock metrics
function calculate_ta_stock_metrics(
    branch_portfolio_history::Vector{DayData},
    date_range::Vector{String},
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    total_days::Int,
    sort_function::String,
    sort_window::Int,
    indicator_cache::Dict{String,Vector{Float32}},
    live_execution::Bool,
)::Tuple{Vector{Float32},Int}
    ticker::String = branch_portfolio_history[1].stockList[1].ticker
    sort_window_str::String = string(sort_window)

    indicator_functions::Dict{String,Function} = Dict(
        "Relative Strength Index" => calculate_rsi,
        "Simple Moving Average of Price" => calculate_sma,
        "Moving Average of Price" => calculate_sma,
        "Exponential Moving Average of Price" => calculate_ema,
        "Cumulative Return" => calculate_cumulative_return,
        "Max Drawdown" => calculate_max_drawdown,
        "Moving Average of Return" => calculate_sma_returns,
        "Standard Deviation of Return" => calculate_sd_returns,
        "Standard Deviation of Price" => calculate_sd,
        "current price" =>
            (
                indicator_cache,
                ticker,
                sort_window_str,
                total_days,
                end_date,
                live_execution,
            ) -> calculate_current_price(
                ticker, date_range, end_date, price_cache, total_days, live_execution
            ),
    )

    if haskey(indicator_functions, sort_function)
        indicator_values::Vector{Float32} = indicator_functions[sort_function](
            indicator_cache, ticker, sort_window_str, total_days, end_date, live_execution
        )
        return pad_indicator_values(indicator_values, total_days)
    else
        throw(ServerError(400, "Bad request: Unknown sort function"))
    end
end

function apply_sort_ta_stock_function(
    temp_portfolio_vectors::Vector{Vector{DayData}},
    date_range::Vector{String},
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    total_days::Int,
    sort_function::String,
    sort_window::Int,
    indicator_cache::Dict{String,Vector{Float32}},
    live_execution::Bool=false,
)::Tuple{Vector{Vector{Float64}},Int}
    branch_metrics::Vector{Vector{Float64}} = Vector{Vector{Float64}}(
        undef, length(temp_portfolio_vectors)
    )
    branch_data_length::Vector{Int} = Vector{Int}(undef, length(temp_portfolio_vectors))

    for (branch_idx, branch_portfolio_history) in enumerate(temp_portfolio_vectors)
        float32_metrics, branch_data_length[branch_idx] = calculate_ta_stock_metrics(
            branch_portfolio_history,
            date_range,
            end_date,
            price_cache,
            total_days,
            sort_function,
            sort_window,
            indicator_cache,
            live_execution,
        )
        branch_metrics[branch_idx] = Vector{Float64}(float32_metrics)
    end
    return branch_metrics, minimum(branch_data_length)
end

end
