#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides introspection functions and the core dependency loader.

# Sourcing Guard
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename//./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

# Global variable for the library path
#declare -g g_lib_dir
#g_lib_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Centralized dependency loader function
lib_require() {
    local parent_script="${BASH_SOURCE[1]}" # The script that is asking for dependencies.

    for dependency in "$@"; do
        local dep_path="$g_lib_dir/$dependency"
        # Create the guard name from the filename (e.g., lib_logging.sh -> sourced_lib_logging_sh)
        local dep_guard_name="sourced_${dependency//./_}"

        # Check if the guard variable is already set. If so, it's already sourced.
        if declare -p "$dep_guard_name" > /dev/null 2>&1; then
            continue # Skip to the next dependency.
        fi

        # Check if file exists and source it.
        if [ -f "$dep_path" ]; then
            source "$dep_path"
        else
            printf "FATAL: Dependency not found.\n  Required by: '%s'\n  Missing:   '%s'\n" "$parent_script" "$dep_path" >&2
            exit 1
        fi
    done
}

# --- Introspection Functions ---
thisFile()   { echo "$(basename "${BASH_SOURCE[1]}")"; }
thisCaller() { echo "$(basename "${BASH_SOURCE[2]}")"; }
thisScript() { echo "$(basename "$0")"; }

