module GlobalCache

using ..VectoriseBacktestService
using JSON, Dates, Serialization, HTTP
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.TimeCalculation
using ..VectoriseBacktestService.BacktestUtilites
using ..VectoriseBacktestService.MarketTechnicalsIndicators
using ..VectoriseBacktestService.ErrorHandlers: ServerError

export get_or_create_cached_json_data,
    cache_results,
    get_cached_results,
    cache_flow_data,
    get_cached_flow_data,
    cache_data,
    get_cached_data,
    update_cached_response

function get_cached_flow_data(hash::String, end_date::Date)
    dir_path::String = "./Cache/" * hash
    file_path::String = dir_path * "/" * string(end_date) * "-flow.json"
    # Check if the directory exists
    if isdir(dir_path)
        if isfile(file_path)
            json_data = JSON.parsefile(file_path)
            return json_data
        end
    else
        #println("directory does not exist")
        return nothing
    end
end

function cache_flow_data(
    hash::String, end_date::Date, flow_data::Dict{String,Dict{String,Any}}
)
    try
        dir_path::String = "./Cache/" * hash
        # Check if the directory exists
        if !isdir(dir_path)
            # Create the directory if it doesn't exist
            mkpath(dir_path)
        end

        # Convert the dictionary to a JSON string
        json_str = JSON.json(flow_data)

        # Specify the file path
        file_path = dir_path * "/" * string(end_date) * "-flow.json"

        # Open the file in write mode and write the JSON string to it
        open(file_path, "w") do file
            write(file, json_str)
        end
    catch e
        @error "Failed to cache flow data: $e"
        throw(ServerError(400, "Internal server error: Failed to cache flow data $e"))
    end
end

function get_or_create_cached_json_data(json_path::String)::Dict{String,Any}
    # Create a cache directory if it doesn't exist
    cache_dir = joinpath(dirname(json_path), "cache")
    mkpath(cache_dir)

    # Generate a cache file name based on the input json file
    cache_file = joinpath(cache_dir, basename(json_path) * ".jls")

    if isfile(cache_file)
        # If cache file exists, deserialize and return it
        return open(cache_file, "r") do io
            deserialize(io)
        end
    else
        # If cache file doesn't exist, read the JSON file
        json_data = read_json_file(json_path)

        # Serialize the data to the cache file
        open(cache_file, "w") do io
            serialize(io, json_data)
        end

        return json_data
    end
end

function cache_results(hash::String, response)
    dir_path = joinpath(".", "Cache", hash)

    # Create the directory if it doesn't exist
    try
        mkpath(dir_path)
    catch e
        @warn "Failed to create directory: $dir_path. Error: $e"
        return nothing
    end

    # Specify the file path
    file_path = joinpath(dir_path, hash * ".json")

    # Convert the dictionary to a JSON string
    json_str = JSON.json(response)

    try
        open(file_path, "w") do file
            write(file, json_str)
        end
        @info "Successfully wrote to file: $file_path"
    catch e
        @error "Failed to write to file: $file_path. Error: $e"
    end
end
function get_cached_results(hash::String)::Union{Dict{String,Vector},Nothing}
    dir_path::String = "./Cache/" * hash
    file_path::String = dir_path * "/" * hash * ".json"

    # Check if the directory exists
    if isdir(dir_path)
        if isfile(file_path)
            # Read json file and return the data
            json_data = read(file_path)
            # Convert Vector{UInt8} to String before parsing
            json_string = String(json_data)
            json_return::Dict{String,Vector} = JSON.parse(json_string)
            return json_return
        end
    else
        #println("Directory does not exist")
        return nothing
    end
end

function update_cached_response(
    cached_response::Dict{String,Vector},
    return_curve::Vector{Float32},
    dates::Vector{String},
    uncalculated_trading_days::Int,
    profile_history::Vector{DayData},
)::Dict{String,Vector}

    # see the last date of the cached response and append the new data according to that
    last_date = Date(cached_response["dates"][end])
    indexes_to_append = findall(x -> Date(x) > last_date, Date.(dates))

    if length(indexes_to_append) == 0
        return cached_response
    end
    append!(cached_response["returns"], return_curve[(indexes_to_append[1]:end)])
    append!(cached_response["dates"], dates[(indexes_to_append[1]:end)])
    append!(cached_response["profile_history"], profile_history[(indexes_to_append[1]:end)])
    return cached_response
end

function cache_data(
    hash::String,
    response::Dict{String,Vector},
    end_date::Date,
    flow_data::Dict{String,Dict{String,Any}},
)::Nothing
    @maybe_time cache_results(hash, response)
    @maybe_time cache_flow_data(hash, end_date, flow_data)
    #println("^Time for cache_results")
    return nothing
end

function get_cached_data(
    hash::String, end_date::Date, live_data::Bool=false
)::Tuple{Union{Nothing,Dict{String,Vector}},Int,Bool}
    cached_response::Union{Nothing,Dict{String,Vector}} = @maybe_time get_cached_results(
        hash
    )
    #println("^Time for get_cached_results")

    if cached_response === nothing
        return nothing, 0, false
    end

    last_cached_date::Date = Date(cached_response["dates"][end])
    if last_cached_date >= end_date
        #println("returning cached response")
        return cached_response, 0, true
    end

    #println("cached response is missing required data")
    uncalculated_trading_days::Int = get_trading_days(
        "SPY", last_cached_date, end_date, live_data
    )
    if uncalculated_trading_days == 0
        return cached_response, 0, true
    end
    return cached_response, uncalculated_trading_days, false
end

end
