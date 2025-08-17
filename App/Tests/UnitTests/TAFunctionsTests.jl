include("../../Main.jl")
include("../../Data&TA/TAFunctions.jl")
include("../BenchmarkTimes.jl")
using Test
using Dates
using DataFrames
using BenchmarkTools
using ..MarketTechnicalsIndicators
using ..VectoriseBacktestService
using ..VectoriseBacktestService.GlobalServerCache
initialize_server_cache()

function compare_with_tolerance(actual, expected, tolerance=0.5)
    if length(actual) != length(expected)
        return false
    end

    for (a, e) in zip(actual, expected)
        if abs(a - e) > tolerance
            return false
        end
    end

    return true
end
# Test the write_to_parquet function
@testset "TAFunctions tests" begin
    @testset "Successful write" begin
        values = [1.0, 2.0, 3.0]
        indicator_name = "UNIT_TEST_INDICATOR"
        ticker = "UNIT_TEST_TICKER"
        length_data = 3
        period = 14
        end_date = Date("2023-10-01")
        dates = ["2023-09-29", "2023-09-30", "2023-10-01"]

        result = write_to_parquet(
            values,
            indicator_name,
            ticker,
            length_data,
            period,
            end_date,
            dates,
            "./data/IndicatorData/$(indicator_name)_$(ticker)_$(length_data)_$(period)_$(end_date).parquet",
        )
        @test result == true
    end

    # Test the read_parquet_with_duckdb function
    @testset "read_parquet_with_duckdb tests" begin
        @testset "Successful read" begin
            indicator_name = "UNIT_TEST_INDICATOR"
            ticker = "UNIT_TEST_TICKER"
            length_data = 3
            period = 14
            end_date = Date("2023-10-01")

            result = read_parquet_with_duckdb(
                indicator_name,
                ticker,
                length_data,
                period,
                end_date,
                "./data/IndicatorData/$(indicator_name)_$(ticker)_$(length_data)_$(period)_$(end_date).parquet",
            )
            @test !isnothing(result)
            @test result.date ==
                [Date("2023-09-29"), Date("2023-09-30"), Date("2023-10-01")]
            @test result.value == Union{Missing,Float64}[1.0, 2.0, 3.0]
        end

        @testset "Read with no data" begin
            indicator_name = "NO_INDICATOR"
            ticker = "NO_TICKER"
            length_data = 3
            period = 14
            end_date = Date("2023-10-01")

            result = read_parquet_with_duckdb(
                indicator_name,
                ticker,
                length_data,
                period,
                end_date,
                "./data/IndicatorData/$(indicator_name)_$(ticker)_$(length_data)_$(period)_$(end_date).parquet",
            )
            @test isnothing(result)
        end
    end

    # Test for get_ema_of_data function
    @testset "get_ema_of_data Tests" begin
        # Test case 1: Basic functionality
        @testset "Basic Functionality" begin
            return_curve = Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
            window = 3
            result = get_ema_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test !isnan(result[3])

            timing_data = @benchmark get_ema_of_data($return_curve, $window)
            min_time = minimum(timing_data).time * 1e-9
            range = get_range(MIN_GET_EMA_OF_DATA)
            @test MIN_GET_EMA_OF_DATA - range <= min_time <= MIN_GET_EMA_OF_DATA + range
            println("Minimum time taken for get_ema_of_data: ", min_time, " seconds")
        end

        # Test case 2: Window size larger than return curve
        @testset "Window Size Larger Than Return Curve" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 5
            @test_throws ErrorException get_ema_of_data(return_curve, window)
        end

        # Test case 3: Window size equal to return curve length
        @testset "Window Size Equal To Return Curve Length" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 3
            @test_throws ErrorException get_ema_of_data(return_curve, window)
        end

        # Test case 4: All elements in return curve are the same
        @testset "All Elements Same" begin
            return_curve = Float64[5.0, 5.0, 5.0, 5.0, 5.0]
            window = 3
            result = get_ema_of_data(return_curve, window)
            @test all(isnan, result[1:(window - 1)])
            @test all(x -> x == 5.0, result[window:end])
        end

        # Test case 5: Negative values in return curve
        @testset "Negative Values" begin
            return_curve = Float64[-1.0, -2.0, -3.0, -4.0, -5.0]
            window = 3
            result = get_ema_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test !isnan(result[3])
        end
    end

    # Test for get_sma_of_data function
    @testset "get_sma_of_data Tests" begin
        # Test case 1: Basic functionality
        @testset "Basic Functionality" begin
            return_curve = Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
            window = 3
            result = get_sma_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test !isnan(result[3])

            timing_data = @benchmark get_sma_of_data($return_curve, $window)
            min_time = minimum(timing_data).time * 1e-9
            range = get_range(MIN_GET_SMA_OF_DATA)
            @test MIN_GET_SMA_OF_DATA - range <= min_time <= MIN_GET_SMA_OF_DATA + range
            println("Minimum time taken for get_sma_of_data: ", min_time, " seconds")
        end

        # Test case 2: Window size larger than return curve
        @testset "Window Size Larger Than Return Curve" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 5
            @test_throws ErrorException get_sma_of_data(return_curve, window)
        end

        # Test case 3: Window size equal to return curve length
        @testset "Window Size Equal To Return Curve Length" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 3
            @test_throws ErrorException get_sma_of_data(return_curve, window)
        end

        # Test case 4: All elements in return curve are the same
        @testset "All Elements Same" begin
            return_curve = Float64[5.0, 5.0, 5.0, 5.0, 5.0]
            window = 3
            result = get_sma_of_data(return_curve, window)
            @test all(isnan, result[1:(window - 1)])
            @test all(x -> x == 5.0, result[window:end])
        end

        # Test case 5: Negative values in return curve
        @testset "Negative Values" begin
            return_curve = Float64[-1.0, -2.0, -3.0, -4.0, -5.0]
            window = 3
            result = get_sma_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test !isnan(result[3])
        end
    end

    # Test for get_rsi_of_data function
    @testset "get_rsi_of_data Tests" begin
        # Test case 1: Basic functionality
        @testset "Basic Functionality" begin
            return_curve = Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
            window = 3
            result = get_rsi_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test isnan(result[3])
            @test !isnan(result[4])

            timing_data = @benchmark get_rsi_of_data($return_curve, $window)
            min_time = minimum(timing_data).time * 1e-9
            range = get_range(MIN_GET_RSI_OF_DATA)
            @test MIN_GET_RSI_OF_DATA - range <= min_time <= MIN_GET_RSI_OF_DATA + range
            println("Minimum time taken for get_rsi_of_data: ", min_time, " seconds")
        end

        # Test case 2: Window size larger than return curve
        @testset "Window Size Larger Than Return Curve" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 5
            @test_throws ErrorException get_rsi_of_data(return_curve, window)
        end

        # Test case 3: Window size equal to return curve length
        @testset "Window Size Equal To Return Curve Length" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 3
            @test_throws ErrorException get_rsi_of_data(return_curve, window)
        end

        # Test case 4: All elements in return curve are the same
        @testset "All Elements Same" begin
            return_curve = Float64[5.0, 5.0, 5.0, 5.0, 5.0]
            window = 3
            result = get_rsi_of_data(return_curve, window)
            @test all(isnan, result)
        end

        # Test case 5: Negative values in return curve
        @testset "Negative Values" begin
            return_curve = Float64[-1.0, -2.0, -3.0, -4.0, -5.0]
            window = 3
            result = get_rsi_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test isnan(result[3])
            @test !isnan(result[4])
        end
    end

    # Test for get_sd_of_data function
    @testset "get_sd_of_data Tests" begin
        # Test case 1: Basic functionality
        @testset "Basic Functionality" begin
            return_curve = Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
            window = 3
            result = get_sd_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test !isnan(result[3])

            timing_data = @benchmark get_sd_of_data($return_curve, $window)
            min_time = minimum(timing_data).time * 1e-9
            range = get_range(MIN_GET_SD_OF_DATA)
            @test MIN_GET_SD_OF_DATA - range <= min_time <= MIN_GET_SD_OF_DATA + range
            println("Minimum time taken for get_sd_of_data: ", min_time, " seconds")
        end

        # Test case 2: Window size larger than return curve
        @testset "Window Size Larger Than Return Curve" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 5
            @test_throws ErrorException get_sd_of_data(return_curve, window)
        end

        # Test case 3: Window size equal to return curve length
        @testset "Window Size Equal To Return Curve Length" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 3
            @test_throws ErrorException get_sd_of_data(return_curve, window)
        end

        # Test case 4: All elements in return curve are the same
        @testset "All Elements Same" begin
            return_curve = Float64[5.0, 5.0, 5.0, 5.0, 5.0]
            window = 3
            result = get_sd_of_data(return_curve, window)
            @test all(isnan, result[1:(window - 1)])
            @test all(x -> x == 0.0, result[window:end])
        end

        # Test case 5: Negative values in return curve
        @testset "Negative Values" begin
            return_curve = Float64[-1.0, -2.0, -3.0, -4.0, -5.0]
            window = 3
            result = get_sd_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test !isnan(result[3])
        end
    end

    # Test for get_cumulative_return_of_data function
    @testset "get_cumulative_return_of_data Tests" begin
        # Test case 1: Basic functionality
        @testset "Basic Functionality" begin
            return_curve = Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
            window = 3
            result = get_cumulative_return_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test isnan(result[3])
            @test !isnan(result[4])

            timing_data = @benchmark get_cumulative_return_of_data($return_curve, $window)
            min_time = minimum(timing_data).time * 1e-9
            range = get_range(MIN_GET_CUMULATIVE_RETURN_OF_DATA)
            @test MIN_GET_CUMULATIVE_RETURN_OF_DATA - range <=
                min_time <=
                MIN_GET_CUMULATIVE_RETURN_OF_DATA + range
            println(
                "Minimum time taken for get_cumulative_return_of_data: ",
                min_time,
                " seconds",
            )
        end

        # Test case 2: Window size larger than return curve
        @testset "Window Size Larger Than Return Curve" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 5
            @test_throws ErrorException get_cumulative_return_of_data(return_curve, window)
        end

        # Test case 3: Window size equal to return curve length
        @testset "Window Size Equal To Return Curve Length" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 3
            result = get_cumulative_return_of_data(return_curve, window)
            @test all(isnan, result)
        end

        # Test case 4: All elements in return curve are the same
        @testset "All Elements Same" begin
            return_curve = Float64[5.0, 5.0, 5.0, 5.0, 5.0]
            window = 3
            result = get_cumulative_return_of_data(return_curve, window)
            @test all(isnan, result[1:(window - 1)])
            @test all(x -> x == 0.0, result[(window + 1):end])
        end

        # Test case 5: Negative values in return curve
        @testset "Negative Values" begin
            return_curve = Float64[-1.0, -2.0, -3.0, -4.0, -5.0]
            window = 3
            result = get_cumulative_return_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test isnan(result[3])
            @test !isnan(result[4])
        end
    end

    # Test for get_max_drawdown_of_data function
    @testset "get_max_drawdown_of_data Tests" begin
        # Test case 1: Basic functionality
        @testset "Basic Functionality" begin
            return_curve = Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
            window = 3
            result = get_max_drawdown_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test !isnan(result[3])

            timing_data = @benchmark get_max_drawdown_of_data($return_curve, $window)
            min_time = minimum(timing_data).time * 1e-9
            range = get_range(MIN_GET_MAX_DRAWDOWN_OF_DATA)
            @test MIN_GET_MAX_DRAWDOWN_OF_DATA - range <=
                min_time <=
                MIN_GET_MAX_DRAWDOWN_OF_DATA + range
            println(
                "Minimum time taken for get_max_drawdown_of_data: ", min_time, " seconds"
            )
        end

        # Test case 2: Window size larger than return curve
        @testset "Window Size Larger Than Return Curve" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 5
            @test_throws ErrorException get_max_drawdown_of_data(return_curve, window)
        end

        # Test case 3: Window size equal to return curve length
        @testset "Window Size Equal To Return Curve Length" begin
            return_curve = Float64[1.0, 2.0, 3.0]
            window = 3
            @test_throws ErrorException get_max_drawdown_of_data(return_curve, window)
        end

        # Test case 4: All elements in return curve are the same
        @testset "All Elements Same" begin
            return_curve = Float64[5.0, 5.0, 5.0, 5.0, 5.0]
            window = 3
            result = get_max_drawdown_of_data(return_curve, window)
            @test all(isnan, result[1:(window - 1)])
            @test all(x -> x == 0.0, result[window:end])
        end

        # Test case 5: Negative values in return curve
        @testset "Negative Values" begin
            return_curve = Float64[-1.0, -2.0, -3.0, -4.0, -5.0]
            window = 3
            result = get_max_drawdown_of_data(return_curve, window)
            @test length(result) == length(return_curve)
            @test isnan(result[1])
            @test isnan(result[2])
            @test !isnan(result[3])
        end
    end

    # Test for calculate_max_drawdown function
    @testset "calculate_max_drawdown Tests" begin
        # Test case 1: Basic functionality
        @testset "Basic Functionality" begin
            return_curve = Float64[
                100.0, 105.0, 102.0, 110.0, 108.0, 107.0, 115.0, 113.0, 120.0, 118.0
            ]
            result = calculate_max_drawdown(return_curve)
            @test isapprox(result, 2.857142873108387, atol=0.1)

            timing_data = @benchmark calculate_max_drawdown($return_curve)
            min_time = minimum(timing_data).time * 1e-9
            range = get_range(MIN_CALCULATE_MAX_DRAWDOWN)
            @test MIN_CALCULATE_MAX_DRAWDOWN - range <=
                min_time <=
                MIN_CALCULATE_MAX_DRAWDOWN + range
            println("Minimum time taken for calculate_max_drawdown: ", min_time, " seconds")
        end

        # Test case 2: No drawdown (monotonically increasing)
        @testset "No Drawdown" begin
            return_curve = Float64[100.0, 101.0, 102.0, 103.0, 104.0, 105.0]
            result = calculate_max_drawdown(return_curve)
            @test result == 0.0f0
        end

        # Test case 3: Monotonically decreasing
        @testset "Monotonically Decreasing" begin
            return_curve = Float64[105.0, 104.0, 103.0, 102.0, 101.0, 100.0]
            result = calculate_max_drawdown(return_curve)
            @test isapprox(result, 4.76190485060215, atol=0.1)
        end

        # Test case 4: Single element
        @testset "Single Element" begin
            return_curve = Float64[100.0]
            result = calculate_max_drawdown(return_curve)
            @test result == 0.0f0
        end

        # Test case 5: All elements the same
        @testset "All Elements Same" begin
            return_curve = Float64[100.0, 100.0, 100.0, 100.0, 100.0]
            result = calculate_max_drawdown(return_curve)
            @test result == 0.0f0
        end

        # Test case 6: Random values with known drawdown
        @testset "Known Drawdown" begin
            return_curve = Float64[
                100.0, 90.0, 95.0, 85.0, 80.0, 70.0, 75.0, 65.0, 60.0, 55.0
            ]
            result = calculate_max_drawdown(return_curve)
            @test isapprox(result, 44.999998807907104, atol=0.1)
        end
    end

    @testset "calculate_daily_returns_data_f32 tests" begin
        # Test case 1: Valid input
        input_data_1 = Float64[1.0, 2.0, 3.0, 4.0, 5.0]
        expected_result_1 = Float64[NaN, 1.0, 0.5, 0.3333333333333333, 0.25]
        result_1 = calculate_daily_returns_data_f32(input_data_1)

        @test length(result_1) == length(expected_result_1)
        @test all(isapprox.(result_1, expected_result_1, atol=1e-7, nans=true))

        # Test case 2: Different valid input
        input_data_2 = Float64[10.0, 20.0, 30.0, 40.0, 50.0]
        expected_result_2 = Float64[NaN, 1.0, 0.5, 0.3333333333333333, 0.25]
        result_2 = calculate_daily_returns_data_f32(input_data_2)

        @test length(result_2) == length(expected_result_2)
        @test all(isapprox.(result_2, expected_result_2, atol=1e-7, nans=true))

        timing_data = @benchmark calculate_daily_returns_data_f32($input_data_1)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_CALCULATE_DAILY_RETURNS_DATA_F32)
        @test MIN_CALCULATE_DAILY_RETURNS_DATA_F32 - range <=
            min_time <=
            MIN_CALCULATE_DAILY_RETURNS_DATA_F32 + range
        println(
            "Minimum time taken for calculate_daily_returns_data_f32: ",
            min_time,
            " seconds",
        )

        # Error handling tests
        @testset "error handling" begin
            # Input containing zero
            input_data_with_zero = Float64[1.0, 0.0, 3.0, 4.0, 5.0]
            @test_throws ErrorException calculate_daily_returns_data_f32(
                input_data_with_zero
            )
        end
    end

    @testset "calculate_inverse_volatility_data_f32 tests" begin
        # Test case 1: Valid input
        input_data_1 = Float64[1.0, 2.0, 3.0, 4.0, 5.0]
        lookback_period_1 = 3
        expected_result_1 = Float64[
            NaN, NaN, NaN, NaN, NaN, 2.8823067684915684, 7.855844048495725
        ]
        result_1 = calculate_inverse_volatility_data_f32(input_data_1, lookback_period_1)

        @test length(result_1) == length(expected_result_1)
        @test all(isapprox.(result_1, expected_result_1, atol=1e-7, nans=true))

        # Test case 2: Different valid input
        input_data_2 = Float64[10.0, 20.0, 30.0, 40.0, 50.0]
        lookback_period_2 = 3
        expected_result_2 = Float64[
            NaN, NaN, NaN, NaN, NaN, 2.8823067684915684, 7.855844048495725
        ]
        result_2 = calculate_inverse_volatility_data_f32(input_data_2, lookback_period_2)

        @test length(result_2) == length(expected_result_2)
        @test all(isapprox.(result_2, expected_result_2, atol=1e-7, nans=true))

        timing_data = @benchmark calculate_inverse_volatility_data_f32(
            $input_data_1, $lookback_period_1
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_CALCULATE_INVERSE_VOLATILITY_DATA_F32)
        @test MIN_CALCULATE_INVERSE_VOLATILITY_DATA_F32 - range <=
            min_time <=
            MIN_CALCULATE_INVERSE_VOLATILITY_DATA_F32 + range
        println(
            "Minimum time taken for calculate_inverse_volatility_data_f32: ",
            min_time,
            " seconds",
        )

        # Error handling tests
        @testset "error handling" begin
            # Input containing zero
            input_data_with_zero = Float64[1.0, 0.0, 3.0, 4.0, 5.0]
            @test_throws ErrorException calculate_inverse_volatility_data_f32(
                input_data_with_zero, 3
            )

            # Invalid lookback period
            input_data_invalid_lookback = Float64[1.0, 2.0, 3.0, 4.0, 5.0]
            @test_throws ErrorException calculate_inverse_volatility_data_f32(
                input_data_invalid_lookback, -3
            )

            # Invalid input (resulting in Inf values)
            input_data_with_zero = Float64[1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0]
            @test_throws ErrorException calculate_inverse_volatility_data_f32(
                input_data_with_zero, 3
            )
        end
    end

    # Test for calculate_inverse_volatility_for_data_f32 function
    @testset "calculate_inverse_volatility_for_data_f32 Tests" begin
        # Test case 1: Basic functionality
        @testset "Basic Functionality" begin
            data_vectors = [
                Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0],
                Float64[2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0],
            ]
            dates = [Date("2023-01-01") + Day(i) for i in 0:9]
            lookback_period = 3
            result = calculate_inverse_volatility_for_data_f32(
                data_vectors, dates, lookback_period
            )
            @test length(result) == length(dates) - lookback_period
            fail = false
            for i in (lookback_period + 1):length(dates)
                if !haskey(result, dates[i])
                    fail = true
                end
            end
            @test fail == false

            timing_data = @benchmark calculate_inverse_volatility_for_data_f32(
                $data_vectors, $dates, $lookback_period
            )
            min_time = minimum(timing_data).time * 1e-9
            range = get_range(MIN_CALCULATE_INVERSE_VOLATILITY_FOR_DATA_F32)
            @test MIN_CALCULATE_INVERSE_VOLATILITY_FOR_DATA_F32 - range <=
                min_time <=
                MIN_CALCULATE_INVERSE_VOLATILITY_FOR_DATA_F32 + range
            println(
                "Minimum time taken for calculate_inverse_volatility_for_data_f32: ",
                min_time,
                " seconds",
            )
        end

        # Test case 2: Lookback period larger than data length
        @testset "Lookback Period Larger Than Data Length" begin
            data_vectors = [Float64[1.0, 2.0, 3.0], Float64[2.0, 3.0, 4.0]]
            dates = [Date("2023-01-01") + Day(i) for i in 0:2]
            lookback_period = 5
            @test_throws ErrorException calculate_inverse_volatility_for_data_f32(
                data_vectors, dates, lookback_period
            )
        end

        # Test case 3: Single data vector
        @testset "Single Data Vector" begin
            data_vector = [Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]]
            dates = [Date("2023-01-01") + Day(i) for i in 0:9]
            lookback_period = 3
            result = calculate_inverse_volatility_for_data_f32(
                data_vector, dates, lookback_period
            )
            @test length(result) == length(dates) - lookback_period
            fail = false
            for i in (lookback_period + 1):length(dates)
                if !haskey(result, dates[i])
                    fail = true
                end
            end
            @test fail == false
        end

        # Test case 5: Negative values in data vector
        @testset "Negative Values" begin
            data_vectors = [
                Float64[-1.0, -2.0, -3.0, -4.0, -5.0], Float64[-2.0, -3.0, -4.0, -5.0, -6.0]
            ]
            dates = [Date("2023-01-01") + Day(i) for i in 0:4]
            lookback_period = 3
            result = calculate_inverse_volatility_for_data_f32(
                data_vectors, dates, lookback_period
            )
            @test length(result) == length(dates) - lookback_period
            fail = false
            for i in (lookback_period + 1):length(dates)
                if !haskey(result, dates[i])
                    fail = true
                end
            end
            @test fail == false
        end
    end

    @testset "get_max_drawdown tests" begin
        # Test case 1: Valid input
        expected_result_1 = Union{Missing,Float64}[
            2.0903682263923082,
            2.0903682263923082,
            2.0903682263923082,
            2.0903682263923082,
            1.5889665889617777,
            1.5889665889617777,
            1.5889665889617777,
            1.5889665889617777,
            2.1727997659550997,
            2.9263296510656978,
        ]
        result_1 = get_max_drawdown("AAPL", 10, 11, Date("2021-01-01"))
        @test length(result_1) == length(expected_result_1)
        @test all(isapprox.(result_1, expected_result_1))

        # Error handling tests
        @testset "error handling" begin
            # No data available
            @test_throws ErrorException get_max_drawdown(
                "INVALID_TICKER", 10, 10, Date("2021-01-01")
            )
        end
    end

    @testset "get_trading_days tests" begin
        # Test case 1
        expected_result_1 = 2
        result_1 = get_trading_days("AAPL", Date("2023-01-01"), Date("2023-01-05"))
        @test result_1 == expected_result_1

        # Test case 2: Different date range
        function get_stock_data_dataframe_start_end(ticker, start_date, end_date)
            if ticker == "AAPL" &&
                start_date == Date("2023-01-01") &&
                end_date == Date("2023-01-10")
                dates = [
                    Date("2023-01-03"),
                    Date("2023-01-04"),
                    Date("2023-01-05"),
                    Date("2023-01-06"),
                    Date("2023-01-09"),
                    Date("2023-01-10"),
                ]
                adjusted_close = [150.0, 152.0, 148.0, 149.0, 151.0, 150.0]
                return DataFrame(; date=dates, adjusted_close=adjusted_close)
            else
                error("Unsupported ticker or date range for mock data")
            end
        end

        expected_result_2 = 5
        result_2 = get_trading_days("AAPL", Date("2023-01-01"), Date("2023-01-10"))
        @test result_2 == expected_result_2

        # Error handling tests
        @testset "error handling" begin
            # Invalid ticker
            @test_throws ErrorException get_trading_days(
                "INVALID_TICKER", Date("2023-01-01"), Date("2023-01-05")
            )
        end
    end

    @testset "get_rsi tests" begin
        expected_result = Float64[76.635, 90.653, 67.299, 54.092, 42.806]
        expected_result = round.(expected_result, digits=3)
        result = get_rsi("AAPL", 5, 3, Date("2023-01-05"))
        result = round.(result, digits=3)
        for i in eachindex(expected_result)
            @test isapprox(expected_result[i], result[i], atol=0.1)
        end

        @testset "error handling" begin
            # Invalid ticker
            @test_throws ErrorException get_rsi("INVALID_TICKER", 5, 3, Date("2023-01-05"))
        end
    end

    @testset "get_sma tests" begin
        # Test case 1
        expected_result_1 = [128.835, 130.404, 131.68, 132.251, 130.946]
        result_1 = get_sma("AAPL", 5, 3, Date("2023-01-05"))
        result_1 = round.(result_1, digits=3)
        @test compare_with_tolerance(result_1, expected_result_1)

        # Error handling tests
        @testset "error handling" begin
            # Invalid ticker
            @test_throws ErrorException get_sma("INVALID_TICKER", 5, 3, Date("2023-01-05"))
        end
    end

    @testset "get_sma_returns tests" begin
        # Test case 1
        expected_result_1 = Float64[0.973, 1.217, 1.005, 0.464, -0.985]
        result_1 = get_sma_returns("AAPL", 5, 3, Date("2023-01-05"))
        result_1 = round.(result_1, digits=3)
        expected_result_1 = round.(expected_result_1, digits=3)
        for i in eachindex(result_1)
            @test isapprox(expected_result_1[i], result_1[i], atol=0.1)
        end

        # Test case 2: Different period
        expected_result_2 = Float64[0.037, 2.174, 1.123, -1.092, -0.811]
        result_2 = get_sma_returns("AAPL", 5, 2, Date("2023-01-05"))
        result_2 = round.(result_2, digits=3)
        expected_result_2 = round.(expected_result_2, digits=3)
        for i in eachindex(result_2)
            @test isapprox(expected_result_2[i], result_2[i], atol=0.1)
        end

        # Error handling tests
        @testset "error handling" begin
            # Invalid ticker
            @test_throws MethodError get_sma_returns(
                "INVALID_TICKER", 5, 3, Date("2023-01-05")
            )
        end
    end

    @testset "get_ema tests" begin
        # Test case 1
        expected_result_1 = [128.409, 131.112, 131.572, 131.24, 130.569]
        result_1 = get_ema("AAPL", 5, 3, Date("2023-01-05"))
        result_1 = round.(result_1, digits=3)
        expected_result_1 = round.(expected_result_1, digits=3)
        @test compare_with_tolerance(result_1, expected_result_1)

        # Test case 2: Different period
        expected_result_2 = Union{Missing,Float64}[
            128.81902, 132.14928, 132.07156, 131.29512, 130.36407
        ]
        result_2 = get_ema("AAPL", 5, 2, Date("2023-01-05"))
        # result_2 = round.(result_2, digits=3);
        # expected_result_2 = round.(expected_result_2, digits=3)
        @test compare_with_tolerance(result_2, expected_result_2)

        # Error handling tests
        @testset "error handling" begin
            # Invalid ticker
            @test_throws ErrorException get_ema("INVALID_TICKER", 5, 3, Date("2023-01-05"))
        end
    end

    @testset "get_sd_returns tests" begin
        # Test case 1
        expected_result_1 = Float64[1.781, 2.172, 2.462, 2.706, 0.303]
        result_1 = get_sd_returns("AAPL", 5, 3, Date("2023-01-05"))
        result_1 = round.(result_1, digits=3)
        expected_result_1 = round.(expected_result_1, digits=3)
        for i in eachindex(expected_result_1)
            @test isapprox(result_1[i], expected_result_1[i], atol=0.1)
        end

        # Test case 2: Different period
        expected_result_2 = Float64[1.039, 1.984, 3.471, 0.339, 0.058]
        result_2 = get_sd_returns("AAPL", 5, 2, Date("2023-01-05"))
        result_2 = round.(result_2, digits=3)
        expected_result_2 = round.(expected_result_2, digits=3)
        for i in eachindex(expected_result_2)
            @test isapprox(result_2[i], expected_result_2[i], atol=0.1)
        end

        # Error handling tests
        @testset "error handling" begin
            # Invalid ticker
            @test_throws ErrorException get_sd_returns(
                "INVALID_TICKER", 5, 3, Date("2023-01-05")
            )
        end
    end

    @testset "get_sd tests" begin
        # Test case 1
        expected_result_1 = Float64[0.5, 3.0, 2.3, 1.5, 1.1]
        result_1 = get_sd("AAPL", 5, 3, Date("2023-01-05"))
        result_1 = round.(result_1, digits=1)
        expected_result_1 = round.(expected_result_1, digits=1)
        @test compare_with_tolerance(result_1, expected_result_1)

        # Test case 2: Different period
        expected_result_2 = [0.7, 3.27, 1.26, 0.8, 0.71]
        result_2 = get_sd("AAPL", 5, 2, Date("2023-01-05"))
        result_2 = round.(result_2, digits=2)
        println(result_2)
        expected_result_2 = round.(expected_result_2, digits=2)
        @test compare_with_tolerance(result_2, expected_result_2)

        # Error handling tests
        @testset "error handling" begin
            # Invalid ticker
            @test_throws ErrorException get_sd("INVALID_TICKER", 5, 3, Date("2023-01-05"))
        end
    end
end

@testset "get_cumulative_return tests" begin
    # Test case 1
    expected_result_1 = Float32[
        2.916634f0, 3.6472552f0, 2.9856446f0, 1.326059f0, -2.9263296f0
    ]
    result_1 = get_cumulative_return("AAPL", 5, 3, Date("2023-01-05"))
    for i in eachindex(result_1)
        @test isapprox(result_1[i], expected_result_1[i], atol=0.1)
    end

    # Test case 2: Different period
    expected_result_2 = Float32[
        0.06824386f0, 4.375382f0, 2.1974692f0, -2.1727998f0, -1.6163713f0
    ]
    result_2 = get_cumulative_return("AAPL", 5, 2, Date("2023-01-05"))
    for i in eachindex(result_2)
        @test isapprox(result_2[i], expected_result_2[i], atol=0.1)
    end

    # Error handling tests
    @testset "error handling" begin
        # Invalid ticker
        @test_throws ErrorException get_cumulative_return(
            "INVALID_TICKER", 5, 3, Date("2023-01-05")
        )
    end

    # Test for calculate_market_cap_weighting_f32
    @testset "calculate_market_cap_weighting_f32 Tests" begin
        # Test case 1: Basic functionality
        @testset "Basic Functionality" begin
            tree_market_caps::Dict{Any,Vector{Float32}} = Dict(
                "Branch1" => [100.0f0, 200.0f0, 300.0f0],
                "Branch2" => [50.0f0, 150.0f0, 250.0f0],
            )
            expected_weights::Dict{Any,Vector{Float32}} = Dict(
                "Branch1" => [0.6666667f0, 0.5714286f0, 0.54545456f0],
                "Branch2" => [0.33333334f0, 0.42857143f0, 0.45454547f0],
            )
            expected_min_length = 3

            weights, min_length = calculate_market_cap_weighting_f32(tree_market_caps)

            @test weights == expected_weights
            @test min_length == expected_min_length

            timing_data = @benchmark calculate_market_cap_weighting_f32($tree_market_caps)
            min_time = minimum(timing_data).time * 1e-9
            range = get_range(MIN_CALCULATE_MARKET_CAP_WEIGHTING_F32)
            @test MIN_CALCULATE_MARKET_CAP_WEIGHTING_F32 - range <=
                min_time <=
                MIN_CALCULATE_MARKET_CAP_WEIGHTING_F32 + range
            println(
                "Minimum time taken for calculate_market_cap_weighting_f32: ",
                min_time,
                " seconds",
            )
        end

        # Test case 2: Different lengths of market caps
        @testset "Different Lengths" begin
            tree_market_caps::Dict{Any,Vector{Float32}} = Dict(
                "Branch1" => [100.0f0, 200.0f0, 300.0f0, 400.0f0],
                "Branch2" => [50.0f0, 150.0f0, 250.0f0],
            )
            expected_weights::Dict{Any,Vector{Float32}} = Dict{Any,Vector{Float32}}(
                "Branch1" => [0.8, 0.6666667, 0.61538464],
                "Branch2" => [0.2, 0.33333334, 0.3846154],
            )
            expected_min_length = 3

            weights, min_length = calculate_market_cap_weighting_f32(tree_market_caps)

            @test weights == expected_weights
            @test min_length == expected_min_length
        end

        # Test case 3: Single branch
        @testset "Single Branch" begin
            tree_market_caps::Dict{Any,Vector{Float32}} = Dict(
                "Branch1" => [100.0f0, 200.0f0, 300.0f0]
            )
            expected_weights::Dict{Any,Vector{Float32}} = Dict(
                "Branch1" => [1.0f0, 1.0f0, 1.0f0]
            )
            expected_min_length = 3

            weights, min_length = calculate_market_cap_weighting_f32(tree_market_caps)

            @test weights == expected_weights
            @test min_length == expected_min_length
        end

        # Test case 4: Empty input
        @testset "Empty Input" begin
            tree_market_caps::Dict{Any,Vector{Float32}} = Dict{Any,Vector{Float32}}()
            @test_throws ErrorException calculate_market_cap_weighting_f32(tree_market_caps)
        end
    end
end
