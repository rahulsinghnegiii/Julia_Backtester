include("./../../App/Main.jl")
include("./../../App/BacktestUtils/SIMDOperations.jl")
using ..VectoriseBacktestService
using ..VectoriseBacktestService.StockData
using Dates, DataFrames, JSON, HTTP, JSON3, Parquet2
using ..VectoriseBacktestService.StockData.StockDataUtils
using ..VectoriseBacktestService.MarketTechnicalsIndicators
using ..VectoriseBacktestService.ErrorHandlers: ServerError

function get_ticker_with_max_records()
    # Path to the metadata.parquet file
    parquet_file_path::String = "./../../App/data/metadata.parquet"

    # Load the metadata file
    metadata::DataFrame = DataFrame(Parquet2.Dataset(parquet_file_path))

    # Ensure metadata is not empty
    if isempty(metadata)
        throw(error("The metadata file is empty"))
    end
    # Extract the required columns
    try
        tickers = metadata[!, :ticker]
        num_records = metadata[!, :num_records]
        if isempty(tickers) || isempty(num_records)
            throw(error("The required columns are empty"))
        end

        # Find the maximum num_records and corresponding ticker
        max_index = argmax(num_records)
        max_ticker = tickers[max_index]
        max_num_records = num_records[max_index]

        return max_ticker, max_num_records
    catch e
        throw(error("Error accessing required columns: $(sprint(showerror, e))"))
    end
    return "", 0
    # Ensure the columns are not empty
end

# Example usage

max_ticker, max_num_records = get_ticker_with_max_records()
println("Ticker with the maximum number of records: $max_ticker")
println("Number of records: $max_num_records")
