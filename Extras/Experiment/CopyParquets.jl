using Parquet2
using Arrow
using DataFrames

function copy_parquet(old_file_path::String, new_file_path::String, ticker::String)
    # Check if the Parquet file exists
    if !isfile(old_file_path)
        error("Parquet file not found: $old_file_path")
    end

    # Read the Parquet file
    try
        # Read the Parquet file into a DataFrame
        df = DataFrame(Parquet2.Dataset(old_file_path))

        # Check if the directory exists, and create it if it doesn't
        if !isdir(new_file_path)
            mkpath(new_file_path)
            @info "Directory created: $new_file_path"
        end

        # Write the DataFrame to a Parquet file
        Parquet2.writefile(joinpath(new_file_path, "$ticker.parquet"), df)

        println("Successfully copied Parquet file.")
        println("Parquet file: $old_file_path")
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
    copy_parquet("../data/$ticker.parquet", "./ParquetData", ticker)
end
