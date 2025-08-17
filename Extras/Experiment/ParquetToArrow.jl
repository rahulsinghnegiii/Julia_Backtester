using Parquet2
using Arrow
using DataFrames

function parquet_to_arrow(
    parquet_file_path::String, arrow_file_path::String, ticker::String
)
    # Check if the Parquet file exists
    if !isfile(parquet_file_path)
        error("Parquet file not found: $parquet_file_path")
    end

    # Read the Parquet file
    try
        # Read the Parquet file into a DataFrame
        df = DataFrame(Parquet2.Dataset(parquet_file_path))

        # Check if the directory exists, and create it if it doesn't
        if !isdir(arrow_file_path)
            mkpath(arrow_file_path)
            @info "Directory created: $arrow_file_path"
        end

        # Write the DataFrame to an Arrow file
        Arrow.write(joinpath(arrow_file_path, "$ticker.arrow"), df)

        println("Successfully converted Parquet file to Arrow file.")
        println("Parquet file: $parquet_file_path")
        println("Arrow file: $arrow_file_path")
    catch e
        error("Error during conversion: $e")
    end
end

# main
tickers = [
    "AAPL",
    "MSFT",
    "QQQ",
    "PSQ",
    "SPY",
    "SHY",
    "TSLA",
    "NVDA",
    "XOM",
    "AMZN",
    "UPRO",
    "BIL",
    "AMD",
    "TMF",
    "TLT",
    "SHV",
    "GLD",
    "UUP",
    "DBC",
    "XLP",
]

for ticker in tickers
    parquet_to_arrow("../data/$ticker.parquet", "./ArrowData", ticker)
end
