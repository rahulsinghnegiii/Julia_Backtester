#!/usr/bin/env julia

"""
Quick SmallStrategy Validation
=============================

This script performs a quick validation to ensure the SmallStrategy implementation
is working correctly before running the full test suite.
"""

println("SmallStrategy Quick Validation")
println("=" ^ 40)

# Test 1: File existence
println("1. Checking file existence...")
required_files = [
    "App/Tests/E2E/JSONs/SmallStrategy.json",
    "App/Tests/E2E/ExpectedFiles/SmallStrategy.json", 
    "App/Tests/UnitTests/SmallStrategyTest.jl",
    "App/Tests/RunSmallStrategyTests.jl",
    "DemoSmallStrategy.jl"
]

all_files_exist = true
for file in required_files
    if isfile(file)
        println("  ✓ $file")
    else
        println("  ✗ $file - NOT FOUND")
        all_files_exist = false
    end
end

if !all_files_exist
    println("\n❌ Some required files are missing!")
    exit(1)
end

# Test 2: JSON parsing
println("\n2. Testing JSON parsing...")
try
    strategy_data = JSON.parse(read("App/Tests/E2E/JSONs/SmallStrategy.json", String))
    strategy_json = JSON.parse(strategy_data["json"])
    println("  ✓ SmallStrategy.json parsed successfully")
    println("  ✓ Strategy type: $(strategy_json["type"])")
    println("  ✓ Tickers: $(join(strategy_json["tickers"], ", "))")
catch e
    println("  ✗ JSON parsing failed: $e")
    exit(1)
end

# Test 3: Module loading
println("\n3. Testing module loading...")
try
    cd("App")
    include("Main.jl")
    println("  ✓ Main module loaded successfully")
    
    # Test that key functions exist
    @assert isdefined(VectoriseBacktestService, :handle_backtesting_api) "handle_backtesting_api not found"
    println("  ✓ handle_backtesting_api function available")
    
    cd("..")
catch e
    println("  ✗ Module loading failed: $e")
    cd("..")
    exit(1)
end

println("\n✅ Quick validation PASSED!")
println("\nYou can now run:")
println("  - Full tests: julia App/Tests/RunSmallStrategyTests.jl") 
println("  - Demo: julia DemoSmallStrategy.jl")
println("  - Integration test: julia App/Tests/SmallStrategyIntegrationTest.jl")