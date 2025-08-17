using HTTP

function warmup_ticker_date(ticker::String, date::String, endpoint::String, url::String)
    url_req = url * endpoint * "?ticker=$ticker&date=$date"

    response = HTTP.get(url_req)

    if response.status == 200
        println("Warmup $endpoint request successful.")
    else
        println("Warmup $endpoint request unsuccessful.")
    end
end

function warmup_data_ticker_enddate(
    ticker::String, close_prices::Vector{Float64}, endpoint::String, url::String
)
    close_prices_str = join(close_prices, ',')
    url_req = url * endpoint * "?ticker=$ticker&close_prices=$close_prices_str"

    response = HTTP.get(url_req)

    if response.status == 200
        println("Warmup $endpoint request successful.")
    else
        println("Warmup $endpoint request unsuccessful.")
    end
end

function warmup_data_ticker_period_enddate(
    ticker::String,
    period::Int,
    close_prices::Vector{Float64},
    endpoint::String,
    url::String,
)
    close_prices_str = join(close_prices, ',')
    url_req =
        url * endpoint * "?ticker=$ticker&period=$period&close_prices=$close_prices_str"

    response = HTTP.get(url_req)

    if response.status == 200
        println("Warmup $endpoint request successful.")
    else
        println("Warmup $endpoint request unsuccessful.")
    end
end

function warmup_ticker_length_period_enddate(
    ticker::String,
    length::Int,
    period::Int,
    end_date::String,
    endpoint::String,
    url::String,
)
    url_req =
        url * endpoint * "?ticker=$ticker&length=$length&period=$period&end_date=$end_date"

    response = HTTP.get(url_req)

    if response.status == 200
        println("Warmup $endpoint request successful.")
    else
        println("Warmup $endpoint request unsuccessful.")
    end
end

function warmup_ticker_date_period(
    ticker::String, date::String, period::Int, endpoint::String, url::String
)
    url_req = url * endpoint * "?ticker=$ticker&date=$date&period=$period"

    response = HTTP.get(url_req)

    if response.status == 200
        println("Warmup $endpoint request successful.")
    else
        println("Warmup $endpoint request unsuccessful.")
    end
end

function warmup_ticker_period_enddate(
    ticker::String, period::Int, end_date::String, endpoint::String, url::String
)
    url_req = url * endpoint * "?ticker=$ticker&period=$period&end_date=$end_date"

    response = HTTP.get(url_req)

    if response.status == 200
        println("Warmup $endpoint request successful.")
    else
        println("Warmup $endpoint request unsuccessful.")
    end
end

function warmup_ticker_startdate_enddate(
    ticker::String, start_date::String, end_date::String, endpoint::String, url::String
)
    url_req = url * endpoint * "?ticker=$ticker&start_date=$start_date&end_date=$end_date"

    response = HTTP.get(url_req)

    if response.status == 200
        println("Warmup $endpoint request successful.")
    else
        println("Warmup $endpoint request unsuccessful.")
    end
end

function warmup_inverse_volatility(
    stocklist::Vector{String},
    len::Int,
    end_date::String,
    lookback_period::Int,
    endpoint::String,
    url::String,
)
    stocklist_str = join(stocklist, ',')
    url_req =
        url *
        endpoint *
        "?stocklist=$stocklist_str&length=$len&enddate=$end_date&lookbackperiod=$lookback_period"

    response = HTTP.get(url_req)

    if response.status == 200
        println("Warmup $endpoint request successful.")
    else
        println("Warmup $endpoint request unsuccessful.")
    end
end

function warmup_weighting(json_data::String, endpoint::String, url::String)
    # The URL for the POST request
    url_req = url * endpoint
    # Set the Content-Type header to application/json
    headers = ["Content-Type" => "application/json"]

    # Make the POST request with the JSON data
    response = HTTP.post(url_req, headers, json_data)

    # Check the response status and print a message accordingly
    if response.status == 200
        println("Warmup $endpoint request successful.")
    else
        println("Warmup $endpoint request unsuccessful. Status code: $(response.status)")
        println("Response body: $(String(response.body))")
    end
end

function warmup_api(url::String, ticker::String)
    try
        warmup_ticker_date_period("MSFT", "2023-1-1", 5, "market_cap", url)
    catch e
        println("Call to 'market_cap' failed with parameters: MSFT, 2023-1-1")
    end

    try
        warmup_ticker_period_enddate(ticker, 10, "2023-1-1", "get_stock_data_period", url)
    catch e
        println(
            "Call to 'get_stock_data_period' failed with parameters: ",
            ticker,
            ", 10, 2023-1-1",
        )
    end

    try
        warmup_ticker_period_enddate(
            ticker, 10, "2023-1-1", "get_stock_data_period_full", url
        )
    catch e
        println(
            "Call to 'get_stock_data_period_full' failed with parameters: ",
            ticker,
            ", 10, 2023-1-1",
        )
    end

    try
        warmup_ticker_length_period_enddate(ticker, 10, 14, "2023-1-1", "max_drawdown", url)
    catch e
        println("Call to 'max_drawdown' failed with parameters: ", ticker, ", 10, 2023-1-1")
    end

    try
        warmup_ticker_length_period_enddate(
            ticker, 10, 14, "2023-1-1", "cumulative_return", url
        )
    catch e
        println(
            "Call to 'cumulative_return' failed with parameters: ",
            ticker,
            ", 10, 14, 2023-1-1",
        )
    end

    try
        warmup_ticker_startdate_enddate(
            ticker, "2023-1-1", "2023-2-1", "get_trading_days", url
        )
    catch e
        println(
            "Call to 'get_trading_days' failed with parameters: ",
            ticker,
            ", 2023-1-1, 2023-2-1",
        )
    end

    try
        warmup_ticker_length_period_enddate(ticker, 30, 14, "2023-1-1", "rsi", url)
    catch e
        println("Call to 'rsi' failed with parameters: ", ticker, ", 30, 14, 2023-1-1")
    end

    try
        warmup_ticker_length_period_enddate(ticker, 30, 14, "2023-1-1", "ema", url)
    catch e
        println("Call to 'ema' failed with parameters: ", ticker, ", 30, 14, 2023-1-1")
    end

    try
        warmup_ticker_length_period_enddate(ticker, 30, 14, "2023-1-1", "sma", url)
    catch e
        println("Call to 'sma' failed with parameters: ", ticker, ", 30, 14, 2023-1-1")
    end

    try
        warmup_ticker_length_period_enddate(
            ticker, 30, 14, "2023-11-11", "sma_returns", url
        )
    catch e
        println(
            "Call to 'sma_returns' failed with parameters: ", ticker, ", 30, 14, 2023-1-1"
        )
    end

    try
        warmup_ticker_length_period_enddate(ticker, 30, 14, "2023-1-1", "sd_returns", url)
    catch e
        println(
            "Call to 'sd_returns' failed with parameters: ", ticker, ", 30, 14, 2023-1-1"
        )
    end

    try
        warmup_ticker_length_period_enddate(ticker, 7, 15, "2023-1-1", "sd", url)
    catch e
        println("Call to 'sd' failed with parameters: ", ticker, ", 7, 15, 2023-1-1")
    end

    data = [
        430.76,
        434.69,
        435.69,
        436.93,
        437.25,
        433.84,
        440.61,
        440.19,
        448.73,
        449.68,
        450.50,
        452.34,
        453.62,
        455.12,
    ]

    try
        warmup_data_ticker_enddate(ticker, data, "max_drawdown_data", url)
    catch e
        println("Call to 'max_drawdown_data' failed with parameters: ", ticker, ", ", data)
    end

    try
        warmup_data_ticker_period_enddate(ticker, 5, data, "cumulative_return_data", url)
    catch e
        println(
            "Call to 'cumulative_return_data' failed with parameters: ",
            ticker,
            ", 5, ",
            data,
        )
    end

    try
        warmup_data_ticker_period_enddate(ticker, 5, data, "rsi_data", url)
    catch e
        println("Call to 'rsi_data' failed with parameters: ", ticker, ", 5, ", data)
    end

    try
        warmup_data_ticker_period_enddate(ticker, 5, data, "ema_data", url)
    catch e
        println("Call to 'ema_data' failed with parameters: ", ticker, ", 5, ", data)
    end

    try
        warmup_data_ticker_period_enddate(ticker, 5, data, "sma_data", url)
    catch e
        println("Call to 'sma_data' failed with parameters: ", ticker, ", 5, ", data)
    end

    try
        warmup_data_ticker_period_enddate(ticker, 5, data, "sma_returns_data", url)
    catch e
        println(
            "Call to 'sma_returns_data' failed with parameters: ", ticker, ", 5, ", data
        )
    end

    try
        warmup_data_ticker_period_enddate(ticker, 5, data, "sd_returns_data", url)
    catch e
        println("Call to 'sd_returns_data' failed with parameters: ", ticker, ", 5, ", data)
    end

    try
        warmup_data_ticker_period_enddate(ticker, 5, data, "sd_data", url)
    catch e
        println("Call to 'sd_data' failed with parameters: ", ticker, ", 5, ", data)
    end

    try
        warmup_inverse_volatility(
            ["SPY", "AAPL"], 10, "2023-01-31", 14, "inverse_volatility", url
        )
    catch e
        println(
            "Call to 'inverse_volatility' failed with parameters: ",
            ["SPY", "AAPL"],
            ", 10, 2023-01-31, 14",
        )
    end

    json_data_for_weighting = """
    {"dates": ["2024-03-01", "2024-03-02", "2024-03-03", "2024-03-04", "2024-03-05", "2024-03-06"], "lookbackperiod": 2, "data": {"1": [412.25, 123.25, 233, 254.21, 239.23, 125.25], "2": [423.25, 134.25, 223, 225.32, 441.25, 125.35], "3": [543.15, 126.35, 323, 223.36, 332.24, 114.75]}}
    """
    try
        warmup_weighting(json_data_for_weighting, "weighting", url)
    catch e
        println("Call to 'weighting' failed with parameters: ", json_data_for_weighting)
    end

    try
        warmup_ticker_startdate_enddate(
            ticker, "2023-1-1", "2023-2-1", "get_stock_data_start_end", url
        )
    catch e
        println(
            "Call to 'get_stock_data_start_end' failed with parameters: ",
            ticker,
            ", 2023-1-1, 2023-2-1",
        )
    end

    try
        warmup_ticker_startdate_enddate(
            ticker, "2023-1-1", "2023-2-1", "get_deltas_start_end", url
        )
    catch e
        println(
            "Call to 'get_deltas_start_end' failed with parameters: ",
            ticker,
            ", 2023-1-1, 2023-2-1",
        )
    end

    return println("All warmup requests complete.")
end
