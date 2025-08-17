module TA_Functions_V2

using Genie, Genie.Renderer.Json, Genie.Requests
using HTTP
using JSON
using DuckDB, DataFrames
using Dates
using Genie.Router
using MarketTechnicals
using TimeSeries
using Statistics
using Glob

# using .Stock_Data_V2
# include("Stock_Data.jl")

function safe_delete(file_path)
    for attempt in 1:5
        try
            GC.gc()  # Run the garbage collector before attempting to delete the file
            if isfile(file_path)
                rm(file_path; force=true)
                println("Deleted file: $file_path")
                return true
            end
        catch e
            println("Attempt $attempt: Failed to delete $file_path. Error: $e")
            sleep(1)  # Wait for 1 second before retrying
        end
    end
    println("Failed to delete $file_path after multiple attempts.")
    return false
end

function write_to_parquet(values, indicator_name, ticker, length, period, end_date, dates)
    # Create a DataFrame with named columns
    col_name = Symbol(indicator_name)
    df = DataFrame()
    df[!, col_name] = Float64.(values)
    df[!, :Date] = Date.(dates)

    # Convert Date column to String
    df[!, :Date] = string.(df[!, :Date])

    # Construct the file path for the new file
    parquet_file = "indicatordata/$(indicator_name)_$(ticker)_$(period)_$(end_date).parquet"

    # Pattern to find existing files with different end_dates
    pattern = "indicatordata/$(indicator_name)_$(ticker)_$(period)_*.parquet"

    # Find existing files that match the pattern
    existing_files = glob(pattern)

    # Determine the most recent file based on end_date comparison
    latest_file = nothing
    latest_date = Date("0000-01-01")

    for file in existing_files
        # Extract the end_date from the filename
        file_end_date_str = split(basename(file), '_')[end]
        file_end_date_str = replace(file_end_date_str, ".parquet" => "")
        file_end_date = Date(file_end_date_str)

        if file_end_date > latest_date
            latest_date = file_end_date
            latest_file = file
        end
    end

    combined_df = df  # Initialize combined_df with the new data

    # Read the most recent file if it exists
    if isnothing(latest_file)
        try
            existing_df = Parquet.read_parquet(latest_file)
            existing_df = DataFrame(existing_df)
            existing_df[!, :Date] = Date.(existing_df[!, :Date])

            # Append only new data points that do not already exist in the file
            combined_df = vcat(existing_df, df)
            combined_df = unique(combined_df, :Date)

            # Convert Date column to String before writing
            combined_df[!, :Date] = string.(combined_df[!, :Date])

            # Delete the old file
            safe_delete(latest_file)
        catch e
            println("Error reading file: $latest_file. Error: $e")
        end
    end

    # Save the combined DataFrame to a Parquet file
    try
        Parquet.write_parquet(parquet_file, combined_df)
        println("Saved new file: $parquet_file")
    catch e
        println("Failed to write Parquet file: $parquet_file. Error: $e")
    end

    return parquet_file
end

function read_from_parquet(indicator_name, ticker, length, period, end_date)
    # Construct the file path for the new file
    parquet_file = "indicatordata/$(indicator_name)_$(ticker)_$(period)_$(end_date).parquet"

    pattern = "indicatordata/$(indicator_name)_$(ticker)_$(period)_*.parquet"

    # Find existing files that match the pattern
    existing_files = glob(pattern)

    # Determine the action based on end_date comparison
    for file in existing_files
        # Extract the end_date from the filename
        file_end_date_str = split(file, '_')[end]
        file_end_date_str = replace(file_end_date_str, ".parquet" => "")
        file_end_date = Date(file_end_date_str)
        df = DataFrame()
        if end_date <= file_end_date
            try
                df = Parquet.read_parquet(file)
                df = DataFrame(df)
                df.Date = Date.(df.Date)
                df = df[df.Date .<= end_date, :]
                if nrow(df) >= length
                    df_copy = copy(df)
                    df = nothing
                    return df_copy[(nrow(df_copy) - length + 1):end, :]
                end
                return false
            catch e
                println("Error reading file: $file. Error: $e")
                return false
            end
        end
    end

    return false
end

function get_rsi(ticker, length, period, end_date)
    println("Getting RSI", ticker, length, period, end_date)
    df = read_from_parquet("rsi", ticker, length, period, end_date)
    if df != false
        println("Reading from parquet file")
        return df.rsi
    end
    df = get_stock_data_dataframe(ticker, length + period, Date(end_date))

    time_series_data = TimeArray(df[:, :date], df[:, :adjusted_close], [:adjusted_close])

    rsi_values = MarketTechnicals.rsi(time_series_data, period; wilder=true)

    rsi_matrix = reverse(values(rsi_values))
    # extract dates from the time series data
    rsi_dates = reverse(timestamp(rsi_values))
    # convert the dates to strings
    date_strings = string.(rsi_dates)
    # create a DataFrame with the dates and the RSI values
    println("Writing to parquet file", date_strings[1])
    write_to_parquet(vec(rsi_matrix), "rsi", ticker, length, period, end_date, date_strings)
    return vec(rsi_matrix)
end

function get_sma(ticker, length, period, end_date)
    df = read_from_parquet("sma", ticker, length, period, end_date)
    if df != false
        println("Reading from parquet file")
        return df.sma
    end

    df = get_stock_data_dataframe(ticker, length + period, end_date)

    time_series_data = TimeArray(df[:, :date], df[:, :adjusted_close], [:adjusted_close])

    sma_values = MarketTechnicals.sma(time_series_data, period)

    sma_matrix = reverse(values(sma_values))
    sma_dates = reverse(timestamp(sma_values))
    date_strings = string.(sma_dates)

    write_to_parquet(vec(sma_matrix), "sma", ticker, length, period, end_date, date_strings)
    return vec(sma_matrix)
end

function get_ema(ticker, length, period, end_date)
    df = read_from_parquet("ema", ticker, length, period, end_date)
    if df != false
        println("Reading from parquet file")
        return df.ema
    end

    df = get_stock_data_dataframe(ticker, length + period, end_date)

    time_series_data = TimeArray(df[:, :date], df[:, :adjusted_close], [:adjusted_close])

    ema_values = MarketTechnicals.ema(time_series_data, period; wilder=false)

    ema_matrix = reverse(values(ema_values))
    ema_dates = reverse(timestamp(ema_values))
    date_strings = string.(ema_dates)

    write_to_parquet(vec(ema_matrix), "ema", ticker, length, period, end_date, date_strings)

    return vec(ema_matrix)
end

function get_sma_returns(ticker, length, period, end_date)
    df = read_from_parquet("smareturns", ticker, length, period, end_date)
    if df != false
        println("Reading from parquet file")
        return df.smareturns
    end

    df = get_stock_data_dataframe(ticker, length + period, end_date)

    daily_returns = 100 * diff(df[:, :adjusted_close]) ./ df[1:(end - 1), :adjusted_close]

    returns_time_series_data = TimeArray(df[2:end, :date], daily_returns, [:returns])

    sma_returns_values = MarketTechnicals.sma(returns_time_series_data, period)

    sma_returns_matrix = reverse(values(sma_returns_values))
    sma_returns_dates = reverse(timestamp(sma_returns_values))
    date_strings = string.(sma_returns_dates)

    write_to_parquet(
        vec(sma_returns_matrix),
        "smareturns",
        ticker,
        length,
        period,
        end_date,
        date_strings,
    )

    return vec(sma_returns_matrix)
end

function get_sd_returns(ticker, len, period, end_date)
    df = read_from_parquet("sdreturns", ticker, len, period, end_date)
    if df != false
        println("Reading from parquet file")
        return df.sdreturns
    end

    df = get_stock_data_dataframe(ticker, len + period, end_date)
    dates_str = string.(df.date)

    close_prices = parse_dataframe_into_list(df)
    returns = 100 * diff(close_prices) ./ close_prices[1:(end - 1)]
    returns_sd_values = []

    for i in period:length(returns)
        window = returns[(i - period + 1):i]
        mean = sum(window) / period
        variance = sum((x - mean)^2 for x in window) / period
        push!(returns_sd_values, sqrt(variance))
    end

    if len > length(returns_sd_values)
        write_to_parquet(
            returns_sd_values,
            "sdreturns",
            ticker,
            len,
            period,
            end_date,
            reverse(dates_str),
        )
        return returns_sd_values
    else
        write_to_parquet(
            returns_sd_values[(end - len + 1):end],
            "sdreturns",
            ticker,
            len,
            period,
            end_date,
            reverse(dates_str[(end - len + 1):end]),
        )
        return returns_sd_values[(end - len + 1):end]
    end
end

function get_sd(ticker, len, period, end_date)
    df = read_from_parquet("sd", ticker, len, period, end_date)
    if df != false
        println("Reading from parquet file")
        return df.sd
    end

    df = get_stock_data_dataframe(ticker, len + period, end_date)
    dates_str = string.(df.date)
    close_prices = parse_dataframe_into_list(df)
    sd_values = []

    close_prices = reverse(close_prices)

    for i in period:length(close_prices)
        window = close_prices[(i - period + 1):i]
        mean = sum(window) / period
        variance = sum((x - mean)^2 for x in window) / period
        push!(sd_values, sqrt(variance))
    end

    if len > length(sd_values)
        return_values = reverse(sd_values)
        write_to_parquet(
            return_values, "sd", ticker, len, period, end_date, reverse(dates_str)
        )
        return return_values
    else
        return_values = reverse(sd_values[(end - len + 1):end])
        write_to_parquet(
            return_values,
            "sd",
            ticker,
            len,
            period,
            end_date,
            reverse(dates_str[(end - len + 1):end]),
        )
        return return_values
    end
end

function get_cumulative_return(ticker, len, period, end_date)
    df = read_from_parquet("cumulativereturn", ticker, len, period, end_date)
    if df != false
        println("Reading from parquet file")
        return df.cumulativereturn
    end

    df = get_stock_data_dataframe(ticker, len + period, end_date)
    dates_str = string.(df.date)
    prices = (parse_dataframe_into_list(df))
    cumulative_returns = Float64[]
    for i in period:length(prices)
        period_prices = prices[(i - period + 1):i]
        daily_returns = [
            period_prices[j + 1] / period_prices[j] - 1 for
            j in 1:(length(period_prices) - 1)
        ]
        cumulative_return = 1 - prod(1 .+ daily_returns)
        push!(cumulative_returns, cumulative_return * 100)
    end
    dates_str = dates_str[(length(dates_str) - length(cumulative_returns) + 1):end]
    dates_str = (dates_str)
    cumulative_returns = (cumulative_returns)
    write_to_parquet(
        cumulative_returns, "cumulativereturn", ticker, len, period, end_date, dates_str
    )
    return cumulative_returns
end

function calculate_max_drawdown(prices::Vector{Float64})
    """
    Calculates the maximum drawdown from a vector of prices.
    """
    # Calculate the running maximum of the prices
    running_max = accumulate(max, prices)

    # Calculate drawdowns as the ratio of current prices to the running maximum
    drawdowns = prices ./ running_max

    # Calculate the maximum drawdown
    max_drawdown_value = minimum(drawdowns) - 1

    return max_drawdown_value * 100
end

function get_max_drawdown(ticker, period, length_data, end_date)
    df = read_from_parquet("maxdrawdown", ticker, length_data, period, end_date)
    if df != false
        println("Reading from parquet file")
        return df.maxdrawdown
    end

    df = get_stock_data_dataframe(ticker, length_data + period, end_date)
    if isempty(df)
        error("No data available for the specified parameters.")
    end
    array = reverse(parse_dataframe_into_list(df))
    max_drawdown_value = reverse([
        calculate_max_drawdown(array[(i - period + 1):i]) for i in period:length(array)
    ])

    dates_str = reverse(
        string.(df.date[(length(df.date) - length(max_drawdown_value) + 1):end])
    )
    write_to_parquet(
        max_drawdown_value, "maxdrawdown", ticker, length_data, period, end_date, dates_str
    )

    return max_drawdown_value
end

function get_trading_days(ticker, start_date, end_date)
    stock_data = get_stock_data_dataframe_start_end(ticker, start_date, end_date)

    if isa(stock_data, DataFrame)
        num_days = nrow(stock_data)
        return num_days
    end

    num_days = length(stock_data)

    return num_days
end

function calculate_weights(data)
    date_sums = Dict{String,Float64}()
    weights = Dict{String,Dict{Int,Float64}}()
    for (branch_index, branch) in enumerate(data)
        for date_entry in branch
            for (date, value) in date_entry
                date_str = string(date)
                date_sums[date_str] = get(date_sums, date_str, 0) + value
                if !haskey(weights, date_str)
                    weights[date_str] = Dict{Int,Float64}()
                end
                weights[date_str][branch_index - 1] = value
            end
        end
    end
    for (date, branches) in weights
        for (branch_index, value) in branches
            weights[date][branch_index] = value / date_sums[date]
        end
    end

    return weights
end

function calculate_daily_returns(data::DataFrame)
    data[!, :daily_return] = [
        NaN
        diff(data.adjusted_close) ./ data.adjusted_close[1:(end - 1)]
    ]
    return data
end

function calculate_inverse_volatility(
    ticker::String, len::Int, end_date::Date, lookback_period::Int
)
    stock_data = get_stock_data_dataframe(ticker, len + lookback_period, end_date)
    stock_data = calculate_daily_returns(stock_data)
    stock_data[!, :Inv_Std_Dev] = vcat(
        [NaN for _ in 1:(lookback_period - 1)],
        [
            1 / std(stock_data.daily_return[(i - lookback_period + 1):i]) for
            i in lookback_period:length(stock_data.daily_return)
        ],
    )
    return stock_data
end

function calculate_inverse_volatility_for_stocks(
    stocklist::Vector{String}, len::Int, end_date::Date, lookback_period::Int
)
    stock_volatilities = Dict{Date,Dict{String,Float64}}()

    # Modified part: Use a counter to ensure uniqueness of tickers
    ticker_counter = Dict{String,Int}()
    for ticker in stocklist
        # Ensure each ticker is treated uniquely by appending a counter
        ticker_counter[ticker] = get(ticker_counter, ticker, 0) + 1
        unique_ticker = ticker * "#" * string(ticker_counter[ticker])

        stock_data = calculate_inverse_volatility(ticker, len, end_date, lookback_period)
        for i in lookback_period:length(stock_data.daily_return)
            date = stock_data.date[i]
            inv_vol = stock_data.Inv_Std_Dev[i]
            if ismissing(inv_vol) || isnan(inv_vol)
                continue
            end
            if !haskey(stock_volatilities, date)
                stock_volatilities[date] = Dict{String,Float64}()
            end
            stock_volatilities[date][unique_ticker] = inv_vol
        end
    end

    # Normalize inverse volatilities
    for (date, volatilities) in stock_volatilities
        sum_of_inverses = sum(values(volatilities))
        for (ticker, inv_vol) in volatilities
            stock_volatilities[date][ticker] = inv_vol / sum_of_inverses
        end
    end

    # Transform the dictionary for output, removing the unique identifier
    transformed_dict = Dict{Date,Vector{Dict{String,Any}}}()

    for (date, volatilities) in stock_volatilities
        ticker_values = [
            Dict("Ticker" => split(ticker, "#")[1], "Value" => value)  # Remove the unique identifier here
            for (ticker, value) in volatilities
        ]

        transformed_dict[date] = ticker_values
    end

    return transformed_dict
end

function calculate_daily_returns_data(values::Vector{Float64})
    if any(values .== 0)
        throw(ErrorException("Division by zero encountered in daily returns calculation"))
    end
    daily_return = [NaN; diff(values) ./ values[1:(end - 1)]]
    return daily_return
end

function calculate_inverse_volatility_data(values::Vector{Float64}, lookback_period::Int)
    # Calculate daily returns
    daily_returns = calculate_daily_returns_data(values)

    # Calculate inverse standard deviation
    inv_std_dev = vcat(
        fill(NaN, lookback_period - 1),  # Fill the first rows with NaN
        1 ./ [
            std(daily_returns[max(1, i - lookback_period + 1):i]) for
            i in 1:length(daily_returns)
        ],
    )

    return inv_std_dev
end

function calculate_inverse_volatility_for_data(
    data::Dict{Any,Vector{Float64}}, dates::Vector{Date}, lookback_period::Int
)
    stock_volatilities = Dict{Date,Dict{String,Float64}}()

    # Modified part: Use a counter to ensure uniqueness of tickers
    ticker_counter = Dict{String,Int}()
    for (key, values) in data
        # Ensure each ticker is treated uniquely by appending a counter
        ticker_counter[string(key)] = get(ticker_counter, string(key), 0) + 1
        unique_ticker = string(key) * "#" * string(ticker_counter[string(key)])

        stock_data = calculate_inverse_volatility_data(values, lookback_period)
        for i in lookback_period:length(stock_data)
            date = dates[i - (lookback_period - 1)]
            inv_vol = stock_data[i]
            if ismissing(inv_vol) || isnan(inv_vol)
                continue
            end
            if !haskey(stock_volatilities, date)
                stock_volatilities[date] = Dict{String,Float64}()
            end
            stock_volatilities[date][unique_ticker] = inv_vol
        end
    end

    # Normalize inverse volatilities
    for (date, volatilities) in stock_volatilities
        sum_of_inverses = sum(values(volatilities))
        for (ticker, inv_vol) in volatilities
            stock_volatilities[date][ticker] = inv_vol / sum_of_inverses
        end
    end

    # Transform the dictionary for output, removing the unique identifier
    transformed_dict = Dict{Date,Vector{Dict{String,Any}}}()

    for (date, volatilities) in stock_volatilities
        ticker_values = [
            Dict("Ticker" => split(ticker, "#")[1], "Value" => value)  # Remove the unique identifier here
            for (ticker, value) in volatilities
        ]

        transformed_dict[date] = ticker_values
    end

    return transformed_dict
end

# export all
for n in names(@__MODULE__; all=true)
    if Base.isidentifier(n) && n ∉ (Symbol(@__MODULE__), :eval, :include)
        @eval export $n
    end
end

end # end of module
