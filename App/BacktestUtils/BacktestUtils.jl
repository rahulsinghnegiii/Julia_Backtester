module BacktestUtilites
include("./SIMDOperations.jl")

using ..VectoriseBacktestService
using ..VectoriseBacktestService.StockData
using Dates, DataFrames, JSON, HTTP, JSON3, Parquet2, Mmap
using ..VectoriseBacktestService.StockData.StockDataUtils
using ..VectoriseBacktestService.MarketTechnicalsIndicators
using ..VectoriseBacktestService.ErrorHandlers

export calculate_portfolio_values_single_curve,
    get_earliest_dates_of_tickers,
    calculate_portfolio_values,
    truncate_to_common_period,
    parse_select_properties,
    cache_portfolio_values,
    parse_sort_properties,
    read_portfolio_values,
    find_matching_branch,
    get_cached_indicator,
    get_cached_value_df,
    get_price_dataframe,
    get_indicator_value,
    apply_sort_function,
    calculate_num_days,
    make_sort_branches,
    get_current_price,
    get_cached_value,
    read_json_file,
    populate_dates,
    compare_values,
    read_metadata,
    get_branches

function read_metadata(cache_tickers::Vector{Any})
    project_root = get_project_root()
    parquet_file_path = joinpath(project_root, "data", "metadata.parquet")

    # Read the Parquet file first
    dataset = Parquet2.Dataset(parquet_file_path)
    # Create DataFrame with all columns
    metadata = DataFrame(dataset)

    # Select only needed columns after DataFrame creation
    metadata = metadata[:, [:ticker, :num_records, :end_date]]

    # Filter metadata for the requested tickers
    filtered_data = filter(row -> row.ticker in cache_tickers, metadata)

    if isempty(filtered_data)
        throw(ProcessingError("No metadata found for the requested tickers"))
    end

    # Process num_records
    num_records = filtered_data.num_records
    if any(isnothing, num_records)
        problematic_ticker = filtered_data[findfirst(isnothing, num_records), :ticker]
        throw(ProcessingError("No num records found for ticker $problematic_ticker"))
    end

    # Process end_dates
    end_dates = filtered_data.end_date
    if any(isnothing, end_dates)
        problematic_ticker = filtered_data[findfirst(isnothing, end_dates), :ticker]
        throw(ProcessingError("No end date found for ticker $problematic_ticker"))
    end

    # Convert dates and handle any conversion errors
    try
        date_records = Date.(end_dates)
        return minimum(num_records), minimum(date_records)
    catch e
        throw(ProcessingError("Failed to convert end dates to Date type", e))
    end
end

function get_earliest_dates_of_tickers(tickers_list::Vector{Any})::Vector{Any}
    project_root = get_project_root()
    parquet_file_path = joinpath(project_root, "data", "metadata.parquet")

    !isfile(parquet_file_path) && return []

    dataset = Parquet2.Dataset(parquet_file_path)
    metadata = DataFrame(dataset)

    metadata = metadata[:, [:ticker, :start_date]]

    df = filter(row -> row.ticker in tickers_list, metadata)

    return [(String(row.ticker), String(row.start_date)) for row in eachrow(df)]
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
        throw(ProcessingError("Failed to get cached value for $key", e))
    end
end

# For price_cache
function get_cached_value_df(
    key::String,
    price_cache::Dict{String,DataFrame},
    start_date::Date,
    end_date::Date,
    compute_func::Function,
)::DataFrame
    try
        recompute = false

        if haskey(price_cache, key)
            df = price_cache[key]
            df.date = Date.(df.date)

            # Check if recomputation is needed
            if size(df, 1) < 2 || minimum(df.date) > start_date
                recompute = true
            end
        else
            recompute = true
        end

        if recompute
            df = compute_func()
            df.date = Date.(df.date)
            price_cache[key] = df
        end

        original_length = size(df, 1)
        filtered_view = @view df[(df.date .>= start_date) .& (df.date .<= end_date), :]
        result_df = DataFrame(filtered_view)

        # Ensure at least 2 rows, otherwise recompute again
        if size(result_df, 1) < 2
            df = compute_func()
            df.date = Date.(df.date)
            price_cache[key] = df
            filtered_view = @view df[(df.date .>= start_date) .& (df.date .<= end_date), :]
            result_df = DataFrame(filtered_view)
        end

        result_df[!, :original_length] .= original_length
        return result_df
    catch e
        throw(ProcessingError("Failed to get cached value for $key", e))
    end
end

function get_price_dataframe(
    ticker::String, period::Int, end_date::Date, live_execution::Bool=false
)::DataFrame
    try
        return get_stock_data_dataframe(ticker, period + 1, end_date, live_execution)
    catch e
        throw(
            ProcessingError(
                "Failed to get price data for $ticker, period: $period, end_date: $end_date",
                e,
            ),
        )
    end
end

# Read JSON file
function read_json_file(filename::String)::Dict{String,Any}
    try
        json_str::String = read(filename, String)
        return JSON.parse(json_str)
    catch e
        throw(ServerError(400, "Internal server error: Failed to read JSON file"))
    end
end

# Populate dates if not already populated
function populate_dates(
    dateLength::Int, end_date::Date, dates::Vector{String}, live_execution::Bool=false
)::Vector{String}
    try
        if isempty(dates)
            price = get_stock_data_dataframe("KO", dateLength, end_date, live_execution)
            if size(price, 1) < 1
                throw(
                    ServerError(
                        400, "Bad request: Insufficient price data for $dateLength days"
                    ),
                )
            end
            resize!(dates, size(price, 1))
            dates .= string.(price[!, "date"])
        end
        return dates
    catch e
        if isa(e, ServerError)
            rethrow(e)
        else
            throw(ProcessingError("Failed to populate dates", e))
        end
    end
end

function compare_values(
    x::Vector{Float32}, y::Vector{Float32}, comparison::String
)::Vector{Bool}
    comparison_functions = Dict{String,Function}(
        ">" => (a, b) -> compare_greater!(a, b, :>),
        ">=" => (a, b) -> compare_greater!(a, b, :>=),
        "<" => (a, b) -> compare_lower!(a, b, :<),
        "<=" => (a, b) -> compare_lower!(a, b, :<=),
    )

    if haskey(comparison_functions, comparison)
        return comparison_functions[comparison](x, y)
    else
        throw(ArgumentError("Unknown comparison operator: $comparison"))
    end
end

function get_cached_indicator(
    cache::Dict{String,Vector{Float32}},
    indicator::String,
    source::String,
    period::Union{String,Nothing},
    dateLength::Int,
    end_date::Date,
    live_execution::Bool,
    indicator_function::Function,
)::Vector{Float32}
    period_str = isnothing(period) ? "" : "_$(period)"
    cache_key = "$(indicator)_$(source)$(period_str)_$(dateLength)_$(end_date)"

    return get_cached_value(
        cache,
        cache_key,
        () -> indicator_function(
            source, dateLength, parse(Int, period), end_date, live_execution
        ),
    )
end

function get_current_price(
    source::String,
    dates::Vector{String},
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    dateLength::Int,
    live_execution::Bool=false,
)::Vector{Float32}
    price = get_cached_value_df(
        source,
        price_cache,
        Date(dates[1]),
        end_date,
        () -> get_price_dataframe(source, dateLength, end_date, live_execution),
    )
    price = price[max(1, (end - dateLength + 1)):end, :]
    return price[!, "adjusted_close"]
end

function get_stock_ratio(
    prop::Dict{String,Any},
    dates::Vector{String},
    dateLength::Int,
    end_date::Date,
    cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
)
    if !haskey(prop, "numerator") || !haskey(prop, "denominator")
        throw(ArgumentError("Bad request: Missing numerator or denominator in stock ratio"))
    end
    if isempty(prop["numerator"]) || isempty(prop["denominator"])
        throw(ArgumentError("Bad request: Empty numerator or denominator in stock ratio"))
    end

    ratioFunction = prop["indicator"]
    period = get(prop, "period", nothing)

    numerator = prop["numerator"]
    denominator = prop["denominator"]

    numerator_dict = Dict{String,Any}(
        "source" => numerator, "indicator" => ratioFunction, "period" => period
    )
    denominator_dict = Dict{String,Any}(
        "source" => denominator, "indicator" => ratioFunction, "period" => period
    )

    numerator_data = get_indicator_value(
        numerator_dict, dates, dateLength, end_date, cache, price_cache
    )
    denominator_data = get_indicator_value(
        denominator_dict, dates, dateLength, end_date, cache, price_cache
    )
    min_data_len = min(length(numerator_data), length(denominator_data))
    numerator_data = numerator_data[(end - min_data_len + 1):end]
    denominator_data = denominator_data[(end - min_data_len + 1):end]

    return numerator_data ./ denominator_data
end

function get_indicator_value(
    prop::Dict{String,Any},
    dates::Vector{String},
    dateLength::Int,
    end_date::Date,
    cache::Dict{String,Vector{Float32}},
    price_cache::Dict{String,DataFrame},
    live_execution::Bool=false,
)::Vector{Float32}
    indicator = prop["indicator"]
    if indicator == "Fixed-Value" || indicator == "constant"
        return fill(parse(Float32, prop["period"]), dateLength)
    elseif isempty(prop["source"]) &&
        haskey(prop, "numerator") &&
        haskey(prop, "denominator") &&
        !isempty(prop["numerator"]) &&
        !isempty(prop["denominator"])
        try
            return get_stock_ratio(prop, dates, dateLength, end_date, cache, price_cache)
        catch e
            throw(ServerError(400, "Bad request: Failed to get stock ratio"))
        end
    end
    source = prop["source"]
    period = get(prop, "period", nothing)

    indicator_functions = Dict{String,Function}(
        "current price" =>
            () -> get_current_price(
                source, dates, end_date, price_cache, dateLength, live_execution
            ),
        "Cumulative Return" =>
            () -> get_cached_indicator(
                cache,
                "cumulative_return",
                source,
                period,
                dateLength,
                end_date,
                live_execution,
                get_cumulative_return,
            ),
        "Exponential Moving Average of Price" =>
            () -> get_cached_indicator(
                cache,
                "ema",
                source,
                period,
                dateLength,
                end_date,
                live_execution,
                get_ema,
            ),
        "Max Drawdown" =>
            () -> get_cached_indicator(
                cache,
                "max_drawdown",
                source,
                period,
                dateLength,
                end_date,
                live_execution,
                get_max_drawdown,
            ),
        "Relative Strength Index" =>
            () -> get_cached_indicator(
                cache,
                "rsi",
                source,
                period,
                dateLength,
                end_date,
                live_execution,
                get_rsi,
            ),
        "Moving Average of Price" =>
            () -> get_cached_indicator(
                cache,
                "sma",
                source,
                period,
                dateLength,
                end_date,
                live_execution,
                get_sma,
            ),
        "Simple Moving Average of Price" =>
            () -> get_cached_indicator(
                cache,
                "sma",
                source,
                period,
                dateLength,
                end_date,
                live_execution,
                get_sma,
            ),
        "Moving Average of Return" =>
            () -> get_cached_indicator(
                cache,
                "sma_return",
                source,
                period,
                dateLength,
                end_date,
                live_execution,
                get_sma_returns,
            ),
        "Standard Deviation of Return" =>
            () -> get_cached_indicator(
                cache,
                "sd_return",
                source,
                period,
                dateLength,
                end_date,
                live_execution,
                get_sd_returns,
            ),
        "Standard Deviation of Price" =>
            () -> get_cached_indicator(
                cache,
                "sd",
                source,
                period,
                dateLength,
                end_date,
                live_execution,
                get_sd,
            ),
    )

    if haskey(indicator_functions, indicator)
        return indicator_functions[indicator]()
    else
        throw(ArgumentError("Unknown indicator: $indicator"))
    end
end

function make_sort_branches(branches::Dict{String,Any})::Tuple{Dict{String,Any},Bool}
    extracted = Dict{String,Any}()
    folder_id = 1
    has_folders = false
    for (key::String, nodes::Vector{Dict{String,Any}}) in branches
        for node::Dict{String,Any} in nodes
            if node["type"] == "icon"
                continue
            end

            if node["type"] == "folder"
                extracted[string(folder_id)] = [node]
                folder_id += 1
                has_folders = true
            else
                extracted[string(folder_id)] = [node]
                folder_id += 1
            end
        end
    end
    return extracted, has_folders
end
function calculate_num_days(uncalculated_trading_days::Int)::Int
    return max(252, uncalculated_trading_days)
end

function apply_sort_function(
    branch_return_curves::Vector{Vector{Float64}}, sort_function::String, sort_window::Int
)
    branch_metrics = Vector{Vector{Float64}}(undef, length(branch_return_curves))

    for (idx, return_curve) in enumerate(branch_return_curves)
        if sort_function == "Relative Strength Index"
            branch_metrics[idx] = get_rsi_of_data(return_curve, sort_window)
        elseif sort_function == "Current Price"
            branch_metrics[idx] = return_curve
        elseif sort_function == "Cumulative Return"
            branch_metrics[idx] = get_cumulative_return_of_data(return_curve, sort_window)
        elseif sort_function == "Exponential Moving Average of Price"
            branch_metrics[idx] = get_ema_of_data(return_curve, sort_window)
        elseif sort_function == "Max Drawdown"
            branch_metrics[idx] = get_max_drawdown_of_data(return_curve, sort_window)
        elseif sort_function == "Moving Average of Price"
            branch_metrics[idx] = get_sma_of_data(return_curve, sort_window)
        elseif sort_function == "Simple Moving Average of Price"
            branch_metrics[idx] = get_sma_of_data(return_curve, sort_window)
        elseif sort_function == "Moving Average of Return"
            branch_metrics[idx] = get_sma_returns_of_data(return_curve, sort_window)
        elseif sort_function == "Standard Deviation of Return"
            branch_metrics[idx] = get_sd_return_of_data(return_curve, sort_window)
        elseif sort_function == "Standard Deviation of Price"
            branch_metrics[idx] = get_sd_of_data(return_curve, sort_window)
        else
            throw(ServerError(400, "Bad request: Unknown sort function: $sort_function"))
        end
    end

    return branch_metrics
end

function get_branches(node::Dict{String,Any})::Tuple{Dict{String,Any},Bool}
    if haskey(node, "branches") && isa(node["branches"], Dict)
        return make_sort_branches(node["branches"])
    else
        return Dict{String,Any}(), false
    end
end

function parse_select_properties(node::Dict{String,Any})::Tuple{Int,String}
    top_n = parse(Int, node["properties"]["select"]["howmany"])
    select_function = node["properties"]["select"]["function"]
    return top_n, select_function
end

function parse_sort_properties(node::Dict{String,Any})::Tuple{String,Int}
    sort_function = node["properties"]["sortby"]["function"]
    if isempty(node["properties"]["sortby"]["window"])
        sort_window = 0
    else
        sort_window = parse(Int, node["properties"]["sortby"]["window"])
    end
    return sort_function, sort_window
end

function find_matching_branch(branches, branch_name, branch_weight)
    tolerance = 0.01  # 0.01% tolerance
    for (key, value) in branches
        if startswith(key, branch_name)
            weight_str = match(r"\((.*?)%\)", key).captures[1]
            key_weight = parse(Float64, weight_str)
            if abs(key_weight - branch_weight) < tolerance
                return key, value
            end
        end
    end
    throw(ArgumentError("Branch with weight $branch_weight% does not exist"))
end

function truncate_to_common_period(
    branch_return_curves::Vector{Vector{Float64}}, min_data_length::Int
)::Vector{Vector{Float64}}
    return [curve[(end - min_data_length + 1):end] for curve in branch_return_curves]
end

function calculate_portfolio_values_single_curve(
    returns::Vector{Float64}, initial_value::Float64=10000.0
)::Vector{Float64}
    n = length(returns)
    portfolio_values = zeros(Float64, n)
    current_value = BigFloat(initial_value)
    scale_factor = BigFloat(10000)  # Scale factor for percentage conversion

    portfolio_values[1] = Float64(current_value)  # Initial value

    for i in 2:n
        if isnan(returns[i])
            portfolio_values[i] = portfolio_values[i - 1]
            continue
        end
        # Convert return to BigFloat
        return_value = BigFloat(returns[i]) / scale_factor

        # Update portfolio value
        current_value *= (1 + return_value)

        # Round to 2 decimal places and convert to Float64
        portfolio_values[i] = current_value
    end
    # TODO: try rounding after FOR loop
    return round.(portfolio_values; digits=6)
end

function calculate_portfolio_values(
    branch_return_curves::Vector{Vector{Float64}},
    min_data_length::Int,
    sort_function::String,
    cached_mapping::Dict{String,Float64},
)::Vector{Vector{Float64}}
    cumulative_returns = Vector{Vector{Float64}}()

    for (i, branch_return_curve) in enumerate(branch_return_curves)
        branch_cumulative_returns = Vector{Float64}()
        branch_cumulative_returns = calculate_portfolio_values_single_curve(
            branch_return_curve,
            if haskey(cached_mapping, string(i))
                Float64(cached_mapping[string(i)])
            else
                10000.0
            end,
        )
        push!(cumulative_returns, branch_cumulative_returns)
    end

    cumulative_returns = [curve .+ 100 for curve in cumulative_returns]

    return cumulative_returns
end

function read_portfolio_values(
    hash_key::String
)::Tuple{Dict{String,Vector{Float64}},Bool,Union{Date,Nothing}}
    result = Dict{String,Vector{Float64}}()
    filepath = "SubtreeCache/SyntheticReturns/$(hash_key).mmap"
    cached_date = nothing

    if isfile(filepath)
        try
            open(filepath, "r") do io
                # Read number of keys
                n_keys = read(io, UInt32)
                total_size = read(io, UInt32)

                # Read the end_date (stored as Int64 - days since epoch)
                date_days = read(io, Int64)
                # Convert days to Date using proper constructor
                cached_date = Date(Dates.rata2datetime(date_days))

                # Create memory map
                mmap_array = Mmap.mmap(io, Vector{UInt8}, total_size)
                pos = 1  # Julia uses 1-based indexing

                for _ in 1:n_keys
                    # Read key (numeric)
                    key_val = GC.@preserve mmap_array unsafe_load(
                        Ptr{UInt32}(pointer(mmap_array, pos))
                    )
                    pos += sizeof(UInt32)

                    # Convert to string
                    key = string(key_val)

                    # Read number of values
                    n_values = GC.@preserve mmap_array unsafe_load(
                        Ptr{UInt32}(pointer(mmap_array, pos))
                    )
                    pos += sizeof(UInt32)

                    # Read float values
                    values = Vector{Float64}(undef, n_values)
                    for j in 1:n_values
                        values[j] = GC.@preserve mmap_array unsafe_load(
                            Ptr{Float64}(pointer(mmap_array, pos))
                        )
                        pos += sizeof(Float64)
                    end

                    result[key] = values
                end

                return result, true, cached_date
            end
        catch e
            @warn "Failed to read memory-mapped data: $e"
            return Dict{String,Vector{Float64}}(), false, nothing
        end
    else
        return result, false, nothing
    end
end

function safe_remove_file(filepath)
    try
        GC.gc()
        if isfile(filepath)
            rm(filepath; force=true)
        end
    catch e
        @warn "Failed to remove file: $filepath" exception = e
    end
end

function cache_portfolio_values(
    data::Dict{String,Vector{Float64}},
    hash_key::String,
    end_date::Date,
    live_execution::Bool=false,
)::Bool
    try
        if isfile("SubtreeCache/SyntheticReturns/$(hash_key).mmap")
            safe_remove_file("SubtreeCache/SyntheticReturns/$(hash_key).mmap")
        end
        # Ensure directory exists
        mkpath(dirname("SubtreeCache/SyntheticReturns/$(hash_key).mmap"))

        # Adjust data if live_execution is true
        adjusted_data = Dict{String,Vector{Float64}}()
        if live_execution
            # Skip the last value for each key when in live execution mode
            for (key, values) in data
                if length(values) > 1
                    adjusted_data[key] = values[1:(end - 1)]
                else
                    adjusted_data[key] = Float64[]
                end
            end
            # Adjust end_date to be one day earlier
            end_date = end_date - Day(1)
        else
            adjusted_data = data
        end

        # Calculate total size
        total_size = sum(
            sizeof(UInt32) + sizeof(UInt32) + length(values) * sizeof(Float64) for
            values in values(adjusted_data)
        )

        open("SubtreeCache/SyntheticReturns/$(hash_key).mmap", "w+") do io
            # Write number of keys and total size
            write(io, UInt32(length(adjusted_data)))
            write(io, UInt32(total_size))

            # Write the end_date (as Int64 - days since epoch)
            # Convert Date to days since rata die (Julian day)
            write(io, Int64(Dates.datetime2rata(DateTime(end_date))))

            # Create memory map
            mmap_array = Mmap.mmap(io, Vector{UInt8}, total_size)
            pos = 1  # Julia uses 1-based indexing

            for (key_str, values) in adjusted_data
                # Parse key to numeric (UInt32)
                key = parse(UInt32, key_str)

                # Write key
                GC.@preserve mmap_array unsafe_store!(
                    Ptr{UInt32}(pointer(mmap_array, pos)), key
                )
                pos += sizeof(UInt32)

                # Write length of values
                GC.@preserve mmap_array unsafe_store!(
                    Ptr{UInt32}(pointer(mmap_array, pos)), UInt32(length(values))
                )
                pos += sizeof(UInt32)

                # Write float values
                for value in values
                    GC.@preserve mmap_array unsafe_store!(
                        Ptr{Float64}(pointer(mmap_array, pos)), value
                    )
                    pos += sizeof(Float64)
                end
            end

            # Ensure data is written to disk
            Mmap.sync!(mmap_array)
        end
        return true
    catch e
        @warn "Failed to write memory-mapped data: $e"
        return false
    end
end

end
