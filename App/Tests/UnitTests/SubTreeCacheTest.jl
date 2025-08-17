include("../../Main.jl")
using Test
using Dates
using Mmap
using JSON
using Parquet2
using DataFrames
using ..VectoriseBacktestService
using .VectoriseBacktestService.Types
using ..VectoriseBacktestService.SubtreeCache
using ..VectoriseBacktestService.GlobalServerCache
initialize_server_cache()
# Test setup and teardown functions
function setup_test_environment()
    test_dir = "./SubtreeCache"
    # Remove directory if it exists
    if isdir(test_dir)
        try
            rm(test_dir; recursive=true, force=true)
        catch e
            @warn "Failed to remove existing directory" exception = e
        end
    end
    # Create fresh directory
    mkdir(test_dir)
    return test_dir
end

function safe_remove_file(filepath)
    try
        GC.gc()
        if isfile(filepath)
            rm(filepath; force=true)
        end
    catch e
        @warn "Failed to remove file: $filepath" exception = e
    end
end

# Test helper functions
function create_test_data()
    date_range = [Dates.format(Date("2024-01-0$i"), "yyyy-mm-dd") for i in 1:30]
    stocks = [StockInfo("AAPL", 0.3f0), StockInfo("GOOGL", 0.4f0), StockInfo("MSFT", 0.3f0)]
    profile_history = [
        DayData([StockInfo("$(s.ticker)", s.weightTomorrow) for s in stocks]) for i in 1:30
    ]
    return date_range, profile_history
end

function create_multiple_test_data()
    dates = ["2023-12-01", "2023-12-01", "2023-12-01"]
    data = [
        DayData([StockInfo("AAPL", 0.3), StockInfo("GOOGL", 0.4), StockInfo("MSFT", 0.3)]),
        DayData([StockInfo("AMZN", 0.5), StockInfo("FB", 0.5)]),
        DayData([StockInfo("NFLX", 0.6), StockInfo("TSLA", 0.4)]),
    ]
    return dates, data
end
# Helper functions
function read_portfolio_data(path)
    portfolio_data = Vector{PortfolioEntry}()
    open(path, "r") do io
        for line in eachline(io)
            parts = split(line, " "; limit=3)  # Split into 3 parts max
            date = parts[1]
            is_valid = parse(Bool, parts[2])
            weights = JSON.parse(parts[3])
            push!(portfolio_data, PortfolioEntry(date, weights, is_valid))
        end
    end
    return portfolio_data
end

function verify_weights(entry, pairs...)
    for (i, (ticker, weight)) in enumerate(pairs)
        @test haskey(entry.weights[i], ticker)
        @test entry.weights[i][ticker] ≈ weight
    end
end

# Helper function
function verify_portfolio_consistency(mmap_portfolio, parquet_portfolio)
    @test length(mmap_portfolio) == length(parquet_portfolio)
    for (mmap_day, parquet_day) in zip(mmap_portfolio, parquet_portfolio)
        @test length(mmap_day.stockList) == length(parquet_day.stockList)

        sort!(mmap_day.stockList; by=x -> x.ticker)
        sort!(parquet_day.stockList; by=x -> x.ticker)

        for (m_stock, p_stock) in zip(mmap_day.stockList, parquet_day.stockList)
            @test m_stock.ticker == p_stock.ticker
            @test isapprox(m_stock.weightTomorrow, p_stock.weightTomorrow, atol=1e-6)
        end
    end
end

# Main test set
@testset "Portfolio Writing Tests" begin
    test_dir = setup_test_environment()

    date_range, profile_history = create_test_data()
    end_date = Date("2024-01-05")
    test_hash = "test_hash_123"
    common_data_span = 30

    @testset "Original Parquet Implementation" begin
        parquet_path = joinpath(test_dir, "$(test_hash).parquet")

        # Ensure clean state
        safe_remove_file(parquet_path)

        # Test normal execution
        result = @time write_subtree_portfolio(
            date_range, end_date, test_hash, common_data_span, profile_history, false
        )
        println("time for parquet creation")
        @test result

        # Verify file exists
        @test isfile(parquet_path)

        # Read and verify data
        df = nothing
        try
            df = DataFrame(Parquet2.Dataset(parquet_path))
            @test size(df, 1) == length(profile_history) * 3
            @test all(df.weight .≈ vcat(fill([0.3f0, 0.4f0, 0.3f0], common_data_span)...))
        finally
            df = nothing
            GC.gc()
            safe_remove_file(parquet_path)
        end
    end

    @testset "Memory-Mapped Implementation" begin
        mmap_path = joinpath(test_dir, "$(test_hash).mmap")

        # Ensure clean state 
        safe_remove_file(mmap_path)

        # Test normal execution
        result = @time write_subtree_portfolio_mmap(
            date_range, end_date, test_hash, common_data_span, profile_history, false
        )
        println("Time for file creation")
        @test result

        # Verify file exists
        @test isfile(mmap_path)

        # Read and verify data
        try
            portfolio_data = Vector{PortfolioEntry}()
            open(mmap_path, "r") do io
                for line in eachline(io)
                    parts = split(line, " "; limit=3)  # Split into 3 parts max
                    date = parts[1]
                    is_valid = parse(Bool, parts[2])
                    weights = JSON.parse(parts[3])
                    push!(portfolio_data, PortfolioEntry(date, weights, is_valid))
                end
            end
            println(portfolio_data[1])
            # Verify first entry
            @test portfolio_data[1].date == date_range[1]

            # Verify weights format
            @test length(portfolio_data[1].weights) == 3
            @test haskey(portfolio_data[1].weights[1], "AAPL")
            @test portfolio_data[1].weights[1]["AAPL"] ≈ 0.3f0
            @test portfolio_data[1].weights[2]["GOOGL"] ≈ 0.4f0
            @test portfolio_data[1].weights[3]["MSFT"] ≈ 0.3f0

            # Verify number of entries
            @test length(portfolio_data) == common_data_span

        finally
            GC.gc()
            safe_remove_file(mmap_path)
        end
    end

    @testset "Live Execution Tests" begin
        @testset "Parquet Live Execution" begin
            parquet_path = joinpath(test_dir, "$(test_hash).parquet")

            # Ensure clean state
            safe_remove_file(parquet_path)

            result = write_subtree_portfolio(
                date_range, end_date, test_hash, common_data_span, profile_history, true
            )
            @test result

            try
                @test isfile(parquet_path)
                df = DataFrame(Parquet2.Dataset(parquet_path))
                @test !any(df.date .== Dates.format(end_date, "yyyy-mm-dd"))
            finally
                GC.gc()
                safe_remove_file(parquet_path)
            end
        end

        @testset "Memory-Mapped Live Execution" begin
            mmap_path = joinpath(test_dir, "$(test_hash).mmap")

            # Ensure clean state
            safe_remove_file(mmap_path)

            result = write_subtree_portfolio_mmap(
                date_range, end_date, test_hash, common_data_span, profile_history, true
            )
            @test result

            try
                @test isfile(mmap_path)

                portfolio_data = Vector{PortfolioEntry}()
                open(mmap_path, "r") do io
                    for line in eachline(io)
                        parts = split(line, " "; limit=3)  # Split into 3 parts max
                        date = parts[1]
                        is_valid = parse(Bool, parts[2])
                        weights = JSON.parse(parts[3])
                        push!(portfolio_data, PortfolioEntry(date, weights, is_valid))
                    end
                end

                # Test that no entries have the end_date
                @test !any(
                    entry.date == Dates.format(end_date, "Y-m-d") for
                    entry in portfolio_data
                )

                # Additional test to verify the content  
                @test all(Date(entry.date) != end_date for entry in portfolio_data)

            finally
                GC.gc()
                safe_remove_file(mmap_path)
            end
        end
    end
    @testset "Append Subtree Portfolio Mmap Tests" begin
        test_dir = setup_test_environment()
        test_hash = "test_hash_append"
        mmap_path = joinpath(test_dir, "$(test_hash).mmap")

        @testset "Append to Empty File" begin
            date_range = [Dates.format(Date("2024-01-0$i"), "yyyy-mm-dd") for i in 1:5]
            stocks = [StockInfo("AAPL", 0.5f0), StockInfo("GOOGL", 0.5f0)]
            profile_history = [
                DayData([StockInfo("$(s.ticker)", s.weightTomorrow) for s in stocks]) for
                _ in 1:5
            ]
            end_date = Date("2024-01-05")
            common_data_span = 5

            result = append_subtree_portfolio_mmap(
                date_range, end_date, test_hash, common_data_span, profile_history
            )
            @test result

            portfolio_data = read_portfolio_data(mmap_path)
            @test length(portfolio_data) == 5
            @test portfolio_data[end].date == Dates.format(end_date, "yyyy-mm-dd")
            verify_weights(portfolio_data[1], "AAPL" => 0.5f0, "GOOGL" => 0.5f0)
        end

        @testset "Append New Data" begin
            new_date_range = [Dates.format(Date("2024-01-0$i"), "yyyy-mm-dd") for i in 6:10]
            new_profile_history = [
                DayData([StockInfo("AAPL", 0.6f0), StockInfo("GOOGL", 0.4f0)]) for _ in 6:10
            ]
            new_end_date = Date("2024-01-10")

            result = append_subtree_portfolio_mmap(
                new_date_range, new_end_date, test_hash, 5, new_profile_history
            )
            @test result

            portfolio_data = read_portfolio_data(mmap_path)
            @test length(portfolio_data) == 10
            verify_weights(portfolio_data[end], "AAPL" => 0.6f0, "GOOGL" => 0.4f0)
        end

        @testset "Append Overlapping Data" begin
            overlap_date_range = [
                Dates.format(Date("2024-01-0$i"), "yyyy-mm-dd") for i in 9:15
            ]
            overlap_profile_history = [
                DayData([StockInfo("AAPL", 0.7f0), StockInfo("GOOGL", 0.3f0)]) for _ in 9:15
            ]
            overlap_end_date = Date("2024-01-15")

            result = append_subtree_portfolio_mmap(
                overlap_date_range, overlap_end_date, test_hash, 7, overlap_profile_history
            )
            @test result

            portfolio_data = read_portfolio_data(mmap_path)
            @test length(portfolio_data) == 15
            verify_weights(portfolio_data[end], "AAPL" => 0.7f0, "GOOGL" => 0.3f0)
        end

        @testset "Append Non-chronological Data" begin
            non_chrono_dates = [18, 16, 20, 17, 19]
            non_chrono_date_range = [
                Dates.format(Date("2024-01-$i"), "yyyy-mm-dd") for i in non_chrono_dates
            ]
            non_chrono_profile_history = [
                DayData([StockInfo("AAPL", 0.8f0), StockInfo("GOOGL", 0.2f0)]) for _ in 1:5
            ]
            non_chrono_end_date = Date("2024-01-20")

            result = append_subtree_portfolio_mmap(
                non_chrono_date_range,
                non_chrono_end_date,
                test_hash,
                5,
                non_chrono_profile_history,
            )
            @test result

            portfolio_data = read_portfolio_data(mmap_path)
            @test length(portfolio_data) == 20
            verify_weights(portfolio_data[end], "AAPL" => 0.8f0, "GOOGL" => 0.2f0)
        end

        @testset "Append with Live Execution" begin
            live_date_range = [
                Dates.format(Date("2024-01-$i"), "yyyy-mm-dd") for i in 21:25
            ]
            live_profile_history = [DayData([StockInfo("AAPL", 1.0f0)]) for _ in 1:5]
            live_end_date = Date("2024-01-25")

            result = append_subtree_portfolio_mmap(
                live_date_range, live_end_date, test_hash, 5, live_profile_history, true
            )
            @test result

            portfolio_data = read_portfolio_data(mmap_path)
            @test length(portfolio_data) == 24  # Should not include last day
            @test Date(portfolio_data[end].date) == Date("2024-01-24")
            verify_weights(portfolio_data[end], "AAPL" => 1.0f0)
        end

        # Clean up
        safe_remove_file(mmap_path)
    end

    @testset "Read Subtree Portfolio Tests" begin
        test_dir = setup_test_environment()
        date_range, profile_history = create_test_data()
        end_date = Date("2024-01-30")
        test_hash = "test_hash_123"
        common_data_span = 30

        mmap_path = joinpath(test_dir, "$(test_hash).mmap")

        # Ensure clean state
        safe_remove_file(mmap_path)

        # Write test data
        result = write_subtree_portfolio_mmap(
            date_range, end_date, test_hash, common_data_span, profile_history, false
        )
        @test result

        @testset "Read Memory-Mapped Portfolio" begin
            try
                mask = BitVector([
                    true, true, true, true, true, true, true, true, true, true
                ])
                # Test reading the entire portfolio
                portfolio_history, last_date = read_subtree_portfolio_mmem(
                    test_hash, end_date, mask
                )
                @test !isnothing(portfolio_history)
                @test !isnothing(last_date)
                @test length(portfolio_history) == common_data_span
                @test last_date == Date("2024-01-30")

                # Verify first day content
                first_day = portfolio_history[1]
                @test length(first_day.stockList) == 3
                @test first_day.stockList[1].ticker == "AAPL"
                @test first_day.stockList[1].weightTomorrow ≈ 0.3f0
                @test first_day.stockList[2].ticker == "GOOGL"
                @test first_day.stockList[2].weightTomorrow ≈ 0.4f0
                @test first_day.stockList[3].ticker == "MSFT"
                @test first_day.stockList[3].weightTomorrow ≈ 0.3f0

                # Test reading with earlier end date
                earlier_end_date = Date("2024-01-15")
                mask = BitVector([
                    true, true, true, true, true, true, true, true, true, true
                ])
                partial_history, partial_last_date = read_subtree_portfolio_mmem(
                    test_hash, earlier_end_date, mask
                )
                @test length(partial_history) == 15
                @test partial_last_date == earlier_end_date

                # Test reading with future date
                future_date = Date("2024-02-01")
                future_history, future_last_date = read_subtree_portfolio_mmem(
                    test_hash, future_date, mask
                )
                @test length(future_history) == common_data_span
                @test future_last_date == Date("2024-01-30")

                # Test reading with past date
                past_date = Date("2023-12-31")
                past_history, past_last_date = read_subtree_portfolio_mmem(
                    test_hash, past_date, mask
                )
                @test isnothing(past_history)
                @test isnothing(past_last_date)

            finally
                GC.gc()
                safe_remove_file(mmap_path)
            end
        end

        @testset "Read Non-existent Portfolio" begin
            non_existent_hash = "non_existent_hash"
            mask = BitArray([
                true, false, true, false, true, false, true, false, true, false
            ])
            portfolio_history, last_date = read_subtree_portfolio_mmem(
                non_existent_hash, end_date, mask
            )
            @test isnothing(portfolio_history)
            @test isnothing(last_date)
        end
    end

    @testset "Parquet vs Memory-Mapped Comparison Tests" begin
        test_dir = setup_test_environment()
        date_range, profile_history = create_test_data()
        end_date = Date("2024-01-30")
        test_hash = "test_hash_123"
        common_data_span = 30

        @testset "Write Performance Comparison" begin
            # Ensure clean state
            safe_remove_file(joinpath(test_dir, "$(test_hash).parquet"))
            safe_remove_file(joinpath(test_dir, "$(test_hash).mmap"))

            # Parquet write
            parquet_time = @elapsed begin
                @time write_subtree_portfolio(
                    date_range,
                    end_date,
                    test_hash,
                    common_data_span,
                    profile_history,
                    false,
                )
                println("Time to Write Parquet")
            end

            # Memory-mapped write
            mmap_time = @elapsed begin
                @time write_subtree_portfolio_mmap(
                    date_range,
                    end_date,
                    test_hash,
                    common_data_span,
                    profile_history,
                    false,
                )
                println("Time to Write Mmem")
            end

            println("Parquet write time: $parquet_time seconds")
            println("Memory-mapped write time: $mmap_time seconds")

            @test isfile(joinpath(test_dir, "$(test_hash).parquet"))
            @test isfile(joinpath(test_dir, "$(test_hash).mmap"))
        end

        @testset "Read Performance Comparison" begin
            # Parquet read
            parquet_time = @elapsed begin
                parquet_portfolio, _ = @time read_subtree_portfolio(test_hash, end_date)
                println("Time to read parquet")
            end

            # Memory-mapped read
            mmap_time = @elapsed begin
                mask = BitVector(trues(length(profile_history)))
                mmap_portfolio, _ = @time read_subtree_portfolio_mmem(
                    test_hash, end_date, mask
                )
                println("Time to read Mmem")
            end

            println("Parquet read time: $parquet_time seconds")
            println("Memory-mapped read time: $mmap_time seconds")

            @test !isnothing(parquet_portfolio)
            @test !isnothing(mmap_portfolio)
        end

        @testset "Data Consistency Comparison" begin
            # Read data from both methods
            parquet_portfolio, parquet_last_date = read_subtree_portfolio(
                test_hash, end_date
            )
            mask = BitVector(trues(length(parquet_portfolio)))
            mmap_portfolio, mmap_last_date = read_subtree_portfolio_mmem(
                test_hash, end_date, mask
            )

            # Compare results
            @test length(parquet_portfolio) == length(mmap_portfolio)
            @test parquet_last_date == mmap_last_date

            for (parquet_day, mmap_day) in zip(parquet_portfolio, mmap_portfolio)
                @test length(parquet_day.stockList) == length(mmap_day.stockList)

                # Sort both lists by ticker for consistent comparison
                sort!(parquet_day.stockList; by=x -> x.ticker)
                sort!(mmap_day.stockList; by=x -> x.ticker)

                for (p_stock, m_stock) in zip(parquet_day.stockList, mmap_day.stockList)
                    @test p_stock.ticker == m_stock.ticker
                    @test isapprox(
                        p_stock.weightTomorrow, m_stock.weightTomorrow, atol=1e-6
                    )
                end
            end
        end

        @testset "Partial Read Comparison" begin
            partial_end_date = Date("2024-01-15")

            # Read partial data from both methods
            parquet_portfolio, parquet_last_date = read_subtree_portfolio(
                test_hash, partial_end_date
            )
            println(
                "Parquet last date: $parquet_last_date with length: $(length(parquet_portfolio))",
            )
            mask = BitVector(trues(15))
            mmap_portfolio, mmap_last_date = read_subtree_portfolio_mmem(
                test_hash, partial_end_date, mask
            )

            # Compare results
            @test length(parquet_portfolio) == length(mmap_portfolio)
            @test parquet_last_date == mmap_last_date
            @test parquet_last_date <= partial_end_date

            for (parquet_day, mmap_day) in zip(parquet_portfolio, mmap_portfolio)
                @test length(parquet_day.stockList) == length(mmap_day.stockList)

                # Sort both lists by ticker for consistent comparison
                sort!(parquet_day.stockList; by=x -> x.ticker)
                sort!(mmap_day.stockList; by=x -> x.ticker)

                for (p_stock, m_stock) in zip(parquet_day.stockList, mmap_day.stockList)
                    @test p_stock.ticker == m_stock.ticker
                    @test isapprox(
                        p_stock.weightTomorrow, m_stock.weightTomorrow, atol=1e-6
                    )
                end
            end
        end

        @testset "Memory Usage Comparison" begin
            # Parquet memory usage
            parquet_mem = @allocated begin
                parquet_portfolio, _ = read_subtree_portfolio(test_hash, end_date)
            end
            mask = BitArray([
                true, false, true, false, true, false, true, false, true, false
            ])
            # Memory-mapped memory usage
            mmap_mem = @allocated begin
                mmap_portfolio, _ = read_subtree_portfolio_mmem(test_hash, end_date, mask)
            end

            println("Parquet estimated memory usage: $parquet_mem bytes")
            println("Memory-mapped estimated memory usage: $mmap_mem bytes")

            @test true  # Memory usage comparison only
        end

        # Clean up
        safe_remove_file(joinpath(test_dir, "$(test_hash).parquet"))
        safe_remove_file(joinpath(test_dir, "$(test_hash).mmap"))
    end

    @testset "Append Comparison: Mmap vs Parquet" begin
        test_dir = setup_test_environment()
        test_hash = "test_hash_compare"
        mmap_path = joinpath(test_dir, "$(test_hash).mmap")
        parquet_path = joinpath(test_dir, "$(test_hash).parquet")

        function create_test_data(start_day, num_days)
            date_range = [
                Dates.format(Date("2024-01-$(i)"), "yyyy-mm-dd") for
                i in start_day:(start_day + num_days - 1)
            ]
            stocks = [
                StockInfo("AAPL", 0.3f0),
                StockInfo("GOOGL", 0.4f0),
                StockInfo("MSFT", 0.3f0),
            ]
            profile_history = [
                DayData([StockInfo("$(s.ticker)", s.weightTomorrow) for s in stocks]) for
                _ in 1:num_days
            ]
            return date_range, profile_history
        end

        @testset "Initial Write and Append" begin
            # Initial data
            date_range, profile_history = create_test_data(1, 10)
            end_date = Date("2024-01-10")
            common_data_span = 10

            # Write initial data
            mmap_write_time = @elapsed write_subtree_portfolio_mmap(
                date_range, end_date, test_hash, common_data_span, profile_history
            )
            parquet_write_time = @elapsed write_subtree_portfolio(
                date_range, end_date, test_hash, common_data_span, profile_history
            )

            println("Initial Mmap write time: $mmap_write_time seconds")
            println("Initial Parquet write time: $parquet_write_time seconds")

            # Append new data
            new_date_range, new_profile_history = create_test_data(11, 5)
            new_end_date = Date("2024-01-15")

            mmap_append_time = @elapsed append_subtree_portfolio_mmap(
                new_date_range, new_end_date, test_hash, 5, new_profile_history
            )
            parquet_append_time = @elapsed append_subtree_portfolio_in_parquet(
                new_profile_history, test_hash, new_end_date, new_date_range, 5
            )

            println("Mmap append time: $mmap_append_time seconds")
            println("Parquet append time: $parquet_append_time seconds")
            mask = BitArray([
                true, true, true, true, true, true, true, true, true, true, true, true
            ])
            # Verify data consistency
            mmap_portfolio, mmap_last_date = read_subtree_portfolio_mmem(
                test_hash, new_end_date, mask
            )
            parquet_portfolio, parquet_last_date = read_subtree_portfolio(
                test_hash, new_end_date
            )

            verify_portfolio_consistency(mmap_portfolio, parquet_portfolio)
            @test mmap_last_date == parquet_last_date
            @test mmap_last_date == new_end_date
        end

        @testset "Append Overlapping Data" begin
            overlap_date_range, overlap_profile_history = create_test_data(13, 5)
            overlap_end_date = Date("2024-01-17")

            mmap_overlap_time = @elapsed append_subtree_portfolio_mmap(
                overlap_date_range, overlap_end_date, test_hash, 5, overlap_profile_history
            )
            parquet_overlap_time = @elapsed append_subtree_portfolio_in_parquet(
                overlap_profile_history, test_hash, overlap_end_date, overlap_date_range, 5
            )

            println("Mmap overlap append time: $mmap_overlap_time seconds")
            println("Parquet overlap append time: $parquet_overlap_time seconds")
            mask = BitArray([
                true, true, true, true, true, true, true, true, true, true, true, true, true
            ])
            mmap_portfolio, mmap_last_date = read_subtree_portfolio_mmem(
                test_hash, overlap_end_date, mask
            )
            parquet_portfolio, parquet_last_date = read_subtree_portfolio(
                test_hash, overlap_end_date
            )

            verify_portfolio_consistency(mmap_portfolio, parquet_portfolio)
            @test mmap_last_date == parquet_last_date
            @test mmap_last_date == overlap_end_date
        end

        @testset "Append Non-chronological Data" begin
            non_chrono_dates = [20, 18, 22, 19, 21]
            non_chrono_date_range = [
                Dates.format(Date("2024-01-$i"), "yyyy-mm-dd") for i in non_chrono_dates
            ]
            non_chrono_profile_history = [
                DayData([StockInfo("AAPL", 0.5f0), StockInfo("GOOGL", 0.5f0)]) for _ in 1:5
            ]
            non_chrono_end_date = Date("2024-01-22")

            mmap_non_chrono_time = @elapsed append_subtree_portfolio_mmap(
                non_chrono_date_range,
                non_chrono_end_date,
                test_hash,
                5,
                non_chrono_profile_history,
            )
            parquet_non_chrono_time = @elapsed append_subtree_portfolio_in_parquet(
                non_chrono_profile_history,
                test_hash,
                non_chrono_end_date,
                non_chrono_date_range,
                5,
            )

            println("Mmap non-chronological append time: $mmap_non_chrono_time seconds")
            println(
                "Parquet non-chronological append time: $parquet_non_chrono_time seconds"
            )
            # all true mask
            mask = BitArray([true, true, true, true, true, true, true, true, true, true])
            mmap_portfolio, mmap_last_date = read_subtree_portfolio_mmem(
                test_hash, non_chrono_end_date, mask
            )
            parquet_portfolio, parquet_last_date = read_subtree_portfolio(
                test_hash, non_chrono_end_date
            )

            verify_portfolio_consistency(mmap_portfolio, parquet_portfolio)
            @test mmap_last_date == parquet_last_date
            @test mmap_last_date == non_chrono_end_date
        end

        @testset "Performance Metrics" begin
            final_end_date = Date("2024-01-22")
            mask = BitArray([true, true, true, true, true, true, true, true, true, true])
            # Read performance
            mmap_read_time = @elapsed (mmap_portfolio, _) = read_subtree_portfolio_mmem(
                test_hash, final_end_date, mask
            )
            parquet_read_time = @elapsed (parquet_portfolio, _) = read_subtree_portfolio(
                test_hash, final_end_date
            )
            println(
                "Read times - Mmap: $mmap_read_time, Parquet: $parquet_read_time seconds"
            )
            @test length(mmap_portfolio) == length(parquet_portfolio)

            mask = BitArray([true, true, true, true, true, true, true, true, true, true])
            # Memory usage
            mmap_mem = @allocated (mmap_portfolio, _) = read_subtree_portfolio_mmem(
                test_hash, final_end_date, mask
            )
            parquet_mem = @allocated (parquet_portfolio, _) = read_subtree_portfolio(
                test_hash, final_end_date
            )
            println("Memory usage - Mmap: $mmap_mem, Parquet: $parquet_mem bytes")

            # File size
            mmap_size = filesize(mmap_path)
            parquet_size = filesize(parquet_path)
            println("File sizes - Mmap: $mmap_size, Parquet: $parquet_size bytes")
        end

        # Clean up
        safe_remove_file(mmap_path)
        safe_remove_file(parquet_path)
    end

    @testset "Write Multiple Stocks Same Day" begin
        dates, data = create_multiple_test_data()
        hash = "test_hash"
        end_date = Date("2023-12-01")

        # Write data
        @test write_subtree_portfolio_mmap(
            dates, end_date, hash, length(dates), data, false
        )

        # Read and verify
        portfolio, dates_read, last_date = read_subtree_portfolio_with_dates_mmem(
            hash, end_date
        )

        @test length(portfolio) == 3
        @test dates_read == dates
        @test last_date == end_date

        # Verify individual entries
        @test length(portfolio[1].stockList) == 3
        @test length(portfolio[2].stockList) == 2
        @test length(portfolio[3].stockList) == 2

        # Verify stock data
        @test portfolio[1].stockList[1].ticker == "AAPL"
        @test portfolio[2].stockList[1].ticker == "AMZN"
        @test portfolio[3].stockList[1].ticker == "NFLX"
    end
    @testset "Write Empty StockList" begin
        empty_profile = [DayData(Vector{StockInfo}())]
        empty_dates = ["2024-01-01"]

        result = write_subtree_portfolio_mmap(
            empty_dates, Date("2024-01-01"), "empty_test", 1, empty_profile
        )
        @test result
        mask = BitArray([false])
        portfolio, last_date = read_subtree_portfolio_mmem(
            "empty_test", Date("2024-01-01"), mask
        )
        @test !isnothing(portfolio)
        @test length(portfolio) == 1
        @test isempty(portfolio[1].stockList)
        @test last_date == Date("2024-01-01")
    end
    @testset "Write Mixed Valid/Invalid Data" begin
        mixed_profile = [
            DayData(Vector{StockInfo}()),
            DayData([StockInfo("AAPL", 0.5)]),
            DayData(Vector{StockInfo}()),
        ]
        mixed_dates = ["2024-01-01", "2024-01-02", "2024-01-03"]

        result = write_subtree_portfolio_mmap(
            mixed_dates, Date("2024-01-03"), "mixed_test", 3, mixed_profile
        )
        @test result
        mask_ = BitArray([false, true, false])
        portfolio, last_date = read_subtree_portfolio_mmem(
            "mixed_test", Date("2024-01-03"), mask_
        )
        @test length(portfolio) == 3
        @test isempty(portfolio[1].stockList)
        @test !isempty(portfolio[2].stockList)
        @test isempty(portfolio[3].stockList)

        safe_remove_file(joinpath(test_dir, "mixed_test.mmap"))

        # Clean up
        rm(test_dir; recursive=true, force=true)
    end

    @testset "Update Invalid Data Tests" begin
        test_dir = setup_test_environment()
        test_hash = "test_hash_invalid"
        mmap_path = joinpath(test_dir, "$(test_hash).mmap")

        @testset "Update Invalid to Valid Data" begin
            # Initial data with invalid entry
            initial_dates = ["2024-01-01", "2024-01-02", "2024-01-03"]
            initial_profile = [
                DayData([StockInfo("AAPL", 0.5), StockInfo("SPY", 0.5)]),
                DayData(Vector{StockInfo}()), # Invalid data
                DayData([StockInfo("AAPL", 0.5), StockInfo("SPY", 0.5)]),
            ]

            # Write initial data
            write_subtree_portfolio_mmap(
                initial_dates, Date("2024-01-03"), test_hash, 3, initial_profile
            )

            # Verify initial state
            portfolio_data = read_portfolio_data(mmap_path)
            @test length(portfolio_data) == 3
            @test !portfolio_data[2].is_valid
            @test haskey(portfolio_data[2].weights[1], "NULLSTOCK")

            # Update with valid data
            update_dates = ["2024-01-01", "2024-01-02", "2024-01-03"]
            update_profile = [
                DayData(Vector{StockInfo}()),
                DayData([StockInfo("AAPL", 1.0)]), # Valid data
                DayData([StockInfo("AAPL", 0.5), StockInfo("SPY", 0.5)]),
            ]

            write_subtree_portfolio_mmap(
                update_dates, Date("2024-01-03"), test_hash, 3, update_profile
            )

            # Verify update
            updated_data = read_portfolio_data(mmap_path)
            println(updated_data)
            @test length(updated_data) == 3
            @test updated_data[2].is_valid
            @test haskey(updated_data[2].weights[1], "AAPL")
            @test updated_data[2].weights[1]["AAPL"] ≈ 1.0f0
        end

        @testset "Multiple Updates to Invalid Data" begin
            # Initial data
            initial_dates = ["2024-01-01", "2024-01-02", "2024-01-03"]
            initial_profile = [
                DayData(Vector{StockInfo}()),
                DayData(Vector{StockInfo}()),
                DayData([StockInfo("AAPL", 1.0)]),
            ]

            write_subtree_portfolio_mmap(
                initial_dates, Date("2024-01-03"), test_hash, 3, initial_profile
            )

            # First update
            update1_profile = [
                DayData([StockInfo("AAPL", 1.0)]),
                DayData(Vector{StockInfo}()),
                DayData([StockInfo("AAPL", 1.0)]),
            ]

            write_subtree_portfolio_mmap(
                initial_dates, Date("2024-01-03"), test_hash, 3, update1_profile
            )

            # Second update
            update2_profile = [
                DayData([StockInfo("AAPL", 1.0)]),
                DayData([StockInfo("GOOGL", 1.0)]),
                DayData([StockInfo("AAPL", 1.0)]),
            ]

            write_subtree_portfolio_mmap(
                initial_dates, Date("2024-01-03"), test_hash, 3, update2_profile
            )

            # Verify final state
            final_data = read_portfolio_data(mmap_path)
            @test length(final_data) == 3
            @test final_data[1].is_valid
            @test final_data[2].is_valid
            @test haskey(final_data[1].weights[1], "AAPL")
            @test haskey(final_data[2].weights[1], "GOOGL")
        end

        # Clean up
        safe_remove_file(mmap_path)
        rm(test_dir; recursive=true, force=true)
    end
end
@testset "Read with Active Mask Tests" begin
    test_dir = setup_test_environment()
    test_hash = "test_hash_mask"
    mmap_path = joinpath(test_dir, "$(test_hash).mmap")

    @testset "Longer Mask Than Data" begin
        # Write data with 3 entries [true, true, true]
        dates = ["2024-01-01", "2024-01-02", "2024-01-03"]
        profile = [
            DayData([StockInfo("AAPL", 0.5)]),
            DayData([StockInfo("GOOGL", 1.0)]),
            DayData([StockInfo("MSFT", 0.7)]),
        ]

        write_subtree_portfolio_mmap(dates, Date("2024-01-03"), test_hash, 3, profile)

        # Test with longer mask [false, false, true, true, true]
        # Should only check last 3 positions where mask is true
        active_mask = BitVector([false, false, true, true, true])
        portfolio_history, last_date = read_subtree_portfolio_mmem(
            test_hash, Date("2024-01-03"), active_mask
        )

        @test !isnothing(portfolio_history)
        @test !isnothing(last_date)
        safe_remove_file(mmap_path)
    end

    @testset "Complex Mixed Patterns" begin
        # Test 1: Data [true, false, true, false, true]
        dates = ["2024-01-01", "2024-01-02", "2024-01-03", "2024-01-04", "2024-01-05"]
        profile = [
            DayData([StockInfo("AAPL", 0.5)]),
            DayData(Vector{StockInfo}()),  # Invalid
            DayData([StockInfo("MSFT", 0.7)]),
            DayData(Vector{StockInfo}()),  # Invalid
            DayData([StockInfo("AMZN", 0.8)]),
        ]

        write_subtree_portfolio_mmap(dates, Date("2024-01-05"), test_hash, 5, profile)

        # Should PASS - only checking valid positions
        mask1 = BitVector([true, false, true, false, true])  # Exact match
        h1, d1 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-05"), mask1)
        @test !isnothing(h1)

        mask2 = BitVector([true, false, false, false, true])  # Checking first and last
        h2, d2 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-05"), mask2)
        @test !isnothing(h2)

        mask3 = BitVector([false, false, true, false, false])  # Checking only middle valid
        h3, d3 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-05"), mask3)
        @test !isnothing(h3)

        # Should FAIL - checking invalid positions
        mask4 = BitVector([false, true, false, true, false])  # Checking invalid positions
        h4, d4 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-05"), mask4)
        @test isnothing(h4)
        safe_remove_file(mmap_path)
    end

    @testset "Edge Cases" begin
        # Test 1: All invalid data with partial true mask
        dates = ["2024-01-01", "2024-01-02", "2024-01-03"]
        profile = [
            DayData(Vector{StockInfo}()),  # Invalid
            DayData(Vector{StockInfo}()),  # Invalid
            DayData(Vector{StockInfo}()),  # Invalid
        ]

        write_subtree_portfolio_mmap(dates, Date("2024-01-03"), test_hash, 3, profile)

        # Should FAIL - requires some valid entries
        mask1 = BitVector([true, false, false])
        h1, d1 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-03"), mask1)
        @test isnothing(h1)

        # Should PASS - doesn't require any valid entries
        mask2 = BitVector([false, false, false])
        h2, d2 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-03"), mask2)
        @test !isnothing(h2)

        # Test 2: All valid data with mixed mask
        profile = [
            DayData([StockInfo("AAPL", 0.5)]),
            DayData([StockInfo("GOOGL", 1.0)]),
            DayData([StockInfo("MSFT", 0.7)]),
        ]

        write_subtree_portfolio_mmap(dates, Date("2024-01-03"), test_hash, 3, profile)

        # Should PASS - all data is valid
        mask3 = BitVector([true, true, true])
        h3, d3 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-03"), mask3)
        @test !isnothing(h3)

        mask4 = BitVector([true, false, true])
        h4, d4 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-03"), mask4)
        @test !isnothing(h4)
        safe_remove_file(mmap_path)
    end

    @testset "Single Entry Tests" begin
        # Test with single entry
        dates = ["2024-01-01"]
        profile = [DayData([StockInfo("AAPL", 0.5)])]

        write_subtree_portfolio_mmap(dates, Date("2024-01-01"), test_hash, 1, profile)

        # Should PASS - valid entry with true mask
        mask1 = BitVector([true])
        h1, d1 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-01"), mask1)
        @test !isnothing(h1)

        # Should PASS - valid entry with false mask
        mask2 = BitVector([false])
        h2, d2 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-01"), mask2)
        @test !isnothing(h2)
        safe_remove_file(mmap_path)
        # Test with single invalid entry
        profile = [DayData(Vector{StockInfo}())]
        write_subtree_portfolio_mmap(dates, Date("2024-01-01"), test_hash, 1, profile)

        # Should FAIL - invalid entry with true mask
        mask3 = BitVector([true])
        h3, d3 = read_subtree_portfolio_mmem(test_hash, Date("2024-01-01"), mask3)
        @test isnothing(h3)
    end

    # Clean up
    safe_remove_file(mmap_path)
    rm(test_dir; recursive=true, force=true)
end
