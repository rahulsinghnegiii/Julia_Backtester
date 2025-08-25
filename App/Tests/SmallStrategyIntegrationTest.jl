"""
SmallStrategy Integration Test
=============================

This file provides integration testing for SmallStrategy.json to ensure it works
correctly with the existing test framework and can be executed as part of the
main test suite.

This serves as a lightweight integration test that can be included in automated
test runs without requiring the full comprehensive test suite.
"""

include("../Main.jl")
include("UnitTests/SmallStrategyTest.jl")

using Test
using JSON
using Dates
using ..VectoriseBacktestService

@testset "SmallStrategy Integration" begin
    
    @testset "Quick Smoke Test" begin
        println("Running SmallStrategy smoke test...")
        
        # Load strategy
        strategy_json_path = "./App/Tests/E2E/JSONs/SmallStrategy.json"
        @test isfile(strategy_json_path) "SmallStrategy.json must exist"
        
        strategy_request = JSON.parse(read(strategy_json_path, String))
        strategy_data = JSON.parse(strategy_request["json"])
        
        # Quick execution test
        result = handle_backtesting_api(
            strategy_data,
            100,  # Shorter period for smoke test
            strategy_request["hash"] * "_smoke",
            Date("2024-01-31"),
            false
        )
        
        @test result !== nothing "SmallStrategy should execute successfully"
        @test haskey(result, "returns") "Result should contain returns"
        @test length(result["returns"]) > 0 "Should generate return data"
        
        println("✓ SmallStrategy smoke test passed")
    end
    
    @testset "Framework Compatibility" begin
        println("Testing framework compatibility...")
        
        # Test that all required modules are available
        @test isdefined(VectoriseBacktestService, :handle_backtesting_api) "Main API function should be available"
        @test isdefined(Main, :VectoriseBacktestService) "Main module should be loaded"
        
        # Test that expected files exist
        required_files = [
            "./App/Tests/E2E/JSONs/SmallStrategy.json",
            "./App/Tests/E2E/ExpectedFiles/SmallStrategy.json",
            "./App/Tests/UnitTests/SmallStrategyTest.jl"
        ]
        
        for file in required_files
            @test isfile(file) "Required file should exist: $file"
        end
        
        println("✓ Framework compatibility verified")
    end
end

println("SmallStrategy integration test completed successfully!")