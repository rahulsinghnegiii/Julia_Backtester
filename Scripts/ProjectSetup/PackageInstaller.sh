#!/bin/bash

# Navigate to the project directory
cd App

# Start Julia and run commands
julia --project=. -e 'using Pkg; Pkg.activate("."); Pkg.precompile(); Pkg.instantiate()'

echo "All packages have been installed."
