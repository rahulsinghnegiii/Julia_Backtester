
module StockDataUtils
using Dates, TimeZones, DuckDB, DataFrames

export get_project_root,
    get_nth_weekday,
    get_last_weekday,
    adjust_holidays,
    is_us_market_open,
    find_previous_business_day,
    find_valid_business_days,
    check_trading_hours,
    get_new_york_time_date,
    contains_pattern,
    parse_parquet_to_dictionary,
    convert_to_dataframe,
    combine_data,
    combine_data_full,
    parse_dataframe_into_list

HOLIDAY_CACHE = Dict{Int,Vector{Date}}()
NY_TIMEZONE = tz"America/New_York"

# Precompute day of week constants
const MONDAY, THURSDAY, SATURDAY, SUNDAY = 1, 4, 6, 7

function get_project_root()
    try
        # Start from the current directory and move up until we find a directory containing "Project.toml"
        current_dir = pwd()
        if isdir("./App")
            return "./App"
        else
            while !isfile(joinpath(current_dir, "Project.toml"))
                parent_dir = dirname(current_dir)
                if parent_dir == current_dir  # We've reached the root directory
                    error("error: Could not find project root (no Project.toml found)")
                end
                current_dir = parent_dir
            end
            return current_dir
        end
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_project_root: " * e.msg))
        else
            throw(error("Error in get_project_root"))
        end
    end
end

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

function check_trading_hours(nyt_time::ZonedDateTime)
    try
        market_open = ZonedDateTime(DateTime(Date(nyt_time), Time(9, 30)), NY_TIMEZONE)
        market_close = ZonedDateTime(DateTime(Date(nyt_time), Time(16, 0)), NY_TIMEZONE)
        return market_open <= nyt_time <= market_close
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in check_trading_hours: " * e.msg))
        else
            throw(error("Error in check_trading_hours"))
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

function contains_pattern(str::String, pattern::Regex)
    return occursin(pattern, str)
end

function parse_parquet_to_dictionary(input)
    try
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
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in parse_parquet_to_dictionary: " * e.msg))
        else
            throw(error("Error in parse_parquet_to_dictionary"))
        end
    end
end

function convert_to_dataframe(live_data)
    try
        df = DataFrame(live_data)
        df_selected = select(df, [:date, :adjusted_close])
        return df_selected
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in convert_to_dataframe: " * e.msg))
        else
            throw(error("Error in convert_to_dataframe"))
        end
    end
end

function combine_data(historical_data, live_data)
    try
        combined_data = vcat(historical_data, live_data)
        combined_data.date = Date.(combined_data.date)
        return combined_data
    catch e
        if hasproperty(e, :msg)
        else
        end
        throw(error("Error in combine_data: " * e.msg))
    end
end

function combine_data_full(historical_data, live_data)
    try
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
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in combine_data_full: " * e.msg))
        else
            throw(error("Error in combine_data_full"))
        end
    end
end

function parse_dataframe_into_list(dataframe)
    try
        prices_list = dataframe[!, :adjusted_close]
        last_prices = collect(skipmissing(prices_list))
        return last_prices
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in parse_dataframe_into_list: " * e.msg))
        else
            throw(error("Error in parse_dataframe_into_list"))
        end
    end
end
end
