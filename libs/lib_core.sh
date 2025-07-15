#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides the bootstrapping methods and variables 

#********************************************
# Sourcing Guard
#********************************************
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename//[^a-zA-Z0-9_]/_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 0; else declare -g "$isSourcedName=true"; fi

#********************************************
# Global variable for the library path
#********************************************
if [[ -z "$g_lib_dir" ]]; then 
    declare -g -r g_lib_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
fi

#********************************************
# Have a common way to get the sourced name of a file.
#********************************************
sourced_name() {
    local filename=""
    if [[ -z "$1" ]]; then
        echo "Error: sourced_name requires a filename argument." >&2
        return 1
    fi
    # Replace all non-alphanumeric characters with underscores
    # This ensures the variable name is safe for use in bash.
    # e.g., sourced_lib_logging.sh becomes sourced_lib_logging_sh
    filename=$(basename "$1")
    filename="${filename//[^a-zA-Z0-9_]/_}"
    echo "$filename"
}

#********************************************
# Centralized dependency loader function
#********************************************
lib_require() {
    local parent_script="${BASH_SOURCE[1]}" # The script that is asking for dependencies.

    for dependency in "$@"; do
        local dep_path="$g_lib_dir/$dependency"
        # Create the guard name from the filename (e.g., lib_logging.sh -> sourced_lib_logging_sh)
        local dep_guard_name="$(sourced_name "$dependency")"

        # Check if the guard variable is already set. If so, it's already sourced.
        if declare -p "$dep_guard_name" > /dev/null 2>&1; then
            # echo "$dep_path has already been sourced. Skipping subsequent sourcing."
            continue # Skip to the next dependency.
        fi

        # Check if file exists and source it.
        if [ -f "$dep_path" ]; then
            # echo "Sourcing $dep_path"
            source "$dep_path"
        else
            printf "FATAL: Dependency not found.\n  Required by: '%s'\n  Missing:   '%s'\n" "$parent_script" "$dep_path" >&2
            exit 1
        fi
    done
}


