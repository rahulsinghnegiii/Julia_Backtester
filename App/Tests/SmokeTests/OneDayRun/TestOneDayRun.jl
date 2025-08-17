module TestOneDayRun

include("../../../Main.jl")
include("../../../BacktestUtils/BacktestUtils.jl")
using Test, Dates, JSON
using .VectoriseBacktestService
using .VectoriseBacktestService.Types
using .VectoriseBacktestService.BacktestUtilites
using .VectoriseBacktestService.SubtreeCache
using .VectoriseBacktestService.GlobalServerCache

initialize_server_cache()

# Paths configuration
const TEST_JSONS_PATH = "App/Tests/SmokeTests/OneDayRun/JSONs/"
const CACHE_PATH = "Cache/"
const INDICATOR_DATA_PATH = "IndicatorData/"
const PORTFOLIO_CACHE_PATH = "SubtreeCache/SyntheticReturns"
const SUBTREE_CACHE_PATH = "SubtreeCache/"
const REMOVE_LAST_LINE_SCRIPT = "App/Tests/SmokeTests/OneDayRun/RemoveLastLine.sh"

function truncate(filename::String, n::Int)
    json = JSON.parse(read(filename, String))

    # Extract and truncate data
    n -= 1
    dates::Vector{String}, returns::Vector{Float32}, temp_portfolio = map(
        x -> json[x][(end - n):end], ["dates", "returns", "profile_history"]
    )

    # Reconstruct portfolio data
    portfolio = [DayData() for _ in 1:length(temp_portfolio)]
    for (i, day) in enumerate(temp_portfolio)
        stocks = [
            StockInfo(stock["ticker"], stock["weightTomorrow"]) for
            stock in day["stockList"]
        ]
        portfolio[i] = DayData(stocks)
    end

    # Update remaining keys and days count
    days = json["days"][1]
    n += 1
    keys::Vector{String} = ["dates", "returns", "profile_history"]
    for key in keys
        json[key] = json[key][1:(end - n)]
        println("Key: $key -> End Value: $(json[key][end])")
    end
    json["days"] = [days - n]
    write(filename, JSON.json(json))

    return (dates, returns, portfolio, days)
end

function truncate_portfolio_cache_files(folder::String, n::Int, end_date::Date)
    for file in readdir(folder)
        file_path = joinpath(folder, file)

        if endswith(file, ".mmap")
            file_hash = String(split(file, ".mmap")[1])
            try
                data, use, cached_end_date = read_portfolio_values(file_hash)
                for key in keys(data)
                    data[key] = data[key][1:(max(1, end - n))]
                end

                # Adjust the end date by n business days (skipping weekends)
                adjusted_end_date = end_date
                business_days_count = 0

                while business_days_count < n
                    adjusted_end_date = adjusted_end_date - Day(1)
                    # Skip weekends (Saturday = 6, Sunday = 7 in Julia's dayofweek)
                    if dayofweek(adjusted_end_date) != 6 &&
                        dayofweek(adjusted_end_date) != 7
                        business_days_count += 1
                    end
                end

                cache_portfolio_values(data, file_hash, adjusted_end_date)
            catch e
                println("Error processing $file_path: ", e)
            end
        end
    end
end
function safe_remove_file(filepath)
    try
        GC.gc()
        if isfile(filepath)
            rm(filepath; force=true)
        else
            println("Not a file: $filepath")
        end
    catch e
        @warn "Failed to remove file: $filepath" exception = e
    end
end

function truncate_subtree_cache(truncate_days::Int, end_date::Date)
    for file in readdir(SUBTREE_CACHE_PATH)
        if !isfile("$SUBTREE_CACHE_PATH/$file")
            continue
        end
        hash = String(split(file, ".")[1])
        portfolio, dates, last_date = read_subtree_portfolio_with_dates_mmem(hash, end_date)
        portfolio = portfolio[1:(end - truncate_days)]
        dates = dates[1:(end - truncate_days)]
        write_subtree_portfolio_mmap(
            dates, last_date, hash, length(portfolio), portfolio, false
        )
    end
end

function cleanup()
    if (isdir(CACHE_PATH))
        rm(CACHE_PATH; recursive=true, force=true)
    end
    if (isdir(INDICATOR_DATA_PATH))
        rm(INDICATOR_DATA_PATH; recursive=true, force=true)
    end
    if (isdir(PORTFOLIO_CACHE_PATH))
        rm(PORTFOLIO_CACHE_PATH; recursive=true, force=true)
    end
    if (isdir(SUBTREE_CACHE_PATH))
        rm(SUBTREE_CACHE_PATH; recursive=true, force=true)
    end

    mkdir(SUBTREE_CACHE_PATH)
    mkdir(PORTFOLIO_CACHE_PATH)

    return nothing
end

function run_test(file::String, truncate_days::Int)
    @testset "Testing $file $truncate_days days" begin
        cleanup()
        strategy_json = read_json_file("$TEST_JSONS_PATH/$file")
        backtest_period, end_date = read_metadata(strategy_json["tickers"])
        hash = String(split(file, ".")[1])

        # Initial backtest run
        handle_backtesting_api(strategy_json, 50000, hash, end_date, false)
        dates, returns, portfolio, days = truncate(
            "$CACHE_PATH/$hash/$hash.json", truncate_days
        )
        println("Dates $dates")
        println("Returns $returns")
        println("Portfolio $portfolio")
        println("Days $days")
        truncate_portfolio_cache_files(
            "SubtreeCache/SyntheticReturns", truncate_days, end_date
        )
        truncate_subtree_cache(truncate_days, Date(dates[end]))
        @testset "Truncated global cache of first run. Testing lengths of dates, returns, portfolio" begin
            @test length(dates) == truncate_days
            @test length(returns) == truncate_days
            @test length(portfolio) == truncate_days
        end

        # Run backtest again
        println("\nSECOND BACKTEST")
        handle_backtesting_api(strategy_json, 50000, hash, end_date, false)
        new_dates, new_returns, new_portfolio, new_days = truncate(
            "$CACHE_PATH/$hash/$hash.json", truncate_days
        )
        println("new_dates $new_dates")
        println("new_returns $new_returns")
        println("new_portfolio $new_portfolio")
        println("new_days $new_days")

        truncate_portfolio_cache_files(
            "SubtreeCache/SyntheticReturns", truncate_days, end_date
        )

        @testset "Comparing entire backtest with $truncate_days day backtest results" begin
            @test dates == new_dates
            @testset "Comparing returns" begin
                for i in eachindex(returns)
                    @test isapprox(returns[i], new_returns[i]; atol=1e-1) ||
                        isapprox(returns[i], new_returns[i]; atol=1e-2)
                end
            end
            expected_dict = [Dict{String,Float32}() for _ in eachindex(portfolio)]
            for day in eachindex(portfolio)
                for stock in portfolio[day].stockList
                    if !haskey(expected_dict[day], stock.ticker)
                        expected_dict[day][stock.ticker] = stock.weightTomorrow
                    else
                        expected_dict[day][stock.ticker] += stock.weightTomorrow
                    end
                end
            end

            result_dict = [Dict{String,Float32}() for _ in eachindex(new_portfolio)]
            for day in eachindex(new_portfolio)
                for stock in new_portfolio[day].stockList
                    if !haskey(result_dict[day], stock.ticker)
                        result_dict[day][stock.ticker] = stock.weightTomorrow
                    else
                        result_dict[day][stock.ticker] += stock.weightTomorrow
                    end
                end
            end

            for day in eachindex(expected_dict)
                for key in keys(expected_dict[day])
                    println("Day: $day, Key: $key")
                    println("Expected: ", expected_dict[day])
                    println("Result: ", result_dict[day])
                    @test haskey(result_dict[day], key) && isapprox(
                        result_dict[day][key], expected_dict[day][key]; atol=0.01
                    )
                end
            end

            @test days == new_days
        end
    end
end

test_jsons::Vector{String} = [
    # "300d-sort-min.json",
    # "short-min.json",
    # "sort-min.json",
    # "rsi-ema-sort.json",
    # "inv-min.json",
    # "10k-min.json",
    # "if-inv-sort-min.json",
    # "if-sort-inv-min.json",
    "qac-min.json",
    # "eldorado-copy-min.json", # 400k algo size
    # "eldorado-diversified-issue-min.json", # What Have I Done.
    # "eldorado-diversified-min.json", # inv vol issues
    # "acc-min.json",
]

# Run tests for both scenarios,
for i in [1]
    for file in test_jsons
        run_test("$file", i)
        println("\n")
    end
end
cleanup()

end
