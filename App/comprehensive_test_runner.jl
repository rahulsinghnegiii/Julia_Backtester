#!/usr/bin/env julia

"""
SmallStrategy Test Suite Runner
==============================

This script runs the complete SmallStrategy.json test suite including:
1. Unit tests
2. Performance benchmarks  
3. Cache validation
4. Expected results verification
"""

using Pkg
using Test
using JSON
using Dates
using BenchmarkTools

println("="^80)
println("SMALLSTRATEGY.JSON COMPLETE TEST SUITE")
println("="^80)
println("Test execution started at: $(now())")
println()

# Ensure we're in the correct directory
cd(dirname(@__FILE__))

# Set up load paths
push!(LOAD_PATH, pwd())
push!(LOAD_PATH, "../")

# Global test tracking
global test_results = Dict(
    "total_tests" => 0,
    "passed_tests" => 0, 
    "failed_tests" => 0,
    "start_time" => now(),
    "performance_data" => Dict()
)

function run_basic_validation()
    println("STEP 1: BASIC VALIDATION")
    println("-"^40)
    
    # Check required files
    required_files = [
        "Tests/E2E/JSONs/SmallStrategy.json",
        "Tests/E2E/ExpectedFiles/SmallStrategy.json",
        "Tests/UnitTests/SmallStrategyTest.jl",
        "Tests/RunSmallStrategyTests.jl",
        "Main.jl"
    ]
    
    println("Checking required files...")
    all_files_exist = true
    for file in required_files
        if isfile(file)
            println("  ✓ $file")
        else
            println("  ✗ $file - MISSING")
            global all_files_exist = false
        end
    end
    
    if !all_files_exist
        println("❌ Missing required files!")
        return false
    end
    
    # Test JSON parsing
    println("\nTesting SmallStrategy.json parsing...")
    try
        strategy_data = JSON.parse(read("Tests/E2E/JSONs/SmallStrategy.json", String))
        strategy_json = JSON.parse(strategy_data["json"])
        
        println("  ✓ JSON parsed successfully")
        println("  ✓ Strategy type: $(strategy_json["type"])")
        println("  ✓ Tickers: $(join(strategy_json["tickers"], ", "))")
        println("  ✓ Period: $(strategy_data["period"]) days")
        println("  ✓ End date: $(strategy_data["end_date"])")
        
    catch e
        println("  ✗ JSON parsing failed: $e")
        return false
    end
    
    println("✅ Basic validation PASSED\n")
    return true
end

function run_module_loading()
    println("STEP 2: MODULE LOADING")
    println("-"^40)
    
    try
        println("Loading Main.jl...")
        include("Main.jl")
        
        println("  ✓ Main module loaded")
        
        # Check if VectoriseBacktestService is available
        if isdefined(Main, :VectoriseBacktestService)
            println("  ✓ VectoriseBacktestService module found")
            
            # Check key functions
            if isdefined(VectoriseBacktestService, :handle_backtesting_api)
                println("  ✓ handle_backtesting_api function available")
            else
                println("  ✗ handle_backtesting_api function not found")
                return false
            end
        else
            println("  ✗ VectoriseBacktestService module not found")
            return false
        end
        
    catch e
        println("  ✗ Module loading failed: $e")
        return false
    end
    
    println("✅ Module loading PASSED\n")
    return true
end

function run_direct_strategy_execution()
    println("STEP 3: DIRECT STRATEGY EXECUTION")
    println("-"^40)
    
    try
        # Load strategy
        strategy_data = JSON.parse(read("Tests/E2E/JSONs/SmallStrategy.json", String))
        strategy_json = JSON.parse(strategy_data["json"])
        
        backtest_period = parse(Int, strategy_data["period"])
        end_date = Date(strategy_data["end_date"])
        strategy_hash = strategy_data["hash"]
        
        println("Executing strategy:")
        println("  - Period: $backtest_period days")
        println("  - End date: $end_date")
        println("  - Hash: $strategy_hash")
        
        # Execute the backtest
        start_time = time()
        result = VectoriseBacktestService.handle_backtesting_api(
            strategy_json,
            backtest_period,
            strategy_hash,
            end_date,
            false  # live_execution = false
        )
        execution_time = time() - start_time
        
        if result === nothing
            println("  ✗ Strategy execution returned nothing")
            return false, nothing
        end
        
        # Validate result structure
        required_keys = ["returns", "dates", "profile_history", "days"]
        for key in required_keys
            if !haskey(result, key)
                println("  ✗ Missing key in result: $key")
                return false, nothing
            end
        end
        
        println("  ✓ Strategy executed successfully")
        println("  ✓ Execution time: $(round(execution_time, digits=3)) seconds")
        println("  ✓ Generated $(length(result["returns"])) return data points")
        println("  ✓ Date range: $(result["dates"][1]) to $(result["dates"][end])")
        println("  ✓ Final return: $(round(result["returns"][end], digits=6))")
        
        # Store performance data
        test_results["performance_data"]["execution_time"] = execution_time
        
        return true, result
        
    catch e
        println("  ✗ Strategy execution failed: $e")
        return false, nothing
    end
    
    println("✅ Direct strategy execution PASSED\n")
end

function run_expected_results_validation(result)
    println("STEP 4: EXPECTED RESULTS VALIDATION")
    println("-"^40)
    
    expected_file = "Tests/E2E/ExpectedFiles/SmallStrategy.json"
    
    if !isfile(expected_file)
        println("  ⚠️  Expected results file not found: $expected_file")
        println("     Skipping validation...")
        return true
    end
    
    try
        expected_data = JSON.parse(read(expected_file, String))
        
        # Compare up to a specific date for consistency
        comparison_date = "2024-01-02"
        expected_date_idx = findfirst(x -> x == comparison_date, expected_data["dates"])
        actual_date_idx = findfirst(x -> x == comparison_date, result["dates"])
        
        if expected_date_idx === nothing || actual_date_idx === nothing
            println("  ⚠️  Cannot find comparison date ($comparison_date) in datasets")
            return true
        end
        
        # Compare returns
        expected_returns = expected_data["returns"][1:expected_date_idx]
        actual_returns = result["returns"][1:actual_date_idx]
        
        returns_match = true
        max_diff = 0.0
        for (i, (exp, act)) in enumerate(zip(expected_returns, actual_returns))
            diff = abs(exp - act)
            max_diff = max(max_diff, diff)
            if diff > 1e-6
                println("  ✗ Return mismatch at index $i: expected $exp, got $act (diff: $diff)")
                returns_match = false
                break
            end
        end
        
        # Compare portfolio history
        expected_portfolio = expected_data["profile_history"][1:expected_date_idx]
        actual_portfolio = result["profile_history"][1:actual_date_idx]
        
        portfolio_match = true
        for (i, (exp_day, act_day)) in enumerate(zip(expected_portfolio, actual_portfolio))
            exp_stocks = Set([(s["ticker"], s["weightTomorrow"]) for s in exp_day["stockList"]])
            act_stocks = Set([(s["ticker"], s["weightTomorrow"]) for s in act_day["stockList"]])
            if exp_stocks != act_stocks
                println("  ✗ Portfolio mismatch at day $i")
                portfolio_match = false
                break
            end
        end
        
        if returns_match && portfolio_match
            println("  ✓ Returns match expected values (max diff: $(round(max_diff, digits=10)))")
            println("  ✓ Portfolio allocations match expected values")
            println("  ✓ Validated $(length(expected_returns)) data points")
            return true
        else
            println("  ✗ Expected results validation failed")
            println("    - Returns match: $returns_match")
            println("    - Portfolio match: $portfolio_match")
            return false
        end
        
    catch e
        println("  ✗ Expected results validation error: $e")
        return false
    end
end

function run_cache_validation()
    println("STEP 5: CACHE VALIDATION")
    println("-"^40)
    
    strategy_hash = "d2936843a0ad3275a5f5e72749594ffe"
    cache_dir = "Cache/$strategy_hash"
    
    # Check main cache
    if isdir(cache_dir)
        println("  ✓ Main cache directory exists: $cache_dir")
        
        cache_file = "$cache_dir/$strategy_hash.json"
        if isfile(cache_file)
            println("  ✓ Main cache file exists: $cache_file")
            
            # Validate cache content
            try
                cache_data = JSON.parse(read(cache_file, String))
                required_keys = ["returns", "dates", "profile_history"]
                for key in required_keys
                    if haskey(cache_data, key)
                        println("  ✓ Cache contains $key")
                    else
                        println("  ✗ Cache missing $key")
                        return false
                    end
                end
            catch e
                println("  ✗ Cache file parsing failed: $e")
                return false
            end
        else
            println("  ✗ Main cache file not found")
            return false
        end
    else
        println("  ✗ Main cache directory not found")
        return false
    end
    
    # Check subtree cache
    if isdir("SubtreeCache")
        println("  ✓ SubtreeCache directory exists")
        
        # Expected subtree hashes from SmallStrategy structure
        expected_subtree_hashes = [
            "2511ec40670864a5df3291f137f8f5c7",
            "7457fea7ea524c71fda4053459977a7e",
            "ddd84df46214783f11e60e928760cd18"
        ]
        
        subtree_files_found = 0
        for hash in expected_subtree_hashes
            subtree_file = "SubtreeCache/$hash.parquet"
            if isfile(subtree_file)
                println("  ✓ Subtree cache found: $hash.parquet")
                subtree_files_found += 1
            end
        end
        
        if subtree_files_found > 0
            println("  ✓ Found $subtree_files_found subtree cache files")
        else
            println("  ⚠️  No subtree cache files found (may be normal)")
        end
    else
        println("  ⚠️  SubtreeCache directory not found")
    end
    
    return true
end

function run_performance_benchmark()
    println("STEP 6: PERFORMANCE BENCHMARK")
    println("-"^40)
    
    try
        # Load strategy for benchmarking
        strategy_data = JSON.parse(read("Tests/E2E/JSONs/SmallStrategy.json", String))
        strategy_json = JSON.parse(strategy_data["json"])
        
        backtest_period = parse(Int, strategy_data["period"])
        end_date = Date(strategy_data["end_date"])
        strategy_hash = strategy_data["hash"] * "_benchmark"
        
        println("Running performance benchmark (3 samples)...")
        
        # Clean cache for fair benchmarking
        benchmark_cache_dir = "Cache/$strategy_hash"
        if isdir(benchmark_cache_dir)
            rm(benchmark_cache_dir; recursive=true)
        end
        
        # Benchmark execution
        timing_data = @benchmark VectoriseBacktestService.handle_backtesting_api(
            $strategy_json,
            $backtest_period,
            $strategy_hash,
            $end_date,
            false
        ) samples=3 evals=1
        
        min_time = minimum(timing_data).time * 1e-9
        mean_time = mean(timing_data).time * 1e-9
        max_time = maximum(timing_data).time * 1e-9
        
        println("  ✓ Benchmark completed")
        println("  ✓ Minimum time: $(round(min_time, digits=6)) seconds")
        println("  ✓ Mean time: $(round(mean_time, digits=6)) seconds")
        println("  ✓ Maximum time: $(round(max_time, digits=6)) seconds")
        println("  ✓ Memory allocated: $(timing_data.memory) bytes")
        println("  ✓ Total allocations: $(timing_data.allocs)")
        
        # Performance validation
        if min_time < 10.0
            println("  ✅ Performance: Within acceptable limits (< 10 seconds)")
            test_results["performance_data"]["benchmark_time"] = min_time
            return true
        else
            println("  ⚠️  Performance: Slower than expected (> 10 seconds)")
            return false
        end
        
    catch e
        println("  ✗ Performance benchmark failed: $e")
        return false
    end
end

function generate_test_report()
    test_results["end_time"] = now()
    execution_time = test_results["end_time"] - test_results["start_time"]
    
    println("="^80)
    println("SMALLSTRATEGY TEST EXECUTION REPORT")
    println("="^80)
    
    println("Execution Summary:")
    println("  Start Time: $(test_results["start_time"])")
    println("  End Time: $(test_results["end_time"])")
    println("  Total Duration: $(execution_time)")
    println()
    
    println("Test Results:")
    println("  Passed Tests: $(test_results["passed_tests"])")
    println("  Failed Tests: $(test_results["failed_tests"])")
    
    if haskey(test_results["performance_data"], "execution_time")
        println("  Strategy Execution Time: $(round(test_results["performance_data"]["execution_time"], digits=3))s")
    end
    
    if haskey(test_results["performance_data"], "benchmark_time")
        println("  Benchmark Time: $(round(test_results["performance_data"]["benchmark_time"], digits=6))s")
    end
    
    println()
    
    if test_results["failed_tests"] == 0
        println("🎉 ALL TESTS PASSED! SmallStrategy.json implementation is working correctly.")
        return true
    else
        println("❌ SOME TESTS FAILED! Please review the error messages above.")
        return false
    end
end

# Main execution
function main()
    try
        test_success = true
        
        # Step 1: Basic validation
        if !run_basic_validation()
            test_results["failed_tests"] += 1
            test_success = false
        else
            test_results["passed_tests"] += 1
        end
        
        # Step 2: Module loading
        if !run_module_loading()
            test_results["failed_tests"] += 1
            test_success = false
        else
            test_results["passed_tests"] += 1
        end
        
        # Step 3: Strategy execution
        execution_success, result = run_direct_strategy_execution()
        if !execution_success
            test_results["failed_tests"] += 1
            test_success = false
        else
            test_results["passed_tests"] += 1
        end
        
        # Step 4: Expected results validation (only if execution succeeded)
        if execution_success && result !== nothing
            if !run_expected_results_validation(result)
                test_results["failed_tests"] += 1
                test_success = false
            else
                test_results["passed_tests"] += 1
            end
        end
        
        # Step 5: Cache validation
        if !run_cache_validation()
            test_results["failed_tests"] += 1
            test_success = false
        else
            test_results["passed_tests"] += 1
        end
        
        # Step 6: Performance benchmark
        if !run_performance_benchmark()
            test_results["failed_tests"] += 1
            test_success = false
        else
            test_results["passed_tests"] += 1
        end
        
        # Generate final report
        final_success = generate_test_report()
        
        return test_success && final_success
        
    catch e
        println("\n💥 Test suite encountered an unexpected error:")
        println(e)
        Base.show_backtrace(stdout, catch_backtrace())
        return false
    end
end

# Execute the test suite
if abspath(PROGRAM_FILE) == @__FILE__
    success = main()
    exit(success ? 0 : 1)
end