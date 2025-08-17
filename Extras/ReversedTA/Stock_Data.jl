module Stock_Data_V2

using Dates
using TimeZones
using HTTP
using JSON
using DuckDB
using Parquet
using DataFrames

include("../config.jl")
# using .Config

const holiday_cache = Dict()

function get_nth_weekday(year, month, day_of_week, n)
    first_of_month = Date(year, month, 1)
    first_day_of_week =
        first_of_month + Dates.Day(day_of_week - Dates.dayofweek(first_of_month))
    if first_day_of_week < first_of_month
        first_day_of_week += Dates.Day(7)
    end
    return first_day_of_week + Dates.Day((n - 1) * 7)
end

function adjust_holidays(year::Int)
    if haskey(holiday_cache, year)
        return holiday_cache[year]
    end

    holidays = Dict(
        "New Year's Day" => Date(year, 1, 1),
        "Martin Luther King Jr. Day" => get_nth_weekday(year, 1, Dates.Monday, 3),
        "Washington's Birthday" => get_nth_weekday(year, 2, Dates.Monday, 3),
        "Memorial Day" => get_nth_weekday(year, 5, Dates.Monday, 5),
        "Independence Day" => Date(year, 7, 4),
        "Labor Day" => get_nth_weekday(year, 9, Dates.Monday, 1),
        "Thanksgiving Day" => get_nth_weekday(year, 11, Dates.Thursday, 4),
        "Christmas Day" => Date(year, 12, 25),
    )

    for (holiday, holiday_date) in holidays
        if Dates.dayofweek(holiday_date) == Dates.Saturday
            holidays[holiday] = holiday_date - Dates.Day(1)
        elseif Dates.dayofweek(holiday_date) == Dates.Sunday
            holidays[holiday] = holiday_date + Dates.Day(1)
        end
    end

    holiday_cache[year] = values(holidays)
    return holiday_cache[year]
end

function is_us_market_open(date::Date)
    year = Dates.year(date)
    holidays = adjust_holidays(year)

    if Dates.dayofweek(date) in (Dates.Saturday, Dates.Sunday) || date in holidays
        return false
    else
        return true
    end
end
# TODO - Fix bugs when period=1 and return date is 1 day more than expected
function find_previous_business_day(date::Date, period::Int)
    current_date = date
    days_to_subtract = period
    while days_to_subtract > 0
        current_date -= Dates.Day(1)
        if is_us_market_open(current_date)
            days_to_subtract -= 1
        end
    end
    return current_date
end

function find_valid_business_days(end_date::Date, period::Int)
    current_end_date = end_date
    current_start_date = @time find_previous_business_day(end_date, period)

    return current_start_date, current_end_date
end

function check_trading_hours(nyt_time::ZonedDateTime)
    market_open = ZonedDateTime(
        DateTime(year(nyt_time), month(nyt_time), day(nyt_time), 9, 30), timezone(nyt_time)
    )
    market_close = ZonedDateTime(
        DateTime(year(nyt_time), month(nyt_time), day(nyt_time), 16, 0), timezone(nyt_time)
    )

    return market_open <= nyt_time <= market_close
end

function get_new_york_time_date()
    local_now = now()
    local_zoned = ZonedDateTime(local_now, localzone())
    nyt_now = astimezone(local_zoned, tz"America/New_York")
    return nyt_now
end

# bottom level function (api)
function get_historical_stock_data_API_Call_start_end(
    ticker::String, start_date::Date, end_date::Date
)
    try
        base_url = "https://eodhd.com/api/eod/"
        api_url = "$base_url$ticker?from=$start_date&to=$end_date&api_token=$(EOD_API)&fmt=json"
        response = HTTP.get(api_url)

        if response.status == 200
            data = JSON.parse(String(response.body))
            println("Data fetched from API", data)
            return data
        else
            error("Error: Unable to fetch data. Status code: $(response.status)")
        end

    catch e
        error("Error: Unable to fetch data. Error: $e")
    end
end

# bottom level function (api)
function get_historical_stock_data_API_Call(ticker::String, period::Int, end_date::Date)
    start_date, end_date = find_valid_business_days(end_date, period)
    println("Fetching data from API", start_date, end_date)
    return get_historical_stock_data_API_Call_start_end(ticker, start_date, end_date)
end

# Function to fetch market cap data from the API
function fetch_market_cap_api(symbol, period, date)
    url = "https://financialmodelingprep.com/api/v3/historical-market-capitalization/$symbol?limit=$period&to=$date&apikey=$(FMP_API)"
    response = HTTP.get(url)

    if response.status == 200
        data = JSON.parse(String(response.body))
        return DataFrame(reverse(data))
    else
        error("Error: Unable to fetch data. Status code: $(response.status)")
    end
end

# Main function to get market cap data
function get_market_cap(symbol, date, period)
    filepath = "data/market_cap/$(symbol).parquet"

    if isfile(filepath)
        df = DataFrame(read_parquet(filepath))
        df.date = Date.(df.date, "yyyy-mm-dd")
        target_date = Date(date)
        # Filter the DataFrame to include only rows up to the specified 'date'
        df_filtered = filter(row -> row.date <= target_date, df)

        # Ensure only the last 'period' rows are returned
        if nrow(df_filtered) >= period
            println("Sufficient data in file, no need to call API")
            return df_filtered[(end - period + 1):end, :]
        else
            # If the filtered data doesn't have enough data, fetch the remaining from the API
            println("Insufficient data in file, calling API")
            df_api = fetch_market_cap_api(symbol, period - nrow(df_filtered), date)
            # Combine the data from file and API
            return vcat(df_filtered, df_api)
        end
    else
        println("File not found, calling API")
        return fetch_market_cap_api(symbol, period, date)
    end
end

function historical_data_api_parser(historical_data)
    parsed_data = DataFrame(; date=Date[], adjusted_close=Float64[])

    for i in length(historical_data):-1:1
        bar = historical_data[i]
        push!(parsed_data, (Date(split(bar["date"], 'T')[1]), bar["adjusted_close"]))
    end

    return parsed_data
end

function historical_data_api_parser_FMP(historical_data)
    df = DataFrame(; date=Date[], adjusted_close=Float64[])

    for entry in historical_data
        push!(df, (Date(entry["date"]), entry["adjClose"]))
    end

    return reverse(df)
end

function get_historical_stock_data_parquet_start_end_date(ticker, start_date, end_date)
    file_path = "data/$(ticker).parquet"
    df = DataFrame(read_parquet(file_path))

    df.date = Date.(df.date, "yyyy-mm-dd")

    df = filter(row -> row.date >= start_date && row.date <= end_date, df)
    df = select(df, :date, :adjusted_close)

    return df
end

# bottom level function (parquet)
function get_historical_stock_data_parquet(ticker, period, end_date)
    println("Calculating start and end date")
    start_date, end_date = find_valid_business_days(end_date, period)
    println("Start date: $start_date, End date: $end_date")

    file_path = "data/$(ticker).parquet"
    df = DataFrame(read_parquet(file_path))

    # Parse the date strings into Date objects
    df.date = Date.(df.date, "yyyy-mm-dd")

    df = filter(row -> row.date >= start_date && row.date <= end_date, df)
    df = select(df, :date, :adjusted_close)

    return df
end

# mid level function (historical data, checks for parquet)
function get_historical_stock_data_start_end_date(
    ticker::String, start_date::Date, end_date::Date
)
    if isfile("data/$ticker.parquet")
        historical_data = get_historical_stock_data_parquet_start_end_date(
            ticker, start_date, end_date
        )

        if (nrow(historical_data) == 0 || historical_data === nothing)
            historical_data = get_historical_stock_data_API_Call_start_end(
                ticker, start_date, end_date
            )

            return historical_data_api_parser(historical_data)
        end

        return historical_data
    end

    historical_data = get_historical_stock_data_API_Call_start_end(
        ticker, start_date, end_date
    )

    return historical_data_api_parser(historical_data)
end

# mid level function (historical data, checks for parquet)
function get_historical_stock_data(ticker::String, period::Int, end_date::Date)
    println("Fetching hist data for $ticker with period $period and end date $end_date")

    if isfile("data/$ticker.parquet")
        println("Fetching historical data from parquet")
        historical_data = get_historical_stock_data_parquet(ticker, period, end_date)

        println(nrow(historical_data), " ", period, "historical data length")
        if (
            nrow(historical_data) == 0 ||
            historical_data === nothing ||
            nrow(historical_data) < (period - 10)
        )
            println("Fetching historical data from API")
            if (period != 110000) # 110000 is a flag to get all data
                historical_data = get_historical_stock_data_API_Call(
                    ticker, period, end_date
                )

                return historical_data_api_parser(historical_data)
            end
        end

        return historical_data
    end

    historical_data = get_historical_stock_data_API_Call(ticker, period, end_date)

    return historical_data_api_parser(historical_data)
end

function historical_data_api_parser_full(input)
    parsed_data = []

    for entry in input
        date_str = replace(entry["date"], "Z" => "")
        parsed_date = Dates.format(
            Dates.DateTime(date_str, dateformat"yyyy-mm-ddTHH:MM:SS"), "yyyy-mm-dd"
        )

        push!(
            parsed_data,
            Dict(
                "open" => entry["open"],
                "high" => entry["high"],
                "low" => entry["low"],
                "close" => entry["adjusted_close"],
                "volume" => entry["volume"],
                "date" => parsed_date,
            ),
        )
    end

    return parsed_data
end

function historical_data_api_parser_full_FMP(input)
    parsed_data = []

    for entry in input
        push!(
            parsed_data,
            Dict(
                "open" => entry["open"],
                "high" => entry["high"],
                "low" => entry["low"],
                "close" => entry["adjClose"],
                "volume" => entry["volume"],
                "trade_count" => "0",
                "vwap" => entry["vwap"],
                "date" => entry["date"],
            ),
        )
    end

    return reverse(parsed_data)
end

# bottom level function (parquet)
function get_historical_stock_data_parquet_full(ticker, period, end_date)
    start_date, end_date = find_valid_business_days(end_date, period)

    file_path = "data/$(ticker).parquet"
    df = DataFrame(read_parquet(file_path))

    df.date = Date.(df.date, "yyyy-mm-dd")

    df = filter(row -> row.date >= start_date && row.date <= end_date, df)

    return df
end

function parse_parquet_to_dictionary(input)
    parsed_data = []

    for entry in eachrow(input)
        parsed_date = if entry["date"] isa Date
            Dates.format(entry["date"], "yyyy-mm-dd")
        else
            entry["date"]
        end

        formatted_entry = Dict(
            "high" => entry["adjusted_high"],
            "volume" => entry["volume"],
            "open" => entry["adjusted_open"],
            "date" => parsed_date,
            "low" => entry["adjusted_low"],
            "close" => entry["adjusted_close"],
        )

        push!(parsed_data, formatted_entry)
    end

    return parsed_data
end

# mid level function (historical data, checks for parquet)

function get_historical_stock_data_full(ticker::String, period::Int, end_date::Date)
    if isfile("data/$ticker.parquet")
        println("Fetching historical data from parquet")
        historical_data_df = get_historical_stock_data_parquet_full(
            ticker, period, end_date
        )
        historical_data = parse_parquet_to_dictionary(historical_data_df)

        if (length(historical_data) != period)
            historical_data = get_historical_stock_data_API_Call(ticker, period, end_date)

            return historical_data_api_parser_full(historical_data)
        end

        return historical_data
    end

    println("Fetching historical data from API")
    historical_data = get_historical_stock_data_API_Call(ticker, period, end_date)

    return historical_data_api_parser_full(historical_data)
end

function convert_to_dataframe(live_data)
    df = DataFrame(live_data)
    df_selected = select(df, [:date, :adjusted_close])
    return df_selected
end

# bottom level function (api)
function get_live_data_api_call(symbol::String)
    try
        url = "http://live_data_service:4001/get_live_data?symbol=$symbol"
        response = HTTP.get(url)

        if HTTP.status(response) == 200
            parsed_data = JSON.parse(String(response.body))
            println(parsed_data)
            return parsed_data["data"]
        else
            return Dict("error" => "Error getting live data"), HTTP.status(response)
        end
    catch e
        return Dict("error" => "Error getting live data"), 500
    end
end

function get_live_data(symbol::String)
    live_data = get_live_data_api_call(symbol)
    print(live_data)
    return convert_to_dataframe(live_data)
end

function get_live_data_full(symbol::String)
    live_data = get_live_data_api_call(symbol)

    return DataFrame(live_data)
end

function combine_data(historical_data, live_data)
    combined_data = vcat(historical_data, live_data)
    combined_data.date = Date.(combined_data.date)

    return combined_data
end

function combine_data_full(historical_data, live_data)
    live_entry = Dict{String,Any}(
        "date" => live_data[1, "date"],
        "close" => live_data[1, "adjusted_close"],
        "high" => 0,
        "low" => 0,
        "open" => 0,
        "volume" => 0,
        "vwap" => 0,
        "trade_count" => 0,
    )

    push!(historical_data, live_entry)

    return historical_data
end

# top level function (include checks for live data)

function get_stock_data_dataframe(ticker, period, end_date::Date)
    println("Fetching data for $ticker with period $period and end date $end_date")
    nyt_time = get_new_york_time_date()
    original_period = period
    period = convert(Int, round(period * 1.1))

    if Dates.day(nyt_time) == day(end_date) &&
        Dates.month(nyt_time) == month(end_date) &&
        Dates.year(nyt_time) == year(end_date)
        print("Fetching live data")
        if is_us_market_open(end_date)
            if check_trading_hours(nyt_time)
                live_data = get_live_data(ticker)
                if period == 1
                    return live_data
                else
                    live_data = get_live_data(ticker)
                    adjusted_end_date = end_date - Day(1)
                    adjusted_period = original_period - 1

                    df = get_historical_stock_data(ticker, period, adjusted_end_date)
                    historical_data_return =
                        size(df, 1) > adjusted_period ? first(df, adjusted_period) : df

                    return combine_data(historical_data_return, live_data)
                end
            end
        end
    end

    println("Fetching historical data")

    df = get_historical_stock_data(ticker, Number(period), end_date)
    historical_data_return = size(df, 1) > original_period ? first(df, original_period) : df

    return historical_data_return
end

function parse_dataframe_into_list(dataframe)
    prices_list = dataframe[!, :adjusted_close]
    last_prices = collect(skipmissing(prices_list))

    return last_prices
end

function get_stock_data_list(ticker, period, end_date::Date)
    stock_data = get_stock_data_dataframe(ticker, period, end_date)

    return parse_dataframe_into_list(stock_data)
end

# top level function (include checks for live data)

function get_stock_data_dataframe_full(ticker, period, end_date::Date)
    nyt_time = get_new_york_time_date()
    original_period = period
    period = convert(Int, round(period * 1.1))

    if Dates.day(nyt_time) == day(end_date) &&
        Dates.month(nyt_time) == month(end_date) &&
        Dates.year(nyt_time) == year(end_date)
        if is_us_market_open(end_date)
            if check_trading_hours(nyt_time)
                live_data = get_live_data_full(ticker)
                if period == 1
                    return live_data
                else
                    live_data = get_live_data_full(ticker)
                    adjusted_end_date = end_date - Day(1)
                    adjusted_period = original_period - 1

                    df = get_historical_stock_data_full(ticker, period, adjusted_end_date)
                    historical_data_return =
                        size(df, 1) > adjusted_period ? first(df, adjusted_period) : df

                    return combine_data_full(historical_data_return, live_data)
                end
            end
        end
    end

    println("Fetching historical data")
    df = get_historical_stock_data_full(ticker, period, end_date)
    historical_data_return = size(df, 1) > original_period ? first(df, original_period) : df

    return historical_data_return
end

# top level function (include checks for live data)

function get_stock_data_dataframe_start_end(ticker, start_date::Date, end_date::Date)
    nyt_time = get_new_york_time_date()

    if Dates.day(nyt_time) == day(end_date) &&
        Dates.month(nyt_time) == month(end_date) &&
        Dates.year(nyt_time) == year(end_date)
        if is_us_market_open(end_date)
            if check_trading_hours(nyt_time)
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
        end
    end
    println("Fetching historical data")
    df = get_historical_stock_data_start_end_date(ticker, start_date, end_date)
    return df
end

function calculate_delta_percentages(values::Vector{Float64})
    deltas = [0.0; diff(values) ./ values[1:(end - 1)] * 100]
    return deltas
end

# export all
for n in names(@__MODULE__; all=true)
    if Base.isidentifier(n) && n ∉ (Symbol(@__MODULE__), :eval, :include)
        @eval export $n
    end
end

end # end of module
