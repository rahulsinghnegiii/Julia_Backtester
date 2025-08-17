using TimeSeries
using MarketTechnicals
using Statistics
using Parquet2
using DuckDB
using DataFrames
using Dates
using TimeZones
using FilePathsBase

const MONDAY, THURSDAY, SATURDAY, SUNDAY = 1, 4, 6, 7
HOLIDAY_CACHE = Dict{Int,Vector{Date}}()
NY_TIMEZONE = tz"America/New_York"
DB = DBInterface.connect(DuckDB.DB)

function get_nth_weekday(year, month, day_of_week, n)
    try
        first_of_month = Date(year, month, 1)
        offset = day_of_week - Dates.dayofweek(first_of_month)
        offset = offset >= 0 ? offset : offset + 7
        return first_of_month + Dates.Day(offset + (n - 1) * 7)
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_nth_weekday: " * e.msg))
        else
            throw(error("Error in get_nth_weekday"))
        end
    end
end

function get_last_weekday(year, month, day_of_week)
    try
        last_of_month = Date(year, month, Dates.daysinmonth(year, month))
        offset = day_of_week - Dates.dayofweek(last_of_month)
        offset = offset <= 0 ? offset : offset - 7
        return last_of_month + Dates.Day(offset)
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_last_weekday: " * e.msg))
        else
            throw(error("Error in get_last_weekday"))
        end
    end
end

function adjust_holidays(year::Int)
    try
        get!(HOLIDAY_CACHE, year) do
            holidays = [
                Date(year, 1, 1),  # New Year's Day
                get_nth_weekday(year, 1, MONDAY, 3),  # Martin Luther King Jr. Day
                get_nth_weekday(year, 2, MONDAY, 3),  # Washington's Birthday
                get_last_weekday(year, 5, MONDAY),  # Memorial Day
                Date(year, 7, 4),  # Independence Day
                get_nth_weekday(year, 9, MONDAY, 1),  # Labor Day
                get_nth_weekday(year, 11, THURSDAY, 4),  # Thanksgiving Day
                Date(year, 12, 25),  # Christmas Day
            ]

            for (i, date) in enumerate(holidays)
                dow = Dates.dayofweek(date)
                holidays[i] = if dow == SATURDAY
                    date - Dates.Day(1)
                elseif dow == SUNDAY
                    date + Dates.Day(1)
                else
                    date
                end
            end

            return holidays
        end
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in adjust_holidays: " * e.msg))
        else
            throw(error("Error in adjust_holidays"))
        end
    end
end

function is_us_market_open(date::Date)
    try
        return !(
            Dates.dayofweek(date) in (SATURDAY, SUNDAY) ||
            date in adjust_holidays(Dates.year(date))
        )
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in is_us_market_open: " * e.msg))
        else
            throw(error("Error in is_us_market_open"))
        end
    end
end

function find_previous_business_day(date::Date, period::Int)
    try
        current_date = date
        days_to_subtract = period
        while days_to_subtract > 0
            current_date -= Dates.Day(1)
            if is_us_market_open(current_date)
                days_to_subtract -= 1
            end
        end
        return current_date
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in find_previous_business_day: " * e.msg))
        else
            throw(error("Error in find_previous_business_day"))
        end
    end
end

function find_valid_business_days(end_date::Date, period::Int)
    try
        start_date = find_previous_business_day(end_date, period)
        return start_date, end_date
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in find_valid_business_days: " * e.msg))
        else
            throw(error("Error in find_valid_business_days"))
        end
    end
end

function get_new_york_time_date()
    try
        return astimezone(ZonedDateTime(now(), localzone()), NY_TIMEZONE)
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_new_york_time_date: " * e.msg))
        else
            throw(error("Error in get_new_york_time_date"))
        end
    end
end

# bottom level function (parquet)
function get_historical_stock_data_parquet(
    ticker::String, period::Int, end_date::Date, tempdir
)::DataFrame
    try
        start_date, end_date = find_valid_business_days(end_date, period)

        # Construct the file path
        file_path = joinpath(tempdir, "$ticker.parquet")

        if isfile(file_path)
            try
                query = """
                SELECT adjusted_close, date
                FROM read_parquet('$file_path')
                WHERE date >= '$start_date' AND date <= '$end_date'
                """
                result = DuckDB.execute(DB, query)
                return DataFrame(result)
            catch e
                error("Error reading parquet file: $e")
                return DataFrame(; adjusted_close=Float64[], date=Date[])
            end
        else
            error("Error: File not found: $file_path")
            return DataFrame(; adjusted_close=Float64[], date=Date[])
        end
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_historical_stock_data_parquet: " * e.msg))
        else
            throw(error("Error in get_historical_stock_data_parquet"))
        end
    end
end

# mid level function (historical data, checks for parquet)
function get_historical_stock_data(ticker::String, period::Int, end_date::Date, tempdir)
    try
        # Construct the file path
        file_path = joinpath(tempdir, "$ticker.parquet")

        # Check if the file exists
        if isfile(file_path)
            historical_data = get_historical_stock_data_parquet(
                ticker, period, end_date, tempdir
            )
            return historical_data
        else
            error("Error: Stock data file not found for symbol $ticker at path: $file_path")
        end
    catch e
        error_msg = isa(e, ErrorException) ? e.msg : string(e)
        throw(ErrorException("Error in get_historical_stock_data: $error_msg"))
    end
end

# top level function (include checks for live data)
function get_stock_data_dataframe(ticker, period, end_date::Date, tempdir)
    try
        nyt_time = get_new_york_time_date()
        original_period = period
        period = convert(Int, round(period * 1.1))

        if Dates.day(nyt_time) == day(end_date) &&
            Dates.month(nyt_time) == month(end_date) &&
            Dates.year(nyt_time) == year(end_date)
            if is_us_market_open(end_date)
                if check_trading_hours(nyt_time)
                    live_data = get_live_data(ticker)
                    if period == 1
                        return live_data
                    else
                        live_data = get_live_data(ticker)
                        adjusted_end_date = end_date - Day(1)
                        adjusted_period = original_period - 1

                        df = get_historical_stock_data(
                            ticker, period, adjusted_end_date, tempdir
                        )
                        historical_data_return =
                            size(df, 1) > adjusted_period ? last(df, adjusted_period) : df

                        return combine_data(historical_data_return, live_data)
                    end
                end
            end
        end

        df = get_historical_stock_data(ticker, Number(period), end_date, tempdir)
        historical_data_return =
            size(df, 1) > original_period ? last(df, original_period) : df
        return historical_data_return
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_stock_data_dataframe: " * e.msg))
        else
            throw(error("Error in get_stock_data_dataframe"))
        end
    end
end

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

function calculate_rsi(
    ticker::String, length_data::Int, period::Int, end_date::Date, tempdir
)
    try
        # Step 1: Try to read from cache
        cached_data = read_parquet_with_duckdb(
            "rsi",
            ticker,
            length_data,
            period,
            end_date,
            "IndicatorData/rsi_$(ticker)_$(length_data)_$(period)_$(end_date).parquet",
        )
        if !isnothing(cached_data)
            return cached_data.value
        end

        # Step 2: Fetch stock data
        df = get_stock_data_dataframe(ticker, length_data + period, end_date, tempdir)
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
            "IndicatorData/rsi_$(ticker)_$(length_data)_$(period)_$(end_date).parquet",
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

function get_rsi(ticker::String, length_data::Int, period::Int, end_date::Date, tempdir)
    return calculate_rsi(ticker, length_data, period, end_date, tempdir)
end

function run_single_experiment(tickers, length_data, period, end_date, tempdir)
    for _ in 1:5
        for i in 1:20
            get_rsi(tickers[i], length_data, period, end_date, tempdir)
        end
    end
end

function run_experiments(n_experiments, tempdir)
    for _ in 1:n_experiments
        @time run_single_experiment(tickers, 250, 1500, Date("2024-05-31"), tempdir)
    end
end

function setup_temp_dir(tickers::Vector{String})
    # Create a temporary file system
    tempdir = mktempdir()

    for ticker in tickers
        local_parquet_path = joinpath("./ParquetData", "$ticker.parquet")
        temp_parquet_path = joinpath(tempdir, "$ticker.parquet")
        cp(local_parquet_path, temp_parquet_path)
    end

    return tempdir
end

function cleanup_temp_dir(tempdir)
    return rm(tempdir; recursive=true, force=true)
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

tempdir = setup_temp_dir(tickers)

# warm-up call
run_experiments(1, tempdir)

n_experiments = 10
run_experiments(n_experiments, tempdir)

cleanup_temp_dir(tempdir)
