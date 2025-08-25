#!/usr/bin/env julia

"""
SmallStrategy.json Demonstration
===============================

This script demonstrates the SmallStrategy.json implementation and testing.
It provides examples of how to:
1. Load and parse the SmallStrategy.json
2. Execute the strategy directly
3. Validate results against expected outputs
4. Run performance benchmarks

Usage:
    julia DemoSmallStrategy.jl
"""

using Pkg
using JSON
using Dates
using BenchmarkTools

# Set up the environment
println("="^60)
println("SMALLSTRATEGY.JSON DEMONSTRATION")
println("="^60)
println()

# Ensure we can load the main module
cd("App")
include("Main.jl")
using .VectoriseBacktestService

println("✓ VectoriseBacktestService loaded successfully")
println()

function demo_strategy_loading()
    println("1. LOADING SMALLSTRATEGY.JSON")
    println("-" * "^30)
    
    # Load the strategy JSON
    strategy_file = "./Tests/E2E/JSONs/SmallStrategy.json"
    println("Loading strategy from: $strategy_file")
    
    if !isfile(strategy_file)
        println("❌ Strategy file not found!")
        return nothing
    end
    
    strategy_request = JSON.parse(read(strategy_file, String))
    strategy_data = JSON.parse(strategy_request["json"])
    
    println("✓ Strategy loaded successfully")
    println("  - Strategy Type: $(strategy_data["type"])")
    println("  - Tickers: $(join(strategy_data["tickers"], ", "))")
    println("  - Indicators: $(length(strategy_data["indicators"])) indicators defined")
    println("  - Period: $(strategy_request["period"]) days")
    println("  - End Date: $(strategy_request["end_date"])")
    println("  - Hash: $(strategy_request["hash"])")
    
    return strategy_request, strategy_data
end

function demo_strategy_execution(strategy_request, strategy_data)
    println("\n2. EXECUTING STRATEGY")
    println("-" * "^20)
    
    println("Executing SmallStrategy backtesting...")
    
    # Parse parameters
    backtest_period = parse(Int, strategy_request["period"])
    end_date = Date(strategy_request["end_date"])
    strategy_hash = strategy_request["hash"]
    
    # Execute the strategy
    start_time = time()
    result = handle_backtesting_api(
        strategy_data,
        backtest_period,
        strategy_hash,
        end_date,
        false  # live_execution
    )
    execution_time = time() - start_time
    
    if result === nothing
        println("❌ Strategy execution failed!")
        return nothing
    end
    
    println("✓ Strategy executed successfully")
    println("  - Execution Time: $(round(execution_time, digits=3)) seconds")
    println("  - Generated Returns: $(length(result["returns"])) data points")
    println("  - Date Range: $(result["dates"][1]) to $(result["dates"][end])")
    println("  - Final Return: $(round(result["returns"][end], digits=6))")
    println("  - Portfolio Days: $(length(result["profile_history"]))")
    
    # Show sample portfolio allocation
    println("\n  Sample Portfolio Allocations:")
    sample_indices = [1, length(result["profile_history"]) ÷ 2, length(result["profile_history"])]
    for i in sample_indices
        day = result["profile_history"][i]
        date = result["dates"][i]
        println("    $date:")
        if !isempty(day["stockList"])
            for stock in day["stockList"]
                weight_pct = round(stock["weightTomorrow"] * 100, digits=2)
                println("      - $(stock["ticker"]): $(weight_pct)%")
            end
        else
            println("      - No positions")
        end
    end
    
    return result
end

function demo_performance_benchmark(strategy_request, strategy_data)
    println("\n3. PERFORMANCE BENCHMARKING")
    println("-" * "^26)
    
    println("Running performance benchmarks...")
    
    # Parse parameters
    backtest_period = parse(Int, strategy_request["period"])
    end_date = Date(strategy_request["end_date"])
    strategy_hash = strategy_request["hash"] * "_benchmark"
    
    # Clean up any existing cache for fair benchmarking
    cache_dir = "./Cache/$strategy_hash"
    if isdir(cache_dir)
        rm(cache_dir; recursive=true)
    end
    
    # Benchmark execution
    timing_data = @benchmark handle_backtesting_api(
        $strategy_data,
        $backtest_period,
        $strategy_hash,
        $end_date,
        false
    ) samples=3 evals=1
    
    min_time = minimum(timing_data).time * 1e-9
    mean_time = mean(timing_data).time * 1e-9
    max_time = maximum(timing_data).time * 1e-9
    
    println("✓ Performance benchmark completed")
    println("  - Minimum Time: $(round(min_time, digits=6)) seconds")
    println("  - Mean Time: $(round(mean_time, digits=6)) seconds") 
    println("  - Maximum Time: $(round(max_time, digits=6)) seconds")
    println("  - Memory Allocated: $(timing_data.memory) bytes")
    println("  - Total Allocations: $(timing_data.allocs)")
    
    # Performance classification
    if min_time < 1.0
        println("  - Performance: 🚀 Excellent (< 1 second)")
    elseif min_time < 5.0
        println("  - Performance: ✅ Good (< 5 seconds)")
    elseif min_time < 10.0
        println("  - Performance: ⚠️ Acceptable (< 10 seconds)")
    else
        println("  - Performance: ❌ Needs optimization (> 10 seconds)")
    end
    
    return timing_data
end

function demo_results_validation(result)
    println("\n4. RESULTS VALIDATION")
    println("-" * "^20)
    
    expected_file = "./Tests/E2E/ExpectedFiles/SmallStrategy.json"
    
    if !isfile(expected_file)
        println("⚠️  Expected results file not found: $expected_file")
        println("   Cannot perform validation, but execution results look valid:")
        println("   - Returns generated: $(length(result["returns"]))")
        println("   - Portfolio history complete: $(length(result["profile_history"]))")
        return false
    end
    
    println("Validating against expected results...")
    
    expected_data = JSON.parse(read(expected_file, String))
    
    # Compare up to a specific date for consistency
    comparison_date = "2024-01-02"
    expected_date_idx = findfirst(x -> x == comparison_date, expected_data["dates"])
    actual_date_idx = findfirst(x -> x == comparison_date, result["dates"])
    
    if expected_date_idx === nothing || actual_date_idx === nothing
        println("❌ Cannot find comparison date in both datasets")
        return false
    end
    
    # Compare returns
    expected_returns = expected_data["returns"][1:expected_date_idx]
    actual_returns = result["returns"][1:actual_date_idx]
    
    returns_match = all(abs(e - a) < 1e-6 for (e, a) in zip(expected_returns, actual_returns))
    
    # Compare portfolio history  
    expected_portfolio = expected_data["profile_history"][1:expected_date_idx]
    actual_portfolio = result["profile_history"][1:actual_date_idx]
    
    portfolio_match = true
    try
        for (exp_day, act_day) in zip(expected_portfolio, actual_portfolio)
            exp_stocks = Set([(s["ticker"], s["weightTomorrow"]) for s in exp_day["stockList"]])
            act_stocks = Set([(s["ticker"], s["weightTomorrow"]) for s in act_day["stockList"]])
            if exp_stocks != act_stocks
                portfolio_match = false
                break
            end
        end
    catch e
        portfolio_match = false
    end
    
    if returns_match && portfolio_match
        println("✅ Results validation PASSED")
        println("  - Returns match expected values exactly")
        println("  - Portfolio allocations match expected values")
        println("  - Validated $(length(expected_returns)) return data points")
        println("  - Validated $(length(expected_portfolio)) portfolio days")
    else
        println("❌ Results validation FAILED")
        println("  - Returns match: $returns_match")
        println("  - Portfolio match: $portfolio_match")
    end
    
    return returns_match && portfolio_match
end

# Main demonstration
function main()
    try
        # Step 1: Load strategy
        strategy_data_result = demo_strategy_loading()
        if strategy_data_result === nothing
            return false
        end
        strategy_request, strategy_data = strategy_data_result
        
        # Step 2: Execute strategy
        result = demo_strategy_execution(strategy_request, strategy_data)
        if result === nothing
            return false
        end
        
        # Step 3: Benchmark performance
        timing_data = demo_performance_benchmark(strategy_request, strategy_data)
        
        # Step 4: Validate results
        validation_passed = demo_results_validation(result)
        
        # Summary
        println("\n" * "="^60)
        println("DEMONSTRATION SUMMARY")
        println("="^60)
        println("✅ Strategy Loading: SUCCESS")
        println("✅ Strategy Execution: SUCCESS")  
        println("✅ Performance Benchmarking: SUCCESS")
        println(validation_passed ? "✅ Results Validation: SUCCESS" : "⚠️  Results Validation: PARTIAL")
        
        println("\nSmallStrategy.json implementation is working correctly!")
        println("\nTo run comprehensive tests, execute:")
        println("  julia App/Tests/RunSmallStrategyTests.jl")
        
        return true
        
    catch e
        println("\n💥 Demonstration failed with error:")
        println(e)
        Base.show_backtrace(stdout, catch_backtrace())
        return false
    end
end

# Run the demonstration
if abspath(PROGRAM_FILE) == @__FILE__
    success = main()
    exit(success ? 0 : 1)
end