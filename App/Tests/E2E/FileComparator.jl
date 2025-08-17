module FileComparator
using Test, JSON, Dates
using Blobs
using Mmap
using DataFrames
using Parquet
include("../../Main.jl")
include("../../BacktestUtils/SubTreeCache.jl")
using .SubtreeCache

export compare_cache_files, compare_subtree_cache_files, compare_indicator_files

function compare_cache_files(
    expected_file::String, response_file::String, end_date::String
)::Bool
    # Ensure the files exist
    if !(isfile(expected_file) && isfile(response_file))
        return false
    end

    # Read and parse the JSON files
    expected_content = JSON.parse(read(expected_file, String))
    response_content = JSON.parse(read(response_file, String))

    # Find the index of the last date we want to check
    end_date_index = findfirst(x -> x == end_date, expected_content["dates"])
    if isnothing(end_date_index)
        return false
    end

    # Ensure the response contains that date
    if isnothing(findfirst(x -> x == end_date, response_content["dates"]))
        return false
    end

    # Compare the profile history
    expected_profile_history = expected_content["profile_history"][1:end_date_index]
    response_profile_history = response_content["profile_history"][1:end_date_index]
    if expected_profile_history != response_profile_history
        return false
    end

    # Compare the dates
    expected_dates = expected_content["dates"][1:end_date_index]
    response_dates = response_content["dates"][1:end_date_index]
    if expected_dates != response_dates
        return false
    end

    # Compare the returns
    expected_returns = expected_content["returns"][1:end_date_index]
    response_returns = response_content["returns"][1:end_date_index]
    if expected_returns != response_returns
        return false
    end

    return true
end

function compare_subtree_cache_files(hash::String, len::Int, end_date::String)::Bool
    expected_DIR = "./App/Tests/E2E/ExpectedFiles/SubtreeCache/"
    response_DIR = "./App/SubtreeCache/"
    expected_content = read_subtree_portfolio_mmem(
        hash, Date(end_date), BitVector(trues(len)), expected_DIR
    )
    response_content = read_subtree_portfolio_mmem(
        hash, Date(end_date), BitVector(trues(len)), response_DIR
    )

    if expected_content != response_content
        return false
    end

    return true
end

function compare_indicator_files(
    expected_path::String, response_path::String, end_date::String
)::Bool
    @test isfile(expected_path)
    @test isfile(response_path)
    # Read parquet files
    df1 = DataFrame(Parquet.File(expected_path))
    df2 = DataFrame(Parquet.File(response_path))

    # Filter data up to end_date
    end_date_dt = Date(end_date)
    df1_filtered = filter(row -> Date(row.date) <= end_date_dt, df1)
    df2_filtered = filter(row -> Date(row.date) <= end_date_dt, df2)

    # Compare the filtered dataframes
    return df1_filtered == df2_filtered
end

end
