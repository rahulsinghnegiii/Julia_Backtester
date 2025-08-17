module ReturnCalculations

using Dates, DataFrames
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.StockData
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.BacktestUtilites

export calculate_branch_return_curves,
    calculate_final_return_curve,
    process_single_day,
    process_single_branch,
    process_branches_return_curve

function process_branches_return_curve(
    temp_portfolio_vectors::Vector{Vector{DayData}},
    date_range::Vector{String},
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    total_days::Int,
    live_execution::Bool=false,
)::Tuple{Vector{Vector{Float64}},Vector{Int}}
    branch_return_curves::Vector{Vector{Float64}} = Vector{Vector{Float64}}(
        undef, length(temp_portfolio_vectors)
    )
    branch_data_lengths::Vector{Int} = fill(total_days, length(temp_portfolio_vectors))
    # println("Branches: ", length(temp_portfolio_vectors))
    for (branch_index, branch_portfolio_history) in enumerate(temp_portfolio_vectors)
        branch_return_curve::Vector{Float64}, branch_min_data_length::Int = @time process_single_branch(
            branch_portfolio_history,
            date_range,
            end_date,
            price_cache,
            total_days,
            live_execution,
        )
        # println("TIME TAKEN FOR BR")
        # println("Branch $branch_index: ", branch_min_data_length)

        branch_data_lengths[branch_index] = branch_min_data_length
        branch_return_curves[branch_index] = branch_return_curve
    end

    return branch_return_curves, branch_data_lengths
end

function collect_unique_tickers(branch_portfolio_history::Vector{DayData})::Set{String}
    unique_tickers = Set{String}()

    for day_data in branch_portfolio_history
        for stock in day_data.stockList
            push!(unique_tickers, stock.ticker)
        end
    end

    return unique_tickers
end

# Function to find the data range for a specific ticker
function find_ticker_data_range(
    price_data::DataFrame, date_range::Vector{String}
)::Tuple{Int,Int}
    # Default to maximum possible range
    start_idx = 1
    end_idx = length(date_range)

    # Find the actual start and end dates in the price data
    if :date in propertynames(price_data) && size(price_data, 1) > 0
        # Convert dates to strings for comparison
        price_dates = string.(price_data.date)

        # Find the earliest date in price_data that's also in date_range
        for (i, date) in enumerate(date_range)
            if date in price_dates
                start_idx = i
                break
            end
        end

        # Find the latest date in price_data that's also in date_range
        for i in length(date_range):-1:1
            if date_range[i] in price_dates
                end_idx = i
                break
            end
        end
    end

    return (start_idx, end_idx)
end

# Function to determine the available data range for each ticker
function determine_ticker_data_ranges(
    unique_tickers::Set{String},
    date_range::Vector{String},
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    live_execution::Bool=false,
)::Dict{String,Tuple{Int,Int}}
    ticker_data_ranges = Dict{String,Tuple{Int,Int}}()

    for ticker in unique_tickers
        # Get the price data for the entire date range
        price_data = get_cached_value_df(
            ticker,
            price_cache,
            Date(date_range[1]),
            Date(date_range[end]),
            () -> get_price_dataframe(ticker, length(date_range), end_date, live_execution),
        )

        # Determine the available data range for this ticker
        if size(price_data, 1) >= 2
            # Find the start and end indices where this ticker has data
            start_idx, end_idx = find_ticker_data_range(price_data, date_range)
            ticker_data_ranges[ticker] = (start_idx, end_idx)
        else
            # If no data is available, use a default range that will be filtered out
            ticker_data_ranges[ticker] = (length(date_range), 0)
        end
    end

    return ticker_data_ranges
end

function find_common_data_range(
    ticker_data_ranges::Dict{String,Tuple{Int,Int}}
)::Tuple{Int,Int}
    if isempty(ticker_data_ranges)
        return (0, 1)  # No data available
    end

    # Initialize with extreme values
    latest_start = 1
    earliest_end = typemax(Int)

    # Find the latest start and earliest end across all tickers
    for (_, (start_idx, end_idx)) in ticker_data_ranges
        latest_start = max(latest_start, start_idx)
        earliest_end = min(earliest_end, end_idx)
    end

    # Calculate the actual data length
    actual_data_length = max(0, earliest_end - latest_start + 1)

    return (actual_data_length, latest_start)
end
function process_single_branch(
    branch_portfolio_history::Vector{DayData},
    date_range::Vector{String},
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    total_days::Int,
    live_execution::Bool=false,
)::Tuple{Vector{Float64},Int}
    try
        unique_tickers = collect_unique_tickers(branch_portfolio_history)

        # Determine the available data range for each ticker
        ticker_data_ranges = determine_ticker_data_ranges(
            unique_tickers, date_range, end_date, price_cache, live_execution
        )

        # Find the common data range across all tickers
        actual_data_length, start_index = find_common_data_range(ticker_data_ranges)
        # println(
        #     "Common data range in branch return curves: $actual_data_length, $start_index"
        # )
        branch_return_curve::Vector{Float64} = zeros(Float64, total_days)
        min_data_length::Int = min(total_days, actual_data_length)
        # println("Total days: ", total_days, " Actual data length: ", actual_data_length)
        # println("Date range: ", length(date_range))
        # # Skip first and last day as we can't calculate return for them as we don't have data for the next day and we are not holding any stocks on the last day
        for day_index in (total_days - actual_data_length + 1):(total_days - 1)
            daily_return::Float64, all_stocks_have_data::Bool, updated_min_data_length::Int = process_single_day(
                branch_portfolio_history[day_index].stockList,
                date_range,
                day_index,
                end_date,
                price_cache,
                min_data_length,
                total_days,
                live_execution,
            )

            if all_stocks_have_data
                # println(
                #     "Day $day_index: ",
                #     daily_return,
                #     " ",
                #     all_stocks_have_data,
                #     " ",
                #     updated_min_data_length,
                # )
                branch_return_curve[day_index + 1] = round(daily_return; digits=6)
            end

            min_data_length = min(min_data_length, updated_min_data_length)
        end

        return branch_return_curve, min_data_length
    catch e
        @error "Error in process_single_branch" exception = (e, catch_backtrace())
        rethrow(e)
    end
end

function process_single_day(
    stock_list::Vector{StockInfo},
    date_range::Vector{String},
    day_index::Int,
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    min_data_length::Int,
    total_days::Int,
    live_execution::Bool=false,
)::Tuple{Float64,Bool,Int}
    daily_return::Float64 = 0.0f0
    all_stocks_have_data::Bool = true

    for stock in stock_list
        price_data::DataFrame = DataFrame()
        # #println("Date range: ", date_range[day_index], " ", date_range[day_index + 1])
        price_data = get_cached_value_df(
            stock.ticker,
            price_cache,
            Date(date_range[day_index]),
            Date(date_range[day_index + 1]),
            () -> get_price_dataframe(
                stock.ticker, total_days, Date(date_range[end]), live_execution
            ),
        )

        # TODO: Figure out a way to make this work with 1 day backtest
        if size(price_data.original_length, 1) > 0
            min_data_length = min(min_data_length, price_data.original_length[1])
        end

        if size(price_data, 1) >= 2
            stock_return::Float64 =
                (price_data[2, :adjusted_close] - price_data[1, :adjusted_close]) /
                price_data[1, :adjusted_close]
            if isnan(stock.weightTomorrow)
                stock.weightTomorrow = 0.0f0
            end
            daily_return += stock_return * stock.weightTomorrow
        else
            all_stocks_have_data = false
            break
        end
    end
    daily_return = daily_return * 100

    return daily_return, all_stocks_have_data, min_data_length
end

# TODO: enforce local variable types
# TODO: try to recycle/combine this code with root retrun-curve
function calculate_branch_return_curves(
    temp_portfolio_vectors::Vector{Vector{DayData}},
    date_range::Vector{String},
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    total_days::Int,
    sort_function::String,
    cached_mapping::Dict{String,Float64}=Dict{String,Float64}(),
    live_execution::Bool=false,
)::Tuple{Vector{Vector{Float64}},Int}
    try
        branch_return_curves::Vector{Vector{Float64}}, branch_data_lengths::Vector{Int} = process_branches_return_curve(
            temp_portfolio_vectors,
            date_range,
            end_date,
            price_cache,
            total_days,
            live_execution,
        )
        # println("branch_data_lengths: ", branch_data_lengths)
        common_data_length::Int = minimum(branch_data_lengths)
        # trim all branches to common time
        truncated_return_curves::Vector{Vector{Float64}} = truncate_to_common_period(
            branch_return_curves, common_data_length
        )
        portfolio_values::Vector{Vector{Float64}} = calculate_portfolio_values(
            truncated_return_curves, common_data_length, sort_function, cached_mapping
        )
        return portfolio_values, common_data_length
    catch e
        @error "Error in calculate_branch_return_curves" exception = (e, catch_backtrace())
        rethrow(e)
    end
end

function calculate_final_return_curve_global(
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    total_days::Int,
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    yesterday_profile_history::DayData,
    global_cache_present::Bool=false,
    live_execution::Bool=false,
)::Vector{Float32}
    # TODO: pushfirst is really slow
    pushfirst!(portfolio_history, yesterday_profile_history)
    date_range = populate_dates(total_days + 1, end_date, String[], live_execution)
    daily_returns::Vector{Float32} = zeros(Float32, length(date_range))
    for day_index in 1:(length(portfolio_history) - 1)
        current_day::DayData = portfolio_history[day_index]
        if day_index > length(date_range)
            break
        end

        # Calculate returns using aggregated weights
        for stock in current_day.stockList
            stock.ticker = map_ticker(stock.ticker)
            # Get cached prices if available, else get dataframe from parquet/api
            price_data::DataFrame = get_cached_value_df(
                stock.ticker,
                price_cache,
                Date(date_range[day_index]),    # Current day on which we are holding the stock
                Date(date_range[day_index + 1]),   # Next day on which we are selling the stock
                () ->
                    get_price_dataframe(stock.ticker, total_days, end_date, live_execution),
            )
            # For debugging

            if size(price_data, 1) < 2
                # remove that day from the curve
                @warn "Stock $(stock.ticker) has no data on $(date_range[day_index])"
                if day_index > 1
                    daily_returns[day_index + 1] = daily_returns[day_index]
                else
                    daily_returns[day_index + 1] = 0
                end
                continue
            end
            # println(
            #     "Day $day_index => ",
            #     date_range[day_index],
            #     " buying ",
            #     stock.weightTomorrow * 100,
            #     "% ",
            #     stock.ticker,
            #     " at ",
            #     price_data[1, "adjusted_close"],
            #     " and selling at ",
            #     price_data[2, "adjusted_close"],
            # )
            stock_return::Float32 =
                (price_data[2, "adjusted_close"] - price_data[1, "adjusted_close"]) /
                price_data[1, "adjusted_close"]

            weighted_stock_return::Float32 = stock_return * stock.weightTomorrow
            daily_returns[day_index + 1] += weighted_stock_return
        end
    end
    popfirst!(portfolio_history)
    return daily_returns[2:end]
end

function calculate_final_return_curve(
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    total_days::Int,
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    yesterday_profile_history::DayData,
    global_cache_present::Bool=false,
    live_execution::Bool=false,
)::Vector{Float32}
    try
        # println("Global cache present: ", global_cache_present)
        if global_cache_present
            return calculate_final_return_curve_global(
                portfolio_history,
                date_range,
                total_days,
                end_date,
                price_cache,
                yesterday_profile_history,
                global_cache_present,
                live_execution,
            )
        end
        daily_returns::Vector{Float32} = zeros(Float32, length(portfolio_history))
        for day_index in 1:(length(portfolio_history) - 1)
            current_day::DayData = portfolio_history[day_index]
            if day_index > length(date_range)
                break
            end

            # Calculate returns using aggregated weights
            for stock in current_day.stockList
                stock.ticker = map_ticker(stock.ticker)
                # Get cached prices if available, else get dataframe from parquet/api
                price_data::DataFrame = get_cached_value_df(
                    stock.ticker,
                    price_cache,
                    Date(date_range[day_index]),    # Current day on which we are holding the stock
                    Date(date_range[day_index + 1]),   # Next day on which we are selling the stock
                    () -> get_price_dataframe(
                        stock.ticker, total_days, end_date, live_execution
                    ),
                )
                # For debugging

                if size(price_data, 1) < 2
                    # remove that day from the curve
                    @warn "Stock $(stock.ticker) has no data on $(date_range[day_index])"
                    if day_index > 1
                        daily_returns[day_index + 1] = daily_returns[day_index]
                    else
                        daily_returns[day_index + 1] = 0
                    end
                    continue
                end
                # println(
                #     "On ",
                #     date_range[day_index],
                #     " buying ",
                #     stock.weightTomorrow * 100,
                #     "% ",
                #     stock.ticker,
                #     " at ",
                #     price_data[1, "adjusted_close"],
                #     " and selling at ",
                #     price_data[2, "adjusted_close"],
                # )
                stock_return::Float32 =
                    (price_data[2, "adjusted_close"] - price_data[1, "adjusted_close"]) /
                    price_data[1, "adjusted_close"]

                weighted_stock_return::Float32 = stock_return * stock.weightTomorrow
                daily_returns[day_index + 1] += weighted_stock_return
            end
        end
        return daily_returns
    catch e
        throw(
            ServerError(
                400, "Internal server error: Failed to calculate final return curve  $(e)"
            ),
        )
    end
end

end
