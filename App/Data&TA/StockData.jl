
include("DuckDbManager.jl")
include("DataUtils.jl")

module StockData

using ..StockDataUtils
using ..DatabaseManager
using ..VectoriseBacktestService
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.GlobalServerCache
using Dates, TimeZones, HTTP, JSON, DuckDB, Parquet, DataFrames, DotEnv, Base64, MbedTLS
DotEnv.load!()

export get_live_data,
    map_ticker,
    get_market_cap,
    get_live_data_api_call,
    get_stock_data_dataframe,
    get_historical_stock_data,
    calculate_delta_percentages,
    get_historical_stock_data_parquet,
    get_stock_data_dataframe_start_end,
    get_historical_stock_data_start_end_date,
    get_historical_stock_data_parquet_till_end_date,
    get_historical_stock_data_parquet_start_end_date

"""
Map ticker symbol FNGU to FNGA
"""
function map_ticker(ticker::String)::String
    # Only map FNGU to FNGA until May 15, 2024
    cutoff_date = Date(2025, 5, 15)
    current_date = today()

    if ticker == "FNGU" && current_date <= cutoff_date
        return "FNGA"
    else
        return ticker
    end
end

"""
Execute a DuckDB query with retry logic and thread-local connection
"""
function execute_duckdb_query(query::String, max_retries::Int=3)
    db_conn = DatabaseManager.get_thread_connection()
    base_wait_time = 0.5  # Start with 0.5 second wait time

    for attempt in 1:max_retries
        try
            return DuckDB.execute(db_conn, query)
        catch e
            if attempt == max_retries
                @error "Error executing DuckDB query after $max_retries attempts" exception = (
                    e, catch_backtrace()
                )
                throw(ProcessingError("Error executing DuckDB query", e))
            end
            wait_time = base_wait_time * (2^(attempt - 1))  # Exponential backoff
            @warn "Attempt $attempt failed. Retrying in $wait_time seconds..."
            sleep(wait_time)
        end
    end
    return nothing
end
# Modified functions to use execute_duckdb_query
function get_market_cap(symbol, date, period)
    try
        # Map FNGU to FNGA
        symbol = map_ticker(symbol)

        project_root = get_project_root()
        filepath = "$project_root/data/market_cap/$(symbol).parquet"

        if isfile(filepath)
            query = """
            SELECT marketCap, date
            FROM read_parquet('$filepath')
            WHERE date <= '$date'
            ORDER BY date DESC
            LIMIT $period
            """
            result = execute_duckdb_query(query)
            return DataFrame(result)
        else
            throw(
                ProcessingError("Error: Market cap data file not found for symbol $symbol.")
            )
        end
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_market_cap: " * e.msg))
        else
            throw(ProcessingError("Error in get_market_cap"))
        end
    end
end

function get_historical_stock_data_parquet_start_end_date(ticker, start_date, end_date)
    try
        # Map FNGU to FNGA
        ticker = map_ticker(ticker)

        root_path = get_project_root()
        file_path = "$root_path/data/$ticker.parquet"
        query = """
        SELECT adjusted_close, date
        FROM read_parquet('$file_path')
        WHERE date >= '$(start_date)' AND date <= '$(end_date)'
        """
        result = execute_duckdb_query(query)
        return DataFrame(result)
    catch e
        if hasproperty(e, :msg)
            throw(
                ProcessingError(
                    "Error in get_historical_stock_data_parquet_start_end_date: " * e.msg
                ),
            )
        else
            throw(
                ProcessingError("Error in get_historical_stock_data_parquet_start_end_date")
            )
        end
    end
end

function get_historical_stock_data_parquet_till_end_date(
    ticker::String, end_date::Date, live_data=false
)
    try
        # Map FNGU to FNGA
        ticker = map_ticker(ticker)

        result = get_price_data("$(ticker)_historical_ind_data")
        if !isnothing(result)
            return result
        end

        root_path = get_project_root()
        file_path = "$root_path/data/$ticker.parquet"
        if !isfile(file_path)
            error("Error: File not found: $file_path")
        end
        query = """
        SELECT adjusted_close, date
        FROM read_parquet('$file_path')
        WHERE date <= '$(end_date)'
        """
        result = execute_duckdb_query(query)
        df = DataFrame(result)
        cache_price_data("$(ticker)_historical_ind_data", df)

        if live_data
            live_data = get_live_data(ticker)
            return combine_data(df, live_data)
        end
        return df
    catch e
        if hasproperty(e, :msg)
            throw(
                ProcessingError(
                    "Error in get_historical_stock_data_parquet_till_end_date: " * e.msg
                ),
            )
        else
            throw(
                ProcessingError("Error in get_historical_stock_data_parquet_till_end_date")
            )
        end
    end
end

function get_historical_stock_data_parquet(
    ticker::String, period::Int, end_date::Date
)::DataFrame
    try
        # Map FNGU to FNGA
        ticker = map_ticker(ticker)

        root_path = get_project_root()
        file_path = joinpath(root_path, "data", "$ticker.parquet")

        if !isfile(file_path)
            error("Error: File not found: $file_path")
        end

        # First subquery gets the latest records
        # Outer query reorders them chronologically
        query = """
        WITH latest_records AS (
            SELECT adjusted_close, date
            FROM read_parquet('$file_path')
            WHERE date <= '$(end_date)'
            ORDER BY date DESC
            LIMIT $period
        )
        SELECT adjusted_close, date
        FROM latest_records
        ORDER BY date ASC
        """

        result = execute_duckdb_query(query)
        return DataFrame(result)
    catch e
        throw(
            ProcessingError(
                "Error in get_historical_stock_data_parquet: $(sprint(showerror, e))"
            ),
        )
    end
end

# mid level function (historical data, checks for parquet)
function get_historical_stock_data_start_end_date(
    ticker::String, start_date::Date, end_date::Date, live_data::Bool=false
)
    try
        # Map FNGU to FNGA
        ticker = map_ticker(ticker)

        root_path = get_project_root()
        file_path = "$root_path/data/$ticker.parquet"
        if isfile(file_path)
            historical_data = get_historical_stock_data_parquet_start_end_date(
                ticker, start_date, end_date
            )

            return historical_data
        else
            throw(ProcessingError("Error: Stock data file not found for symbol $ticker."))
        end
    catch e
        if hasproperty(e, :msg)
            throw(
                ProcessingError(
                    "Error in get_historical_stock_data_start_end_date: " * e.msg
                ),
            )
        else
            throw(ProcessingError("Error in get_historical_stock_data_start_end_date"))
        end
    end
end

# mid level function (historical data, checks for parquet)
function get_historical_stock_data(ticker::String, period::Int, end_date::Date)
    try
        # Map FNGU to FNGA
        ticker = map_ticker(ticker)

        root_path = get_project_root()
        # if ticker contains a dot, replace it with an underscore
        ticker = replace(ticker, "." => "-")
        # Construct the file path
        file_path = joinpath(root_path, "data", "$ticker.parquet")

        # Check if the file exists
        if isfile(file_path)
            historical_data = get_historical_stock_data_parquet(ticker, period, end_date)
            return historical_data
        else
            throw(
                ProcessingError(
                    "Error: Stock data file not found for symbol $ticker at path: $file_path",
                ),
            )
        end
    catch e
        error_msg = isa(e, ErrorException) ? e.msg : e
        throw(ProcessingError("Error in get_historical_stock_data: $error_msg"))
    end
end

function make_authenticated_request(username::String, secret::String, symbol::String)
    # Create the date string in RFC 1123 format
    request_date = Dates.format(now(Dates.UTC), "e, dd u yyyy HH:MM:SS GMT")

    # Define the request target
    request_target = "get /get_live_data?symbol=$symbol"

    # Create the string to sign
    string_to_sign = "date: $request_date\n@request-target: $request_target"

    # Generate HMAC-SHA256 signature
    key = Vector{UInt8}(secret)
    signature = base64encode(digest(MD_SHA256, Vector{UInt8}(string_to_sign), key))

    # Create authorization header
    auth_header =
        "hmac username=\"$username\", algorithm=\"hmac-sha256\", " *
        "headers=\"date @request-target\", signature=\"$signature\""
    # Make the HTTP request
    headers = ["Date" => request_date, "Authorization" => auth_header]
    url = get(ENV, "LIVE_DATA_API_URL", "https://live.trendtrader.ai/get_live_data")
    response = HTTP.get("$url?symbol=$symbol", headers)
    return response
end

# bottom level function (api)
function get_live_data_api_call(symbol::String)
    try
        # Map FNGU to FNGA
        symbol = map_ticker(symbol)

        # Get the live data api url from the environment
        symbol = replace(symbol, "-" => ".")
        username = get(ENV, "LIVE_DATA_API_USERNAME", "")
        secret = get(ENV, "LIVE_DATA_API_SECRET", "")
        url = get(ENV, "LIVE_DATA_API_URL", "https://live.trendtrader.ai/get_live_data")

        local response
        if occursin("live.trendtrader.ai", url)
            response = make_authenticated_request(username, secret, symbol)
        else
            response = HTTP.get("$url?symbol=$symbol")
        end

        if HTTP.status(response) == 200
            # Get the response body as a string
            response_body = String(response.body)

            # Parse the JSON response
            # Use try-catch to handle potential parsing errors
            try
                parsed_data = JSON.parse(response_body)
                return parsed_data["data"]
            catch json_error
                # If standard parsing fails, try to clean the string
                cleaned_response = replace(response_body, "\\\"" => "\"", "\\\\" => "\\")
                try
                    parsed_data = JSON.parse(cleaned_response)
                    return parsed_data["data"]
                catch second_error
                    return Dict("error" => "Failed to parse JSON response: $second_error"),
                    500
                end
            end
        else
            return Dict("error" => "Error getting live data"), HTTP.status(response)
        end
    catch e
        println("Exception in get_live_data_api_call: $e")
        return Dict("error" => "Error getting live data for symbol $symbol: $e"), 500
    end
end

function get_live_data(symbol::String)
    try
        # Map FNGU to FNGA
        symbol = map_ticker(symbol)

        live_data = get_price_data("$(symbol)_live_data")
        if !isnothing(live_data)
            return convert_to_dataframe(live_data)
        end
        live_data = get_live_data_api_call(symbol)
        cache_price_data("$(symbol)_live_data", convert_to_dataframe(live_data))
        return convert_to_dataframe(live_data)
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_live_data  for symbol $symbol: " * e.msg))
        else
            throw(error("Error in get_live_data"))
        end
    end
end

# top level function (include checks for live data)
function get_stock_data_dataframe(ticker, period, end_date::Date, live_data=false)
    try
        # Map FNGU to FNGA
        ticker = map_ticker(ticker)

        nyt_time = get_new_york_time_date()
        original_period = period

        if live_data
            today_date = Date(
                Dates.year(nyt_time), Dates.month(nyt_time), Dates.day(nyt_time)
            )
            live_data = get_live_data(ticker)
            if period == 1
                return live_data
            else
                live_data = get_live_data(ticker)
                adjusted_end_date = end_date - Day(1)
                adjusted_period = original_period - 1

                df = get_historical_stock_data(ticker, period, adjusted_end_date)
                historical_data_return =
                    size(df, 1) > adjusted_period ? last(df, adjusted_period) : df
                return combine_data(historical_data_return, live_data)
            end
        end

        df = get_historical_stock_data(ticker, Number(period), end_date)
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

# top level function (include checks for live data)
function get_stock_data_dataframe_start_end(
    ticker, start_date::Date, end_date::Date, live_data=false
)
    try
        # Map FNGU to FNGA
        ticker = map_ticker(ticker)

        nyt_time = get_new_york_time_date()

        if live_data
            live_data = get_live_data(ticker)
            if start_date == end_date
                return live_data
            else
                live_data = get_live_data(ticker)
                adjusted_end_date = end_date - Day(1)

                df = get_historical_stock_data_start_end_date(
                    ticker, start_date, adjusted_end_date
                )

                return combine_data(df, live_data)
            end
        end
        df = get_historical_stock_data_start_end_date(ticker, start_date, end_date)
        return df
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_stock_data_dataframe_start_end: " * e.msg))
        else
            throw(error("Error in get_stock_data_dataframe_start_end"))
        end
    end
end

function calculate_delta_percentages(values::Vector{Float64})
    try
        deltas = [0.0; diff(values) ./ values[1:(end - 1)] * 100]
        return deltas
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in calculate_delta_percentages: " * e.msg))
        else
            throw(error("Error in calculate_delta_percentages"))
        end
    end
end

end
