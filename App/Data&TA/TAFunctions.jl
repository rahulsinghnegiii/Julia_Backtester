
module MarketTechnicalsIndicators

using HTTP
using JSON
using Dates
using Glob
using Parquet
using Parquet2
using TimeSeries
using Statistics
using Base.Filesystem
using MarketTechnicals
using DuckDB, DataFrames
using ..VectoriseBacktestService
using .VectoriseBacktestService.StockData
using .VectoriseBacktestService.StockData.StockDataUtils
using .VectoriseBacktestService.StockData.DatabaseManager

export get_sd,
    get_rsi,
    get_ema,
    get_sma,
    get_sd_returns,
    get_sd_of_data,
    get_sma_returns,
    get_ema_of_data,
    get_sma_of_data,
    get_rsi_of_data,
    get_trading_days,
    get_max_drawdown,
    write_to_parquet,
    get_cumulative_return,
    get_sd_return_of_data,
    calculate_max_drawdown,
    get_sma_returns_of_data,
    get_max_drawdown_of_data,
    read_parquet_with_duckdb,
    get_cumulative_return_of_data,
    calculate_daily_returns_data_f32,
    calculate_market_cap_weighting_f32,
    calculate_inverse_volatility_data_f32,
    calculate_inverse_volatility_for_data_f32

function write_to_parquet(
    values,
    indicator_name,
    ticker,
    length_data,
    period,
    end_date,
    dates,
    parquet_file_path,
    live_data=false,
)
    range_end = live_data ? (length(values) - 1) : length(values)

    df = DataFrame(;
        indicator_name=fill(indicator_name, range_end),
        ticker=fill(ticker, range_end),
        period=fill(period, range_end),
        date=String.(dates[1:range_end]),
        value=Float64.(values[1:range_end]),
    )

    max_retries = 3
    retry_count = 0

    while retry_count < max_retries
        try
            # Extract the directory from the file path
            parquet_dir = dirname(parquet_file_path)

            # Check if the directory exists, and create it if it doesn't
            if !isdir(parquet_dir)
                mkpath(parquet_dir)
                @info "Directory created: $parquet_dir"
            end

            # Write the DataFrame to a Parquet file
            Parquet2.writefile(parquet_file_path, df)

            @info "Saved data to Parquet for $(indicator_name)_$(ticker)_$(period) up to $(end_date)"
            return true
        catch e
            @error "Error writing to Parquet: $e"
            retry_count += 1
            if retry_count < max_retries
                @warn "Retrying... (Attempt $(retry_count + 1) of $max_retries)"
                sleep(2^retry_count)  # Exponential backoff
            else
                @error "Failed to write data after $max_retries attempts"
                return false
            end
        end
    end
    return false
end

function read_parquet_with_duckdb(
    indicator_name::String,
    ticker::String,
    length_data::Int,
    period::Int,
    end_date::Date,
    parquet_file_path::String,
)::Union{DataFrame,Nothing}

    # check if the file exists
    if !isfile(parquet_file_path)
        return nothing
    end

    query = """
    SELECT date, value
    FROM read_parquet('$parquet_file_path')
    WHERE indicator_name = '$indicator_name'
      AND ticker = '$ticker'
      AND period = '$period'
      AND date <= '$end_date'
    ORDER BY date DESC
    LIMIT '$length_data'
    """

    MAX_RETRIES = 3

    # Get thread-local connection
    db_conn = DatabaseManager.get_thread_connection()

    for attempt in 1:MAX_RETRIES
        try
            result = DuckDB.execute(db_conn, query)
            df = DataFrame(result)

            # Convert the date column from String to Date type
            df.date = Date.(df.date, dateformat"yyyy-mm-dd")
            df = reverse!(df)
            return @view(df[max(1, end - length_data + 1):end, :])
        catch e
            if attempt == MAX_RETRIES
                @error "Error reading from DuckDB after $MAX_RETRIES attempts: $e" exception = (
                    e, catch_backtrace()
                )
                return nothing
            elseif e isa Union{DuckDB.ConnectionException,DuckDB.QueryException}
                @warn "Retrying... (Attempt $attempt of $MAX_RETRIES)"
                sleep(0.5 * (2^(attempt - 1)))  # Exponential backoff
            else
                @error "Unexpected error: $e"
                return nothing
            end
        end
    end

    return nothing
end

function get_rsi(
    ticker::String, length_data::Int, period::Int, end_date::Date, live_data::Bool=false
)::Union{Vector{Float32},Nothing}
    try
        # Step 1: Try to read from cache
        cached_data = read_parquet_with_duckdb(
            "rsi",
            ticker,
            length_data,
            period,
            end_date,
            "./IndicatorData/rsi_$(ticker)_$(period)_$(end_date).parquet",
        )
        if !isnothing(cached_data)
            return cached_data.value
        end

        # Step 2: Fetch stock data
        df = get_historical_stock_data_parquet_till_end_date(ticker, end_date, live_data)
        isempty(df) && error("No stock data available for $ticker")

        # Step 3: Prepare time series data
        df.date = Date.(df.date)
        df.adjusted_close = Float64.(df.adjusted_close)

        time_series_data = TimeArray(
            df[:, :date], df[:, :adjusted_close], [:adjusted_close]
        )

        # Step 4: Calculate RSI
        rsi_values = MarketTechnicals.rsi(time_series_data, period; wilder=true)

        # Step 5: Prepare data for storage and return
        rsi_matrix = values(rsi_values)
        rsi_dates = timestamp(rsi_values)

        # Step 6: Store in cache
        date_strings = Vector{String}(undef, length(rsi_dates))
        if !isempty(rsi_dates)
            date_strings = string.(rsi_dates)
        end
        if live_data
            file_path = "./IndicatorData/rsi_$(ticker)_$(period)_$(date_strings[end - 1]).parquet"
        else
            file_path = "./IndicatorData/rsi_$(ticker)_$(period)_$(end_date).parquet"
        end
        write_to_parquet(
            vec(rsi_matrix),
            "rsi",
            ticker,
            length_data,
            period,
            end_date,
            date_strings,
            file_path,
            live_data,
        )
        # Step 7: Return the requested length of data
        return @view(rsi_matrix[max(1, end - length_data + 1):end])
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_rsi: " * e.msg))
        else
            throw(error("Error in get_rsi"))
        end
    end
end

function get_ema_of_data(return_curve::Vector{Float64}, window::Int)
    try
        if length(return_curve) < window + 1
            throw(
                ArgumentError(
                    "error: Length of return curve must be greater than window size + 1"
                ),
            )
        end

        # Create a vector of dates
        end_date = Dates.today()
        dates = [
            end_date - Dates.Day(length(return_curve) - i) for i in 1:length(return_curve)
        ]
        time_series_data = TimeArray(dates, return_curve, [:close])

        ema_values = MarketTechnicals.ema(time_series_data, window; wilder=false)

        # Pad the beginning with NaNs to match the length of the input
        full_ema = Vector{Float64}(undef, length(return_curve))
        full_ema[1:window] .= NaN64
        full_ema[(window):end] = values(ema_values)

        return full_ema
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_ema_of_data: " * e.msg))
        else
            throw(error("Error in get_ema_of_data"))
        end
    end
end

function get_sma_returns_of_data(price_curve::Vector{Float64}, period::Int)
    try
        if length(price_curve) < period + 2  # We need at least period + 2 points to calculate returns and then SMA
            throw(
                ArgumentError(
                    "Error: Length of price curve must be greater than period + 2"
                ),
            )
        end

        # Calculate returns
        daily_returns = 100 * diff(price_curve) ./ price_curve[1:(end - 1)]

        n = length(daily_returns)

        # Create a vector of dates
        end_date = Dates.today()
        dates = [end_date - Dates.Day(n - i) for i in 1:n]

        # Create a TimeArray with the calculated dates
        returns_time_series_data = TimeArray(dates, daily_returns, [:returns])

        # Calculate SMA using MarketTechnicals
        sma_returns_values = MarketTechnicals.sma(returns_time_series_data, period)

        # Convert the result to a vector
        sma_returns = Vector{Float64}(undef, n)
        sma_returns[1:(period - 1)] .= NaN64
        sma_returns[period:end] = values(sma_returns_values)

        return sma_returns
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_sma_returns_of_data: " * e.msg))
        else
            throw(error("Error in get_sma_returns_of_data"))
        end
    end
end

function get_sma_of_data(return_curve::Vector{Float64}, window::Int)
    try
        if length(return_curve) < window + 1
            throw(
                ArgumentError(
                    "Error: Length of return curve must be greater than window size + 1"
                ),
            )
        end

        # Create a vector of dates
        end_date = Dates.today()
        dates = [
            end_date - Dates.Day(length(return_curve) - i) for i in 1:length(return_curve)
        ]
        time_series_data = TimeArray(dates, return_curve, [:close])

        sma_values = MarketTechnicals.sma(time_series_data, window)

        # Pad the beginning with NaNs to match the length of the input
        full_sma = Vector{Float64}(undef, length(return_curve))
        full_sma[1:window] .= NaN64
        full_sma[(window):end] = values(sma_values)

        return full_sma
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_sma_of_data: " * e.msg))
        else
            throw(error("Error in get_sma_of_data"))
        end
    end
end

#FIXME: Find a way to calculate RSI and EMA without recursion
function get_rsi_of_data(return_curve::Vector{Float64}, window::Int)
    try
        if length(return_curve) < window + 1
            throw(
                ArgumentError(
                    "Error: Length of return curve must be greater than window size + 1"
                ),
            )
        end

        # Create a vector of dates
        end_date = Dates.today()
        dates = [
            end_date - Dates.Day(length(return_curve) - i) for i in 1:length(return_curve)
        ]
        time_series_data = TimeArray(dates, return_curve, [:close])

        rsi_values = MarketTechnicals.rsi(time_series_data, window; wilder=true)

        # Pad the beginning with NaNs to match the length of the input
        full_rsi = Vector{Float64}(undef, length(return_curve))
        full_rsi[1:window] .= NaN64
        full_rsi[(window + 1):end] = values(rsi_values)

        return full_rsi
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_rsi_of_data: " * e.msg))
        else
            throw(error("Error in get_rsi_of_data"))
        end
    end
end

function get_sma(
    ticker::String, length_data::Int, period::Int, end_date::Date, live_data::Bool=false
)::Union{Vector{Float32},Nothing}
    try
        df = read_parquet_with_duckdb(
            "sma",
            ticker,
            length_data,
            period,
            end_date,
            "./IndicatorData/sma_$(ticker)_$(period)_$(end_date).parquet",
        )
        if !isnothing(df)
            return df.value
        end

        df = get_historical_stock_data_parquet_till_end_date(ticker, end_date, live_data)
        df.date = Date.(df.date)
        df.adjusted_close = Float64.(df.adjusted_close)
        time_series_data = TimeArray(
            df[:, :date], df[:, :adjusted_close], [:adjusted_close]
        )

        sma_values = MarketTechnicals.sma(time_series_data, period)

        sma_matrix = values(sma_values)
        sma_dates = timestamp(sma_values)
        date_strings = string.(sma_dates)
        date_component = live_data ? date_strings[end - 1] : end_date
        file_path = "./IndicatorData/sma_$(ticker)_$(period)_$(date_component).parquet"

        write_to_parquet(
            vec(sma_matrix),
            "sma",
            ticker,
            length_data,
            period,
            end_date,
            date_strings,
            file_path,
            live_data,
        )

        return @view(sma_matrix[max(1, end - length_data + 1):end])
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_sma: " * e.msg))
        else
            throw(error("Error in get_sma"))
        end
    end
end

function get_ema(
    ticker::String, length_data::Int, period::Int, end_date::Date, live_data::Bool=false
)::Union{Vector{Float32},Nothing}
    try
        df = read_parquet_with_duckdb(
            "ema",
            ticker,
            length_data,
            period,
            end_date,
            "./IndicatorData/ema_$(ticker)_$(period)_$(end_date).parquet",
        )
        if !isnothing(df)
            return df.value
        end

        df = get_historical_stock_data_parquet_till_end_date(ticker, end_date, live_data)
        df.date = Date.(df.date)
        df.adjusted_close = Float64.(df.adjusted_close)
        time_series_data = TimeArray(
            df[:, :date], df[:, :adjusted_close], [:adjusted_close]
        )

        ema_values = MarketTechnicals.ema(time_series_data, period; wilder=false)

        ema_matrix = values(ema_values)
        ema_dates = timestamp(ema_values)
        date_strings = string.(ema_dates)

        date_component = live_data ? date_strings[end - 1] : end_date
        file_path = "./IndicatorData/ema_$(ticker)_$(period)_$(date_component).parquet"

        write_to_parquet(
            vec(ema_matrix),
            "ema",
            ticker,
            length_data,
            period,
            end_date,
            date_strings,
            file_path,
            live_data,
        )

        return @view(ema_matrix[max(1, end - length_data + 1):end])
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_ema: " * e.msg))
        else
            throw(error("Error in get_ema"))
        end
    end
end

function get_sma_returns(
    ticker::String, length_data::Int, period::Int, end_date::Date, live_data::Bool=false
)::Union{Vector{Float32},Nothing}
    try
        # Check cached data first
        df = read_parquet_with_duckdb(
            "smareturns",
            ticker,
            length_data,
            period,
            end_date,
            "./IndicatorData/smareturns_$(ticker)_$(period)_$(end_date).parquet",
        )
        if !isnothing(df)
            return df.value
        end

        # Get historical data
        df = get_historical_stock_data_parquet_till_end_date(ticker, end_date, live_data)

        # Remove the date conversion since df.date is already Date type
        # If you need to ensure date format, you can add a check instead:
        if !(eltype(df.date) <: Date)
            df.date = Date.(df.date)  # Simple conversion if needed
        end

        # Calculate daily returns
        daily_returns =
            100 * diff(df[:, :adjusted_close]) ./ df[1:(end - 1), :adjusted_close]

        # Create time series
        returns_dates = df.date[2:end]
        returns_time_series_data = TimeArray(returns_dates, daily_returns, [:returns])

        # Calculate SMA
        sma_returns_values = MarketTechnicals.sma(returns_time_series_data, period)

        # Extract values and dates
        sma_returns_matrix = values(sma_returns_values)
        sma_returns_dates = timestamp(sma_returns_values)
        date_strings = Dates.format.(sma_returns_dates, "yyyy-mm-dd")

        # Write to parquet
        write_to_parquet(
            vec(sma_returns_matrix),
            "smareturns",
            ticker,
            length_data,
            period,
            end_date,
            date_strings,
            "./IndicatorData/smareturns_$(ticker)_$(period)_$(end_date).parquet",
        )

        return @view(sma_returns_matrix[max(1, end - length_data + 1):end])
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_sma_returns: " * e.msg))
        else
            throw(error("Error in get_sma_returns: " * e))
        end
    end
end

function get_sd_returns(
    ticker::String, len::Int, period::Int, end_date::Date, live_data::Bool=false
)::Union{Vector{Float32},Nothing}
    try
        df = read_parquet_with_duckdb(
            "sdreturns",
            ticker,
            len,
            period,
            end_date,
            "./IndicatorData/sdreturns_$(ticker)_$(period)_$(end_date).parquet",
        )
        if !isnothing(df)
            return df.value
        end
        df = get_historical_stock_data_parquet_till_end_date(ticker, end_date, live_data)
        dates = df.date
        close_prices = parse_dataframe_into_list(df)
        # Calculate returns
        returns = diff(close_prices) ./ close_prices[1:(end - 1)]
        returns_sd_values = Float64[]
        #  # Set the first value to 0
        for i in period:length(returns)
            window = returns[(i - period + 1):i]
            mean = sum(window) / period
            # Use sample standard deviation formula (n-1 in denominator)
            variance = sum((x - mean)^2 for x in window) / (period - 1)
            push!(returns_sd_values, (sqrt(variance) * 100.0f0))
        end

        result_dates = dates[(period + 1):end]

        date_component = live_data ? string(result_dates[end - 1]) : end_date
        file_path = "./IndicatorData/sdreturns_$(ticker)_$(period)_$(date_component).parquet"

        write_to_parquet(
            returns_sd_values,
            "sdreturns",
            ticker,
            len,
            period,
            end_date,
            string.(result_dates),
            file_path,
            live_data,
        )

        # Ensure we return exactly 'len' values
        return returns_sd_values[max(1, end - len + 1):end]
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_sd_returns: " * e.msg))
        else
            throw(error("Error in get_sd_returns $e"))
        end
    end
end

function get_sd(
    ticker::String, len::Int, period::Int, end_date::Date, live_data::Bool=false
)::Union{Vector{Float32},Nothing}
    try
        df = read_parquet_with_duckdb(
            "sd",
            ticker,
            len,
            period,
            end_date,
            "./IndicatorData/sd_$(ticker)_$(period)_$(end_date).parquet",
        )
        if !isnothing(df)
            return df.value
        end

        df = get_historical_stock_data_parquet_till_end_date(ticker, end_date, live_data)
        dates = df.date
        close_prices = parse_dataframe_into_list(df)
        sd_values = Float64[]

        for i in period:length(close_prices)
            window = close_prices[(i - period + 1):i]
            mean = sum(window) / period
            # Use sample standard deviation formula (n-1 in denominator)
            variance = sum((x - mean)^2 for x in window) / (period - 1)
            push!(sd_values, sqrt(variance))
        end

        result_dates = dates[(period):end]

        date_component = live_data ? string(result_dates[end - 1]) : end_date
        file_path = "./IndicatorData/sd_$(ticker)_$(period)_$(date_component).parquet"

        write_to_parquet(
            sd_values,
            "sd",
            ticker,
            len,
            period,
            end_date,
            string.(result_dates),
            file_path,
            live_data,
        )

        # Ensure we return exactly 'len' values
        return sd_values[max(1, end - len + 1):end]
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_sd: " * e.msg))
        else
            throw(error("Error in get_sd"))
        end
    end
end

function get_sd_return_of_data(data::Vector{Float64}, period::Int)
    try
        if length(data) < period + 2  # We need at least period + 2 points to calculate returns and SD
            throw(
                ArgumentError("Error: Length of data must be greater than period size + 2")
            )
        end

        # Calculate returns
        returns = Vector{Float64}(undef, length(data) - 1)
        for i in 1:length(returns)
            returns[i] = (data[i + 1] - data[i]) / data[i]
        end

        sd_values::Vector{Float64} = fill(NaN64, length(data))

        for i in (period + 1):length(data)
            window = returns[(i - period):(i - 1)]
            mean = sum(window) / period
            variance = sum((x - mean)^2 for x in window) / (period - 1)
            sd_values[i] = sqrt(variance) * 100
        end

        return sd_values
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_sd_of_data: " * e.msg))
        else
            throw(error("Error in get_sd_of_data"))
        end
    end
end

function get_sd_of_data(data::Vector{Float64}, period::Int)
    try
        if length(data) < period + 1
            throw(
                ArgumentError(
                    "Error: Length of return curve must be greater than period size + 1"
                ),
            )
        end

        sd_values::Vector{Float64} = fill(NaN64, length(data))

        for i in period:length(data)
            window = data[(i - period + 1):i]
            mean = sum(window) / period
            variance = sum((x - mean)^2 for x in window) / (period - 1)
            sd_values[i] = sqrt(variance) * 100
        end

        return sd_values
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_sd_of_data: " * e.msg))
        else
            throw(error("Error in get_sd_of_data"))
        end
    end
end

function get_cumulative_return_of_data(data::Vector{Float64}, period::Int)::Vector{Float64}
    try
        cumulative_returns = Vector{Float64}(undef, length(data))
        fill!(view(cumulative_returns, 1:(period)), NaN64)

        for i in (period + 1):length(data)
            cumulative_return = (data[i] - data[i - period]) / data[i - period]
            cumulative_returns[i] = (cumulative_return * 100)
        end

        return cumulative_returns
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_cumulative_return_of_data: " * e.msg))
        else
            throw(error("Error in get_cumulative_return_of_data"))
        end
    end
end

function get_cumulative_return(
    ticker::String, len::Int, period::Int, end_date::Date, live_data::Bool=false
)::Union{Vector{Float32},Nothing}
    try
        df = read_parquet_with_duckdb(
            "cumulativereturn",
            ticker,
            len,
            period,
            end_date,
            "./IndicatorData/cumulativereturn_$(ticker)_$(period)_$(end_date).parquet",
        )
        if !isnothing(df)
            return df.value
        end

        df = get_historical_stock_data_parquet_till_end_date(ticker, end_date, live_data)
        dates_str = string.(df.date)
        prices = parse_dataframe_into_list(df)
        cumulative_returns = Float64[]
        for i in (period + 1):length(prices)
            cumulative_return = (prices[i] - prices[i - period]) / prices[i - period]
            push!(cumulative_returns, cumulative_return * 100)
        end
        dates_str = dates_str[(length(dates_str) - length(cumulative_returns) + 1):end]

        date_component = live_data ? dates_str[end - 1] : end_date
        file_path = "./IndicatorData/cumulativereturn_$(ticker)_$(period)_$(date_component).parquet"

        write_to_parquet(
            cumulative_returns,
            "cumulativereturn",
            ticker,
            len,
            period,
            end_date,
            dates_str,
            file_path,
            live_data,
        )

        return cumulative_returns[max(1, end - len + 1):end]
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_cumulative_return: " * e.msg))
        else
            throw(error("Error in get_cumulative_return"))
        end
    end
end

function calculate_max_drawdown(prices::Union{Vector{Float64},Vector{Float32}})
    try
        """
        Calculates the maximum drawdown from a vector of prices.
        """
        if isempty(prices)
            return 0.0
        end

        peak = prices[1]
        max_drawdown = 0.0

        for price in prices
            if price > peak
                peak = price
            else
                drawdown = (peak - price) / peak
                max_drawdown = max(max_drawdown, drawdown)
            end
        end
        return max_drawdown * 100
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in calculate_max_drawdown: " * e.msg))
        else
            throw(error("Error in calculate_max_drawdown"))
        end
    end
end

function get_max_drawdown(
    ticker::String, length_data::Int, period::Int, end_date::Date, live_data::Bool=false
)::Union{Vector{Float32},Nothing}
    try
        df = read_parquet_with_duckdb(
            "maxdrawdown",
            ticker,
            length_data,
            period,
            end_date,
            "./IndicatorData/maxdrawdown_$(ticker)_$(period)_$(end_date).parquet",
        )
        if !isnothing(df)
            return df.value
        end

        df = get_historical_stock_data_parquet_till_end_date(ticker, end_date, live_data)
        if isempty(df)
            error("No data available for the specified parameters.")
        end
        max_array = parse_dataframe_into_list(df)
        max_drawdown_value = [
            calculate_max_drawdown(max_array[(i - period + 1):i]) for
            i in period:length(max_array)
        ]

        dates_str = string.(df.date[(length(df.date) - length(max_drawdown_value) + 1):end])

        date_component = live_data ? dates_str[end - 1] : end_date
        file_path = "./IndicatorData/maxdrawdown_$(ticker)_$(period)_$(date_component).parquet"

        write_to_parquet(
            max_drawdown_value,
            "maxdrawdown",
            ticker,
            length_data,
            period,
            end_date,
            dates_str,
            file_path,
            live_data,
        )

        return max_drawdown_value[max(1, end - length_data + 1):end]
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_max_drawdown: " * e.msg))
        else
            throw(error("Error in get_max_drawdown"))
        end
    end
end
function get_max_drawdown_of_data(data::Vector{Float64}, period::Int)
    try
        if length(data) < period + 1
            throw(
                ArgumentError(
                    "error: Length of return curve must be greater than period size + 1"
                ),
            )
        end

        max_drawdown_value = [
            calculate_max_drawdown(data[(i - period + 1):i]) for i in period:length(data)
        ]
        # add nan values to the beginning of the array to match the length of the input
        max_drawdown_value = vcat(fill(NaN64, period - 1), max_drawdown_value)

        return max_drawdown_value
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_max_drawdown_of_data: " * e.msg))
        else
            throw(error("Error in get_max_drawdown_of_data"))
        end
    end
end

function get_trading_days(
    ticker::String, start_date::Date, end_date::Date, live_data::Bool=false
)
    try
        stock_data = get_stock_data_dataframe_start_end(
            ticker, start_date, end_date, live_data
        )

        if isa(stock_data, DataFrame)
            num_days = nrow(stock_data)
            #println("Number of trading days: $num_days")
            return num_days >= 1 ? num_days - 1 : 0
        end

        num_days = length(stock_data)
        return num_days >= 1 ? num_days - 1 : 0
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_trading_days: " * e.msg))
        else
            throw(error("Error in get_trading_days"))
        end
    end
end

function calculate_daily_returns_data_f32(values::Vector{Float64})
    try
        if any(values .== 0)
            throw(
                ErrorException(
                    "Error: Division by zero encountered in daily returns calculation"
                ),
            )
        end
        daily_return = [NaN; diff(values) ./ values[1:(end - 1)]]
        return daily_return
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in calculate_daily_returns_data_f32: " * e.msg))
        else
            throw(error("Error in calculate_daily_returns_data_f32"))
        end
    end
end

function calculate_inverse_volatility_data_f32(
    values::Vector{Float64}, lookback_period::Int
)
    try
        # Validation for lookback period
        if lookback_period <= 0
            throw(ArgumentError("Error: Lookback period must be greater than zero"))
        end
        # Calculate daily returns
        daily_returns = calculate_daily_returns_data_f32(values)
        # Calculate inverse standard deviation
        inv_std_dev = vcat(
            fill(NaN, lookback_period - 1),  # Fill the first rows with NaN
            1 ./ [
                std(daily_returns[max(1, i - lookback_period + 1):i]) for
                i in 1:length(daily_returns)
            ],
        )
        return inv_std_dev
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in calculate_inverse_volatility_data_f32: " * e.msg))
        else
            throw(error("Error in calculate_inverse_volatility_data_f32"))
        end
    end
end

function calculate_inverse_volatility_for_data_f32(
    data_vectors::Vector{Vector{Float64}}, dates::Vector{Date}, lookback_period::Int
)
    try
        if (lookback_period > length(dates))
            throw(
                ArgumentError(
                    "Error: Lookback period cannot be larger than the length of data"
                ),
            )
        end

        stock_volatilities = Dict{Date,Dict{String,Float64}}()
        for (i, values) in enumerate(data_vectors)
            ticker = string(i)  # Use the index as a unique identifier
            stock_data = calculate_inverse_volatility_data_f32(values, lookback_period)

            for j in lookback_period:length(stock_data)
                date = dates[j - (lookback_period - 1)]
                inv_vol = stock_data[j]
                if ismissing(inv_vol) || isnan(inv_vol)
                    continue
                end
                if !haskey(stock_volatilities, date)
                    stock_volatilities[date] = Dict{String,Float32}()
                end
                stock_volatilities[date][ticker] = inv_vol
            end
        end

        # Normalize inverse volatilities
        for (date, volatilities) in stock_volatilities
            sum_of_inverses = sum(values(volatilities))
            for (ticker, inv_vol) in volatilities
                stock_volatilities[date][ticker] = inv_vol / sum_of_inverses
            end
        end

        return stock_volatilities
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in calculate_inverse_volatility_for_data_f32: " * e.msg))
        else
            throw(error("Error in calculate_inverse_volatility_for_data_f32"))
        end
    end
end

function calculate_market_cap_weighting_f32(tree_market_caps::Dict{Any,Vector{Float32}})
    try
        # Collect keys from the input dict
        branches::Vector{String} = collect(keys(tree_market_caps))

        # Dict to store final values
        weights::Dict{Any,Vector{Float32}} = Dict{Any,Vector{Float32}}()

        # Initialize weights
        for branch in branches
            weights[branch] = []
        end

        # For trimming
        min_length::Int = typemax(Int)

        for branch in branches
            if length(tree_market_caps[branch]) < min_length
                min_length = length(tree_market_caps[branch])
            end
        end

        for branch in branches
            tree_market_caps[branch] = tree_market_caps[branch][(end - min_length + 1):end]
        end

        # Calculate weights
        for i in 1:length(tree_market_caps[branches[1]])
            total_market_cap::Float32 = 0.0
            for branch in branches
                total_market_cap += tree_market_caps[branch][i]
            end

            for branch in branches
                push!(weights[branch], tree_market_caps[branch][i] / total_market_cap)
            end
        end

        return weights, min_length
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in calculate_market_cap_weighting_f32: " * e.msg))
        else
            throw(error("Error in calculate_market_cap_weighting_f32"))
        end
    end
end
end
