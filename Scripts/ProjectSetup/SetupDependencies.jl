using Pkg

# Initialize a new project
Pkg.activate(".")

# Add required packages
packages = [
    "JSON",
    "Profile",
    "SIMD",
    "Test",
    "BenchmarkTools",
    "Genie",
    "HTTP",
    "DuckDB",
    "DataFrames",
    "Dates",
    "MarketTechnicals",
    "TimeSeries",
    "Statistics",
    "Glob",
    "TimeZones",
]  # Add your required packages here
for pkg in packages
    Pkg.add(pkg)
end

Pkg.add(Pkg.PackageSpec(; name="Parquet", version="0.8.4"))

# Resolve dependencies
Pkg.resolve()

println("Project.toml and Manifest.toml have been created and dependencies resolved.")
