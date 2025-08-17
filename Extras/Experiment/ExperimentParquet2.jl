include("../Stock_Data.jl")

using .StockData
using TimeSeries
using MarketTechnicals
using Statistics
using Parquet2
using DuckDB
using DataFrames

function write_to_parquet(
    values, indicator_name, ticker, length_data, period, end_date, dates, parquet_file_path
)
    df = DataFrame(;
        indicator_name=fill(indicator_name, length(values)),
        ticker=fill(ticker, length(values)),
        period=fill(period, length(values)),
        date=String.(dates),
        value=Float64.(values),
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

function read_parquet_with_parquet2(
    indicator_name::String,
    ticker::String,
    length_data::Int,
    period::Int,
    end_date::Date,
    parquet_file_path::String,
)::Union{DataFrame,Nothing}

    # Check if the file exists
    if !isfile(parquet_file_path)
        @warn "Parquet file not found: $parquet_file_path"
        return nothing
    end

    MAX_RETRIES = 3
    INITIAL_DELAY = 0.5  # seconds

    for attempt in 1:MAX_RETRIES
        try
            # Read the Parquet file
            tbl = Parquet2.Dataset(parquet_file_path)
            df = DataFrame(tbl)

            # Filter the data
            filtered_df = filter(df) do row
                row.indicator_name == indicator_name &&
                    row.ticker == ticker &&
                    row.period == period &&
                    Date(row.date) <= end_date
            end

            # Sort by date in descending order
            sort!(filtered_df, :date; rev=true)

            # Limit to length_data
            if nrow(filtered_df) > length_data
                filtered_df = filtered_df[1:length_data, :]
            end

            # Convert the date column from String to Date type
            filtered_df.date = Date.(filtered_df.date, dateformat"yyyy-mm-dd")

            if nrow(filtered_df) >= length_data
                return reverse!(filtered_df)
            else
                return filtered_df
            end

        catch e
            if attempt == MAX_RETRIES
                @error "Error reading from Parquet file after $MAX_RETRIES attempts: $e"
                return nothing
            else
                delay = INITIAL_DELAY * (2^(attempt - 1))  # Exponential backoff
                @warn "Attempt $attempt failed. Retrying in $delay seconds..."
                sleep(delay)
            end
        end
    end

    @error "Failed to retrieve data after $MAX_RETRIES attempts"
    return nothing
end

function get_cached_value(
    cache::Dict{String,Vector{Float32}}, key::String, compute_func::Function
)::Vector{Float32}
    try
        if haskey(cache, key)
            return cache[key]
        else
            value = compute_func()
            cache[key] = value
            return value
        end
    catch e
        throw(
            error(
                "Internal server error: Failed to get cached value for $key and $compute_func and $e",
            ),
        )
    end
end

function calculate_rsi(ticker::String, length_data::Int, period::Int, end_date::Date)
    try
        # Step 1: Try to read from cache
        cached_data = read_parquet_with_parquet2(
            "rsi",
            ticker,
            length_data,
            period,
            end_date,
            "./IndicatorData/rsi_$(ticker)_$(length_data)_$(period)_$(end_date).parquet",
        )
        if !isnothing(cached_data)
            return cached_data.value
        end

        # Step 2: Fetch stock data
        df = get_stock_data_dataframe(ticker, length_data + period, end_date)
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

        write_to_parquet(
            vec(rsi_matrix),
            "rsi",
            ticker,
            length_data,
            period,
            end_date,
            date_strings,
            "./IndicatorData/rsi_$(ticker)_$(length_data)_$(period)_$(end_date).parquet",
        )
        # Step 7: Return the requested length of data
        return @view(rsi_matrix[max(1, end - length_data + 1):end])
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in calculate_rsi: " * e.msg))
        else
            throw(error("Error in calculate_rsi"))
        end
    end
end

function get_rsi(ticker::String, length_data::Int, period::Int, end_date::Date)
    return calculate_rsi(ticker, length_data, period, end_date)
end

function run_single_experiment(tickers, length_data, period, end_date)
    for _ in 1:5
        for i in 1:20
            get_rsi(tickers[i], length_data, period, end_date)
        end
    end
end

function run_experiments(n_experiments)
    for _ in 1:n_experiments
        @time run_single_experiment(tickers, 250, 1500, Date("2024-05-31"))
    end
end

# Main
db_con = DBInterface.connect(DuckDB.DB)

tickers = [
    "AAPL",
    "MSFT",
    "QQQ",
    "PSQ",
    "SPY",
    "SHY",
    "TSLA",
    "NVDA",
    "XOM",
    "AMZN",
    "UPRO",
    "BIL",
    "AMD",
    "TMF",
    "TLT",
    "SHV",
    "GLD",
    "UUP",
    "DBC",
    "XLP",
]

# warm-up call
run_experiments(1)

n_experiments = 10
run_experiments(n_experiments)
