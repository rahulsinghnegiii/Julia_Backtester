#!/usr/bin/env julia

"""
Simple SmallStrategy Test Runner
==============================
This script runs the SmallStrategy tests without command-line parsing issues.
Run this directly with: julia --project=. run_tests_simple.jl
"""

println("="^80)
println("SMALLSTRATEGY.JSON SIMPLE TEST RUNNER")
println("="^80)
println()

# Ensure we're in the correct directory
println("Current directory: ", pwd())

try
    # Test 1: Check if we can include the integration test
    println("Running SmallStrategy Integration Test...")
    include("Tests/SmallStrategyIntegrationTest.jl")
    println("✅ Integration test completed successfully!")
    
catch e
    println("❌ Integration test failed: ", e)
    
    # Fallback: Try to run a basic validation
    println("\nTrying basic validation...")
    try
        # Check if files exist
        required_files = [
            "Tests/E2E/JSONs/SmallStrategy.json",
            "Tests/UnitTests/SmallStrategyTest.jl",
            "Main.jl"
        ]
        
        println("Checking required files:")
        for file in required_files
            if isfile(file)
                println("  ✓ $file")
            else
                println("  ✗ $file - MISSING")
            end
        end
        
        # Try to parse the SmallStrategy JSON
        using JSON
        strategy_file = "Tests/E2E/JSONs/SmallStrategy.json"
        if isfile(strategy_file)
            strategy_data = JSON.parse(read(strategy_file, String))
            strategy_json = JSON.parse(strategy_data["json"])
            
            println("\nSmallStrategy.json validation:")
            println("  ✓ JSON parsed successfully")
            println("  ✓ Strategy type: $(strategy_json["type"])")
            println("  ✓ Tickers: $(join(strategy_json["tickers"], ", "))")
            println("  ✓ Period: $(strategy_data["period"]) days")
        end
        
        # Try to load Main module
        println("\nTrying to load Main module...")
        include("Main.jl")
        println("  ✓ Main.jl loaded successfully")
        
        if isdefined(Main, :VectoriseBacktestService)
            println("  ✓ VectoriseBacktestService available")
        end
        
        println("\n✅ Basic validation completed successfully!")
        
    catch e2
        println("❌ Basic validation also failed: ", e2)
        println("\nPlease check:")
        println("1. Are all dependencies installed? Run: julia --project=. -e \"using Pkg; Pkg.instantiate()\"")
        println("2. Are data files present?")
        println("3. Is the Julia environment properly configured?")
    end
end

println("\n" * "="^80)
println("Test execution completed. Check output above for results.")
println("="^80)