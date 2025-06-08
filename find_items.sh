#!/usr/bin/env bash

# Script to safely find items matching a pattern

# Safer find_items function
find_items() {
    local path="$1"
    local recursive="$2"
    local search_str="$3"

    # Ensure path is valid
    if [ ! -d "$path" ]; then
        echo "Invalid path: $path"
        return 1
    fi

    # Use find command safely
    if [ "$recursive" == "true" ]; then
        find "$path" -type f -name "*$search_str*" -print
    else
        find "$path" -maxdepth 1 -type f -name "*$search_str*" -print
    fi
}

# Example usage of find_items
# path_to_search="~/Downloads"
path_to_search="/Users/shawnhillis/Downloads"
recursive_search="true"
search_pattern="txt"

find_items "$path_to_search" "$recursive_search" "$search_pattern"
