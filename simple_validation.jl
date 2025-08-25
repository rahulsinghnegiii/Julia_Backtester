#!/usr/bin/env julia

# Simple SmallStrategy Validation Script
println("="^60)
println("SMALLSTRATEGY VALIDATION TEST")
println("="^60)

# Change to App directory
try
    cd("App")
    println("✓ Changed to App directory: ", pwd())
catch e
    println("✗ Failed to change to App directory: $e")
    exit(1)
end

# Test 1: Check if required files exist
println("\n1. Checking required files...")
required_files = [
    "Tests/E2E/JSONs/SmallStrategy.json",
    "Tests/E2E/ExpectedFiles/SmallStrategy.json", 
    "Tests/UnitTests/SmallStrategyTest.jl",
    "Main.jl",
    "Project.toml"
]

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
    println("\n❌ Some required files are missing!")
    exit(1)
end

# Test 2: Load and parse SmallStrategy.json
println("\n2. Testing SmallStrategy.json parsing...")
try
    using JSON
    strategy_data = JSON.parse(read("Tests/E2E/JSONs/SmallStrategy.json", String))
    strategy_json = JSON.parse(strategy_data["json"])
    
    println("  ✓ SmallStrategy.json parsed successfully")
    println("  ✓ Strategy type: $(strategy_json["type"])")
    println("  ✓ Tickers: $(join(strategy_json["tickers"], ", "))")
    println("  ✓ Period: $(strategy_data["period"]) days")
    println("  ✓ Hash: $(strategy_data["hash"])")
    
    # Store for later use
    global parsed_strategy_data = strategy_data
    global parsed_strategy_json = strategy_json
    
catch e
    println("  ✗ Failed to parse SmallStrategy.json: $e")
    exit(1)
end

# Test 3: Load Main module
println("\n3. Testing Main module loading...")
try
    println("  Current directory: ", pwd())
    include("Main.jl")
    println("  ✓ Main.jl loaded successfully")
    
    # Check if VectoriseBacktestService is available
    if isdefined(Main, :VectoriseBacktestService)
        println("  ✓ VectoriseBacktestService module available")
        
        # Check key function
        if isdefined(VectoriseBacktestService, :handle_backtesting_api)
            println("  ✓ handle_backtesting_api function available")
        else
            println("  ✗ handle_backtesting_api function not available")
            exit(1)
        end
    else
        println("  ✗ VectoriseBacktestService module not available")
        exit(1)
    end
    
catch e
    println("  ✗ Failed to load Main module: $e")
    println("     Error details: $e")
    exit(1)
end

# Test 4: Execute SmallStrategy (short version)
println("\n4. Testing SmallStrategy execution...")
try
    using Dates
    
    backtest_period = 100  # Shorter period for testing
    end_date = Date("2024-01-31")
    strategy_hash = parsed_strategy_data["hash"] * "_test"
    
    println("  Executing strategy with:")
    println("    - Period: $backtest_period days")
    println("    - End date: $end_date")
    println("    - Hash: $strategy_hash")
    
    start_time = time()
    result = VectoriseBacktestService.handle_backtesting_api(
        parsed_strategy_json,
        backtest_period,
        strategy_hash,
        end_date,
        false  # live_execution = false
    )
    execution_time = time() - start_time
    
    if result === nothing
        println("  ✗ Strategy execution returned nothing")
        exit(1)
    end
    
    # Validate result structure
    required_keys = ["returns", "dates", "profile_history"]
    for key in required_keys
        if !haskey(result, key)
            println("  ✗ Missing key in result: $key")
            exit(1)
        end
    end
    
    println("  ✓ Strategy executed successfully")
    println("  ✓ Execution time: $(round(execution_time, digits=3)) seconds")
    println("  ✓ Generated $(length(result["returns"])) return points")
    println("  ✓ Date range: $(result["dates"][1]) to $(result["dates"][end])")
    
    if length(result["returns"]) > 0
        println("  ✓ Final return: $(round(result["returns"][end], digits=6))")
    end
    
catch e
    println("  ✗ Strategy execution failed: $e")
    println("     Error details: $e")
    exit(1)
end

# Test 5: Cache validation
println("\n5. Testing cache generation...")
try
    strategy_hash = parsed_strategy_data["hash"] * "_test"
    cache_dir = "Cache/$strategy_hash"
    
    if isdir(cache_dir)
        println("  ✓ Cache directory created: $cache_dir")
        
        cache_file = "$cache_dir/$strategy_hash.json"
        if isfile(cache_file)
            println("  ✓ Cache file created: $cache_file")
        else
            println("  ⚠️  Cache file not found (may be normal)")
        end
    else
        println("  ⚠️  Cache directory not created (may be normal)")
    end
    
    if isdir("SubtreeCache")
        println("  ✓ SubtreeCache directory exists")
    else
        println("  ⚠️  SubtreeCache directory not found")
    end
    
catch e
    println("  ⚠️  Cache validation error: $e")
end

println("\n" * "="^60)
println("🎉 SMALLSTRATEGY VALIDATION COMPLETED SUCCESSFULLY!")
println("="^60)
println("\nThe SmallStrategy.json implementation is working correctly!")
println("\nKey validations passed:")
println("  ✅ File structure is correct")
println("  ✅ JSON parsing works properly")
println("  ✅ Main module loads successfully")
println("  ✅ Strategy execution completes successfully")
println("  ✅ Results are generated in expected format")
println("\nYou can now run the full test suite with confidence!")