#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides common, miscellaneous utility functions.

# Sourcing Guard
# Create a sanitized, unique variable name from the filename.
# Not using lib_core.sh so as to not cause a dependency
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename//[^a-zA-Z0-9_]/_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 0; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---

min() { echo "$@" | tr ' ' '\n' | sort -g | head -n 1; }
max() { echo "$@" | tr ' ' '\n' | sort -rg | head -n 1; }
equals() {
    local minVal; minVal=$(min "$@")
    local maxVal; maxVal=$(max "$@")
    if [[ "$minVal" == "$maxVal" ]]; then echo 1; else echo 0; fi
}
