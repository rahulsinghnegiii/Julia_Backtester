#!/bin/bash

# Define the paths
STRATEGY_DIR="./Strategies/test-strategies"
LOG_DIR="../../diff/all/logs"
BACKTEST_SCRIPT="vec_backtest_service.jl"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Loop through all JSON files in the strategy directory
for strategy_file in "$STRATEGY_DIR"/*.json; do
    # Extract the base name of the file (without path and extension)
    strategy_name=$(basename "$strategy_file" .json)
    
    # Define the log file path
    log_file="$LOG_DIR/${strategy_name}.log"
    
    # Run the Julia script and redirect output to the log file
    julia "$BACKTEST_SCRIPT" "$strategy_file" > "$log_file" 2>&1
    
    echo "Processed $strategy_file, log saved to $log_file"
done
