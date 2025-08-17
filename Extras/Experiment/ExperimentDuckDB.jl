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
        @warn "Parquet file not found: $parquet_file_path"
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
    INITIAL_DELAY = 0.5  # seconds

    for attempt in 1:MAX_RETRIES
        try
            result = DuckDB.execute(db_con, query)
            df = DataFrame(result)

            # Convert the date column from String to Date type
            df.date = Date.(df.date, dateformat"yyyy-mm-dd")

            if length(df.date) >= length_data
                return reverse!(df)
            end
        catch e
            if attempt == MAX_RETRIES
                @error "Error reading from DuckDB after $MAX_RETRIES attempts: $e"
                return nothing
            elseif e isa Union{DuckDB.ConnectionException,DuckDB.QueryException}
                delay = INITIAL_DELAY * (2^(attempt - 1))  # Exponential backoff
                @warn "Attempt $attempt failed. Retrying in $delay seconds..."
                sleep(delay)
            else
                @error "Unexpected error: $e"
                return nothing
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
        cached_data = read_parquet_with_duckdb(
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
