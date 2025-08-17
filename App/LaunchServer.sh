#!/bin/bash

# Flag to determine if cleanup is needed
PERFORM_CLEANUP=true

# Function to perform cleanup
cleanup() {
    CLEANUP_DIRS=("./SubtreeCache" "./Cache" "./IndicatorData")

    for DIR in "${CLEANUP_DIRS[@]}"; do
        if [ -d "$DIR" ]; then
            echo "Cleaning up directory: $DIR"
            # Remove all contents including subdirectories, but keep the parent directory
            find "$DIR" -mindepth 1 -delete
        else
            echo "Directory not found: $DIR"
        fi
    done
}

# Perform cleanup if the flag is set
if [ "$PERFORM_CLEANUP" = true ]; then
    cleanup
fi


# Get the number of available CPU cores
CORES=$(nproc 2>/dev/null || echo 1)

# Set the number of threads to use (you can adjust this formula as needed)
THREADS=$((CORES - 1))

# Ensure at least 1 thread is used
if [ $THREADS -lt 1 ]; then
    THREADS=1
fi

# Run the Julia script with the calculated number of threads
exec julia Server.jl
