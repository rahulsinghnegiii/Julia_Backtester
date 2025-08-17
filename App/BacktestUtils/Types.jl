module Types

export StockInfo, DayData, CacheData, SubtreeContext

mutable struct StockInfo
    ticker::String
    weightTomorrow::Float32
end

function Base.:(==)(a::StockInfo, b::StockInfo)
    return a.ticker == b.ticker && a.weightTomorrow == b.weightTomorrow
end

struct DayData
    stockList::Vector{StockInfo}
    DayData() = new(StockInfo[])
    DayData(stockList::Vector{StockInfo}) = new(stockList)
end

struct CacheData
    response::Union{Nothing,Dict{String,Vector}}
    uncalculated_days::Int
    cache_present::Bool
end

struct SubtreeContext
    backtest_period::Int
    profile_history::Vector{DayData}
    flow_count::Dict{String,Int}
    flow_stocks::Dict{String,Vector{DayData}}
    trading_dates::Vector{String}
    active_mask::BitVector
    common_data_span::Int
end

function Base.:(==)(a::DayData, b::DayData)
    return sort(a.stockList; by=x -> x.ticker) == sort(b.stockList; by=x -> x.ticker)
end

end
