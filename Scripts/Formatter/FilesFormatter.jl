using JuliaFormatter

# Counter for formatted files
formatted_count = 0

# Function to format a single file
function format_single_file(file_path)
    global formatted_count
    if endswith(file_path, ".jl")
        println("Formatting: $file_path")
        normalized_path = replace(file_path, '\\' => Base.Filesystem.path_separator)
        if occursin(
            "LargeExpectedResponse" *
            Base.Filesystem.path_separator *
            "LargeStrategyData.jl",
            normalized_path,
        )
            return nothing
        end
        format_file(file_path)
        formatted_count += 1
    end
end

# Recursive function to format files in a directory and its subdirectories
function format_directory(dir_path)
    for (root, _, files) in walkdir(dir_path)
        for file in files
            format_single_file(joinpath(root, file))
        end
    end
end

# Start formatting from the current directory
current_dir = pwd()
println("Starting to format Julia files in $current_dir and its subdirectories...")
format_directory(current_dir)

println("Formatting complete! Formatted $formatted_count file(s).")
