include("../Data&TA/StockData.jl")
include("../Utils/RoutesTAUtils.jl")
include("../Data&TA/TAFunctions.jl")

using Oxygen
using Dates, JSON, HTTP
using MarketTechnicals, TimeSeries
using .MarketTechnicalsIndicators
using .StockData

# ----- TA_API Routes ----- #

@get "/get_stock_data_start_end" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    start_date = Date(params["start_date"], "yyyy-mm-dd")
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    close_prices = get_stock_data_dataframe_start_end(ticker, start_date, end_date)

    response = Dict(
        "symbol" => ticker,
        "start_date" => start_date,
        "end_date" => end_date,
        "close_prices" => close_prices,
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/get_deltas_start_end" function (req::HTTP.Request)
    # Use HTTP.queryparams to get query parameters
    params = HTTP.queryparams(req)

    ticker = params["ticker"]
    start_date = Date(params["start_date"], "yyyy-mm-dd")
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    close_prices = get_stock_data_dataframe_start_end(ticker, start_date, end_date)
    dates_vector = collect(skipmissing(close_prices[:, :date]))
    close_prices_vector = collect(skipmissing(close_prices[:, :adjusted_close]))
    deltas = calculate_delta_percentages(close_prices_vector)

    response = Dict("symbol" => ticker, "dates" => dates_vector, "deltas" => deltas)

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/get_stock_data_period" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    period = parse(Int, params["period"])
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    close_prices = get_stock_data_dataframe(ticker, period, end_date)

    response = Dict("symbol" => ticker, "period" => period, "close_prices" => close_prices)

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/get_trading_days" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    start_date = Date(params["start_date"], "yyyy-mm-dd")
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    response = get_trading_days(ticker, start_date, end_date)

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/rsi" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    length = parse(Int, params["length"])
    period = parse(Int, params["period"])
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    rsi_values = @time get_rsi(ticker, length, period, end_date)

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "RSI_values" => rsi_values,
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/sma" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    length = parse(Int, params["length"])
    period = parse(Int, params["period"])
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    sma_values = @time get_sma(ticker, length, period, end_date)

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "SMA_values" => sma_values,
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/sma_returns" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    length = parse(Int, params["length"])
    period = parse(Int, params["period"])
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    sma_returns_values = get_sma_returns(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "SMA_Returns_values" => sma_returns_values,
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/ema" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    length = parse(Int, params["length"])
    period = parse(Int, params["period"])
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    ema_values = @time get_ema(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "EMA_values" => ema_values,
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/sd_returns" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    length = parse(Int, params["length"])
    period = parse(Int, params["period"])
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    sd_returns_values = get_sd_returns(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "SD_Returns_values" => sd_returns_values,
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/sd" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    length = parse(Int, params["length"])
    period = parse(Int, params["period"])
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    sd_values = get_sd(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker, "length" => length, "period" => period, "SD_values" => sd_values
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/max_drawdown" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    length = parse(Int, params["length"])
    period = parse(Int, params["period"])
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    max_drawdown_value = get_max_drawdown(ticker, period, length, end_date)

    response = Dict(
        "symbol" => ticker, "period" => period, "Max_Drawdown_value" => max_drawdown_value
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/cumulative_return" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    length = parse(Int, params["length"])
    period = parse(Int, params["period"])
    end_date = Date(params["end_date"], "yyyy-mm-dd")

    cumulative_return_value = get_cumulative_return(ticker, length, period, end_date)

    response = Dict(
        "symbol" => ticker,
        "period" => period,
        "Cumulative_Return_values" => cumulative_return_value,
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end

@get "/market_cap" function (req::HTTP.Request)
    params = HTTP.queryparams(req)
    ticker = params["ticker"]
    period = parse(Int, params["period"])
    date = Date(params["date"], "yyyy-mm-dd")

    market_cap_values = get_market_cap(ticker, date, period)

    response = Dict(
        "symbol" => ticker, "period" => period, "market_cap_values" => market_cap_values
    )

    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(response))
end
