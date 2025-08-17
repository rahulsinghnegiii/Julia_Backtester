module CloudNode
using HTTP
using Base64
using Dates, DataFrames, JSON
using ..VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.FlowData
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.TimeCalculation
using ..VectoriseBacktestService.BacktestUtilites

export process_cloud_node, get_json_from_server, read_json

# "url": "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/temp.json",
# "url": "http://localhost:8080/",

function get_json_from_server(
    url::String, username::Union{String,Nothing}, password::Union{String,Nothing}
)::Union{HTTP.Response,Nothing}
    # Validate URL format
    try
        parsed_url = HTTP.URIs.URI(url)
        if isnothing(parsed_url.host)
            println("Invalid URL: No host found in $url")
            return nothing
        end
    catch e
        println("Invalid URL format: $e")
        return nothing
    end

    # Check if credentials are provided
    headers = Dict{String,String}()
    if !isempty(username) && !isempty(password)
        credentials = base64encode("$username:$password")
        headers["Authorization"] = "Basic $credentials"
    else
        println(
            "No credentials provided. Attempting to access $url without authentication."
        )
    end

    max_retries = 3
    attempt = 0

    while attempt < max_retries
        attempt += 1
        try
            println("Attempt $attempt to fetch JSON from $url")
            response = HTTP.get(url; headers=headers, retries=0)  # Disable automatic retries

            # Check response status
            if response.status == 200
                println("Successfully retrieved JSON.")
                return response
            elseif response.status == 401
                println("Unauthorized: $(response.status). Authentication is required.")
                throw(
                    ServerError(401, "Unauthorized: Invalid credentials for accessing $url")
                )
            elseif response.status == 403
                println("Access forbidden: $(response.status).")
                throw(
                    ServerError(
                        403,
                        "Access forbidden: $(response.status). Please check the URL or parameters.",
                    ),
                )
            elseif response.status == 404
                println("Resource not found: $(response.status).")
                throw(
                    ServerError(
                        404,
                        "Resource not found: $(response.status). Please check the URL or parameters.",
                    ),
                )
            elseif 405 <= response.status < 500
                println("Client error: $(response.status). Retrying...")
            elseif 500 <= response.status < 600
                println("Server error: $(response.status). Retrying...")
            else
                println("Unexpected response status: $(response.status). Retrying...")
            end
        catch e
            if isa(e, HTTP.Exceptions.TimeoutError)
                if attempt == max_retries
                    println(
                        "Timeout error: Unable to retrieve JSON from $url after $max_retries attempts",
                    )
                    return nothing
                else
                    println("Timeout occurred on attempt $attempt. Retrying...")
                end
            elseif isa(e, HTTP.Exceptions.ConnectError)
                if attempt == max_retries
                    println(
                        "Connection error: Unable to reach $url. Please check if the server is live.",
                    )
                    return nothing
                else
                    println("Connection error on attempt $attempt. Retrying...")
                end
            elseif isa(e, HTTP.Exceptions.RequestError)
                println("Request error: $e")
                return nothing
            elseif isa(e, HTTP.Exceptions.StatusError)
                println("Status error: $e")
                return nothing
            else
                println("Unexpected error: $e")
                return nothing
            end
        end

        sleep(2)  # Wait before retrying
    end

    throw(
        ServerError(500, "Failed to retrieve JSON from server after $max_retries attempts")
    )
end

# we need to read temp.json and convert it to a dictionary
function read_json(response_json::HTTP.Response)::Dict{String,Float32}
    # Read and parse the response body
    try
        f = String(response_json.body)
        raw_data = JSON.parse(f)  # Attempt to parse JSON

        # Validate and process JSON
        processed_data = Dict{String,Float32}()
        total_weight = 0.0

        # Add check if json is empty
        if length(raw_data) == 0
            throw(ServerError(400, "JSON is empty. Please provide a valid JSON with data."))
        end

        if !(
            isa(raw_data, Dict) &&
            all(isa(k, String) && isa(v, Number) for (k, v) in raw_data)
        )
            throw(
                ServerError(
                    400,
                    "Invalid JSON structure. JSON must be a flat dictionary with {string: number} format.",
                ),
            )
        end

        # Convert keys to uppercase and aggregate duplicates
        for (key, value) in raw_data
            # Convert key to uppercase
            ticker = uppercase(key)

            # Ensure value is a valid number
            if !isa(value, Number)
                throw(
                    ServerError(
                        400,
                        "Invalid value type for key '$key'. All values must be numbers.",
                    ),
                )
            end
            if !isa(key, String)
                throw(
                    ServerError(
                        400, "Invalid key type for key '$key'. All keys must be strings."
                    ),
                )
            end

            # Aggregate duplicate tickers
            if haskey(processed_data, ticker)
                processed_data[ticker] += value
            else
                processed_data[ticker] = value
            end
        end

        # Ensure the total number of keys doesn't exceed 20
        if length(processed_data) > 20
            throw(ServerError(400, "JSON contains more than 20 keys."))
        end

        # Validate that all weights sum up to 100
        total_weight = sum(values(processed_data))
        if total_weight != 100.0
            throw(
                ServerError(
                    400,
                    "The total weights of all keys must add up to 100. Current total: $total_weight",
                ),
            )
        end

        return processed_data
    catch err
        # Catch syntax errors or malformed JSON
        throw(ServerError(400, "Error parsing JSON: $(err.message)"))
    end
end

function validate_node(cloud_node::Dict{String,Any})
    if !haskey(cloud_node["properties"], "url") ||
        !isa(cloud_node["properties"]["url"], String)
        throw(
            ServerError(400, "Bad request: Invalid or missing url in cloud node properties")
        )
    end

    if !haskey(cloud_node["properties"], "isPasswordProtected") ||
        !isa(cloud_node["properties"]["isPasswordProtected"], Bool)
        throw(
            ServerError(
                400,
                "Bad request: Invalid or missing isPasswordProtected in cloud node properties",
            ),
        )
    end

    if cloud_node["properties"]["isPasswordProtected"] == true
        if !haskey(cloud_node["properties"], "credentials") ||
            !isa(cloud_node["properties"]["credentials"], Dict)
            throw(
                ServerError(
                    400,
                    "Bad request: Invalid or missing credentials in cloud node properties",
                ),
            )
        end
        if !haskey(cloud_node["properties"]["credentials"], "username") ||
            !isa(cloud_node["properties"]["credentials"]["username"], String)
            throw(
                ServerError(
                    400,
                    "Bad request: Invalid or missing username in cloud node credentials",
                ),
            )
        end
        if !haskey(cloud_node["properties"]["credentials"], "password") ||
            !isa(cloud_node["properties"]["credentials"]["password"], String)
            throw(
                ServerError(
                    400,
                    "Bad request: Invalid or missing password in cloud node credentials",
                ),
            )
        end
    end
end

function process_cloud_node(
    cloud_node::Dict{String,Any},
    active_branch_mask::BitVector,
    total_days::Int,
    node_weight::Float32,
    portfolio_history::Vector{DayData},
    date_range::Vector{String},
    end_date::Date,
    price_cache::Dict{String,DataFrame},
    live_execution::Bool=false,
)::Int
    try
        validate_node(cloud_node)
        """
        {
        "properties": {
            "isInvalid": false,
            "url": "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/temp.json",
            isPasswordProtected: true,
            credentials: {
                "username": "fsdev87",
                "password": "1234"
            }
        }
        """

        min_data_length::Int = total_days
        url::String = cloud_node["properties"]["url"]
        # Get username and password
        username = get(cloud_node["properties"]["credentials"], "username", nothing)
        password = get(cloud_node["properties"]["credentials"], "password", nothing)

        json::HTTP.Response = get_json_from_server(url, username, password)

        # Check if JSON is retrieved successfully
        if isnothing(json)
            throw(ServerError(400, "Failed to retrieve JSON from server"))
        end

        data::Dict{String,Float32} = read_json(json)

        for day::Int in findall(active_branch_mask)
            for (key, value) in data
                push!(
                    portfolio_history[end - min_data_length + day].stockList,
                    StockInfo(key, (value * node_weight) / 100),
                )
            end
        end

        for ticker in keys(data)
            price_data = get_cached_value_df(
                ticker,
                price_cache,
                Date(date_range[1]),
                end_date,
                () -> get_price_dataframe(ticker, total_days, Date(date_range[end])),
            )
            # case if no data available is already handled in get_cached_value_df()
            min_data_length = min(min_data_length, price_data.original_length[1])
        end

        return min_data_length
    catch e
        if isa(e, ServerError)
            rethrow(e)
        else
            throw(ServerError(400, "Internal server error: Failed to process cloud node"))
        end
    end
end

end
