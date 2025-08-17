using JSON

strategy = JSON.parse(read("qac-min.json", String))
strategy_folder = "qac"

function sanitize_filename(name::String)
    return (x -> replace(x, " " => "_"))(replace(name, r"[^\w\s-]" => ""))
end

function tickers_traverse(node, tickers)
    if node["type"] === "stock"
        push!(tickers, node["properties"]["symbol"])
    end

    if haskey(node, "sequence") && isa(node["sequence"], Vector)
        for child in node["sequence"]
            tickers_traverse(child, tickers)
        end
    end

    if haskey(node, "branches") && isa(node["branches"], Dict)
        for branch in values(node["branches"])
            if isa(branch, Vector)
                for child in branch
                    tickers_traverse(child, tickers)
                end
            end
        end
    end
end

function extract_tickers(node)
    tickers = Set{String}()
    tickers_traverse(node, tickers)
    return tickers
end

function traverse_and_save_folders(node)
    if haskey(node, "type") && node["type"] == "folder"
        folder_name = sanitize_filename(node["name"])
        folder_data = Dict(
            "tickers" => extract_tickers(node), "indicators" => [], "sequence" => [node]
        )
        !isdir("$strategy_folder") && mkdir("$strategy_folder")
        open("$strategy_folder/$folder_name.json", "w") do io
            JSON.print(io, folder_data)
        end
    end

    if haskey(node, "sequence") && isa(node["sequence"], Vector)
        for child in node["sequence"]
            traverse_and_save_folders(child)
        end
    end

    if haskey(node, "branches") && isa(node["branches"], Dict)
        for branch in values(node["branches"])
            if isa(branch, Vector)
                for child in branch
                    traverse_and_save_folders(child)
                end
            end
        end
    end
end

traverse_and_save_folders(strategy)
