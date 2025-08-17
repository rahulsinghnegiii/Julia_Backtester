using JET
using Base.Filesystem

function get_project_root()
    try
        # Start from the current directory and move up until we find a directory containing "Project.toml"
        current_dir = pwd()
        while !isfile(joinpath(current_dir, "Project.toml"))
            parent_dir = dirname(current_dir)
            if parent_dir == current_dir  # We've reached the root directory
                error("error: Could not find project root (no Project.toml found)")
            end
            current_dir = parent_dir
        end
        return current_dir
    catch e
        if hasproperty(e, :msg)
            throw(error("Error in get_project_root: " * e.msg))
        else
            throw(error("Error in get_project_root"))
        end
    end
end

# Check files using JET.jl
function check_files(files)
    println("Debug: Starting check_files function")
    println("Debug: Files to check: ", files)
    for file in files
        println("Debug: Checking file: ", file)
        if (
            occursin(".jl", file) &&
            !occursin("_test.jl", file) &&
            !occursin("_unused.jl", file) &&
            !occursin("ErrorHandlers.jl", file) &&
            !occursin("Utilis.jl", file)
        )
            project_root = "."
            if !isdir("./App")
                project_root = get_project_root()
            end
            println("Debug: File matched: ", file)
            # Construct the command to run in the Julia REPL using raw string literals
            cmd = `julia --project=$project_root -e "using JET; println(report_file(raw\"$file\"; analyze_from_definitions = true, target_defined_modules = true))"`
            println("Debug: Command to run: ", cmd)
            try
                # Run the command and capture the output
                output = read(cmd, String)
                println("Debug: Output from report_file: ", output)
                if (occursin("error found", output) || occursin("errors found", output))
                    println("Error in file $file")
                    return false
                end
            catch e
                println("Debug: Error running command: ", e)
                return false
            end
        end
    end
    println("Debug: All files checked successfully")
    return true
end
