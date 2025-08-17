include("../../Main.jl")

using HTTP
using JSON
using Test
using DecFP
using Dates
using Logging
using Coverage
using TimeZones
using DataFrames
using Statistics
using ..VectoriseBacktestService
using .VectoriseBacktestService.StockData
using .VectoriseBacktestService.ErrorHandlers
using .VectoriseBacktestService.StockData.StockDataUtils

@testset "Stock Data Tests" begin
    @testset "get_project_root() tests" begin
        # Test 1: Project.toml exists in the current directory
        @testset "Current directory is project root" begin
            current_dir = pwd()
            test_dir = joinpath(current_dir, "test_subdir")
            try
                # Create a temporary directory
                mkdir(test_dir)
                cd(test_dir)

                # Create a temporary Project.toml file
                touch("Project.toml")

                @test get_project_root() == test_dir
            finally
                # Clean up: remove the temporary directory and Project.toml
                rm("Project.toml")
                cd(current_dir)
                rm(test_dir; recursive=true)
            end
        end

        # Test 2: Project.toml exists in a parent directory
        @testset "Project root is a parent directory" begin
            current_dir = pwd()
            test_dir_1 = joinpath(current_dir, "test_subdir_1")
            test_dir_2 = joinpath(test_dir_1, "test_subdir_2")
            try
                # Create a subdirectory
                mkdir(test_dir_1)
                cd(test_dir_1)
                mkdir(test_dir_2)
                cd(test_dir_1)
                new_dir = pwd()

                # Create a temporary Project.toml in the current directory
                touch("Project.toml")

                cd(test_dir_2)

                @test get_project_root() == new_dir
            finally
                # Clean up
                cd(test_dir_1)
                rm("Project.toml")
                cd(current_dir)
                rm(test_dir_1; recursive=true)
            end
        end

        # Test 3: No Project.toml found
        @testset "No Project.toml found" begin
            current_dir = pwd()
            test_dir = mktempdir()
            try
                cd(test_dir)

                @test_throws ErrorException get_project_root()
            finally
                cd(current_dir)
                rm(test_dir; recursive=true)
            end
        end
    end
end

@testset "get_nth_weekday Tests" begin
    @test get_nth_weekday(2023, 1, 1, 1) == Date(2023, 1, 2)  # 1st Monday of January 2023
    @test get_nth_weekday(2023, 1, 1, 2) == Date(2023, 1, 9)  # 2nd Monday of January 2023
    @test get_nth_weekday(2023, 1, 5, 1) == Date(2023, 1, 6)  # 1st Thursday of January 2023
    @test get_nth_weekday(2023, 2, 7, 1) == Date(2023, 2, 5)  # 1st Sunday of February 2023
    @test get_nth_weekday(2023, 2, 7, 2) == Date(2023, 2, 12) # 2nd Sunday of February 2023
end

@testset "get_last_weekday Tests" begin
    @test get_last_weekday(2023, 1, 1) == Date(2023, 1, 30)  # Last Monday of January 2023
    @test get_last_weekday(2023, 1, 4) == Date(2023, 1, 26)  # Last Thursday of January 2023
    @test get_last_weekday(2023, 2, 7) == Date(2023, 2, 26)  # Last Sunday of February 2023
    @test get_last_weekday(2023, 2, 3) == Date(2023, 2, 22)  # Last Friday of February 2023
    @test get_last_weekday(2023, 3, 2) == Date(2023, 3, 28)  # Last Tuesday of March 2023
end

@testset "get_market_cap Tests" begin
    # @testset "Data file exists and has enough data" begin
    #     result = get_market_cap("MSFT", "2023-01-03", 2)
    #     @test nrow(result) == 2
    #     @test result.marketCap == Union{Missing,Float64}[1.78689882e12, 1.78271478e12]
    # end

    @testset "get_nth_weekday Tests" begin
        @test get_nth_weekday(2023, 1, 1, 1) == Date(2023, 1, 2)  # 1st Monday of January 2023
        @test get_nth_weekday(2023, 1, 1, 2) == Date(2023, 1, 9)  # 2nd Monday of January 2023
        @test get_nth_weekday(2023, 1, 5, 1) == Date(2023, 1, 6)  # 1st Thursday of January 2023
        @test get_nth_weekday(2023, 2, 7, 1) == Date(2023, 2, 5)  # 1st Sunday of February 2023
        @test get_nth_weekday(2023, 2, 7, 2) == Date(2023, 2, 12) # 2nd Sunday of February 2023
    end

    @testset "get_last_weekday Tests" begin
        @test get_last_weekday(2023, 1, 1) == Date(2023, 1, 30)  # Last Monday of January 2023
        @test get_last_weekday(2023, 1, 4) == Date(2023, 1, 26)  # Last Thursday of January 2023
        @test get_last_weekday(2023, 2, 7) == Date(2023, 2, 26)  # Last Sunday of February 2023
        @test get_last_weekday(2023, 2, 3) == Date(2023, 2, 22)  # Last Friday of February 2023
        @test get_last_weekday(2023, 3, 2) == Date(2023, 3, 28)  # Last Tuesday of March 2023
    end

    @testset "get_market_cap Tests" begin
        # @testset "Data file exists and has enough data" begin
        #     result = get_market_cap("MSFT", "2023-01-03", 2)
        #     @test nrow(result) == 2
        #     @test result.marketCap == Union{Missing,Float64}[1.78689882e12, 1.78271478e12]
        # end

        @testset "Data file does not exist" begin
            @test_throws ProcessingError get_market_cap("NON_EXISTENT", "2023-01-03", 2)
        end
    end

    @testset "get_historical_stock_data_parquet_start_end_date Tests" begin
        @testset "Data file exists and contains data within the specified date range" begin
            result = get_historical_stock_data_parquet_start_end_date(
                "MSFT", Date("2023-01-01"), Date("2023-01-03")
            )
            @test nrow(result) == 1
            @test result.adjusted_close == Union{Missing,Float64}[235.2559080997]
        end
    end

    @testset "get_historical_stock_data_start_end_date Tests" begin
        @testset "Data file exists and has enough data" begin
            result = get_historical_stock_data_start_end_date(
                "MSFT", Date("2023-01-01"), Date("2023-01-03")
            )
            @test nrow(result) == 1
            @test result.adjusted_close == Union{Missing,Float64}[235.2559080997]
        end
    end

    @testset "parse_parquet_to_dictionary Tests" begin
        @testset "DataFrame contains valid data" begin
            df = DataFrame(;
                date=["2023-01-01", "2023-01-02", "2023-01-03"],
                adjusted_high=[110.0, 210.0, 310.0],
                volume=[1000, 2000, 3000],
                adjusted_open=[100.0, 200.0, 300.0],
                adjusted_low=[90.0, 190.0, 290.0],
                adjusted_close=[105.0, 205.0, 305.0],
            )
            result = parse_parquet_to_dictionary(df)
            expected = [
                Dict(
                    "high" => 110.0,
                    "volume" => 1000,
                    "open" => 100.0,
                    "date" => "2023-01-01",
                    "low" => 90.0,
                    "close" => 105.0,
                ),
                Dict(
                    "high" => 210.0,
                    "volume" => 2000,
                    "open" => 200.0,
                    "date" => "2023-01-02",
                    "low" => 190.0,
                    "close" => 205.0,
                ),
                Dict(
                    "high" => 310.0,
                    "volume" => 3000,
                    "open" => 300.0,
                    "date" => "2023-01-03",
                    "low" => 290.0,
                    "close" => 305.0,
                ),
            ]
            @test result == expected
        end

        @testset "DataFrame is empty" begin
            df = DataFrame(;
                date=String[],
                adjusted_high=Float64[],
                volume=Int[],
                adjusted_open=Float64[],
                adjusted_low=Float64[],
                adjusted_close=Float64[],
            )
            result = parse_parquet_to_dictionary(df)
            expected = []
            @test result == expected
        end
    end

    @testset "calculate_delta_percentages tests" begin
        # Collect execution times in an array
        times = Float64[]

        # Wrap each test call with a function that measures execution time
        push!(
            times,
            (@timed @test calculate_delta_percentages([1.0, 2.0, 3.0, 4.0, 5.0]) ==
                [0.0, 100.0, 50.0, 33.33333333333333, 25.0]).time,
        )
        push!(
            times,
            (@timed @test calculate_delta_percentages([1.0, 1.0, 1.0, 1.0, 1.0]) ==
                [0.0, 0.0, 0.0, 0.0, 0.0]).time,
        )
        push!(
            times,
            (@timed @test calculate_delta_percentages([2.0, 4.0, 8.0, 16.0, 32.0]) ==
                [0.0, 100.0, 100.0, 100.0, 100.0]).time,
        )
        push!(
            times,
            (@timed @test calculate_delta_percentages([10.0, 5.0, 2.5, 1.25, 0.625]) ==
                [0.0, -50.0, -50.0, -50.0, -50.0]).time,
        )

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time of calculate_delta_percentages: ",
            average_time,
            " seconds",
        )
        println()
    end

    @testset "get_stock_data_dataframe_start_end tests" begin
        times = Float64[]

        # First test: Normal function call
        time_result = @timed begin
            result = get_stock_data_dataframe_start_end(
                "AAPL", Date(2021, 1, 1), Date(2021, 1, 5)
            )
            result = [
                Dict(p => getproperty(row, p) for p in propertynames(row)) for
                row in eachrow(result)
            ]
            expected_result = [
                Dict(:date => "2021-01-04", :adjusted_close => 126.4093469655),
                Dict(:date => "2021-01-05", :adjusted_close => 127.9722474766),
            ]
            @test result == expected_result
        end
        push!(times, time_result.time)

        # Second test: Error handling
        time_result = @timed @test_throws ErrorException get_stock_data_dataframe_start_end(
            "INVALID", Date(2021, 1, 1), Date(2021, 1, 5)
        )
        push!(times, time_result.time)

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time of get_stock_data_dataframe_start_end: ",
            average_time,
            " seconds",
        )
        println()
    end
    root_path = get_project_root()
    if isfile("$root_path/Data&TA/StockData.jl")
        coverage_data = process_file("$root_path/Data&TA/StockData.jl")
    else
        error("error: file \"StockData.jl\" not found")
    end

    # Display coverage results for the specific file
    println("Coverage for StockData.jl")
    covered_lines, total_lines = get_summary(coverage_data)
    coverage_percentage = covered_lines / total_lines * 100
    println("Covered lines: $covered_lines")
    println("Total lines: $total_lines")
    println("Coverage percentage: $coverage_percentage%")
    println()

    @testset "DataFrame Parsing Functionality into List" begin
        times = Float64[]

        # Test 1: DataFrame without missing values
        @testset "Without Missing Values" begin
            time_result = @timed begin
                df = DataFrame(; adjusted_close=[181.464, 182.153, 182.493, 184.32, 183.05])
                expected_output = [181.464, 182.153, 182.493, 184.32, 183.05]
                parsed_output = parse_dataframe_into_list(df)
                @test parsed_output == expected_output
            end
            push!(times, time_result.time)
        end

        # Test 2: DataFrame with missing values
        @testset "With Missing Values" begin
            time_result = @timed begin
                df = DataFrame(;
                    adjusted_close=[181.464, missing, 182.493, 184.32, missing]
                )
                expected_output = [181.464, 182.493, 184.32]  # Missing values should be skipped
                parsed_output = parse_dataframe_into_list(df)
                @test parsed_output == expected_output
            end
            push!(times, time_result.time)
        end

        # Test 3: Empty DataFrame
        @testset "Empty DataFrame" begin
            time_result = @timed begin
                df = DataFrame(; adjusted_close=Float64[])
                expected_output = []
                parsed_output = parse_dataframe_into_list(df)
                @test parsed_output == expected_output
            end
            push!(times, time_result.time)
        end

        # Test 4: DataFrame with all missing values
        @testset "All Missing Values" begin
            time_result = @timed begin
                df = DataFrame(; adjusted_close=[missing, missing, missing])
                expected_output = []  # All values are missing, so the list should be empty
                parsed_output = parse_dataframe_into_list(df)
                @test parsed_output == expected_output
            end
            push!(times, time_result.time)
        end

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time of parse_dataframe_into_list: ",
            average_time,
            " seconds",
        )
        println()
    end

    @testset "Stock Data Functionality" begin
        times = Float64[]  # Array to store execution times

        @testset "Fetching Historical Data" begin
            ticker = "AAPL"
            period = 5
            end_date = Date(2024, 5, 11)

            # Mocking necessary functions to simulate conditions
            get_new_york_time_date() = Date(2024, 5, 11)
            is_us_market_open(_) = false
            check_trading_hours(_) = false
            get_live_data(_) = DataFrame(; date=[Date(2024, 5, 11)], adjusted_close=[200.0])
            get_historical_stock_data(_, _, _) = DataFrame(;
                date=[
                    Date(2024, 5, 10),
                    Date(2024, 5, 9),
                    Date(2024, 5, 8),
                    Date(2024, 5, 7),
                    Date(2024, 5, 6),
                ],
                adjusted_close=[183.05, 184.32, 182.493, 182.153, 181.464],
            )

            # Measure the execution time of the test block
            time_result = @timed begin
                result = get_stock_data_dataframe(ticker, period, end_date)
                expected_result = DataFrame(;
                    date=[
                        Date(2024, 5, 10),
                        Date(2024, 5, 9),
                        Date(2024, 5, 8),
                        Date(2024, 5, 7),
                        Date(2024, 5, 6),
                    ],
                    adjusted_close=[
                        182.4383392422,
                        183.7023691977,
                        181.8809717028,
                        181.5425699825,
                        180.85581355,
                    ],
                )

                # Sort both DataFrames by date before comparing
                result_sorted = sort(result, :date)
                expected_result_sorted = sort(expected_result, :date)

                # Compare each row individually, using isapprox with both atol and rtol
                for i in 1:size(result_sorted, 1)
                    @test Date(result_sorted.date[i]) == expected_result_sorted.date[i]
                    @test isapprox(
                        result_sorted.adjusted_close[i],
                        expected_result_sorted.adjusted_close[i],
                        atol=1e-4,
                        rtol=1e-4,
                    )
                end
            end
            push!(times, time_result.time)
        end

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time of get_stock_data_dataframe: ", average_time, " seconds"
        )
        println()
    end

    @testset "combine_data_full Tests" begin
        times = Float64[]  # Array to store execution times

        @testset "Correct data combination" begin
            # Create sample historical data
            historical_data = DataFrame(;
                date=[Date("2023-01-01"), Date("2023-01-02"), Date("2023-01-03")],
                close=[100.0, 110.0, 120.0],
                high=[105.0, 115.0, 125.0],
                low=[95.0, 105.0, 115.0],
                open=[98.0, 108.0, 118.0],
                volume=[1000, 1100, 1200],
                vwap=[99.0, 109.0, 119.0],
                trade_count=[10, 20, 30],
            )

            # Create sample live data
            live_data = DataFrame(; date=[Date("2023-01-04")], adjusted_close=[130.0])

            # Measure the execution time of the test block
            time_result = @timed begin
                result = combine_data_full(historical_data, live_data)

                # Define the expected DataFrame
                expected_df = DataFrame(;
                    date=[
                        Date("2023-01-01"),
                        Date("2023-01-02"),
                        Date("2023-01-03"),
                        Date("2023-01-04"),
                    ],
                    close=[100.0, 110.0, 120.0, 130.0],
                    high=[105.0, 115.0, 125.0, 0],
                    low=[95.0, 105.0, 115.0, 0],
                    open=[98.0, 108.0, 118.0, 0],
                    volume=[1000, 1100, 1200, 0],
                    vwap=[99.0, 109.0, 119.0, 0],
                    trade_count=[10, 20, 30, 0],
                )

                # Assert that the result matches the expected DataFrame
                @test result == expected_df
            end
            push!(times, time_result.time)
        end

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println("Average execution time of combine_data_full: ", average_time, " seconds")
        println()
    end

    @testset "combine_data" begin
        times = Float64[]  # Array to store execution times

        # Test case 1: Correct working
        @testset "Correct data combination" begin
            # Create sample historical data
            historical_data = DataFrame(;
                date=["2023-01-01", "2023-01-02", "2023-01-03"],
                adjusted_close=[100.0, 110.0, 120.0],
                volume=[1000, 1100, 1200],
            )

            # Create sample live data
            live_data = DataFrame(;
                date=["2023-01-04", "2023-01-05"],
                adjusted_close=[130.0, 140.0],
                volume=[1300, 1400],
            )

            # Measure the execution time of the test block
            time_result = @timed begin
                result = combine_data(historical_data, live_data)

                # Define the expected DataFrame
                expected_df = DataFrame(;
                    date=[
                        Date("2023-01-01"),
                        Date("2023-01-02"),
                        Date("2023-01-03"),
                        Date("2023-01-04"),
                        Date("2023-01-05"),
                    ],
                    adjusted_close=[100.0, 110.0, 120.0, 130.0, 140.0],
                    volume=[1000, 1100, 1200, 1300, 1400],
                )

                # Assert that the result matches the expected DataFrame
                @test result == expected_df
            end
            push!(times, time_result.time)
        end

        # Test case 2: Error handling
        @testset "Error handling" begin
            # Create sample historical data with missing columns
            historical_data = DataFrame(;
                date=["2023-01-01", "2023-01-02", "2023-01-03"],
                adjusted_close=[100.0, 110.0, 120.0],
            )

            # Create sample live data with missing columns
            live_data = DataFrame(; date=["2023-01-04", "2023-01-05"], volume=[1300, 1400])

            # Measure the execution time of the test block
            time_result = @timed begin
                @test_throws ErrorException combine_data(historical_data, live_data)
            end
            push!(times, time_result.time)
        end

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println("Average execution time of combine_data: ", average_time, " seconds")
        println()
    end

    @testset "get_live_data_api_call" begin
        times = Float64[]  # Array to store execution times

        # Test case 1: Successful API call
        @testset "Successful API call" begin
            symbol = "AAPL"
            expected_keys = ["adjusted_close", "source", "symbol", "date", "close"]

            # Measure the execution time of the test block
            time_result = @timed begin
                result = get_live_data_api_call(symbol)
                @test all(key -> haskey(result[1], key), expected_keys)
                @test isa(result[1]["adjusted_close"], Number)
                @test result[1]["source"] == "ThetaData"
                @test result[1]["symbol"] == symbol
                @test Date(result[1]["date"]) == Dates.today()
                @test isa(result[1]["close"], Number)
            end
            push!(times, time_result.time)
        end

        # Test case 2: API returns a non-200 status code
        @testset "API returns a non-200 status code" begin
            symbol = "INVALID"
            expected_error = Dict("error" => "Error getting live data")
            expected_status = 500

            # Mock the HTTP.get function to return a non-200 status code
            mock_response = HTTP.Response(expected_status)
            HTTP.get(url::String) = mock_response

            # Measure the execution time of the test block
            time_result = @timed begin
                result, status = get_live_data_api_call(symbol)
                @test result == expected_error
                @test status == expected_status
            end
            push!(times, time_result.time)
        end

        # Test case 3: Exception is raised during the API call
        @testset "Exception is raised during the API call" begin
            symbol = "EXCEPTION"
            expected_error = Dict("error" => "Error getting live data")
            expected_status = 500

            # Mock the HTTP.get function to raise an exception
            HTTP.get(url::String) = error("API call failed")

            # Measure the execution time of the test block
            time_result = @timed begin
                result, status = get_live_data_api_call(symbol)
                @test result == expected_error
                @test status == expected_status
            end
            push!(times, time_result.time)
        end

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time oF get_live_data_api_call: ", average_time, " seconds"
        )
        println()
    end

    @testset "combine_data_full" begin
        times = Float64[]  # Array to store execution times

        # Test case 1: Correct output
        @testset "Correct output" begin
            historical_data = [
                Dict(
                    "date" => "2023-05-01",
                    "close" => 100.0,
                    "high" => 102.0,
                    "low" => 98.0,
                    "open" => 99.0,
                    "volume" => 1000,
                    "vwap" => 100.5,
                    "trade_count" => 100,
                ),
                Dict(
                    "date" => "2023-05-02",
                    "close" => 102.5,
                    "high" => 104.0,
                    "low" => 101.0,
                    "open" => 101.5,
                    "volume" => 1200,
                    "vwap" => 102.8,
                    "trade_count" => 120,
                ),
            ]
            live_data = DataFrame(; date=["2023-05-03"], adjusted_close=[105.0])
            expected_output = [
                Dict(
                    "date" => "2023-05-01",
                    "close" => 100.0,
                    "high" => 102.0,
                    "low" => 98.0,
                    "open" => 99.0,
                    "volume" => 1000,
                    "vwap" => 100.5,
                    "trade_count" => 100,
                ),
                Dict(
                    "date" => "2023-05-02",
                    "close" => 102.5,
                    "high" => 104.0,
                    "low" => 101.0,
                    "open" => 101.5,
                    "volume" => 1200,
                    "vwap" => 102.8,
                    "trade_count" => 120,
                ),
                Dict(
                    "date" => "2023-05-03",
                    "close" => 105.0,
                    "high" => 0,
                    "low" => 0,
                    "open" => 0,
                    "volume" => 0,
                    "vwap" => 0,
                    "trade_count" => 0,
                ),
            ]

            # Measure the execution time of the test block
            time_result = @timed begin
                result = combine_data_full(historical_data, live_data)
                @test result == expected_output
            end
            push!(times, time_result.time)
        end

        # Test case 2: Incorrect output
        @testset "Incorrect output" begin
            historical_data = [
                Dict(
                    "date" => "2023-05-01",
                    "close" => 100.0,
                    "high" => 102.0,
                    "low" => 98.0,
                    "open" => 99.0,
                    "volume" => 1000,
                    "vwap" => 100.5,
                    "trade_count" => 100,
                ),
                Dict(
                    "date" => "2023-05-02",
                    "close" => 102.5,
                    "high" => 104.0,
                    "low" => 101.0,
                    "open" => 101.5,
                    "volume" => 1200,
                    "vwap" => 102.8,
                    "trade_count" => 120,
                ),
            ]
            live_data = DataFrame(; date=["2023-05-03"], adjusted_close=[105.0])
            expected_output = [
                Dict(
                    "date" => "2023-05-01",
                    "close" => 100.0,
                    "high" => 102.0,
                    "low" => 98.0,
                    "open" => 99.0,
                    "volume" => 1000,
                    "vwap" => 100.5,
                    "trade_count" => 100,
                ),
                Dict(
                    "date" => "2023-05-02",
                    "close" => 102.5,
                    "high" => 104.0,
                    "low" => 101.0,
                    "open" => 101.5,
                    "volume" => 1200,
                    "vwap" => 102.8,
                    "trade_count" => 120,
                ),
            ]

            # Measure the execution time of the test block
            time_result = @timed begin
                result = combine_data_full(historical_data, live_data)
                @test result != expected_output
            end
            push!(times, time_result.time)
        end

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println("Average execution time of combine_data_full: ", average_time, " seconds")
        println()
    end

    @testset "combine_data" begin
        times = Float64[]  # Array to store execution times

        # Test case 1: Correct output
        @testset "Correct output" begin
            historical_data = DataFrame(;
                date=["2023-05-01", "2023-05-02", "2023-05-03"],
                adjusted_close=[100.0, 102.5, 105.0],
            )
            live_data = DataFrame(; date=["2023-05-04"], adjusted_close=[107.5])
            expected_output = DataFrame(;
                date=[
                    Date("2023-05-01"),
                    Date("2023-05-02"),
                    Date("2023-05-03"),
                    Date("2023-05-04"),
                ],
                adjusted_close=[100.0, 102.5, 105.0, 107.5],
            )

            # Measure the execution time of the test block
            time_result = @timed begin
                result = combine_data(historical_data, live_data)
                @test result == expected_output
            end
            push!(times, time_result.time)
        end

        # Test case 2: Incorrect output
        @testset "Incorrect output" begin
            historical_data = DataFrame(;
                date=["2023-05-01", "2023-05-02", "2023-05-03"],
                adjusted_close=[100.0, 102.5, 105.0],
            )
            live_data = DataFrame(; date=["2023-05-04"], adjusted_close=[107.5])
            expected_output = DataFrame(;
                date=[Date("2023-05-01"), Date("2023-05-02"), Date("2023-05-03")],
                adjusted_close=[100.0, 102.5, 105.0],
            )

            # Measure the execution time of the test block
            time_result = @timed begin
                result = combine_data(historical_data, live_data)
                @test result != expected_output
            end
            push!(times, time_result.time)
        end

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println("Average execution time of combine_data: ", average_time, " seconds")
        println()
    end

    @testset "convert_to_dataframe" begin
        times = Float64[]  # Array to store execution times

        # Test case 1: Normal input
        @testset "Normal input" begin
            live_data = [
                Dict(
                    "date" => "2023-05-01",
                    "open" => 100.0,
                    "high" => 105.0,
                    "low" => 98.0,
                    "adjusted_close" => 103.5,
                    "volume" => 1000,
                ),
                Dict(
                    "date" => "2023-05-02",
                    "open" => 104.0,
                    "high" => 107.0,
                    "low" => 102.0,
                    "adjusted_close" => 106.2,
                    "volume" => 1500,
                ),
            ]

            expected_output = DataFrame(;
                date=["2023-05-01", "2023-05-02"], adjusted_close=[103.5, 106.2]
            )

            # Measure the execution time of the test block
            time_result = @timed begin
                result = convert_to_dataframe(live_data)
                @test result == expected_output
            end
            push!(times, time_result.time)
        end

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time for 'convert_to_dataframe': ", average_time, " seconds"
        )
        println()
    end

    @testset "get_new_york_time_date" begin
        times = Float64[]  # Array to store execution times

        # Measure the execution time of the test block
        time_result = @timed begin
            result = get_new_york_time_date()
            # println("New York time: ", result)
            @test timezone(result) == tz"America/New_York"
            @test Dates.Date(result) == Dates.today(tz"America/New_York")
        end
        push!(times, time_result.time)

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time for 'get_new_york_time_date': ",
            average_time,
            " seconds",
        )
        println()
    end

    @testset "check_trading_hours" begin
        times = Float64[]  # Array to store execution times

        # Test case 1
        time_result = @timed begin
            nyt_time = ZonedDateTime(2023, 5, 17, 13, 30, TimeZone("America/New_York"))
            @test check_trading_hours(nyt_time) == true
        end
        push!(times, time_result.time)

        # Test case 2
        time_result = @timed begin
            nyt_time = ZonedDateTime(2023, 5, 17, 9, 30, TimeZone("America/New_York"))
            @test check_trading_hours(nyt_time) == true
        end
        push!(times, time_result.time)

        # Test case 3
        time_result = @timed begin
            nyt_time = ZonedDateTime(2023, 5, 17, 16, 0, TimeZone("America/New_York"))
            @test check_trading_hours(nyt_time) == true
        end
        push!(times, time_result.time)

        # Test case 4
        time_result = @timed begin
            nyt_time = ZonedDateTime(2023, 5, 17, 9, 29, TimeZone("America/New_York"))
            @test check_trading_hours(nyt_time) == false
        end
        push!(times, time_result.time)

        # Test case 5
        time_result = @timed begin
            nyt_time = ZonedDateTime(2023, 5, 17, 16, 1, TimeZone("America/New_York"))
            @test check_trading_hours(nyt_time) == false
        end
        push!(times, time_result.time)

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time for 'check_trading_hours': ", average_time, " seconds"
        )
        println()
    end

    @testset "find_valid_business_days tests" begin
        times = Float64[]  # Array to store execution times

        # Test case 1
        time_result = @timed begin
            expected_output1 = (Date("2020-12-24"), Date("2021-01-01"))
            actual_output1 = find_valid_business_days(Date(2021, 1, 1), 5)
            @test actual_output1 == expected_output1
        end
        push!(times, time_result.time)

        # Test case 2
        time_result = @timed begin
            expected_output2 = (Date("2021-01-25"), Date("2021-02-01"))
            actual_output2 = find_valid_business_days(Date(2021, 2, 1), 5)
            @test actual_output2 == expected_output2
        end
        push!(times, time_result.time)

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time for 'find_valid_business_days tests': ",
            average_time,
            " seconds",
        )
        println()
    end

    #Failed invalid counting 1 day counted less and if only 1 day is to be counted it returns the same date
    @testset "find_previous_business_day tests" begin
        times = Float64[]  # Array to store execution times

        # Test case 1
        time_result = @timed begin
            expected_output1 = Date("2020-12-29")
            actual_output1 = find_previous_business_day(Date(2021, 1, 1), 3)
            @test actual_output1 == expected_output1
        end
        push!(times, time_result.time)

        # Test case 2
        time_result = @timed begin
            expected_output2 = Date("2020-12-30")
            actual_output2 = find_previous_business_day(Date(2021, 1, 1), 2)
            @test actual_output2 == expected_output2
        end
        push!(times, time_result.time)

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time for 'find_previous_business_day tests': ",
            average_time,
            " seconds",
        )
        println()
    end

    @testset "is_us_market_open" begin
        times = Float64[]  # Array to store execution times

        # Test cases
        dates_to_test = [
            (Date(2023, 5, 17), true),
            (Date(2023, 5, 20), false),
            (Date(2023, 5, 21), false),
            (Date(2023, 1, 2), false),
            (Date(2023, 7, 4), false),
            (Date(2023, 12, 25), false),
            (Date(2023, 7, 3), true),
            (Date(2023, 12, 26), true),
            (Date(2024, 2, 29), true),
            (Date(1, 1, 1), false),
            (Date(9999, 12, 31), true),
        ]

        for (date, expected) in dates_to_test
            time_result = @timed begin
                @test is_us_market_open(date) == expected
            end
            push!(times, time_result.time)
        end

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println(
            "Average execution time for 'is_us_market_open': ", average_time, " seconds"
        )
        println()
    end

    @testset "adjust_holidays" begin
        times = Float64[]  # Array to store execution times

        # Test case for 2023
        time_result = @timed begin
            holidays_2023 = adjust_holidays(2023)
            # println("Holidays 2023: ", holidays_2023)
            @test issetequal(
                holidays_2023,
                [
                    Date(2023, 1, 2),
                    Date(2023, 1, 16),
                    Date(2023, 2, 20),
                    Date(2023, 5, 29),
                    Date(2023, 7, 4),
                    Date(2023, 9, 4),
                    Date(2023, 11, 23),
                    Date(2023, 12, 25),
                ],
            )
        end
        push!(times, time_result.time)

        # Test case for 2020
        time_result = @timed begin
            holidays_2020 = adjust_holidays(2020)
            # println("Holidays 2020: ", holidays_2020)
            @test Date(2020, 7, 3) in holidays_2020
        end
        push!(times, time_result.time)

        # Test case for 2021
        time_result = @timed begin
            holidays_2021 = adjust_holidays(2021)
            # println("Holidays 2021: ", holidays_2021)
            @test Date(2021, 7, 5) in holidays_2021
        end
        push!(times, time_result.time)

        # Test case for 2023 cached
        time_result = @timed begin
            holidays_2023_cached = adjust_holidays(2023)
            # println("Holidays 2023 (cached): ", holidays_2023_cached)
            @test holidays_2023_cached === holidays_2023
        end
        push!(times, time_result.time)

        # Test case for 2022
        time_result = @timed begin
            holidays_2022 = adjust_holidays(2022)
            # println("Holidays 2022: ", holidays_2022)
            @test all(Dates.dayofweek.(holidays_2022) .!= Dates.Saturday)
            @test all(Dates.dayofweek.(holidays_2022) .!= Dates.Sunday)
        end
        push!(times, time_result.time)

        # Calculate the average execution time
        average_time = mean(times)

        # Print the average execution time
        println("Average execution time for 'adjust_holidays': ", average_time, " seconds")
        println()
    end
end
