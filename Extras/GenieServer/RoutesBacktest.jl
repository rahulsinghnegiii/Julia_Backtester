include("vec_backtest_service.jl")
include("Utils/RoutesBacktestUtils.jl")
using Genie, Genie.Router, Dates, JSON, HTTP
# ----- Backtesting Routes ----- #

# Handling preflight requests
route("/"; method=OPTIONS) do
    return ""
end

route("/backtest"; method=OPTIONS) do
    return ""
end

route("/flow"; method=OPTIONS) do
    return ""
end

route("/"; method=GET) do
    return "Welcome to the backtesting service"
end

route("/backtest"; method=POST) do
    try
        payload = jsonpayload()
        json = get(payload, "json", nothing)
        hash = get(payload, "hash", nothing)
        period = get(payload, "period", nothing)
        end_date_str = get(payload, "end_date", nothing)
        json_data::Dict{String,Any} = Dict()
        end_date::Date = Date("2000-01-01")

        if isnothing(json) ||
            isnothing(period) ||
            isnothing(end_date_str) ||
            isnothing(hash)
            response_body = JSON.json(
                Dict(
                    "error" => "Missing required fields",
                    "missing_fields" => Dict(
                        "json" => isnothing(json),
                        "period" => isnothing(period),
                        "end_date" => isnothing(end_date_str),
                        "hash" => isnothing(hash),
                    ),
                ),
            )
            res = HTTP.Messages.Response(
                400, ["Content-Type" => "application/json"], response_body
            )
            return res
        end

        try
            period = parse(Int, period)
        catch e
            response_body = JSON.json(
                Dict("error" => "Invalid period format", "details" => string(e))
            )
            res = HTTP.Messages.Response(
                400, ["Content-Type" => "application/json"], response_body
            )
            return res
        end

        try
            end_date = Date(end_date_str)
        catch e
            response_body = JSON.json(
                Dict("error" => "Invalid date format", "details" => string(e))
            )
            res = HTTP.Messages.Response(
                400, ["Content-Type" => "application/json"], response_body
            )
            return res
        end

        try
            json_data = JSON.parse(string(json))
        catch e
            response_body = JSON.json(
                Dict("error" => "Invalid JSON format", "details" => string(e))
            )
            res = HTTP.Messages.Response(
                400, ["Content-Type" => "application/json"], response_body
            )
            return res
        end
        result = @time handle_backtesting_api(json_data, period, hash, end_date)
        println("^time for handle_backtesting_api")
        response_body = JSON.json(result)
        res = HTTP.Messages.Response(
            200, ["Content-Type" => "application/json"], response_body
        )
        return res
    catch e
        # Log the error for debugging purposes
        @error "Server error: $e"
        response_body = JSON.json(Dict("error" => "Server error", "details" => string(e)))
        res = HTTP.Messages.Response(
            500, ["Content-Type" => "application/json"], response_body
        )
        return res
    end
end

route("/flow"; method=POST) do
    try
        payload = jsonpayload()
        hash = get(payload, "hash", nothing)
        end_date = get(payload, "end_date", nothing)

        if isnothing(hash) || isnothing(end_date)
            return HTTP.Response(
                400,
                msgpack_response(
                    Dict(
                        "error" => "Missing required fields",
                        "missing_fields" => Dict(
                            "hash" => isnothing(hash), "end_date" => isnothing(end_date)
                        ),
                    ),
                ),
            )
        end
        end_date = Date(end_date)
        result = handle_flow_api(hash, end_date)
        return HTTP.Response(200, msgpack_response(result))
    catch e
        return HTTP.Response(
            500,
            msgpack_response(
                Dict("error" => "Invalid input or server error", "details" => string(e))
            ),
        )
    end
end
