include("CheckFilesTypes&Error.jl")
using Base.Filesystem: walkdir, joinpath, isfile

# Temporary use
function get_julia_files_in_directory(directory)
    println("Debug: Getting .jl files in directory: ", directory)
    files = readdir(directory)
    julia_files = [
        joinpath(directory, file) for
        file in files if endswith(file, ".jl") && isfile(joinpath(directory, file))
    ]
    println("Debug: .jl files found: ", julia_files)
    return julia_files
end

# Cannot use until all errors have been resolved
function get_all_julia_files(base_directory)
    println("Debug: Walking through directory: ", base_directory)
    all_julia_files = String[]
    for (root, dirs, files) in walkdir(base_directory)
        julia_files = [
            joinpath(root, file) for
            file in files if endswith(file, ".jl") && isfile(joinpath(root, file))
        ]
        append!(all_julia_files, julia_files)
    end
    println("Debug: All .jl files found: ", all_julia_files)
    return all_julia_files
end

# Get the current directory
directory = pwd()
println("Debug: Current directory: ", directory)

julia_files = get_julia_files_in_directory(directory)

if !check_files(julia_files)
    println("Pre-push check failed.")
    exit(1)
else
    println("Pre-push check passed.")
end
