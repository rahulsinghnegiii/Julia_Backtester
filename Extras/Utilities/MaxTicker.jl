using Dates, DataFrames, JSON, HTTP, JSON3, Parquet2

function get_top_n_tickers_with_max_records(n::Int)
    parquet_file_path::String = "./../../App/data/metadata.parquet"

    metadata::DataFrame = DataFrame(Parquet2.Dataset(parquet_file_path))

    try
        tickers = metadata[!, :ticker]
        num_records = metadata[!, :num_records]
        if isempty(tickers) || isempty(num_records)
            throw(error("The required columns are empty"))
        end

        sorted_indices = sortperm(num_records; rev=true)
        top_n_indices = sorted_indices[1:min(n, length(sorted_indices))]

        top_n_tickers = tickers[top_n_indices]
        top_n_num_records = num_records[top_n_indices]

        return top_n_tickers, top_n_num_records
    catch e
        throw(error("Error accessing required columns: $(sprint(showerror, e))"))
    end
    return String[], Int[]
end

# Example usage
n = 5
top_n_tickers, top_n_num_records = get_top_n_tickers_with_max_records(n)
println("Top $n tickers with the maximum number of records:")
for i in 1:length(top_n_tickers)
    println("Ticker: $(top_n_tickers[i]), Number of records: $(top_n_num_records[i])")
end
