include("../../Main.jl")
include("../../BacktestUtils/Types.jl")
include("../../BacktestUtils/FlowData.jl")
include("../../BacktestUtils/TASorting.jl")
include("../../NodeProcessors/SortNode.jl")
include("../../NodeProcessors/StockNode.jl")
include("../../BacktestUtils/GlobalCache.jl")
include("../../BacktestUtils/ErrorHandlers.jl")
include("../../BacktestUtils/BacktestUtils.jl")
include("../../NodeProcessors/ConditonalNode.jl")
include("../../NodeProcessors/AllocationNode.jl")
include("../../BacktestUtils/ReturnCalculations.jl")
include("../../BacktestUtils/SubTreeCache.jl")
include("../BenchmarkTimes.jl")

using Test
using JSON
using Dates
using DataFrames
using Parquet2
using BenchmarkTools
using ..Types
using ..VectoriseBacktestService
using ..ConditionalNode
using ..SortNode
using ..StockNode
using ..AllocationNode
using ..FlowData
using ..ReturnCalculations
using ..TASorting
using ..GlobalCache
using ..BacktestUtilites
using ..SubtreeCache
using ..VectoriseBacktestService.ErrorHandlers
using ..VectoriseBacktestService.GlobalServerCache
initialize_server_cache()
@testset "SubtreeCache" begin
    @testset "write_subtree_to_parquet" begin
        dates_to_write = ["2023-01-01", "2023-01-02"]
        tickers_to_write = ["AAPL", "GOOGL"]
        weights_to_write = [0.5f0, 0.5f0]
        hash = "test_hash"
        end_date = Date("2023-01-02")
        dates = ["2023-01-01", "2023-01-02"]
        test_file_path = "./test_subtree.parquet"

        @test SubtreeCache.write_subtree_portfolio_to_parquet(
            dates_to_write,
            tickers_to_write,
            weights_to_write,
            hash,
            end_date,
            dates,
            test_file_path,
        ) == true

        @test isfile(test_file_path)

        timing_data = @benchmark SubtreeCache.write_subtree_portfolio_to_parquet(
            $dates_to_write,
            $tickers_to_write,
            $weights_to_write,
            $hash,
            $end_date,
            $dates,
            $test_file_path,
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_WRITE_SUBTREE_PORTFOLIO_TO_PARQUET)
        @test MIN_WRITE_SUBTREE_PORTFOLIO_TO_PARQUET - range <=
            min_time <=
            MIN_WRITE_SUBTREE_PORTFOLIO_TO_PARQUET + range
        println(
            "Minimum time taken for write_subtree_portfolio_to_parquet: ",
            min_time,
            " seconds",
        )

        # Clean up
        rm(test_file_path)
    end

    @testset "read_subtree_parquet_with_duckdb" begin
        # First, create a test parquet file
        df = DataFrame(;
            date=["2023-01-01", "2023-01-02"],
            ticker=["AAPL", "GOOGL"],
            weight=[0.5f0, 0.5f0],
        )
        test_file_path = "./test_read_subtree.parquet"
        Parquet2.writefile(test_file_path, df)

        result = SubtreeCache.read_subtree_parquet_with_duckdb(
            "test_hash", Date("2023-01-02"), test_file_path
        )

        @test result isa DataFrame
        @test size(result) == (2, 3)
        @test names(result) == ["date", "ticker", "weight"]

        # Test with non-existent file
        @test SubtreeCache.read_subtree_parquet_with_duckdb(
            "non_existent", Date("2023-01-02"), "non_existent.parquet"
        ) === nothing

        timing_data = @benchmark SubtreeCache.read_subtree_parquet_with_duckdb(
            "test_hash", Date("2023-01-02"), $test_file_path
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_READ_SUBTREE_PARQUET_WITH_DUCKDB)
        @test MIN_READ_SUBTREE_PARQUET_WITH_DUCKDB - range <=
            min_time <=
            MIN_READ_SUBTREE_PARQUET_WITH_DUCKDB + range
        println(
            "Minimum time taken for read_subtree_parquet_with_duckdb: ",
            min_time,
            " seconds",
        )

        # Clean up
        rm(test_file_path)
    end

    @testset "read_subtree_portfolio" begin
        # First, create a test parquet file
        df = DataFrame(;
            date=["2023-01-01", "2023-01-02"],
            ticker=["AAPL", "GOOGL"],
            weight=[0.5f0, 0.5f0],
        )
        test_file_path = "./SubtreeCache/test_read_returns.parquet"
        mkpath(dirname(test_file_path))
        Parquet2.writefile(test_file_path, df)

        result, end_date = SubtreeCache.read_subtree_portfolio(
            "test_read_returns", Date("2023-01-02")
        )

        @test result isa Vector{SubtreeCache.DayData}
        @test length(result) == 2
        @test end_date == Date("2023-01-02")

        # Test with non-existent file
        @test SubtreeCache.read_subtree_portfolio("non_existent", Date("2023-01-02")) ==
            (nothing, nothing)

        timing_data = @benchmark SubtreeCache.read_subtree_portfolio(
            "test_read_returns", Date("2023-01-02")
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_READ_SUBTREE_PORTFOLIO)
        @test MIN_READ_SUBTREE_PORTFOLIO - range <=
            min_time <=
            MIN_READ_SUBTREE_PORTFOLIO + range
        println("Minimum time taken for read_subtree_portfolio: ", min_time, " seconds")

        # Clean up
        rm(test_file_path)
    end

    @testset "write_subtree_portfolio" begin
        date_range = ["2023-01-01", "2023-01-02"]
        end_date = Date("2023-01-02")
        hash = "test_write_returns"
        profile_history = [
            SubtreeCache.DayData([SubtreeCache.StockInfo("AAPL", 0.5f0)]),
            SubtreeCache.DayData([SubtreeCache.StockInfo("GOOGL", 0.5f0)]),
        ]

        result = SubtreeCache.write_subtree_portfolio(
            date_range, end_date, hash, length(date_range), profile_history
        )

        @test result == true
        @test isfile("./SubtreeCache/test_write_returns.parquet")

        timing_data = @benchmark SubtreeCache.write_subtree_portfolio(
            $date_range, $end_date, $hash, length($date_range), $profile_history
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_WRITE_SUBTREE_PORTFOLIO)
        @test MIN_WRITE_SUBTREE_PORTFOLIO - range <=
            min_time <=
            MIN_WRITE_SUBTREE_PORTFOLIO + range
        println("Minimum time taken for write_subtree_portfolio: ", min_time, " seconds")

        # Clean up
        rm("./SubtreeCache/test_write_returns.parquet")
    end

    @testset "read_subtree_portfolio" begin
        # First, create a test parquet file
        df = DataFrame(;
            date=["2023-01-01", "2023-01-02"],
            ticker=["AAPL", "GOOGL"],
            weight=[0.5f0, 0.5f0],
        )
        test_file_path = "./SubtreeCache/test_get_returns.parquet"
        mkpath(dirname(test_file_path))
        Parquet2.writefile(test_file_path, df)

        # Test with non-existent file
        @test SubtreeCache.read_subtree_portfolio("non_existent", Date("2023-01-02")) ===
            (nothing, nothing)

        # Clean up
        rm(test_file_path)
    end
end

@testset "get_cached_value tests" begin
    @testset "get existing key exists in cache" begin
        cache = Dict("existing_key" => [1.0f0, 2.0f0, 3.0f0])
        result = get_cached_value(cache, "existing_key", () -> [4.0f0, 5.0f0, 6.0f0])
        @test result == [1.0f0, 2.0f0, 3.0f0]
        @test cache["existing_key"] == [1.0f0, 2.0f0, 3.0f0]

        timing_data = @benchmark get_cached_value(
            $cache, "existing_key", () -> [4.0f0, 5.0f0, 6.0f0]
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_GET_CACHED_VALUE_EXISTING_KEY)
        @test MIN_GET_CACHED_VALUE_EXISTING_KEY - range <=
            min_time <=
            MIN_GET_CACHED_VALUE_EXISTING_KEY + range
        println(
            "Minimum time taken for get_cached_value with existing key: ",
            min_time,
            " seconds",
        )
    end

    @testset "get new key, compute function called" begin
        cache = Dict("existing_key" => [1.0f0, 2.0f0, 3.0f0])
        result = get_cached_value(cache, "new_key", () -> [4.0f0, 5.0f0, 6.0f0])
        @test result == [4.0f0, 5.0f0, 6.0f0]
        @test cache["new_key"] == [4.0f0, 5.0f0, 6.0f0]
        @test cache["existing_key"] == [1.0f0, 2.0f0, 3.0f0]

        timing_data = @benchmark get_cached_value(
            $cache, "new_key", () -> [4.0f0, 5.0f0, 6.0f0]
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_GET_CACHED_VALUE_NEW_KEY)
        @test MIN_GET_CACHED_VALUE_NEW_KEY - range <=
            min_time <=
            MIN_GET_CACHED_VALUE_NEW_KEY + range
        println(
            "Minimum time taken for get_cached_value with new key: ", min_time, " seconds"
        )
    end
end

@testset "get_cached_value_df tests" begin
    @testset "Existing key in cache" begin
        df = DataFrame(; date=["2023-01-01", "2023-01-02", "2023-01-03"], value=[1, 2, 3])
        cache = Dict("existing_key" => df)
        result = get_cached_value_df(
            "existing_key", cache, Date(2023, 1, 1), Date(2023, 1, 3), () -> DataFrame()
        )

        @test size(result, 1) == 3
        @test result.date == Date.(["2023-01-01", "2023-01-02", "2023-01-03"])
        @test result.value == [1, 2, 3]
        @test result.original_length == [3, 3, 3]

        timing_data = @benchmark get_cached_value_df(
            "existing_key", $cache, Date(2023, 1, 1), Date(2023, 1, 3), () -> DataFrame()
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_GET_CACHED_VALUE_DF_EXISTING_KEY)
        @test MIN_GET_CACHED_VALUE_DF_EXISTING_KEY - range <=
            min_time <=
            MIN_GET_CACHED_VALUE_DF_EXISTING_KEY + range
        println(
            "Minimum time taken for get_cached_value_df with existing key: ",
            min_time,
            " seconds",
        )
    end

    @testset "New key, compute function called" begin
        cache = Dict{String,DataFrame}()
        compute_func =
            () -> DataFrame(;
                date=["2023-01-01", "2023-01-02", "2023-01-03", "2023-01-04"],
                value=[1, 2, 3, 4],
            )
        result = get_cached_value_df(
            "new_key", cache, Date(2023, 1, 2), Date(2023, 1, 3), compute_func
        )

        @test size(result, 1) == 2
        @test result.date == Date.(["2023-01-02", "2023-01-03"])
        @test result.value == [2, 3]
        @test result.original_length == [4, 4]
        @test haskey(cache, "new_key")
        @test size(cache["new_key"], 1) == 4

        timing_data = @benchmark get_cached_value_df(
            "new_key", $cache, Date(2023, 1, 2), Date(2023, 1, 3), $compute_func
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_GET_CACHED_VALUE_DF_NEW_KEY)
        @test MIN_GET_CACHED_VALUE_DF_NEW_KEY - range <=
            min_time <=
            MIN_GET_CACHED_VALUE_DF_NEW_KEY + range
        println(
            "Minimum time taken for get_cached_value_df with new key: ",
            min_time,
            " seconds",
        )
    end

    @testset "Date filtering" begin
        df = DataFrame(;
            date=["2023-01-01", "2023-01-02", "2023-01-03", "2023-01-04", "2023-01-05"],
            value=1:5,
        )
        cache = Dict("filter_key" => df)
        result = get_cached_value_df(
            "filter_key", cache, Date(2023, 1, 2), Date(2023, 1, 4), () -> DataFrame()
        )

        @test size(result, 1) == 3
        @test result.date == Date.(["2023-01-02", "2023-01-03", "2023-01-04"])
        @test result.value == [2, 3, 4]
        @test result.original_length == [5, 5, 5]

        timing_data = @benchmark get_cached_value_df(
            "filter_key", $cache, Date(2023, 1, 2), Date(2023, 1, 4), () -> DataFrame()
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_GET_CACHED_VALUE_DF_FILTER)
        @test MIN_GET_CACHED_VALUE_DF_FILTER - range <=
            min_time <=
            MIN_GET_CACHED_VALUE_DF_FILTER + range
        println(
            "Minimum time taken for get_cached_value_df with filtering: ",
            min_time,
            " seconds",
        )
    end

    @testset "Error in compute function" begin
        cache = Dict{String,DataFrame}()
        @test_throws ProcessingError get_cached_value_df(
            "error_key",
            cache,
            Date(2023, 1, 1),
            Date(2023, 1, 3),
            () -> throw(ErrorException("Compute error")),
        )
        @test !haskey(cache, "error_key")
    end
end

@testset "get_price_dataframe tests" begin
    @testset "Valid input for AAPL" begin
        ticker = "AAPL"
        period = 100
        end_date = Date(2024, 5, 30)

        result = get_price_dataframe(ticker, period, end_date)

        @test result isa DataFrame
        @test size(result, 1) == 101  # period + 1

        @test Date(result[end, :date]) <= end_date
        @test result[1, :date] < result[end, :date]

        timing_data = @benchmark get_price_dataframe($ticker, $period, $end_date)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_GET_PRICE_DATAFRAME)
        @test MIN_GET_PRICE_DATAFRAME - range <= min_time <= MIN_GET_PRICE_DATAFRAME + range
        println("Minimum time taken for get_price_dataframe: ", min_time, " seconds")
    end

    @testset "Error handling" begin
        # Test with an invalid ticker
        @test_throws ProcessingError get_price_dataframe(
            "INVALID_TICKER", 100, Date(2024, 5, 30)
        )

        # Test with an invalid period (negative)
        @test_throws ProcessingError get_price_dataframe("INVALID", -1, Date(2024, 5, 30))
    end

    @testset "Date range verification" begin
        ticker = "AAPL"
        period = 100
        end_date = Date(2024, 5, 30)

        result = get_price_dataframe(ticker, period, end_date)

        @test Date(result[end, :date]) <= end_date
    end
end

@testset "read_json_file tests" begin
    @testset "Valid JSON file" begin
        json_file = "./App/Tests/TestsJSON/UnitTestsJSON/valid_test.json"
        result = read_json_file(json_file)

        @test result isa Dict{String,Any}
        @test haskey(result, "key1")
        @test result["key1"] == "value1"
        @test haskey(result, "key2")
        @test result["key2"] == 2
        @test haskey(result, "key3")
        @test result["key3"] == [1, 2, 3]

        timing_data = @benchmark read_json_file($json_file)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_READ_JSON_FILE)
        @test MIN_READ_JSON_FILE - range <= min_time <= MIN_READ_JSON_FILE + range
        println("Minimum time taken for read_json_file: ", min_time, " seconds")
    end
end

@testset "populate_dates tests" begin
    @testset "Valid input" begin
        dateLength::Int = 5
        end_date::Date = Date(2023, 1, 1)
        dates::Vector{String} = []
        populate_dates(dateLength, end_date, dates)

        @test length(dates) == 5
        @test dates ==
            ["2022-12-23", "2022-12-27", "2022-12-28", "2022-12-29", "2022-12-30"]

        timing_data = @benchmark populate_dates($dateLength, $end_date, $dates)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_POPULATE_DATES)
        @test MIN_POPULATE_DATES - range <= min_time <= MIN_POPULATE_DATES + range
        println("Minimum time taken for populate_dates: ", min_time, " seconds")
    end

    @testset "Invalid input" begin
        dateLength::Int = -1
        end_date::Date = Date(2023, 1, 1)
        dates::Vector{String} = []
        @test_throws ProcessingError populate_dates(dateLength, end_date, dates)
    end
end

@testset "compare_values tests" begin
    @testset "Valid input" begin
        value1::Vector{Float32} = [1.0, 2.0, 3.0]
        value2::Vector{Float32} = [2.0, 1.0, 4.0]
        operator::String = ">"
        result = compare_values(value1, value2, operator)

        @test result == [false, true, false]

        timing_data = @benchmark compare_values($value1, $value2, $operator)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_COMPARE_VALUES)
        @test MIN_COMPARE_VALUES - range <= min_time <= MIN_COMPARE_VALUES + range
        println("Minimum time taken for compare_values: ", min_time, " seconds")
    end

    @testset "Invalid input" begin
        value1::Vector{Float32} = [1.0, 2.0, 3.0]
        value2::Vector{Float32} = [2.0, 1.0, 4.0]
        operator::String = "INVALID"
        @test_throws ArgumentError compare_values(value1, value2, operator)
    end

    @testset "Different lengths" begin
        value1::Vector{Float32} = [1.0, 2.0, 3.0]
        value2::Vector{Float32} = [2.0, 1.0]
        operator::String = ">"
        @test compare_values(value1, value2, operator) == [false, true]

        timing_data = @benchmark compare_values($value1, $value2, $operator)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_COMPARE_VALUES_DIFFERENT_LENGTHS)
        @test MIN_COMPARE_VALUES_DIFFERENT_LENGTHS - range <=
            min_time <=
            MIN_COMPARE_VALUES_DIFFERENT_LENGTHS + range
        println(
            "Minimum time taken for compare_values with different lengths: ",
            min_time,
            " seconds",
        )
    end

    @testset "Empty vectors" begin
        value1::Vector{Float32} = Float32[]
        value2::Vector{Float32} = Float32[]
        operator::String = ">"
        @test compare_values(value1, value2, operator) == Float32[]

        timing_data = @benchmark compare_values($value1, $value2, $operator)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_COMPARE_VALUES_EMPTY_VECTORS)
        @test MIN_COMPARE_VALUES_EMPTY_VECTORS - range <=
            min_time <=
            MIN_COMPARE_VALUES_EMPTY_VECTORS + range
        println(
            "Minimum time taken for compare_values with empty vectors: ",
            min_time,
            " seconds",
        )
    end

    @testset "Less than operator" begin
        value1::Vector{Float32} = [1.0, 2.0, 3.0]
        value2::Vector{Float32} = [2.0, 1.0, 4.0]
        operator::String = "<"
        @test compare_values(value1, value2, operator) == [true, false, true]

        timing_data = @benchmark compare_values($value1, $value2, $operator)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_COMPARE_VALUES_LESS_THAN_OPERATOR)
        @test MIN_COMPARE_VALUES_LESS_THAN_OPERATOR - range <=
            min_time <=
            MIN_COMPARE_VALUES_LESS_THAN_OPERATOR + range
        println(
            "Minimum time taken for compare_values with less than operator: ",
            min_time,
            " seconds",
        )
    end

    @testset "Less then equal operator" begin
        value1::Vector{Float32} = [1.0, 2.0, 3.0]
        value2::Vector{Float32} = [2.0, 1.0, 4.0]
        operator::String = "<="
        @test compare_values(value1, value2, operator) == [true, false, true]

        timing_data = @benchmark compare_values($value1, $value2, $operator)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_COMPARE_VALUES_LESS_THAN_EQUAL_OPERATOR)
        @test MIN_COMPARE_VALUES_LESS_THAN_EQUAL_OPERATOR - range <=
            min_time <=
            MIN_COMPARE_VALUES_LESS_THAN_EQUAL_OPERATOR + range
        println(
            "Minimum time taken for compare_values with less than equal operator: ",
            min_time,
            " seconds",
        )
    end
end

@testset "get_indicator_value tests" begin
    # Setup test data dont include saturday and sunday
    dates = [string(Date("2023-05-01") + Day(i)) for i in 0:19]
    dateLength = length(dates)
    end_date = Date("2023-05-20")
    cache = Dict{String,Vector{Float32}}()
    price_cache = Dict{String,DataFrame}()

    # Test case 1: Current price SPY
    prop1 = Dict{String,Any}("indicator" => "current price", "source" => "SPY")
    result1 = get_indicator_value(prop1, dates, dateLength, end_date, cache, price_cache)
    @test result1 == Float32[
        405.6265,
        401.0676,
        398.31467,
        395.4934,
        402.815,
        402.9224,
        401.15546,
        403.0298,
        402.3269,
        401.79974,
        403.18597,
        400.4916,
        405.35315,
        409.25803,
        408.66254,
    ]
    @test eltype(result1) == Float32
    @test all(!isnan, result1)

    # Test case 2: Moving Average of Price SPY 200
    prop2 = Dict{String,Any}(
        "indicator" => "Moving Average of Price", "period" => "200", "source" => "SPY"
    )
    result2 = get_indicator_value(prop2, dates, dateLength, end_date, cache, price_cache)
    @test length(result2) == dateLength
    @test eltype(result2) == Float32
    @test all(!isnan, result2)

    # Test case 3: Current price QQQ
    prop3 = Dict{String,Any}("indicator" => "current price", "source" => "QQQ")
    result3 = get_indicator_value(prop3, dates, dateLength, end_date, cache, price_cache)
    @test result3 == Float32[
        318.58765,
        315.80905,
        313.74243,
        312.63495,
        319.27982,
        320.07086,
        318.0438,
        321.50464,
        322.5528,
        321.39587,
        323.1362,
        323.50208,
        327.4178,
        333.49902,
        332.74753,
    ]
    @test eltype(result3) == Float32
    @test all(!isnan, result3)

    # Test case 4: Moving Average of Price QQQ 20
    prop4 = Dict{String,Any}(
        "indicator" => "Moving Average of Price", "period" => "20", "source" => "QQQ"
    )
    result4 = get_indicator_value(prop4, dates, dateLength, end_date, cache, price_cache)
    @test length(result4) == dateLength
    @test eltype(result4) == Float32
    @test all(!isnan, result4)

    # Test case 5: Relative Strength Index QQQ 10
    prop5 = Dict{String,Any}(
        "indicator" => "Relative Strength Index", "period" => "10", "source" => "QQQ"
    )
    result5 = get_indicator_value(prop5, dates, dateLength, end_date, cache, price_cache)
    @test length(result5) == dateLength
    @test eltype(result5) == Float32
    @test all(0 .<= result5 .<= 100)

    # Test case 6: Constant indicator
    prop6 = Dict{String,Any}("indicator" => "constant", "period" => "50")
    result6 = get_indicator_value(prop6, dates, dateLength, end_date, cache, price_cache)
    @test length(result6) == dateLength
    @test eltype(result6) == Float32
    @test all(result6 .== 50.0f0)

    # Test case 7: Unknown indicator
    prop7 = Dict{String,Any}("indicator" => "unknown", "source" => "SPY")
    @test_throws ArgumentError get_indicator_value(
        prop7, dates, dateLength, end_date, cache, price_cache
    )

    timing_data = @benchmark get_indicator_value(
        $prop1, $dates, $dateLength, $end_date, $cache, $price_cache
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_GET_INDICATOR_VALUE)
    @test MIN_GET_INDICATOR_VALUE - range <= min_time <= MIN_GET_INDICATOR_VALUE + range
    println("Minimum time taken for get_indicator_value: ", min_time, " seconds")

    timing_data = @benchmark get_indicator_value(
        $prop2, $dates, $dateLength, $end_date, $cache, $price_cache
    )
    min_time = minimum(timing_data).time * 1e-9
    # range = get_range(MIN_GET_INDICATOR_VALUE)
    # @test MIN_GET_INDICATOR_VALUE - range <= min_time <= MIN_GET_INDICATOR_VALUE + range
    println("Minimum time taken for get_indicator_value: ", min_time, " seconds")

    timing_data = @benchmark get_indicator_value(
        $prop3, $dates, $dateLength, $end_date, $cache, $price_cache
    )
    min_time = minimum(timing_data).time * 1e-9
    # range = get_range(MIN_GET_INDICATOR_VALUE)
    # @test MIN_GET_INDICATOR_VALUE - range <= min_time <= MIN_GET_INDICATOR_VALUE + range
    println("Minimum time taken for get_indicator_value: ", min_time, " seconds")

    timing_data = @benchmark get_indicator_value(
        $prop4, $dates, $dateLength, $end_date, $cache, $price_cache
    )
    min_time = minimum(timing_data).time * 1e-9
    # range = get_range(MIN_GET_INDICATOR_VALUE)
    # @test MIN_GET_INDICATOR_VALUE - range <= min_time <= MIN_GET_INDICATOR_VALUE + range
    println("Minimum time taken for get_indicator_value: ", min_time, " seconds")

    timing_data = @benchmark get_indicator_value(
        $prop5, $dates, $dateLength, $end_date, $cache, $price_cache
    )
    min_time = minimum(timing_data).time * 1e-9
    # range = get_range(MIN_GET_INDICATOR_VALUE)
    # @test MIN_GET_INDICATOR_VALUE - range <= min_time <= MIN_GET_INDICATOR_VALUE + range
    println("Minimum time taken for get_indicator_value: ", min_time, " seconds")

    timing_data = @benchmark get_indicator_value(
        $prop6, $dates, $dateLength, $end_date, $cache, $price_cache
    )
    min_time = minimum(timing_data).time * 1e-9
    # range = get_range(MIN_GET_INDICATOR_VALUE)
    # @test MIN_GET_INDICATOR_VALUE - range <= min_time <= MIN_GET_INDICATOR_VALUE + range
    println("Minimum time taken for get_indicator_value: ", min_time, " seconds")
end

# make_sort_branches is called in get_branches, so it is tested there
@testset "get_branches tests" begin
    @testset "positive case" begin
        node = Dict{String,Any}(
            "name" => "SortBy Cumulative Return-14",
            "componentType" => "switch",
            "branches" => Dict{String,Any}(
                "Bottom-1" => Any[
                    Dict{String,Any}(
                        "name" => "Buy Order MSFT",
                        "componentType" => "largeTask",
                        "properties" => Dict{String,Any}("symbol" => "MSFT"),
                        "id" => "b86567817630492f981f40fe14a3aef7",
                        "type" => "stock",
                    ),
                    Dict{String,Any}(
                        "name" => "Buy Order AAPL",
                        "componentType" => "largeTask",
                        "properties" => Dict{String,Any}("symbol" => "AAPL"),
                        "id" => "de27becbabb84bdfa3fb3d74c49e90d6",
                        "type" => "stock",
                    ),
                    Dict{String,Any}(
                        "name" => "Buy Order NVDA",
                        "componentType" => "largeTask",
                        "properties" => Dict{String,Any}("symbol" => "NVDA"),
                        "id" => "16570b5c6bf54b91a8d611babfd0b32e",
                        "type" => "stock",
                    ),
                    Dict{String,Any}(
                        "name" => "Folder",
                        "componentType" => "folder",
                        "sequence" => Any[Dict{String,Any}(
                            "name" => "Buy Order SHY",
                            "componentType" => "task",
                            "properties" => Dict{String,Any}(
                                "isInvalid" => false, "symbol" => "SHY"
                            ),
                            "id" => "68652d9a97bf5ab37db74c560f952fd1",
                            "type" => "stock",
                        )],
                        "properties" => Dict{String,Any}(),
                        "id" => "ad367fd08bd3c25f4320dbd39d763e5f",
                        "type" => "folder",
                    ),
                    Dict{String,Any}(
                        "name" => "Interrupting icon",
                        "componentType" => "icon",
                        "id" => "93e8b4b9-1eca-4de4-8e1c-9df69a472c1a",
                        "type" => "icon",
                    ),
                ],
            ),
            "properties" => Dict{String,Any}(
                "sortby" => Dict{String,Any}(
                    "function" => "Cumulative Return", "window" => "14"
                ),
                "select" => Dict{String,Any}("function" => "Bottom", "howmany" => "1"),
            ),
            "id" => "728a906cd81a4ae2b22583201e4af8bf",
            "type" => "Sort",
        )

        result = get_branches(node)

        ans_result = (
            Dict{String,Any}(
                "4" => Dict{String,Any}[Dict(
                    "name" => "Folder",
                    "componentType" => "folder",
                    "sequence" => Any[Dict{String,Any}(
                        "name" => "Buy Order SHY",
                        "componentType" => "task",
                        "properties" => Dict{String,Any}(
                            "isInvalid" => false, "symbol" => "SHY"
                        ),
                        "id" => "68652d9a97bf5ab37db74c560f952fd1",
                        "type" => "stock",
                    )],
                    "properties" => Dict{String,Any}(),
                    "id" => "ad367fd08bd3c25f4320dbd39d763e5f",
                    "type" => "folder",
                )],
                "1" => Dict{String,Any}[Dict(
                    "name" => "Buy Order MSFT",
                    "componentType" => "largeTask",
                    "properties" => Dict{String,Any}("symbol" => "MSFT"),
                    "id" => "b86567817630492f981f40fe14a3aef7",
                    "type" => "stock",
                )],
                "2" => Dict{String,Any}[Dict(
                    "name" => "Buy Order AAPL",
                    "componentType" => "largeTask",
                    "properties" => Dict{String,Any}("symbol" => "AAPL"),
                    "id" => "de27becbabb84bdfa3fb3d74c49e90d6",
                    "type" => "stock",
                )],
                "3" => Dict{String,Any}[Dict(
                    "name" => "Buy Order NVDA",
                    "componentType" => "largeTask",
                    "properties" => Dict{String,Any}("symbol" => "NVDA"),
                    "id" => "16570b5c6bf54b91a8d611babfd0b32e",
                    "type" => "stock",
                )],
            ),
            true,
        )

        @test result == ans_result

        timing_data = @benchmark get_branches($node)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_GET_BRANCHES)
        @test MIN_GET_BRANCHES - range <= min_time <= MIN_GET_BRANCHES + range
        println("Minimum time taken for get_branches: ", min_time, " seconds")
    end

    @testset "empty branch case" begin
        node = Dict{String,Any}(
            "id" => "7e481b98c0a445469687d3ec09db07a7",
            "componentType" => "largeTask",
            "type" => "stock",
            "name" => "Buy Order PSQ",
            "properties" => Dict{String,Any}("symbol" => "PSQ"),
        )
        result = get_branches(node)
        @test result == (Dict{String,Any}(), false)

        timing_data = @benchmark get_branches($node)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_GET_BRANCHES_EMPTY_BRANCH)
        @test MIN_GET_BRANCHES_EMPTY_BRANCH - range <=
            min_time <=
            MIN_GET_BRANCHES_EMPTY_BRANCH + range
        println(
            "Minimum time taken for get_branches with empty branch: ", min_time, " seconds"
        )
    end
end

@testset "parse_select_properties & parse_sort_properties" begin
    @testset "positive case" begin
        node = Dict{String,Any}(
            "name" => "SortBy Relative Strength Index",
            "componentType" => "switch",
            "branches" => Dict{String,Any}(
                "1" => Any[Dict{String,Any}(
                    "name" => "Buy Order PSQ",
                    "componentType" => "task",
                    "properties" => Dict{String,Any}("symbol" => "PSQ"),
                    "id" => "247d1615-ef71-42f9-a9cc-1452f0de5429",
                    "type" => "stock",
                )],
                "2" => Any[Dict{String,Any}(
                    "name" => "Buy Order SHY",
                    "componentType" => "task",
                    "properties" => Dict{String,Any}("symbol" => "SHY"),
                    "id" => "f7537348-f9d1-4619-98f6-6b5dee06e8da",
                    "type" => "stock",
                )],
            ),
            "properties" => Dict{String,Any}(
                "sortby" => Dict{String,Any}(
                    "function" => "Relative Strength Index", "window" => "10"
                ),
                "select" => Dict{String,Any}("function" => "Top", "howmany" => "1"),
            ),
            "id" => "01686dff-09ba-4833-8cc7-9e8a07b35b40",
            "type" => "Sort",
        )
        top_n, select_function = parse_select_properties(node)
        @test top_n == 1
        @test select_function == "Top"

        sort_function, window = parse_sort_properties(node)
        @test sort_function == "Relative Strength Index"
        @test window == 10

        timing_data = @benchmark parse_select_properties($node)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_PARSE_SELECT_PROPERTIES)
        @test MIN_PARSE_SELECT_PROPERTIES - range <=
            min_time <=
            MIN_PARSE_SELECT_PROPERTIES + range
        println("Minimum time taken for parse_select_properties: ", min_time, " seconds")

        timing_data = @benchmark parse_sort_properties($node)
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_PARSE_SORT_PROPERTIES)
        @test MIN_PARSE_SORT_PROPERTIES - range <=
            min_time <=
            MIN_PARSE_SORT_PROPERTIES + range
        println("Minimum time taken for parse_sort_properties: ", min_time, " seconds")
    end

    @testset "positive case" begin
        node = Dict{String,Any}(
            "properties" => Dict{String,Any}(
                "sortby" =>
                    Dict{String,Any}("function" => "current price", "window" => ""),
                "select" => Dict{String,Any}("function" => "Top", "howmany" => "22"),
            ),
            "id" => "01686dff-09ba-4833-8cc7-9e8a07b35b40",
            "type" => "Sort",
        )
        top_n, select_function = parse_select_properties(node)
        @test top_n == 22
        @test select_function == "Top"

        sort_function, window = parse_sort_properties(node)
        @test sort_function == "current price"
        @test window == 0

        timing_data = @benchmark parse_select_properties($node)
        min_time = minimum(timing_data).time * 1e-9
        println("Minimum time taken for parse_select_properties: ", min_time, " seconds")

        timing_data = @benchmark parse_sort_properties($node)
        min_time = minimum(timing_data).time * 1e-9
        println("Minimum time taken for parse_sort_properties: ", min_time, " seconds")
    end

    # A "negative case" can be potentially added here, but it is not necessary
end

@testset "find_matching_branch tests" begin
    node_properties_values = Dict{String,Any}("b" => 33.34, "a" => 33.66, "c" => 33)
    node_branches = Dict{String,Any}(
        "b-(33.34%)" => Any[Dict{String,Any}(
            "name" => "Buy Order XOM",
            "componentType" => "largeTask",
            "properties" => Dict{String,Any}("isInvalid" => false, "symbol" => "XOM"),
            "id" => "3b3ef931bcf1fbd5f103ce0c2d64a6cc",
            "type" => "stock",
        )],
        "a-(33.66%)" => Any[Dict{String,Any}(
            "name" => "Buy Order FNGU",
            "componentType" => "largeTask",
            "properties" => Dict{String,Any}("isInvalid" => false, "symbol" => "FNGU"),
            "id" => "96eb9c12ac2166ae40a8b52f160d4c96",
            "type" => "stock",
        )],
        "c-(33%)" => Any[Dict{String,Any}(
            "name" => "Buy Order FNGU",
            "componentType" => "largeTask",
            "properties" => Dict{String,Any}("isInvalid" => false, "symbol" => "FNGU"),
            "id" => "96eb9c12ac2166ae40a8b52f160d4c96",
            "type" => "stock",
        )],
    )
    for (branch_name::String, branch_weight::Float32) in node_properties_values
        branch_key, branch = find_matching_branch(node_branches, branch_name, branch_weight)
        test_branch_key::String = ""
        if isinteger(branch_weight)
            test_branch_key = "$branch_name-($(Int(branch_weight))%)"
        else
            test_branch_key = "$branch_name-($(branch_weight)%)"
        end
        @test branch_key == test_branch_key
        @test branch == node_branches[test_branch_key]
    end

    timing_data = @benchmark find_matching_branch($node_branches, "b", 33.34)
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_FIND_MATCHING_BRANCH)
    @test MIN_FIND_MATCHING_BRANCH - range <= min_time <= MIN_FIND_MATCHING_BRANCH + range
    println("Minimum time taken for find_matching_branch: ", min_time, " seconds")
end

@testset "adjust_return_curves tests" begin
    branch_return_curves = Vector{Float64}[
        [
            0.0,
            0.0,
            0.0007343941,
            -0.0004892368,
            0.00024473813,
            0.0011010522,
            -0.0006110229,
            -0.0020730374,
            0.000491763,
            0.00073728187,
            0.0009823183,
            -0.0015947007,
            -0.0009829217,
            0.0009838889,
            -0.004054552,
            0.0012336541,
            0.00061606703,
            -0.00036941262,
            -0.0006159152,
            0.0007395538,
            -0.0004926715,
            0.00024645717,
            0.0004927929,
            0.0008619628,
            -0.0003690945,
            -0.00073846156,
            0.00024633575,
            0.0004925502,
            -0.0012307692,
            0.0019915712,
            0.0014805675,
            0.0016015769,
            -0.00012300123,
            0.00012301636,
            -0.00024600246,
            0.00086122047,
            -0.0008604794,
            0.000246063,
            0.0009840098,
            0.0018432047,
            -0.00073592545,
            -0.00061372283,
            -0.00024563988,
            0.0004914005,
            -0.00073673873,
            -0.00049152126,
            0.00036882222,
            -0.0008602679,
            -0.00036900368,
            0.0011074197,
        ],
        [
            0.0,
            0.009735907,
            -0.001467266,
            -0.013714606,
            -0.0028614672,
            -0.00052175974,
            -0.0016847401,
            0.009150979,
            -0.0073721646,
            -0.002349089,
            -0.0061124987,
            0.01828276,
            -0.0021855612,
            0.0039803106,
            -0.007084545,
            0.011033407,
            -0.014091089,
            -0.0195781,
            0.0022725074,
            -0.0066090985,
            -0.018380925,
            -0.012739011,
            0.004610142,
            0.016485434,
            0.0036558136,
            -0.024495184,
            0.018243786,
            -0.010016736,
            -0.03211933,
            0.01440937,
            0.0073428876,
            0.022169717,
            0.01691831,
            -0.010156212,
            0.0029315483,
            0.0043357527,
            0.005869228,
            -0.0024593722,
            0.006864546,
            0.017452467,
            -0.004939964,
            -0.0018527756,
            0.012208181,
            0.0086989235,
            0.0034495618,
            -0.008176159,
            0.0074004685,
            0.0003719546,
            -0.00267243,
            -0.033786144,
        ],
        [
            0.0,
            -0.040857445,
            0.0053101475,
            -0.008300441,
            -0.0066725197,
            0.021212656,
            -0.010559114,
            -0.008455796,
            -0.006998765,
            0.0047974414,
            -0.0048924256,
            0.0045018364,
            -0.0066635218,
            0.007242505,
            -0.01113927,
            0.04327095,
            0.0086266,
            -0.021863494,
            -0.019167295,
            -0.008147361,
            -0.0057142857,
            -0.012212643,
            0.005090909,
            0.0063917027,
            0.012702217,
            0.0051473198,
            -0.0034728353,
            0.024808032,
            -0.018270893,
            -0.006047085,
            0.022031896,
            0.059816215,
            -0.009106773,
            0.0037972594,
            0.001864035,
            0.010014228,
            -0.006880858,
            0.017645452,
            0.006173502,
            0.012217895,
            0.00063251104,
            0.00015802782,
            0.0061621107,
            0.006857203,
            -0.0075383415,
            -0.021058146,
            0.016588185,
            5.263712f-5,
            0.0015790305,
            0.005255137,
        ],
        [
            0.0,
            0.011762492,
            0.03121343,
            0.007561858,
            -0.025694195,
            -0.024967318,
            0.0011745152,
            7.747133f-5,
            -0.01008156,
            -0.00545544,
            -0.034384694,
            0.024480531,
            -0.009942278,
            -0.020417064,
            0.019741314,
            0.04109652,
            -0.026816456,
            -0.024777176,
            0.01644167,
            -0.038666133,
            0.007568275,
            -0.10004606,
            0.043543305,
            0.03653261,
            -0.03331594,
            0.03708724,
            0.061755735,
            0.0002507551,
            -0.015440363,
            -0.038899563,
            0.03342927,
            0.034631833,
            0.037741162,
            -0.017212937,
            -0.0015681251,
            -0.018415697,
            0.012744092,
            0.005796747,
            0.0105864005,
            0.03583782,
            -0.0028637853,
            -0.019923907,
            0.024881324,
            0.006393754,
            -0.0045709014,
            0.09319642,
            0.02572279,
            0.069804356,
            0.008147426,
            -0.037666015,
        ],
    ]
    min_data_length = 50

    result = truncate_to_common_period(branch_return_curves, min_data_length)
    ans_result = Vector{Float64}[
        [
            0.0,
            0.0,
            0.0007343941,
            -0.0004892368,
            0.00024473813,
            0.0011010522,
            -0.0006110229,
            -0.0020730374,
            0.000491763,
            0.00073728187,
            0.0009823183,
            -0.0015947007,
            -0.0009829217,
            0.0009838889,
            -0.004054552,
            0.0012336541,
            0.00061606703,
            -0.00036941262,
            -0.0006159152,
            0.0007395538,
            -0.0004926715,
            0.00024645717,
            0.0004927929,
            0.0008619628,
            -0.0003690945,
            -0.00073846156,
            0.00024633575,
            0.0004925502,
            -0.0012307692,
            0.0019915712,
            0.0014805675,
            0.0016015769,
            -0.00012300123,
            0.00012301636,
            -0.00024600246,
            0.00086122047,
            -0.0008604794,
            0.000246063,
            0.0009840098,
            0.0018432047,
            -0.00073592545,
            -0.00061372283,
            -0.00024563988,
            0.0004914005,
            -0.00073673873,
            -0.00049152126,
            0.00036882222,
            -0.0008602679,
            -0.00036900368,
            0.0011074197,
        ],
        [
            0.0,
            0.009735907,
            -0.001467266,
            -0.013714606,
            -0.0028614672,
            -0.00052175974,
            -0.0016847401,
            0.009150979,
            -0.0073721646,
            -0.002349089,
            -0.0061124987,
            0.01828276,
            -0.0021855612,
            0.0039803106,
            -0.007084545,
            0.011033407,
            -0.014091089,
            -0.0195781,
            0.0022725074,
            -0.0066090985,
            -0.018380925,
            -0.012739011,
            0.004610142,
            0.016485434,
            0.0036558136,
            -0.024495184,
            0.018243786,
            -0.010016736,
            -0.03211933,
            0.01440937,
            0.0073428876,
            0.022169717,
            0.01691831,
            -0.010156212,
            0.0029315483,
            0.0043357527,
            0.005869228,
            -0.0024593722,
            0.006864546,
            0.017452467,
            -0.004939964,
            -0.0018527756,
            0.012208181,
            0.0086989235,
            0.0034495618,
            -0.008176159,
            0.0074004685,
            0.0003719546,
            -0.00267243,
            -0.033786144,
        ],
        [
            0.0,
            -0.040857445,
            0.0053101475,
            -0.008300441,
            -0.0066725197,
            0.021212656,
            -0.010559114,
            -0.008455796,
            -0.006998765,
            0.0047974414,
            -0.0048924256,
            0.0045018364,
            -0.0066635218,
            0.007242505,
            -0.01113927,
            0.04327095,
            0.0086266,
            -0.021863494,
            -0.019167295,
            -0.008147361,
            -0.0057142857,
            -0.012212643,
            0.005090909,
            0.0063917027,
            0.012702217,
            0.0051473198,
            -0.0034728353,
            0.024808032,
            -0.018270893,
            -0.006047085,
            0.022031896,
            0.059816215,
            -0.009106773,
            0.0037972594,
            0.001864035,
            0.010014228,
            -0.006880858,
            0.017645452,
            0.006173502,
            0.012217895,
            0.00063251104,
            0.00015802782,
            0.0061621107,
            0.006857203,
            -0.0075383415,
            -0.021058146,
            0.016588185,
            5.263712f-5,
            0.0015790305,
            0.005255137,
        ],
        [
            0.0,
            0.011762492,
            0.03121343,
            0.007561858,
            -0.025694195,
            -0.024967318,
            0.0011745152,
            7.747133f-5,
            -0.01008156,
            -0.00545544,
            -0.034384694,
            0.024480531,
            -0.009942278,
            -0.020417064,
            0.019741314,
            0.04109652,
            -0.026816456,
            -0.024777176,
            0.01644167,
            -0.038666133,
            0.007568275,
            -0.10004606,
            0.043543305,
            0.03653261,
            -0.03331594,
            0.03708724,
            0.061755735,
            0.0002507551,
            -0.015440363,
            -0.038899563,
            0.03342927,
            0.034631833,
            0.037741162,
            -0.017212937,
            -0.0015681251,
            -0.018415697,
            0.012744092,
            0.005796747,
            0.0105864005,
            0.03583782,
            -0.0028637853,
            -0.019923907,
            0.024881324,
            0.006393754,
            -0.0045709014,
            0.09319642,
            0.02572279,
            0.069804356,
            0.008147426,
            -0.037666015,
        ],
    ]

    @test result == ans_result

    timing_data = @benchmark truncate_to_common_period(
        $branch_return_curves, $min_data_length
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_TRUNCATE_TO_COMMON_PERIOD)
    @test MIN_TRUNCATE_TO_COMMON_PERIOD - range <=
        min_time <=
        MIN_TRUNCATE_TO_COMMON_PERIOD + range
    println("Minimum time taken for truncate_to_common_period: ", min_time, " seconds")
end

@testset "calculate_portfolio_values tests" begin
    branch_return_curves = Vector{Float64}[
        [
            0.0,
            0.0,
            0.0007343941,
            -0.0004892368,
            0.00024473813,
            0.0011010522,
            -0.0006110229,
            -0.0020730374,
            0.000491763,
            0.00073728187,
            0.0009823183,
            -0.0015947007,
            -0.0009829217,
            0.0009838889,
            -0.004054552,
            0.0012336541,
            0.00061606703,
            -0.00036941262,
            -0.0006159152,
            0.0007395538,
            -0.0004926715,
            0.00024645717,
            0.0004927929,
            0.0008619628,
            -0.0003690945,
            -0.00073846156,
            0.00024633575,
            0.0004925502,
            -0.0012307692,
            0.0019915712,
            0.0014805675,
            0.0016015769,
            -0.00012300123,
            0.00012301636,
            -0.00024600246,
            0.00086122047,
            -0.0008604794,
            0.000246063,
            0.0009840098,
            0.0018432047,
            -0.00073592545,
            -0.00061372283,
            -0.00024563988,
            0.0004914005,
            -0.00073673873,
            -0.00049152126,
            0.00036882222,
            -0.0008602679,
            -0.00036900368,
            0.0011074197,
        ],
        [
            0.0,
            0.009735907,
            -0.001467266,
            -0.013714606,
            -0.0028614672,
            -0.00052175974,
            -0.0016847401,
            0.009150979,
            -0.0073721646,
            -0.002349089,
            -0.0061124987,
            0.01828276,
            -0.0021855612,
            0.0039803106,
            -0.007084545,
            0.011033407,
            -0.014091089,
            -0.0195781,
            0.0022725074,
            -0.0066090985,
            -0.018380925,
            -0.012739011,
            0.004610142,
            0.016485434,
            0.0036558136,
            -0.024495184,
            0.018243786,
            -0.010016736,
            -0.03211933,
            0.01440937,
            0.0073428876,
            0.022169717,
            0.01691831,
            -0.010156212,
            0.0029315483,
            0.0043357527,
            0.005869228,
            -0.0024593722,
            0.006864546,
            0.017452467,
            -0.004939964,
            -0.0018527756,
            0.012208181,
            0.0086989235,
            0.0034495618,
            -0.008176159,
            0.0074004685,
            0.0003719546,
            -0.00267243,
            -0.033786144,
        ],
        [
            0.0,
            -0.040857445,
            0.0053101475,
            -0.008300441,
            -0.0066725197,
            0.021212656,
            -0.010559114,
            -0.008455796,
            -0.006998765,
            0.0047974414,
            -0.0048924256,
            0.0045018364,
            -0.0066635218,
            0.007242505,
            -0.01113927,
            0.04327095,
            0.0086266,
            -0.021863494,
            -0.019167295,
            -0.008147361,
            -0.0057142857,
            -0.012212643,
            0.005090909,
            0.0063917027,
            0.012702217,
            0.0051473198,
            -0.0034728353,
            0.024808032,
            -0.018270893,
            -0.006047085,
            0.022031896,
            0.059816215,
            -0.009106773,
            0.0037972594,
            0.001864035,
            0.010014228,
            -0.006880858,
            0.017645452,
            0.006173502,
            0.012217895,
            0.00063251104,
            0.00015802782,
            0.0061621107,
            0.006857203,
            -0.0075383415,
            -0.021058146,
            0.016588185,
            5.263712f-5,
            0.0015790305,
            0.005255137,
        ],
        [
            0.0,
            0.011762492,
            0.03121343,
            0.007561858,
            -0.025694195,
            -0.024967318,
            0.0011745152,
            7.747133f-5,
            -0.01008156,
            -0.00545544,
            -0.034384694,
            0.024480531,
            -0.009942278,
            -0.020417064,
            0.019741314,
            0.04109652,
            -0.026816456,
            -0.024777176,
            0.01644167,
            -0.038666133,
            0.007568275,
            -0.10004606,
            0.043543305,
            0.03653261,
            -0.03331594,
            0.03708724,
            0.061755735,
            0.0002507551,
            -0.015440363,
            -0.038899563,
            0.03342927,
            0.034631833,
            0.037741162,
            -0.017212937,
            -0.0015681251,
            -0.018415697,
            0.012744092,
            0.005796747,
            0.0105864005,
            0.03583782,
            -0.0028637853,
            -0.019923907,
            0.024881324,
            0.006393754,
            -0.0045709014,
            0.09319642,
            0.02572279,
            0.069804356,
            0.008147426,
            -0.037666015,
        ],
    ]
    min_data_length = 50

    result = calculate_portfolio_values(
        branch_return_curves, min_data_length, "TESTS", Dict{String,Float64}()
    )

    expected_result = [
        [
            10100.0,
            10100.0,
            10100.000734,
            10100.000245,
            10100.00049,
            10100.001591,
            10100.00098,
            10099.998907,
            10099.999399,
            10100.000136,
            10100.001118,
            10099.999524,
            10099.998541,
            10099.999525,
            10099.99547,
            10099.996704,
            10099.99732,
            10099.99695,
            10099.996334,
            10099.997074,
            10099.996581,
            10099.996828,
            10099.99732,
            10099.998182,
            10099.997813,
            10099.997075,
            10099.997321,
            10099.997814,
            10099.996583,
            10099.998575,
            10100.000055,
            10100.001657,
            10100.001534,
            10100.001657,
            10100.001411,
            10100.002272,
            10100.001411,
            10100.001658,
            10100.002642,
            10100.004485,
            10100.003749,
            10100.003135,
            10100.002889,
            10100.003381,
            10100.002644,
            10100.002153,
            10100.002521,
            10100.001661,
            10100.001292,
            10100.0024,
        ],
        [
            10100.0,
            10100.009736,
            10100.008269,
            10099.994554,
            10099.991693,
            10099.991171,
            10099.989486,
            10099.998637,
            10099.991265,
            10099.988916,
            10099.982803,
            10100.001086,
            10099.9989,
            10100.002881,
            10099.995796,
            10100.00683,
            10099.992739,
            10099.97316,
            10099.975433,
            10099.968824,
            10099.950443,
            10099.937704,
            10099.942314,
            10099.958799,
            10099.962455,
            10099.93796,
            10099.956204,
            10099.946187,
            10099.914068,
            10099.928477,
            10099.93582,
            10099.95799,
            10099.974908,
            10099.964752,
            10099.967683,
            10099.972019,
            10099.977888,
            10099.975429,
            10099.982293,
            10099.999746,
            10099.994806,
            10099.992953,
            10100.005161,
            10100.01386,
            10100.01731,
            10100.009134,
            10100.016534,
            10100.016906,
            10100.014234,
            10099.980447,
        ],
        [
            10100.0,
            10099.959143,
            10099.964453,
            10099.956152,
            10099.94948,
            10099.970692,
            10099.960133,
            10099.951677,
            10099.944679,
            10099.949476,
            10099.944584,
            10099.949086,
            10099.942422,
            10099.949665,
            10099.938525,
            10099.981796,
            10099.990423,
            10099.968559,
            10099.949392,
            10099.941245,
            10099.93553,
            10099.923318,
            10099.928409,
            10099.9348,
            10099.947502,
            10099.95265,
            10099.949177,
            10099.973985,
            10099.955714,
            10099.949667,
            10099.971699,
            10100.031515,
            10100.022408,
            10100.026205,
            10100.028069,
            10100.038083,
            10100.031203,
            10100.048848,
            10100.055022,
            10100.06724,
            10100.067872,
            10100.06803,
            10100.074192,
            10100.08105,
            10100.073511,
            10100.052453,
            10100.069041,
            10100.069094,
            10100.070673,
            10100.075928,
        ],
        [
            10100.0,
            10100.011762,
            10100.042976,
            10100.050538,
            10100.024844,
            10099.999876,
            10100.001051,
            10100.001128,
            10099.991047,
            10099.985591,
            10099.951206,
            10099.975687,
            10099.965745,
            10099.945328,
            10099.965069,
            10100.006165,
            10099.979349,
            10099.954572,
            10099.971013,
            10099.932347,
            10099.939915,
            10099.83987,
            10099.883413,
            10099.919945,
            10099.886629,
            10099.923716,
            10099.985471,
            10099.985722,
            10099.970282,
            10099.931382,
            10099.964811,
            10099.999443,
            10100.037184,
            10100.019971,
            10100.018403,
            10099.999987,
            10100.012731,
            10100.018528,
            10100.029114,
            10100.064952,
            10100.062089,
            10100.042165,
            10100.067046,
            10100.07344,
            10100.068869,
            10100.162066,
            10100.187789,
            10100.257595,
            10100.265742,
            10100.228075,
        ],
    ]

    @test result == expected_result

    timing_data = @benchmark calculate_portfolio_values(
        $branch_return_curves, $min_data_length, "TESTS", Dict{String,Float64}()
    )
    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_CALCULATE_PORTFOLIO_VALUES)
    @test MIN_CALCULATE_PORTFOLIO_VALUES - range <=
        min_time <=
        MIN_CALCULATE_PORTFOLIO_VALUES + range
    println("Minimum time taken for calculate_portfolio_values: ", min_time, " seconds")
end

@testset "apply_sort_function tests" begin
    @testset "cumulative return test" begin
        branch_return_curves = Vector{Float64}[
            [
                100.0,
                100.0016,
                100.0014,
                100.0015,
                100.0012,
                100.0021,
                100.0011,
                100.0013,
                100.0023,
                100.0041,
                100.0033,
                100.0026,
                100.0023,
                100.0028,
                100.002,
                100.0014,
                100.0018,
                100.0008,
                100.0003,
                100.0014,
            ],
            [
                100.0,
                99.9806,
                99.9695,
                99.9696,
                99.9702,
                99.9689,
                99.9669,
                99.9651,
                99.9585,
                99.9437,
                99.9459,
                99.9467,
                99.94,
                99.9384,
                99.9385,
                99.9437,
                99.9347,
                99.9312,
                99.9381,
                99.9489,
            ],
            [
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
            ],
        ]
        sort_function = "Cumulative Return"
        sort_window = 10

        result = apply_sort_function(branch_return_curves, sort_function, sort_window)
        ans_result = Vector{Float64}[
            [
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                0.0033035278,
                0.0009994346,
                0.00089262665,
                0.0012969775,
                0.0008010768,
                -0.00069426035,
                0.00070189656,
                -0.00049590424,
                -0.0019988555,
                -0.002693066,
            ],
            [
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                -0.05410004,
                -0.03390398,
                -0.029504238,
                -0.031206083,
                -0.031709585,
                -0.02520773,
                -0.032214336,
                -0.033916865,
                -0.02040947,
                0.0051985444,
            ],
            [
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
            ],
        ]
        for i in eachindex(result)
            for j in eachindex(result[i])
                if !isnan(result[i][j]) && !isnan(ans_result[i][j])
                    @test isapprox(result[i][j], ans_result[i][j], atol=0.1)
                else
                    @test isnan(result[i][j]) == isnan(ans_result[i][j])
                end
            end
        end

        timing_data = @benchmark apply_sort_function(
            $branch_return_curves, $sort_function, $sort_window
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_APPLY_SORT_FUNCTION_CUMULATIVE_RETURN)
        @test MIN_APPLY_SORT_FUNCTION_CUMULATIVE_RETURN - range <=
            min_time <=
            MIN_APPLY_SORT_FUNCTION_CUMULATIVE_RETURN + range
        println(
            "Minimum time taken for apply_sort_function with cumulative return: ",
            min_time,
            " seconds",
        )
    end

    @testset "relative strength index test" begin
        branch_return_curves = Vector{Float64}[
            [
                100.0,
                100.0016,
                100.0014,
                100.0015,
                100.0012,
                100.0021,
                100.0011,
                100.0013,
                100.0023,
                100.0041,
                100.0033,
                100.0026,
                100.0023,
                100.0028,
                100.002,
                100.0014,
                100.0018,
                100.0008,
                100.0003,
                100.0014,
            ],
            [
                100.0,
                99.9806,
                99.9695,
                99.9696,
                99.9702,
                99.9689,
                99.9669,
                99.9651,
                99.9585,
                99.9437,
                99.9459,
                99.9467,
                99.94,
                99.9384,
                99.9385,
                99.9437,
                99.9347,
                99.9312,
                99.9381,
                99.9489,
            ],
            [
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
                100.0,
            ],
        ]
        sort_function = "Relative Strength Index"
        sort_window = 10
        result = apply_sort_function(branch_return_curves, sort_function, sort_window)
        ans_result = Vector{Float64}[
            [
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                70.91788,
                64.543236,
                61.85715,
                64.56105,
                57.37187,
                52.542576,
                55.32797,
                47.520836,
                44.041924,
                52.525867,
            ],
            [
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                4.840148,
                6.233527,
                5.487049,
                5.3178105,
                5.518253,
                15.896699,
                13.125038,
                12.205289,
                23.889673,
                38.182396,
            ],
            [
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
                NaN,
            ],
        ]

        for i in eachindex(result)
            for j in eachindex(result[i])
                if !isnan(result[i][j]) && !isnan(ans_result[i][j])
                    @test isapprox(result[i][j], ans_result[i][j], atol=0.1)
                else
                    @test isnan(result[i][j]) == isnan(ans_result[i][j])
                end
            end
        end

        timing_data = @benchmark apply_sort_function(
            $branch_return_curves, $sort_function, $sort_window
        )
        min_time = minimum(timing_data).time * 1e-9
        range = get_range(MIN_APPLY_SORT_FUNCTION_RSI)
        @test MIN_APPLY_SORT_FUNCTION_RSI - range <=
            min_time <=
            MIN_APPLY_SORT_FUNCTION_RSI + range
        println(
            "Minimum time taken for apply_sort_function with rsi: ", min_time, " seconds"
        )
    end
end
