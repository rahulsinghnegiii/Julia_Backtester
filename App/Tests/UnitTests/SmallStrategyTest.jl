"""
SmallStrategy.json Unit Tests
============================

This module provides comprehensive unit tests for SmallStrategy.json execution,
including direct strategy execution, expected results validation, and performance benchmarking.

The strategy being tested follows this logic:
1. If SPY current price < SPY SMA-200d: Buy QQQ
2. Else if QQQ current price < QQQ SMA-20d: Sort by RSI-10d (Top 1) → Buy PSQ or SHY
3. Else: Buy QQQ

Test Coverage:
- Direct strategy execution without HTTP server
- Exact match against expected portfolio history
- Exact match against expected return calculations
- Performance benchmarking and timing validation
- Cache validation and subtree cache verification
"""

include("../../Main.jl")
include("../../BacktestUtils/Types.jl") 
include("../../BacktestUtils/GlobalCache.jl")
include("../../BacktestUtils/ErrorHandlers.jl")
include("../../BacktestUtils/SubTreeCache.jl")
include("../E2E/FileComparator.jl")
include("../BenchmarkTimes.jl")

using Test
using JSON
using JSON3
using Dates
using DataFrames
using BenchmarkTools
using ..Types
using ..VectoriseBacktestService
using ..VectoriseBacktestService.GlobalServerCache
using ..SubtreeCache
using .FileComparator

# Initialize server cache for tests
initialize_server_cache()

@testset "SmallStrategy.json Unit Tests" begin
    
    @testset "Strategy Parsing and Structure Validation" begin
        # Load the strategy JSON
        strategy_json_path = "./App/Tests/E2E/JSONs/SmallStrategy.json"
        @test isfile(strategy_json_path)
        
        strategy_request = JSON.parse(read(strategy_json_path, String))
        @test haskey(strategy_request, "json")
        @test haskey(strategy_request, "period")
        @test haskey(strategy_request, "end_date")
        @test haskey(strategy_request, "hash")
        
        # Parse the embedded JSON strategy
        strategy_data = JSON.parse(strategy_request["json"])
        @test strategy_data["type"] == "root"
        @test haskey(strategy_data, "sequence")
        @test haskey(strategy_data, "tickers")
        @test haskey(strategy_data, "indicators")
        
        # Validate expected tickers
        expected_tickers = ["QQQ", "PSQ", "SHY"]
        @test Set(strategy_data["tickers"]) == Set(expected_tickers)
        
        # Validate strategy structure
        root_condition = strategy_data["sequence"][1]
        @test root_condition["type"] == "condition"
        @test root_condition["properties"]["comparison"] == "<"
        
        # Validate the conditional logic structure
        @test haskey(root_condition["branches"], "true")
        @test haskey(root_condition["branches"], "false")
        
        true_branch = root_condition["branches"]["true"]
        @test length(true_branch) == 1
        @test true_branch[1]["type"] == "stock"
        @test true_branch[1]["properties"]["symbol"] == "QQQ" "True branch should buy QQQ"
        
        false_branch = root_condition["branches"]["false"]
        @test length(false_branch) == 1 "False branch should have one nested condition"
        @test false_branch[1]["type"] == "condition" "False branch should contain another condition"
        
        println("✓ Strategy structure validation passed")
    end
    
    @testset "Direct Strategy Execution" begin
        println("\n--- Testing Direct Strategy Execution ---")
        
        # Load strategy data
        strategy_json_path = "./App/Tests/E2E/JSONs/SmallStrategy.json"
        strategy_request = JSON.parse(read(strategy_json_path, String))
        strategy_data = JSON.parse(strategy_request["json"])
        
        # Parse request parameters
        backtest_period = parse(Int, strategy_request["period"])
        end_date = Date(strategy_request["end_date"])
        strategy_hash = strategy_request["hash"]
        
        println("Executing strategy with:")
        println("  - Period: $backtest_period days")
        println("  - End Date: $end_date") 
        println("  - Strategy Hash: $strategy_hash")
        println("  - Expected Tickers: $(strategy_data["tickers"])")
        
        # Execute the backtest directly using the main engine
        result = handle_backtesting_api(
            strategy_data,
            backtest_period, 
            strategy_hash,
            end_date,
            false  # live_execution = false
        )
        
        @test result !== nothing "Strategy execution should return results"
        @test haskey(result, "returns") "Results should contain returns"
        @test haskey(result, "dates") "Results should contain dates"  
        @test haskey(result, "profile_history") "Results should contain profile_history"
        @test haskey(result, "days") "Results should contain days"
        
        # Validate result structure
        @test length(result["returns"]) > 0 "Returns should not be empty"
        @test length(result["dates"]) > 0 "Dates should not be empty"
        @test length(result["profile_history"]) > 0 "Profile history should not be empty"
        @test length(result["returns"]) == length(result["dates"]) "Returns and dates should have same length"
        @test length(result["profile_history"]) == length(result["dates"]) "Profile history and dates should have same length"
        
        # Validate that each day in profile history contains valid stock allocations
        for (i, day) in enumerate(result["profile_history"])
            @test haskey(day, "stockList") "Each day should have stockList"
            if !isempty(day["stockList"])
                for stock in day["stockList"] 
                    @test haskey(stock, "ticker") "Each stock should have ticker"
                    @test haskey(stock, "weightTomorrow") "Each stock should have weightTomorrow"
                    @test stock["ticker"] in ["QQQ", "PSQ", "SHY"] "Stock ticker should be one of expected tickers"
                    @test stock["weightTomorrow"] >= 0.0 "Weight should be non-negative"
                end
                
                # Validate weights sum to approximately 1.0 (allowing for floating point precision)
                total_weight = sum(stock["weightTomorrow"] for stock in day["stockList"])
                @test abs(total_weight - 1.0) < 1e-6 "Total weights should sum to 1.0"
            end
        end
        
        println("✓ Direct strategy execution completed successfully")
        println("  - Generated $(length(result["returns"])) return data points")
        println("  - Portfolio history spans $(length(result["profile_history"])) days")
        println("  - Final return: $(result["returns"][end])")
        
        # Store results for comparison tests
        global executed_result = result
    end
    
    @testset "Expected Results Validation" begin
        println("\n--- Testing Expected Results Validation ---")
        
        expected_file_path = "./App/Tests/E2E/ExpectedFiles/SmallStrategy.json"
        @test isfile(expected_file_path) "Expected results file must exist"
        
        expected_data = JSON.parse(read(expected_file_path, String))
        
        # Use the executed result from previous test
        actual_result = executed_result
        
        # Compare portfolio history up to a specific date for consistency
        comparison_date = "2024-01-02"
        comparison_date_index = findfirst(x -> x == comparison_date, expected_data["dates"])
        @test comparison_date_index !== nothing "Comparison date should exist in expected data"
        
        actual_date_index = findfirst(x -> x == comparison_date, actual_result["dates"])
        @test actual_date_index !== nothing "Comparison date should exist in actual results"
        
        # Compare profile history up to comparison date
        expected_profile_history = expected_data["profile_history"][1:comparison_date_index]
        actual_profile_history = actual_result["profile_history"][1:actual_date_index]
        
        @test length(expected_profile_history) == length(actual_profile_history) "Profile histories should have same length up to comparison date"
        
        # Detailed comparison of each day's portfolio
        for (i, (expected_day, actual_day)) in enumerate(zip(expected_profile_history, actual_profile_history))
            @test Set([(stock["ticker"], stock["weightTomorrow"]) for stock in expected_day["stockList"]]) == 
                  Set([(stock["ticker"], stock["weightTomorrow"]) for stock in actual_day["stockList"]]) "Day $i portfolio should match expected"
        end
        
        # Compare returns up to comparison date  
        expected_returns = expected_data["returns"][1:comparison_date_index]
        actual_returns = actual_result["returns"][1:actual_date_index]
        
        @test length(expected_returns) == length(actual_returns) "Returns should have same length up to comparison date"
        
        # Allow small floating point differences in returns comparison
        for (i, (expected_return, actual_return)) in enumerate(zip(expected_returns, actual_returns))
            @test abs(expected_return - actual_return) < 1e-6 "Day $i return should match expected (expected: $expected_return, actual: $actual_return)"
        end
        
        # Compare dates
        expected_dates = expected_data["dates"][1:comparison_date_index]
        actual_dates = actual_result["dates"][1:actual_date_index]
        @test expected_dates == actual_dates "Dates should match exactly"
        
        println("✓ Expected results validation passed")
        println("  - Compared $(length(expected_profile_history)) days of portfolio history")
        println("  - Compared $(length(expected_returns)) return data points")
        println("  - All results match expected values exactly")
    end
    
    @testset "Cache Validation" begin
        println("\n--- Testing Cache Validation ---")
        
        strategy_hash = "d2936843a0ad3275a5f5e72749594ffe"
        
        # Verify main cache directory exists
        cache_dir = "./App/Cache/$strategy_hash"
        @test isdir(cache_dir) "Cache directory should exist after execution"
        
        # Verify cache file exists
        cache_file = "$cache_dir/$strategy_hash.json"
        @test isfile(cache_file) "Cache file should exist"
        
        # Validate cache file structure
        cache_data = JSON.parse(read(cache_file, String))
        @test haskey(cache_data, "returns") "Cache should contain returns"
        @test haskey(cache_data, "dates") "Cache should contain dates" 
        @test haskey(cache_data, "profile_history") "Cache should contain profile_history"
        
        # Verify subtree cache
        @test isdir("./App/SubtreeCache") "SubtreeCache directory should exist"
        
        # Expected subtree hashes from strategy structure
        expected_subtree_hashes = [
            "2511ec40670864a5df3291f137f8f5c7",
            "7457fea7ea524c71fda4053459977a7e", 
            "ddd84df46214783f11e60e928760cd18"
        ]
        
        comparison_date = "2024-01-02"
        result_length = length(executed_result["dates"])
        
        for hash in expected_subtree_hashes
            @test compare_subtree_cache_files(hash, result_length, comparison_date) "Subtree cache $hash should match expected"
        end
        
        println("✓ Cache validation passed")
        println("  - Main cache file validated: $cache_file")
        println("  - $(length(expected_subtree_hashes)) subtree caches validated")
    end
    
    @testset "Performance Benchmarking" begin
        println("\n--- Testing Performance Benchmarking ---")
        
        # Load strategy data for benchmarking
        strategy_json_path = "./App/Tests/E2E/JSONs/SmallStrategy.json"
        strategy_request = JSON.parse(read(strategy_json_path, String))
        strategy_data = JSON.parse(strategy_request["json"])
        
        backtest_period = parse(Int, strategy_request["period"])
        end_date = Date(strategy_request["end_date"])
        strategy_hash = strategy_request["hash"]
        
        println("Benchmarking SmallStrategy execution...")
        
        # Clean cache to ensure fresh execution for benchmarking
        cleanup_cache()
        initialize_server_cache()
        
        # Benchmark the complete strategy execution
        timing_data = @benchmark handle_backtesting_api(
            $strategy_data,
            $backtest_period,
            $strategy_hash, 
            $end_date,
            false
        ) samples=3 evals=1
        
        min_time = minimum(timing_data).time * 1e-9  # Convert nanoseconds to seconds
        max_time = maximum(timing_data).time * 1e-9
        mean_time = mean(timing_data).time * 1e-9
        
        println("SmallStrategy Execution Performance:")
        println("  - Minimum time: $(round(min_time, digits=6)) seconds")
        println("  - Maximum time: $(round(max_time, digits=6)) seconds") 
        println("  - Mean time: $(round(mean_time, digits=6)) seconds")
        println("  - Memory allocated: $(timing_data.memory) bytes")
        println("  - Allocations: $(timing_data.allocs)")
        
        # Performance validation - should complete within reasonable time
        @test min_time < 10.0 "Strategy execution should complete within 10 seconds"
        @test min_time > 0.001 "Strategy execution should take measurable time (> 1ms)"
        
        # Log performance for regression tracking
        println("\n--- Performance Regression Tracking ---")
        println("MIN_SMALL_STRATEGY_EXECUTION = $min_time")
        
        # Benchmark individual components
        println("\nBenchmarking individual components:")
        
        # Benchmark strategy parsing
        parse_timing = @benchmark JSON.parse($(strategy_request["json"])) 
        parse_time = minimum(parse_timing).time * 1e-9
        println("  - Strategy parsing: $(round(parse_time, digits=6)) seconds")
        
        # Benchmark cache operations (if cache exists)
        cache_dir = "./App/Cache/$strategy_hash"
        if isdir(cache_dir)
            cache_file = "$cache_dir/$strategy_hash.json"
            if isfile(cache_file)
                cache_timing = @benchmark JSON.parse(read($cache_file, String))
                cache_time = minimum(cache_timing).time * 1e-9
                println("  - Cache file reading: $(round(cache_time, digits=6)) seconds")
            end
        end
        
        println("✓ Performance benchmarking completed")
    end
    
    @testset "Error Handling and Edge Cases" begin
        println("\n--- Testing Error Handling ---")
        
        # Test with invalid JSON
        @test_throws Exception handle_backtesting_api(
            Dict("invalid" => "structure"),
            1260,
            "test_hash", 
            Date("2024-11-25"),
            false
        )
        
        # Test with zero period
        strategy_json_path = "./App/Tests/E2E/JSONs/SmallStrategy.json"
        strategy_request = JSON.parse(read(strategy_json_path, String))
        strategy_data = JSON.parse(strategy_request["json"])
        
        @test_throws Exception handle_backtesting_api(
            strategy_data,
            0,  # Invalid period
            "test_hash",
            Date("2024-11-25"),
            false
        )
        
        # Test with future end date (should work but with limited data)
        future_date = Date("2030-01-01")
        result = handle_backtesting_api(
            strategy_data,
            100,
            "future_test_hash",
            future_date,
            false
        )
        @test result !== nothing "Strategy should handle future dates gracefully"
        
        println("✓ Error handling tests passed")
    end
end

println("\n" * "="^60)
println("SmallStrategy.json Unit Tests Completed Successfully!")
println("="^60)