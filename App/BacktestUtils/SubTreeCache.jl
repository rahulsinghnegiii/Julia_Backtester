module SubtreeCache

using Dates
using Blobs
using Mmap
using DuckDB
using Parquet2
using DataFrames
using ..VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.GlobalServerCache
using ..VectoriseBacktestService.StockData.DatabaseManager

export set_portfolio_history,
    write_subtree_portfolio,
    read_subtree_portfolio,
    append_subtree_portfolio_in_parquet,
    write_subtree_portfolio_mmap,
    read_subtree_portfolio_mmem,
    read_subtree_portfolio_with_dates_mmem,
    append_subtree_portfolio_mmap,
    int2date,
    date2int,
    PortfolioEntry

const CACHE_DIR = "./SubtreeCache"

struct PortfolioEntry
    date::UInt32    # Packed date representation (YYYYMMDD)
    ticker::NTuple{5,UInt8}  # Keep the original ticker format
    weight::Float32
end

function read_subtree_portfolio_mmem(hash::String, end_date::Date, DIR::String=CACHE_DIR)
    try
        mmap_path = joinpath(DIR, "$(hash).mmap")
        isfile(mmap_path) || return nothing, nothing

        mmap_data = open(mmap_path, "r") do io
            Mmap.mmap(io, Vector{PortfolioEntry})
        end

        isempty(mmap_data) && return nothing, nothing

        end_date_int = date2int(end_date)
        filtered_data = filter(entry -> entry.date <= end_date_int, mmap_data)
        isempty(filtered_data) && return nothing, nothing

        df = DataFrame(;
            date=[int2date(entry.date) for entry in filtered_data],
            ticker=[strip(String(collect(entry.ticker))) for entry in filtered_data],
            weight=[entry.weight for entry in filtered_data],
        )

        grouped_data = groupby(df, :date)
        cached_portfolio_history = [
            DayData([StockInfo(row.ticker, row.weight) for row in eachrow(group)]) for
            group in grouped_data
        ]

        last_date = maximum(df.date)
        return cached_portfolio_history, last_date
    catch e
        throw(ErrorException("Error in read_subtree_portfolio: $(sprint(showerror, e))"))
    end
end

function read_subtree_portfolio_with_dates_mmem(hash::String, end_date::Date)
    try
        mmap_path = joinpath(CACHE_DIR, "$(hash).mmap")
        isfile(mmap_path) || return nothing, nothing, nothing

        mmap_data = open(mmap_path, "r") do io
            Mmap.mmap(io, Vector{PortfolioEntry})
        end

        isempty(mmap_data) && return nothing, nothing, nothing

        end_date_int = date2int(end_date)
        filtered_data = filter(entry -> entry.date <= end_date_int, mmap_data)
        isempty(filtered_data) && return nothing, nothing, nothing

        df = DataFrame(;
            date=[int2date(entry.date) for entry in filtered_data],
            ticker=[strip(String(collect(entry.ticker))) for entry in filtered_data],
            weight=[entry.weight for entry in filtered_data],
        )

        grouped_data = groupby(df, :date)
        cached_portfolio_history = [
            DayData([StockInfo(row.ticker, row.weight) for row in eachrow(group)]) for
            group in grouped_data
        ]
        cached_dates = [string(date) for date in unique(df.date)]

        last_date = maximum(df.date)
        return cached_portfolio_history, cached_dates, last_date
    catch e
        throw(ErrorException("Error in read_subtree_portfolio: $(sprint(showerror, e))"))
    end
end

function append_subtree_portfolio_mmap(
    date_range::Vector{String},
    end_date::Date,
    hash::String,
    common_data_span::Int,
    profile_history::Vector{DayData},
    live_execution::Bool=false,
)
    mmap_path = joinpath(CACHE_DIR, "$(hash).mmap")
    end_date_int = date2int(end_date)

    # Read existing data and find the actual last date
    last_existing_date = UInt32(0)
    if isfile(mmap_path)
        open(mmap_path, "r") do io
            existing_data = Mmap.mmap(io, Vector{PortfolioEntry})
            if !isempty(existing_data)
                last_existing_date = maximum(entry.date for entry in existing_data)
            end
        end
    end

    # Filter new data
    new_data_indices = findall(
        i -> date2int(Date(date_range[end - common_data_span + i])) > last_existing_date,
        1:common_data_span,
    )

    # If there's no new data to append, return early
    if isempty(new_data_indices)
        @info "No new data to append for node with hash $(hash)"
        return true
    end

    # Calculate the number of new entries
    new_entries = sum(
        length(profile_history[end - common_data_span + i].stockList) for
        i in new_data_indices
    )

    # Prepare new data
    new_data = Vector{PortfolioEntry}(undef, new_entries)
    idx = 1
    @inbounds for i in new_data_indices
        current_date_int = date2int(Date(date_range[end - common_data_span + i]))

        if live_execution && current_date_int == end_date_int
            continue
        end

        day_data = profile_history[end - common_data_span + i]
        @simd for stock in day_data.stockList
            ticker = stock.ticker
            ticker_tuple = (
                UInt8(ticker[1]),
                UInt8(get(ticker, 2, ' ')),
                UInt8(get(ticker, 3, ' ')),
                UInt8(get(ticker, 4, ' ')),
                UInt8(get(ticker, 5, ' ')),
            )
            new_data[idx] = PortfolioEntry(
                current_date_int, ticker_tuple, stock.weightTomorrow
            )
            idx += 1
        end
    end

    # Resize the vector to remove any unused entries
    resize!(new_data, idx - 1)

    # Append new data to the existing file
    open(mmap_path, "a+") do io
        write(io, new_data)
    end

    @info "Appended memory-mapped data for node with hash $(hash) up to $(end_date)"
    return true
end

function write_subtree_portfolio_mmap(
    date_range::Vector{String},
    end_date::Date,
    hash::String,
    common_data_span::Int,
    profile_history::Vector{DayData},
    live_execution::Bool=false,
)
    mmap_path = joinpath(CACHE_DIR, "$(hash).mmap")
    end_date_int = date2int(end_date)
    # println("Writing to mmap file: $mmap_path with end_date_int: $end_date_int")
    # Pre-allocate the portfolio_data vector
    total_entries = sum(
        length(day.stockList) for day in profile_history[(end - common_data_span + 1):end]
    )
    portfolio_data = Vector{PortfolioEntry}(undef, total_entries)

    # Pre-compute date integers
    date_ints = [date2int(Date(d)) for d in date_range[(end - common_data_span + 1):end]]

    idx = 1
    @inbounds for i in 1:common_data_span
        current_date_int = date_ints[i]

        if live_execution && current_date_int == end_date_int
            continue
        end

        day_data = profile_history[end - common_data_span + i]
        @simd for stock in day_data.stockList
            ticker = stock.ticker
            ticker_tuple = (
                UInt8(ticker[1]),
                UInt8(get(ticker, 2, ' ')),
                UInt8(get(ticker, 3, ' ')),
                UInt8(get(ticker, 4, ' ')),
                UInt8(get(ticker, 5, ' ')),
            )
            portfolio_data[idx] = PortfolioEntry(
                current_date_int, ticker_tuple, stock.weightTomorrow
            )
            idx += 1
        end
    end

    # Resize the vector to the actual number of entries used
    if idx > 1
        resize!(portfolio_data, idx - 1)

        # Write to file with proper error handling
        try
            open(mmap_path, "w+") do io
                write(io, portfolio_data)
                flush(io)  # Ensure data is written to disk

                # Only mmap if we have data to map
                if length(portfolio_data) > 0
                    seekstart(io)
                    mmap_data = Mmap.mmap(
                        io, Vector{PortfolioEntry}, length(portfolio_data)
                    )
                    Mmap.sync!(mmap_data)
                end
            end
            @info "Saved memory-mapped data for node with hash $(hash) up to $(end_date)"
            return true
        catch e
            @error "Failed to write memory-mapped data" exception = e
            return false
        end
    else
        @warn "No data to write for hash $(hash)"
        return false
    end
end

# Helper functions for date conversion
@inline date2int(d::Date) = UInt32(year(d)) << 16 | UInt32(month(d)) << 8 | UInt32(day(d))
@inline int2date(i::UInt32) = Date(i >> 16, (i >> 8) & 0xFF, i & 0xFF)

function set_portfolio_history(
    portfolio_history::Vector{DayData},
    subtree_portfolio_history::Vector{DayData},
    active_mask::BitVector,
    node_weight::Float32,
    common_data_span::Int,
)
    min_length = min(
        length(active_mask), length(subtree_portfolio_history), common_data_span
    )
    @inbounds for i in 1:min_length
        if active_mask[end - i + 1]
            for j in 1:length(subtree_portfolio_history[end - i + 1].stockList)
                stock_info = StockInfo(
                    subtree_portfolio_history[end - i + 1].stockList[j].ticker,
                    subtree_portfolio_history[end - i + 1].stockList[j].weightTomorrow *
                    node_weight,
                )
                push!(portfolio_history[end - i + 1].stockList, stock_info)
            end
        end
    end
    return nothing
end

function write_subtree_portfolio_to_parquet(
    dates_to_write::Vector{String},
    tickers_to_write::Vector{String},
    weights_to_write::Vector{Float32},
    hash::String,
    end_date::Date,
    dates::Vector{String},
    parquet_file_path::String,
)
    df = DataFrame(; date=dates_to_write, ticker=tickers_to_write, weight=weights_to_write)

    max_retries = 3
    retry_count = 0

    while retry_count < max_retries
        try
            parquet_dir = dirname(parquet_file_path)
            isdir(parquet_dir) || mkpath(parquet_dir)
            isfile(parquet_file_path) && rm(parquet_file_path; force=true)

            Parquet2.writefile(parquet_file_path, df)
            @info "Saved data to Parquet for node with hash $(hash) up to $(end_date)"
            return true
        catch e
            @error "Error writing to Parquet: $e"
            retry_count += 1
            if retry_count < max_retries
                @warn "Retrying... (Attempt $(retry_count + 1) of $max_retries)"
                sleep(2^retry_count)
            else
                @error "Failed to write data after $max_retries attempts"
                return false
            end
        end
    end
    return false
end

function write_subtree_portfolio(
    date_range::Vector{String},
    end_date::Date,
    hash::String,
    common_data_span::Int,
    profile_history::Vector{DayData},
    live_execution::Bool=false,
)
    # Pre-allocate vectors with estimated capacity
    total_size = sum(
        length(ph.stockList) for
        ph in @view profile_history[(end - common_data_span + 1):end]
    )
    dates_to_write = Vector{String}(undef, total_size)
    tickers_to_write = Vector{String}(undef, total_size)
    weights_to_write = Vector{Float32}(undef, total_size)

    idx = 1
    @inbounds for i in 1:common_data_span
        for stock in profile_history[end - common_data_span + i].stockList
            dates_to_write[idx] = date_range[end - common_data_span + i]
            tickers_to_write[idx] = stock.ticker
            weights_to_write[idx] = stock.weightTomorrow
            idx += 1
        end
    end
    if live_execution
        end_date_str = Dates.format(end_date, "yyyy-mm-dd")
        valid_indices = findall(x -> x != end_date_str, dates_to_write[1:end])

        return write_subtree_portfolio_to_parquet(
            dates_to_write[valid_indices],
            tickers_to_write[valid_indices],
            weights_to_write[valid_indices],
            hash,
            end_date,
            date_range,
            joinpath(CACHE_DIR, "$(hash).parquet"),
        )
    end

    return write_subtree_portfolio_to_parquet(
        dates_to_write,
        tickers_to_write,
        weights_to_write,
        hash,
        end_date,
        date_range,
        joinpath(CACHE_DIR, "$(hash).parquet"),
    )
end

function append_subtree_portfolio_in_parquet(
    subtree_portfolio::Vector{DayData},
    hash::String,
    end_date::Date,
    date_range::Vector{String},
    common_data_span::Int,
    live_execution::Bool=false,
)
    try
        existing_portfolio = read_subtree_parquet_with_duckdb(
            hash, end_date, joinpath(CACHE_DIR, "$(hash).parquet")
        )

        isnothing(existing_portfolio) && return false

        last_cached_date = Date(last(existing_portfolio.date))
        last_cached_date >= end_date && return true

        # Pre-allocate vectors with estimated capacity
        total_size = sum(
            length(ph.stockList) for
            ph in @view subtree_portfolio[(end - common_data_span + 1):end]
        )
        dates_to_write = Vector{String}(undef, total_size)
        tickers_to_write = Vector{String}(undef, total_size)
        weights_to_write = Vector{Float32}(undef, total_size)

        idx = 1
        @inbounds for i in 1:common_data_span
            for stock in subtree_portfolio[end - common_data_span + i].stockList
                dates_to_write[idx] = date_range[end - common_data_span + i]
                tickers_to_write[idx] = string(stock.ticker)
                weights_to_write[idx] = Float32(stock.weightTomorrow)
                idx += 1
            end
        end
        resize!(dates_to_write, idx - 1)
        resize!(tickers_to_write, idx - 1)
        resize!(weights_to_write, idx - 1)
        # Find unique dates and their indices
        unique_dates = unique(dates_to_write)
        unique_indices = findall(x -> Date(x) > last_cached_date, Date.(unique_dates))

        # Create a mask for the original array
        mask = map(x -> Date(x) > last_cached_date, dates_to_write)

        # Apply the mask to all arrays
        dates_to_write = dates_to_write[mask]
        tickers_to_write = tickers_to_write[mask]
        weights_to_write = weights_to_write[mask]

        existing_dates = string.(existing_portfolio.date)
        new_dates = string.(dates_to_write)
        # Convert existing data to proper types
        combined_dates = Vector{String}(vcat(existing_dates, new_dates))
        combined_tickers = Vector{String}(vcat(existing_portfolio.ticker, tickers_to_write))
        combined_weights = Vector{Float32}(
            vcat(existing_portfolio.weight, weights_to_write)
        )
        all_dates = Vector{String}(vcat(existing_dates, new_dates))
        # if live execution, write the data to the cache from 1:end - 1
        if live_execution
            return write_subtree_portfolio_to_parquet(
                combined_dates[1:(end - 1)],
                combined_tickers[1:(end - 1)],
                combined_weights[1:(end - 1)],
                hash,
                end_date,
                all_dates,
                joinpath(CACHE_DIR, "$(hash).parquet"),
            )
        end
        # Write the combined data to the Parquet file
        return write_subtree_portfolio_to_parquet(
            combined_dates,
            combined_tickers,
            combined_weights,
            hash,
            end_date,
            all_dates,
            joinpath(CACHE_DIR, "$(hash).parquet"),
        )
    catch e
        if hasproperty(e, :msg)
            throw(ErrorException("Error in append_subtree_portfolio_in_parquet: " * e.msg))
        else
            throw(ErrorException("Error in append_subtree_portfolio_in_parquet"))
        end
    end
end

function read_subtree_parquet_with_duckdb(
    hash::String, end_date::Date, parquet_file_path::String
)::Union{DataFrame,Nothing}
    isfile(parquet_file_path) || return nothing

    query = """
    SELECT date, ticker, weight
    FROM read_parquet('$parquet_file_path')
    WHERE date <= '$end_date'
    ORDER BY date DESC
    """

    # Get thread-local connection
    db_conn = DatabaseManager.get_thread_connection()

    for attempt in 1:3
        try
            result = DuckDB.execute(db_conn, query)
            df = DataFrame(result)
            df.date = Date.(df.date, dateformat"yyyy-mm-dd")
            isempty(df) && return nothing
            return reverse!(df)
        catch e
            if attempt == 3
                @error "Error reading from DuckDB after 3 attempts: $e" exception = (
                    e, catch_backtrace()
                )
                return nothing
            end
            sleep(0.5 * (2^(attempt - 1)))
        end
    end
    return nothing
end

function read_subtree_portfolio(hash::String, end_date::Date)
    try
        cached_portfolio_history = get_subtree_data("$(hash)_$(end_date)")
        if !isnothing(cached_portfolio_history)
            #println("Using :RU cached portfolio for hash: $hash")
            return cached_portfolio_history, end_date
        end
        cached_portfolio = read_subtree_parquet_with_duckdb(
            hash, end_date, joinpath(CACHE_DIR, "$(hash).parquet")
        )

        if cached_portfolio === nothing
            return nothing, nothing
        end
        #println("Reading from Parquet for hash: $hash")

        if !all(col -> hasproperty(cached_portfolio, col), [:ticker, :weight, :date])
            throw(ErrorException("Missing required columns in cached portfolio"))
        end

        # Pre-allocate the vector with the exact size needed
        n_unique_dates = length(unique(cached_portfolio.date))
        cached_portfolio_history = Vector{DayData}(undef, n_unique_dates)

        # Group the data by date more efficiently
        grouped_data = groupby(cached_portfolio, :date)

        @inbounds for (i, group_df) in enumerate(grouped_data)
            # Pre-allocate stock_list with exact size
            stock_list = Vector{StockInfo}(undef, nrow(group_df))

            # Fill stock_list directly
            for (j, row) in enumerate(eachrow(group_df))
                stock_list[j] = StockInfo(row.ticker, row.weight)
            end

            cached_portfolio_history[i] = DayData(stock_list)
        end
        cache_subtree_data("$(hash)_$(end_date)", cached_portfolio_history)
        return cached_portfolio_history, Date(last(cached_portfolio.date))
    catch e
        if hasproperty(e, :msg)
            throw(ErrorException("Error in read_subtree_returns: " * e.msg))
        else
            throw(ErrorException("Error in read_subtree_returns"))
        end
    end
end

end
