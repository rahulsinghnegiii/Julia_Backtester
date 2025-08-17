using HTTP
using JSON3
using UUIDs
using Dates
using Test

# Helper Functions
function generate_hash()
    return string(uuid4())
end

function make_request(json_file::String)
    url = "http://localhost:5004/backtest"
    headers = Dict("Content-Type" => "application/json")

    try
        # Read JSON file
        json_data = open(json_file) do f
            read(f, String)
        end

        # Prepare payload
        payload = Dict(
            "json" => json_data,
            "period" => "5000",
            "hash" => generate_hash(),
            "end_date" => "2024-12-10",
            "live_execution" => true,
        )

        start_time = time()
        response = HTTP.post(url, headers, JSON3.write(payload))
        duration = time() - start_time

        # Convert JSON3 object to Dict
        body_dict = Dict(pairs(JSON3.read(String(response.body))))

        return (status=response.status, body=body_dict, duration=duration)
    catch e
        if isa(e, HTTP.ExceptionRequest.StatusError)
            return (status=e.status, body=nothing, duration=0.0, error=e)
        else
            return (status=500, body=nothing, duration=0.0, error=e)
        end
    end
end

function validate_response_structure(response_body)
    # Check if response is a dictionary
    if !(response_body isa Dict)
        return false, "Response is not a dictionary"
    end

    # Check if all values are numbers
    for (ticker, value) in response_body
        if !(value isa Number)
            return false, "Value for ticker $ticker is not a number"
        end
    end

    return true, "Valid response structure"
end

function compare_responses(responses)
    @testset "API Response Tests" begin
        for (i, response) in enumerate(responses)
            # Test status code
            @test response.status == 200

            # Test response structure
            valid, message = validate_response_structure(response.body)
            @test valid

            # Print response for verification
            println("\nResponse $i:")
            println("Status: $(response.status)")
            println("Body: ", JSON3.write(response.body))
            println("-"^30)
        end
    end
end

# Main execution
function run_tests()
    println("Starting API Tests")

    # Test files
    json_files = [
        "../Tests/TestsJSON/DevJSON/test1.json",
        # "../Tests/TestsJSON/DevJSON/qacthueK3AdDSjjmoKSh.json",
        "./livefail.json",
    ]

    # Make requests
    responses = []
    for (i, file) in enumerate(json_files)
        println("Making request $i with file: $file")
        response = make_request(file)
        push!(responses, response)

        println("Status: $(response.status)")
        println("Duration: $(round(response.duration, digits=2)) seconds")
        println("-"^50)
    end

    # Compare responses
    return compare_responses(responses)
end

# Run the tests
run_tests()
