include("./../../Main.jl")
include("./../../NodeProcessors/CloudNode.jl")
include("./../BenchmarkTimes.jl")

using Dates, DataFrames, Test, HTTP, JSON, BenchmarkTools
# using PyCall
using .VectoriseBacktestService
using ..VectoriseBacktestService.Types
using ..CloudNode

# For testing password protected server, comment all the test cases except last two ones
# Go to App/Extras and run the python script rest_api.py

@testset "get_json_from_server Tests" begin
    # Test Case 1: Successful JSON retrieval
    @testset "Successful JSON Retrieval" begin
        response = get_json_from_server(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/correct_file.json",
            "fsdev87",
            "1234",
        )
        @test isa(response, HTTP.Response)
        @test response.status == 200
        data::Dict{String,Any} = JSON.parse(String(response.body))
        @test data == Dict{String,Any}(
            "NVDA" => 40.0, "SPY" => 20.0, "AAPL" => 10.0, "TSLA" => 30.0
        )
    end

    # Test Case 2: Invalid URL
    @testset "Invalid URL" begin
        response = get_json_from_server(
            "https://raw.githubusercontentt.com/fsdev87/Frontend/refs/heads/main/temp.json",
            "fsdev87",
            "1234",
        )  # Misspelled githubusercontent
        @test response === nothing
    end

    # Test Case 3: Server Unreachable
    @testset "Server Unreachable" begin
        response = get_json_from_server("http://localhost:12345/", "fsdev87", "1234")  # Port 12345 likely unused
        @test response === nothing
    end

    # Test Case 4: Timeout Handling
    @testset "Timeout Handling" begin
        response = get_json_from_server("http://example.com/timeout", "fsdev87", "1234")  # Simulate a timeout
        @test response === nothing
    end

    # Test Case 5: Empty Response
    @testset "Empty JSON Response/Input" begin
        response = get_json_from_server(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/empty.json",
            "fsdev87",
            "1234",
        )  # Simulate an empty response
        @test response !== nothing
        @test response.status == 200 # At least successfully has gotten a response
        @test_throws ErrorException read_json(response)
    end
end

@testset "read_json Tests" begin
    # Helper function to create mock HTTP.response

    @testset "Valid JSON structure with proper weights" begin
        json_obj = HTTP.get(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/correct_file.json",
        )
        parsed_data = read_json(json_obj)
        @test parsed_data ==
            Dict("NVDA" => 40.0, "SPY" => 20.0, "TSLA" => 30.0, "AAPL" => 10.0)
    end

    @testset "Invalid JSON structure (nested dictionary)" begin
        json_obj = HTTP.get(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/nested.json"
        )
        @test_throws r"ServerError" read_json(json_obj)
    end

    @testset "Invalid value type (string instead of number)" begin
        json_obj = HTTP.get(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/str_weight.json",
        )
        @test_throws r"ServerError" read_json(json_obj)
    end

    @testset "More than 20 keys in JSON" begin
        json_obj = HTTP.get(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/>20_keys.json",
        )
        @test_throws r"ServerError" read_json(json_obj)
    end

    @testset "Total weights do not sum to 100" begin
        json_obj = HTTP.get(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/incorrect_weightage.json",
        )
        @test_throws r"ServerError" read_json(json_obj)
    end

    @testset "Duplicate keys with aggregation" begin
        json_obj = HTTP.get(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/duplicates.json",
        )
        parsed_data = read_json(json_obj)
        @test parsed_data == Dict("NVDA" => 40.0, "SPY" => 60.0)
    end

    @testset "Keys with lowercase letters converted to uppercase" begin
        json_obj = HTTP.get(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/lower_to_upper.json",
        )
        parsed_data = read_json(json_obj)
        @test parsed_data == Dict("NVDA" => 50.0, "SPY" => 50.0)
    end

    @testset "Invalid JSON syntax (trailing comma)" begin
        json_obj = HTTP.get(
            "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/invalid_syntax.json",
        )
        @test_throws ErrorException read_json(json_obj)
    end
end

@testset "Cloud Node Test" begin
    cloud_node::Dict{String,Any} = Dict{String,Any}(
        "id" => "48bcea4dacfe70516eb32b6cd306c32c",
        "componentType" => "task",
        "type" => "CloudNode",
        "name" => "Cloud Node",
        "properties" => Dict{String,Any}(
            "isInvalid" => false,
            "isPasswordProtected" => false,
            "url" => "https://raw.githubusercontent.com/fsdev87/Frontend/refs/heads/main/correct_file.json",
            "credentials" =>
                Dict{String,Any}("username" => "fsdev87", "password" => "1234"),
        ),
        "parentHash" => "b4b147bc522828731f1a016bfa72c073",
    )

    active_branch_mask::BitVector = BitVector(trues(200))
    total_days::Int = 200
    node_weight::Float32 = 1.0f0 # take the node weight from parent as 100
    portfolio_history::Vector{DayData} = [DayData() for _ in 1:200]
    date_range::Vector{String} = [
        "2023-08-15",
        "2023-08-16",
        "2023-08-17",
        "2023-08-18",
        "2023-08-21",
        "2023-08-22",
        "2023-08-23",
        "2023-08-24",
        "2023-08-25",
        "2023-08-28",
        "2023-08-29",
        "2023-08-30",
        "2023-08-31",
        "2023-09-01",
        "2023-09-05",
        "2023-09-06",
        "2023-09-07",
        "2023-09-08",
        "2023-09-11",
        "2023-09-12",
        "2023-09-13",
        "2023-09-14",
        "2023-09-15",
        "2023-09-18",
        "2023-09-19",
        "2023-09-20",
        "2023-09-21",
        "2023-09-22",
        "2023-09-25",
        "2023-09-26",
        "2023-09-27",
        "2023-09-28",
        "2023-09-29",
        "2023-10-02",
        "2023-10-03",
        "2023-10-04",
        "2023-10-05",
        "2023-10-06",
        "2023-10-09",
        "2023-10-10",
        "2023-10-11",
        "2023-10-12",
        "2023-10-13",
        "2023-10-16",
        "2023-10-17",
        "2023-10-18",
        "2023-10-19",
        "2023-10-20",
        "2023-10-23",
        "2023-10-24",
        "2023-10-25",
        "2023-10-26",
        "2023-10-27",
        "2023-10-30",
        "2023-10-31",
        "2023-11-01",
        "2023-11-02",
        "2023-11-03",
        "2023-11-06",
        "2023-11-07",
        "2023-11-08",
        "2023-11-09",
        "2023-11-10",
        "2023-11-13",
        "2023-11-14",
        "2023-11-15",
        "2023-11-16",
        "2023-11-17",
        "2023-11-20",
        "2023-11-21",
        "2023-11-22",
        "2023-11-24",
        "2023-11-27",
        "2023-11-28",
        "2023-11-29",
        "2023-11-30",
        "2023-12-01",
        "2023-12-04",
        "2023-12-05",
        "2023-12-06",
        "2023-12-07",
        "2023-12-08",
        "2023-12-11",
        "2023-12-12",
        "2023-12-13",
        "2023-12-14",
        "2023-12-15",
        "2023-12-18",
        "2023-12-19",
        "2023-12-20",
        "2023-12-21",
        "2023-12-22",
        "2023-12-26",
        "2023-12-27",
        "2023-12-28",
        "2023-12-29",
        "2024-01-02",
        "2024-01-03",
        "2024-01-04",
        "2024-01-05",
        "2024-01-08",
        "2024-01-09",
        "2024-01-10",
        "2024-01-11",
        "2024-01-12",
        "2024-01-16",
        "2024-01-17",
        "2024-01-18",
        "2024-01-19",
        "2024-01-22",
        "2024-01-23",
        "2024-01-24",
        "2024-01-25",
        "2024-01-26",
        "2024-01-29",
        "2024-01-30",
        "2024-01-31",
        "2024-02-01",
        "2024-02-02",
        "2024-02-05",
        "2024-02-06",
        "2024-02-07",
        "2024-02-08",
        "2024-02-09",
        "2024-02-12",
        "2024-02-13",
        "2024-02-14",
        "2024-02-15",
        "2024-02-16",
        "2024-02-20",
        "2024-02-21",
        "2024-02-22",
        "2024-02-23",
        "2024-02-26",
        "2024-02-27",
        "2024-02-28",
        "2024-02-29",
        "2024-03-01",
        "2024-03-04",
        "2024-03-05",
        "2024-03-06",
        "2024-03-07",
        "2024-03-08",
        "2024-03-11",
        "2024-03-12",
        "2024-03-13",
        "2024-03-14",
        "2024-03-15",
        "2024-03-18",
        "2024-03-19",
        "2024-03-20",
        "2024-03-21",
        "2024-03-22",
        "2024-03-25",
        "2024-03-26",
        "2024-03-27",
        "2024-03-28",
        "2024-04-01",
        "2024-04-02",
        "2024-04-03",
        "2024-04-04",
        "2024-04-05",
        "2024-04-08",
        "2024-04-09",
        "2024-04-10",
        "2024-04-11",
        "2024-04-12",
        "2024-04-15",
        "2024-04-16",
        "2024-04-17",
        "2024-04-18",
        "2024-04-19",
        "2024-04-22",
        "2024-04-23",
        "2024-04-24",
        "2024-04-25",
        "2024-04-26",
        "2024-04-29",
        "2024-04-30",
        "2024-05-01",
        "2024-05-02",
        "2024-05-03",
        "2024-05-06",
        "2024-05-07",
        "2024-05-08",
        "2024-05-09",
        "2024-05-10",
        "2024-05-13",
        "2024-05-14",
        "2024-05-15",
        "2024-05-16",
        "2024-05-17",
        "2024-05-20",
        "2024-05-21",
        "2024-05-22",
        "2024-05-23",
        "2024-05-24",
        "2024-05-28",
        "2024-05-29",
        "2024-05-30",
    ]
    end_date::Date = Date("2024-05-30")
    price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()

    result::Int = process_cloud_node(
        cloud_node,
        active_branch_mask,
        total_days,
        node_weight,
        portfolio_history,
        date_range,
        end_date,
        price_cache,
    )

    @test result == 200

    timing_data = @benchmark process_cloud_node(
        $cloud_node,
        $active_branch_mask,
        $total_days,
        $node_weight,
        $portfolio_history,
        $date_range,
        $end_date,
        $price_cache,
    )

    min_time = minimum(timing_data).time * 1e-9
    range = get_range(MIN_CLOUD_NODE)
    @test MIN_CLOUD_NODE - range <= min_time <= MIN_CLOUD_NODE + range
    println("Minimum time taken for Cloud Node: ", min_time, " seconds")
    # println("Profile History")
    # for day in portfolio_history
    #     println(day)
    # end
end

@testset "Cloud Node Error Test (Missing URL)" begin
    cloud_node::Dict{String,Any} = Dict{String,Any}(
        "id" => "48bcea4dacfe70516eb32b6cd306c32c",
        "componentType" => "task",
        "type" => "CloudNode",
        "name" => "Cloud Node",
        "properties" => Dict{String,Any}(
            "isInvalid" => false,
            "credentials" =>
                Dict{String,Any}("username" => "fsdev87", "password" => "1234"),
        ),
        "parentHash" => "b4b147bc522828731f1a016bfa72c073",
    )

    active_branch_mask::BitVector = BitVector(trues(200))
    total_days::Int = 200
    node_weight::Float32 = 1.0f0 # take the node weight from parent as 100
    portfolio_history::Vector{DayData} = [DayData() for _ in 1:200]
    date_range::Vector{String} = [
        "2023-08-15",
        "2023-08-16",
        "2023-08-17",
        "2023-08-18",
        "2023-08-21",
        "2023-08-22",
        "2023-08-23",
        "2023-08-24",
        "2023-08-25",
        "2023-08-28",
        "2023-08-29",
        "2023-08-30",
        "2023-08-31",
        "2023-09-01",
        "2023-09-05",
        "2023-09-06",
        "2023-09-07",
        "2023-09-08",
        "2023-09-11",
        "2023-09-12",
        "2023-09-13",
        "2023-09-14",
        "2023-09-15",
        "2023-09-18",
        "2023-09-19",
        "2023-09-20",
        "2023-09-21",
        "2023-09-22",
        "2023-09-25",
        "2023-09-26",
        "2023-09-27",
        "2023-09-28",
        "2023-09-29",
        "2023-10-02",
        "2023-10-03",
        "2023-10-04",
        "2023-10-05",
        "2023-10-06",
        "2023-10-09",
        "2023-10-10",
        "2023-10-11",
        "2023-10-12",
        "2023-10-13",
        "2023-10-16",
        "2023-10-17",
        "2023-10-18",
        "2023-10-19",
        "2023-10-20",
        "2023-10-23",
        "2023-10-24",
        "2023-10-25",
        "2023-10-26",
        "2023-10-27",
        "2023-10-30",
        "2023-10-31",
        "2023-11-01",
        "2023-11-02",
        "2023-11-03",
        "2023-11-06",
        "2023-11-07",
        "2023-11-08",
        "2023-11-09",
        "2023-11-10",
        "2023-11-13",
        "2023-11-14",
        "2023-11-15",
        "2023-11-16",
        "2023-11-17",
        "2023-11-20",
        "2023-11-21",
        "2023-11-22",
        "2023-11-24",
        "2023-11-27",
        "2023-11-28",
        "2023-11-29",
        "2023-11-30",
        "2023-12-01",
        "2023-12-04",
        "2023-12-05",
        "2023-12-06",
        "2023-12-07",
        "2023-12-08",
        "2023-12-11",
        "2023-12-12",
        "2023-12-13",
        "2023-12-14",
        "2023-12-15",
        "2023-12-18",
        "2023-12-19",
        "2023-12-20",
        "2023-12-21",
        "2023-12-22",
        "2023-12-26",
        "2023-12-27",
        "2023-12-28",
        "2023-12-29",
        "2024-01-02",
        "2024-01-03",
        "2024-01-04",
        "2024-01-05",
        "2024-01-08",
        "2024-01-09",
        "2024-01-10",
        "2024-01-11",
        "2024-01-12",
        "2024-01-16",
        "2024-01-17",
        "2024-01-18",
        "2024-01-19",
        "2024-01-22",
        "2024-01-23",
        "2024-01-24",
        "2024-01-25",
        "2024-01-26",
        "2024-01-29",
        "2024-01-30",
        "2024-01-31",
        "2024-02-01",
        "2024-02-02",
        "2024-02-05",
        "2024-02-06",
        "2024-02-07",
        "2024-02-08",
        "2024-02-09",
        "2024-02-12",
        "2024-02-13",
        "2024-02-14",
        "2024-02-15",
        "2024-02-16",
        "2024-02-20",
        "2024-02-21",
        "2024-02-22",
        "2024-02-23",
        "2024-02-26",
        "2024-02-27",
        "2024-02-28",
        "2024-02-29",
        "2024-03-01",
        "2024-03-04",
        "2024-03-05",
        "2024-03-06",
        "2024-03-07",
        "2024-03-08",
        "2024-03-11",
        "2024-03-12",
        "2024-03-13",
        "2024-03-14",
        "2024-03-15",
        "2024-03-18",
        "2024-03-19",
        "2024-03-20",
        "2024-03-21",
        "2024-03-22",
        "2024-03-25",
        "2024-03-26",
        "2024-03-27",
        "2024-03-28",
        "2024-04-01",
        "2024-04-02",
        "2024-04-03",
        "2024-04-04",
        "2024-04-05",
        "2024-04-08",
        "2024-04-09",
        "2024-04-10",
        "2024-04-11",
        "2024-04-12",
        "2024-04-15",
        "2024-04-16",
        "2024-04-17",
        "2024-04-18",
        "2024-04-19",
        "2024-04-22",
        "2024-04-23",
        "2024-04-24",
        "2024-04-25",
        "2024-04-26",
        "2024-04-29",
        "2024-04-30",
        "2024-05-01",
        "2024-05-02",
        "2024-05-03",
        "2024-05-06",
        "2024-05-07",
        "2024-05-08",
        "2024-05-09",
        "2024-05-10",
        "2024-05-13",
        "2024-05-14",
        "2024-05-15",
        "2024-05-16",
        "2024-05-17",
        "2024-05-20",
        "2024-05-21",
        "2024-05-22",
        "2024-05-23",
        "2024-05-24",
        "2024-05-28",
        "2024-05-29",
        "2024-05-30",
    ]
    end_date::Date = Date("2024-05-30")
    price_cache::Dict{String,DataFrame} = Dict{String,DataFrame}()

    @test_throws r"ServerError" process_cloud_node(
        cloud_node,
        active_branch_mask,
        total_days,
        node_weight,
        portfolio_history,
        date_range,
        end_date,
        price_cache,
    )
end

# # Test Case: Authentication Test Success
# @testset "Authentication Test Correct Credentials" begin
#     response = get_json_from_server("http://localhost:8080/", "fsdev87", "1234")
#     @test response.status == 200
#     @test isa(response, HTTP.Response)
#     data::Dict{String, Any} = JSON.parse(String(response.body))
#     @test data == Dict{String, Any}("NVDA" => 40.0, "SPY" => 20.0, "AAPL" => 10.0, "TSLA" => 30.0)
# end

# # Test Case: Authentication Test Fail
# @testset "Authentication Test Incorrect Credentials" begin
#     response = get_json_from_server("http://localhost:8080/", "user", "123")
#     @test response === nothing
# end
