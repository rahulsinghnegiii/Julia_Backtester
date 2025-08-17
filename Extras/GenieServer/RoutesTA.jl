include("Utils/RoutesTAUtils.jl")
include("RoutesBacktest.jl")

# ----- TA_API Routes ----- #

route("/get_stock_data_start_end"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    start_date = Date(Genie.Router.params(:start_date), "yyyy-mm-dd")
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    close_prices = get_stock_data_dataframe_start_end(ticker, start_date, end_date)

    response = Dict(
        "symbol" => ticker,
        "start_date" => start_date,
        "end_date" => end_date,
        "close_prices" => close_prices,
    )

    return JSON.json(response)
end

route("/get_deltas_start_end"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    start_date = Date(Genie.Router.params(:start_date), "yyyy-mm-dd")
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    close_prices = get_stock_data_dataframe_start_end(ticker, start_date, end_date)
    dates_vector = collect(skipmissing(close_prices[:, :date]))
    close_prices_vector = collect(skipmissing(close_prices[:, :adjusted_close]))
    deltas = calculate_delta_percentages(close_prices_vector)

    response = Dict("symbol" => ticker, "dates" => dates_vector, "deltas" => deltas)

    return JSON.json(response)
end

route("/get_stock_data_period"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    close_prices = get_stock_data_dataframe(ticker, period, end_date)

    response = Dict("symbol" => ticker, "period" => period, "close_prices" => close_prices)

    return JSON.json(response)
end

route("/get_stock_data_period_full"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    response = get_stock_data_dataframe_full(ticker, period, end_date)

    return JSON.json(response)
end

route("/get_trading_days"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    start_date = Date(Genie.Router.params(:start_date), "yyyy-mm-dd")
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    response = get_trading_days(ticker, start_date, end_date)

    return JSON.json(response)
end

route("/rsi"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    length = parse(Int, Genie.Router.params(:length))
    period = parse(Int, Genie.Router.params(:period))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    rsi_values = @time get_rsi(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "RSI_values" => rsi_values,
    )

    return JSON.json(response)
end

route("/sma"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    length = parse(Int, Genie.Router.params(:length))
    period = parse(Int, Genie.Router.params(:period))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    sma_values = @time get_sma(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "SMA_values" => sma_values,
    )

    return JSON.json(response)
end

route("/sma_returns"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    length = parse(Int, Genie.Router.params(:length))
    period = parse(Int, Genie.Router.params(:period))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    sma_returns_values = get_sma_returns(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "SMA_Returns_values" => sma_returns_values,
    )

    return JSON.json(response)
end

route("/ema"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    length = parse(Int, Genie.Router.params(:length))
    period = parse(Int, Genie.Router.params(:period))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    ema_values = @time get_ema(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "EMA_values" => ema_values,
    )

    return JSON.json(response)
end

route("/sd_returns"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    length = parse(Int, Genie.Router.params(:length))
    period = parse(Int, Genie.Router.params(:period))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    sd_returns_values = get_sd_returns(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker,
        "length" => length,
        "period" => period,
        "SD_Returns_values" => sd_returns_values,
    )

    return JSON.json(response)
end

route("/sd"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    length = parse(Int, Genie.Router.params(:length))
    period = parse(Int, Genie.Router.params(:period))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    sd_values = get_sd(ticker, length, period, Date(end_date))

    response = Dict(
        "symbol" => ticker, "length" => length, "period" => period, "SD_values" => sd_values
    )

    return JSON.json(response)
end

route("/max_drawdown"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")
    length = parse(Int, Genie.Router.params(:length))

    max_drawdown_value = get_max_drawdown(ticker, period, length, end_date)

    response = Dict(
        "symbol" => ticker, "period" => period, "Max_Drawdown_value" => max_drawdown_value
    )

    return JSON.json(response)
end

route("/cumulative_return"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    length = parse(Int, Genie.Router.params(:length))
    end_date = Date(Genie.Router.params(:end_date), "yyyy-mm-dd")

    cumulative_return_value = get_cumulative_return(ticker, length, period, end_date)

    response = Dict(
        "symbol" => ticker,
        "period" => period,
        "Cumulative_Return_values" => cumulative_return_value,
    )

    return JSON.json(response)
end

route("/rsi_data"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    close_prices = (x -> parse.(Float64, x))(split(Genie.Router.params(:close_prices), ','))

    dates = Date.(1:length(close_prices))
    time_series_data = TimeArray(dates, close_prices, [:close])

    rsi_values = MarketTechnicals.rsi(time_series_data, period; wilder=true)

    response = Dict(
        "symbol" => ticker, "period" => period, "RSI_values" => vec(values(rsi_values))
    )

    return JSON.json(response)
end

route("/ema_data"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    close_prices = (x -> parse.(Float64, x))(split(Genie.Router.params(:close_prices), ','))

    dates = Date.(1:length(close_prices))
    time_series_data = TimeArray(dates, close_prices, [:close])

    ema_values = MarketTechnicals.ema(time_series_data, period; wilder=false)

    response = Dict(
        "symbol" => ticker, "period" => period, "EMA_values" => vec(values(ema_values))
    )

    return JSON.json(response)
end

route("/sma_data"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    close_prices = (x -> parse.(Float64, x))(split(Genie.Router.params(:close_prices), ','))

    dates = Date.(1:length(close_prices))
    time_series_data = TimeArray(dates, close_prices, [:close])

    sma_values = MarketTechnicals.sma(time_series_data, period)

    response = Dict(
        "symbol" => ticker, "period" => period, "SMA_values" => vec(values(sma_values))
    )

    return JSON.json(response)
end

route("/sma_returns_data"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    close_prices = (x -> parse.(Float64, x))(split(Genie.Router.params(:close_prices), ','))

    returns = diff(close_prices) ./ close_prices[1:(end - 1)] * 100.0

    dates = Date.(2:length(close_prices))
    time_series_data = TimeArray(dates, returns, [:returns])

    sma_values = MarketTechnicals.sma(time_series_data, period)

    response = Dict(
        "symbol" => ticker,
        "period" => period,
        "SMA_Returns_values" => vec(values(sma_values)),
    )

    return JSON.json(response)
end

route("/sd_returns_data"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    close_prices = (x -> parse.(Float64, x))(split(Genie.Router.params(:close_prices), ','))

    returns = 100 * diff(close_prices) ./ close_prices[1:(end - 1)]
    returns_sd_values = []

    for i in period:length(returns)
        window = returns[(i - period + 1):i]
        mean = sum(window) / period
        variance = sum((x - mean)^2 for x in window) / period
        push!(returns_sd_values, sqrt(variance))
    end

    response = Dict(
        "symbol" => ticker, "period" => period, "SD_Returns_values" => returns_sd_values
    )

    return JSON.json(response)
end

route("/sd_data"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    close_prices = (x -> parse.(Float64, x))(split(Genie.Router.params(:close_prices), ','))
    sd_values = []

    for i in period:length(close_prices)
        window = close_prices[(i - period + 1):i]
        mean = sum(window) / period
        variance = sum((x - mean)^2 for x in window) / period
        push!(sd_values, sqrt(variance))
    end

    response = Dict("symbol" => ticker, "period" => period, "SD_values" => sd_values)

    return JSON.json(response)
end

route("/max_drawdown_data"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    close_prices = (x -> parse.(Float64, x))(split(Genie.Router.params(:close_prices), ','))

    min = close_prices[1]
    peak = close_prices[1]

    for price in close_prices
        if price > peak
            peak = price
        elseif price < min
            min = price
        end
    end

    max_drawdown = ((peak - min) / peak) * 100

    response = Dict("symbol" => ticker, "Max_Drawdown_value" => max_drawdown)

    return JSON.json(response)
end

route("/cumulative_return_data"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    period = parse(Int, Genie.Router.params(:period))
    prices = (x -> parse.(Float64, x))(split(Genie.Router.params(:close_prices), ','))
    cumulative_returns = Float64[]

    for i in period:length(prices)
        period_prices = prices[(i - period + 1):i]
        daily_returns = [
            period_prices[j + 1] / period_prices[j] - 1 for
            j in 1:(length(period_prices) - 1)
        ]
        cumulative_return = prod(1 .+ daily_returns) - 1
        push!(cumulative_returns, cumulative_return * 100)
    end

    response = Dict("symbol" => ticker, "Cumulative_Return_values" => cumulative_returns)

    return JSON.json(response)
end

route("/inverse_volatility"; method=GET) do
    stocklist = (x -> String.(x))(split(Genie.Router.params(:stocklist), ','))
    len = parse(Int, Genie.Router.params(:length))
    end_date = Date(Genie.Router.params(:enddate), "yyyy-mm-dd")
    lookback_period = parse(Int, Genie.Router.params(:lookbackperiod))

    stock_volatilities = calculate_inverse_volatility_for_stocks(
        stocklist, len, end_date, lookback_period
    )
    formatted_output = Dict{String,Any}()
    for (date, volatilities) in stock_volatilities
        str_date = Dates.format(date, "yyyy-mm-dd")
        formatted_output[str_date] = volatilities
    end

    return JSON.json(formatted_output)
end

route("/weighting"; method=POST) do
    payload = jsonpayload()
    lookback_period = payload["lookbackperiod"]
    dates_json = payload["dates"]
    data_json = payload["data"]

    dates = Date.(dates_json)

    # Convert the data keys from Int to Any for compatibility
    data = Dict{Any,Vector{Float64}}()
    for (key, value) in data_json
        data[key] = value
    end

    stock_volatilities = calculate_inverse_volatility_for_data(data, dates, lookback_period)

    # Transform the stock_volatilities keys to formatted dates and update the dictionary
    formatted_output = Dict{String,Any}()
    for (date, volatilities) in stock_volatilities
        str_date = Dates.format(date, "yyyy-mm-dd")
        formatted_output[str_date] = volatilities
    end

    return JSON.json(formatted_output)
end

route("/market_cap"; method=GET) do
    ticker = Genie.Router.params(:ticker)
    date = Genie.Router.params(:date)
    period = parse(Int, Genie.Router.params(:period))

    response = get_market_cap(ticker, date, period)

    return JSON.json(response)
end
