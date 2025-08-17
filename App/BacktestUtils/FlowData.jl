module FlowData

using Dates, DataFrames
using ..VectoriseBacktestService.Types
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.ReturnCalculations

export increment_flow_count, set_flow_stocks, package_response, extract_delta, package_flow

function increment_flow_count(flow_count::Dict{String,Int}, node_id::String)
    return flow_count[node_id] = get(flow_count, node_id, 0) + 1
end

function set_flow_stocks(
    flow_stocks::Dict{String,Vector{DayData}}, dateVector::Vector{DayData}, node_id::String
)
    return flow_stocks[node_id] = dateVector
end

function package_response(
    return_curve::Vector{Float32}, dates::Vector{String}, profile_history::Vector{DayData}
)::Dict{String,Vector}
    response_returns::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()
    response_dates::Dict{String,Vector{String}} = Dict{String,Vector{String}}()
    response_profile_history::Dict{String,Vector{DayData}} = Dict{String,Vector{DayData}}()

    response_dates["dates"] = []
    response_returns["returns"] = []
    response_profile_history["profile_history"] = []

    for (i, day_return) in enumerate(return_curve)
        push!(response_dates["dates"], dates[i])
        push!(response_returns["returns"], day_return)
        push!(response_profile_history["profile_history"], profile_history[i])
    end

    merged_response::Dict{String,Vector} = merge(
        response_dates, response_returns, response_profile_history
    )
    return merged_response
end

function extract_delta(
    flow_stocks::Dict{String,Vector{DayData}},
    dates::Vector{String},
    period::Int,
    end_date::Date,
    price_cache::Dict{String,DataFrame},
)
    delta::Dict{String,Vector{Float32}} = Dict{String,Vector{Float32}}()

    for (node_id::String, vec::Vector{DayData}) in flow_stocks
        delta[node_id] = calculate_final_return_curve(
            vec, dates, period, end_date, price_cache, DayData()
        )
    end

    return delta
end

function package_flow(
    flow_count::Dict{String,Int},
    flow_stocks::Dict{String,Vector{DayData}},
    dates::Vector{String},
    period::Int,
    end_date::Date,
    price_cache::Dict{String,DataFrame},
)
    flow_data::Dict{String,Dict{String,Any}} = Dict{String,Dict{String,Any}}()
    delta::Dict{String,Vector{Float32}} = extract_delta(
        flow_stocks, dates, period, end_date, price_cache
    )

    for (node_id::String, count::Int) in flow_count
        flow_data[node_id] = Dict{String,Any}()
        flow_data[node_id]["count"] = count
        flow_data[node_id]["delta"] = delta[node_id]
        flow_data[node_id]["dates"] = dates
    end

    return flow_data
end

end
