include("CheckFilesTypes&Error.jl")
using Pkg

function check_files(files)
    println("Debug: Starting check_files function")
    println("Debug: Files to check: ", files)

    for file in files
        println("Debug: Checking file: ", file)
        if (
            occursin(".jl", file) &&
            !occursin("_test.jl", file) &&
            !occursin("_unused.jl", file) &&
            !occursin("ErrorHandlers.jl", file)
        )
            println("Debug: File matched: ", file)
            # Construct the command to run in the Julia REPL
            cmd = `julia -e "using JET; println(report_file(\"$file\"; analyze_from_definitions = true, target_defined_modules = true))"`
            println("Debug: Command to run: ", cmd)
            # Run the command and redirect output to a file
            # run(pipeline(cmd, stdout="report_output.txt", stderr="report_output.txt"))
            output = read(cmd, String)
            println("Debug: Output from report_file: ", output)
            if (occursin("error found", output) || occursin("errors found", output))
                println("Error in file $file")
                return false
            end
        end
    end
    println("Debug: All files checked successfully")
    return true
end

# Activate project
if isdir("./App")
    Pkg.activate("./App")
else
    project_root = get_project_root()
    Pkg.activate(project_root)
end

# Precompile and instantiate project
Pkg.precompile()
Pkg.instantiate()

# Get the list of files to be checked from the command line arguments
files = ARGS
println("Debug: ARGS: ", ARGS)
if !check_files(files)
    println("Pre-push check failed.")
    exit(1)
else
    println("Pre-push check passed.")
end
