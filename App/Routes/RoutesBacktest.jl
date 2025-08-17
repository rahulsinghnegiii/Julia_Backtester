include("../Main.jl")
include("../FlowMap.jl")
include("./RoutesTA.jl")
include("../Utils/RoutesBacktestUtils.jl")

using .FlowMap
using Dates, JSON, HTTP, JSON3, Oxygen
using ..VectoriseBacktestService
using .VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.GlobalServerCache
initialize_server_cache()
# ----- Backtesting Routes ----- #
@get "/" function ()
    return "Welcome to the backtesting service"
end

# Define a struct for request validation
# Modified struct with optional live_execution
struct BacktestRequest
    json_data::Dict{String,Any}
    period::Int
    hash::String
    end_date::Date
    live_execution::Bool  # New field

    # Inner constructor with default value for live_execution
    function BacktestRequest(
        json_data::Dict{String,Any},
        period::Int,
        hash::String,
        end_date::Date,
        live_execution::Bool=false,  # Default value
    )
        return new(json_data, period, hash, end_date, live_execution)
    end
end

# Modified constructor for validation and parsing
function BacktestRequest(data::JSON3.Object)
    # Validate required fields
    required_fields = (:json, :hash, :period, :end_date)
    missing_fields = filter(f -> !haskey(data, f), required_fields)

    if !isempty(missing_fields)
        throw(
            ValidationError(
                "Missing required fields", Dict(string(f) => true for f in missing_fields)
            ),
        )
    end

    # Parse JSON data once
    json_data = try
        JSON3.read(data.json, Dict{String,Any})
    catch e
        throw(ValidationError("Invalid JSON data format", e))
    end

    # Parse period
    period = try
        parse(Int, data.period)
    catch e
        throw(ValidationError("Invalid period format", e))
    end

    # Parse end_date
    end_date = try
        Date(data.end_date)
    catch e
        throw(ValidationError("Invalid date format", e))
    end

    # Parse live_execution if present, otherwise use default
    live_execution = if haskey(data, :live_execution)
        try
            # Handle different possible boolean representations
            live_exec = data.live_execution
            if isa(live_exec, String)
                if lowercase(live_exec) ∈ ["true", "1", "yes"]
                    true
                elseif lowercase(live_exec) ∈ ["false", "0", "no"]
                    false
                else
                    throw(ArgumentError("Invalid boolean string"))
                end
            elseif isa(live_exec, Bool)
                live_exec
            elseif isa(live_exec, Number)
                Bool(live_exec)
            else
                throw(ArgumentError("Invalid boolean value"))
            end
        catch e
            throw(ValidationError("Invalid live_execution format", e))
        end
    else
        false  # Default value
    end

    return BacktestRequest(json_data, period, data.hash, end_date, live_execution)
end

function FlowMapRequest(data::JSON3.Object)
    required_fields = (:json, :node_children_hash, :end_date, :path)
    missing_fields = filter(f -> !haskey(data, f), required_fields)

    if !isempty(missing_fields)
        throw(
            ValidationError(
                "Missing required fields", Dict(string(f) => true for f in missing_fields)
            ),
        )
    end

    hash = data.node_children_hash
    end_date = try
        Date(data.end_date)
    catch e
        throw(ValidationError("Invalid date format", e))
    end

    return hash, end_date
end
function update_cache_execution_mode(live_execution::Bool)
    cache_manager = GlobalServerCache.CACHE_MANAGER[]

    # Only update if the execution mode has changed
    if cache_manager.live_execution != live_execution
        cache_manager.initialized = false
        cleanup_cache()

        # Initialize with appropriate settings
        if live_execution
            initialize_server_cache(; max_age=Minute(10), live_execution=true)
        else
            initialize_server_cache()
        end
    end
end

# Optimized endpoint function
@post "/backtest" function (req::HTTP.Request)
    try
        # Parse request body once using JSON3
        body = JSON3.read(req.body)

        # Validate and construct request object
        request = BacktestRequest(body)

        # Update cache execution mode if needed
        update_cache_execution_mode(request.live_execution)

        result = handle_backtesting_api(
            request.json_data,
            request.period,
            request.hash,
            request.end_date,
            request.live_execution,
        )

        return HTTP.Response(
            200, ["Content-Type" => "application/json"], JSON3.write(result)
        )
    catch e
        @error "Error in backtest endpoint" exception = (e, catch_backtrace())

        if e isa BacktestError
            status, response = create_error_response(e)
        else
            status = 500
            response = Dict(
                "error" => "InternalServerError",
                "message" => "An unexpected error occurred",
                "details" => string(e),
            )
        end

        return HTTP.Response(
            status, ["Content-Type" => "application/json"], JSON3.write(response)
        )
    end
end

# Helper function to create error responses
function create_error_response(error::BacktestError)
    response = Dict(
        "error" => typeof(error).name.name,
        "message" => isa(error, ServerError) ? error.message : error.message,
        "details" => isa(error, ServerError) ? error.details : error.details,
    )

    status = isa(error, ServerError) ? error.status : 400
    return status, response
end

struct FlowRequest
    json::Dict{String,Any}
    node_children_hash::String
    path::String
    end_date::Date

    function FlowRequest(
        json::Dict{String,Any}, node_children_hash::String, path::String, end_date::Date
    )
        return new(json, node_children_hash, path, end_date)
    end
end

# Constructor for FlowRequest
function FlowRequest(data::JSON3.Object)
    # Validate required fields
    required_fields = ["json", "node_children_hash", "path", "end_date"]
    for field in required_fields
        if !haskey(data, field)
            throw(ArgumentError("Missing required field: $field"))
        end
    end

    json_data = try
        JSON3.read(data.json, Dict{String,Any})
    catch e
        throw(ArgumentError("Invalid JSON data format in 'json' field ($e)"))
    end

    node_children_hash = data.node_children_hash
    path = data.path

    # Parse end_date to Date type
    end_date = try
        Date(data.end_date)
    catch e
        throw(ArgumentError("Invalid date format in 'end_date' field ($e)"))
    end

    return FlowRequest(json_data, node_children_hash, path, end_date)
end

@post "/flow" function (req::HTTP.Request)
    try
        # Parse request body
        body = JSON3.read(req.body)

        # Extract and validate fields
        request = FlowRequest(body)

        # Call get_flow_graph with correct types
        delta_curve, date_range, trade_count = get_flow_graph(
            request.json, request.path, request.node_children_hash, request.end_date
        )

        result = Dict(
            "delta_curve" => delta_curve,
            "date_range" => date_range,
            "trade_count" => trade_count,
        )

        return HTTP.Response(
            200, ["Content-Type" => "application/json"], JSON3.write(result)
        )
    catch e
        @error "Error in flow endpoint" exception = (e, catch_backtrace())

        if e isa ArgumentError
            status = 400
            response = Dict("error" => "BadRequest", "message" => e.msg)
        elseif e isa BacktestError
            status, response = create_error_response(e)
        else
            status = 500
            response = Dict(
                "error" => "InternalServerError",
                "message" => "An unexpected error occurred",
                "details" => string(e),
            )
        end

        return HTTP.Response(
            status, ["Content-Type" => "application/json"], JSON3.write(response)
        )
    end
end
