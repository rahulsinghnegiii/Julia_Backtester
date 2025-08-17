using JSON
include("../Main.jl")
using ..VectoriseBacktestService.Types

if length(ARGS) < 2
    println(
        "Usage: julia truncate.jl <global_cache_json_file> <n> | Truncate the last n elements of global cache file and portfolio value cache",
    )
    exit(1)
end

function truncate(filename::String, n::Int)
    json = JSON.parse(read(filename, String))

    # Extract and truncate data
    n -= 1
    dates::Vector{String}, returns::Vector{Float32}, temp_portfolio = map(
        x -> json[x][(end - n):end], ["dates", "returns", "profile_history"]
    )

    # Reconstruct portfolio data
    portfolio = [DayData() for _ in 1:length(temp_portfolio)]
    for (i, day) in enumerate(temp_portfolio)
        stocks = [
            StockInfo(stock["ticker"], stock["weightTomorrow"]) for
            stock in day["stockList"]
        ]
        portfolio[i] = DayData(stocks)
    end

    # Update remaining keys and days count
    days = json["days"][1]
    n += 1
    keys::Vector{String} = ["dates", "returns", "profile_history"]
    for key in keys
        json[key] = json[key][1:(end - n)]
    end
    json["days"] = [days - n]
    write(filename, JSON.json(json))

    return (dates, returns, portfolio, days)
end

function trim_json_files(folder::String, n::Int)
    for file in readdir(folder)
        file_path = joinpath(folder, file)

        if endswith(file, ".json")
            try
                data = JSON.parsefile(file_path)

                if isa(data, Dict)
                    for key in keys(data)
                        if isa(data[key], Vector)
                            data[key] = data[key][1:max(0, end - n)]
                        end
                    end
                    open(file_path, "w") do io
                        JSON.print(io, data, 2)
                    end
                else
                    println("Skipping (not a dictionary): $file_path")
                end
            catch e
                println("Error processing $file_path: ", e)
            end
        end
    end
end

trim_json_files("PortfolioValueCache/", parse(Int, ARGS[2]))
truncate(ARGS[1], parse(Int, ARGS[2]))
