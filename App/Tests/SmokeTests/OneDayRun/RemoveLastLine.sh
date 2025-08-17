#!/bin/bash

# Check if the user provided a relative path and N as arguments
if [ $# -ne 2 ]; then
  echo "Usage: $0 <relative_path> <n>"
  exit 1
fi

# Resolve the relative path to an absolute path
target_dir=$(realpath "$1")
n="$2"

# Validate that N is a positive integer
if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -le 0 ]; then
  echo "Error: N must be a positive integer."
  exit 1
fi

# Check if the target directory exists
if [ ! -d "$target_dir" ]; then
  echo "Error: Directory '$target_dir' does not exist."
  exit 1
fi

# Iterate over all files in the directory
for file in "$target_dir"/*; do
  # Check if the item is a file
  if [ -f "$file" ]; then
    # Get total number of lines in the file
    total_lines=$(wc -l < "$file")

    # Ensure we don't remove more lines than the file has
    if [ "$total_lines" -gt "$n" ]; then
      # Keep only the first (total_lines - n) lines
      head -n $((total_lines - n)) "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    else
      # If the file has <= n lines, empty the file
      > "$file"
    fi
  fi
done