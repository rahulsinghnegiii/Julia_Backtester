using Genie, Genie.Renderer.Json, Genie.Requests, Genie.Router
using MsgPack
using HTTP
include("vec_backtest_service.jl")

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
Genie.config.cors_allowed_origins = ["*"]  # Consider specifying domains in production

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

        if isnothing(json) ||
            isnothing(period) ||
            isnothing(end_date_str) ||
            isnothing(hash)
            return Genie.Renderer.Json.json("error" => "Missing required fields")
        end

        period = parse(Int, period)
        end_date = Date(end_date_str)

        json_data = JSON.parse(string(json))
        result = @time handle_backtesting_api(json_data, period, hash, end_date)
        println("^time for handle_backtesting_api")
        return Genie.Renderer.Json.json(result)
    catch e
        return Genie.Renderer.Json.json(
            Dict("error" => "Invalid input or server error", "details" => string(e))
        )
    end
end

function msgpack_response(data)
    response = MsgPack.pack(data)
    return response
end

route("/flow"; method=POST) do
    try
        payload = jsonpayload()
        json = get(payload, "json", nothing)
        period = get(payload, "period", nothing)
        end_date_str = get(payload, "end_date", nothing)

        if isnothing(json) || isnothing(period) || isnothing(end_date_str)
            return HTTP.Response(
                400, msgpack_response(Dict("error" => "Missing required fields"))
            )
        end

        period = parse(Int, period)
        end_date = Date(end_date_str)

        json_data = JSON.parse(string(json))
        result = handle_flow_api(json_data, period, end_date)
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

PORT = 5004
up(PORT, "0.0.0.0"; async=true)

while true
    sleep(1)
end
