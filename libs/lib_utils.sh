#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides common, miscellaneous utility functions.

filename="$(basename "${BASH_SOURCE[0]}")"; isSourcedName="sourced_${filename/./_}";
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

min() { echo "$@" | tr ' ' '\n' | sort -g | head -n 1; }
max() { echo "$@" | tr ' ' '\n' | sort -rg | head -n 1; }
equals() {
    local minVal; minVal=$(min "$@")
    local maxVal; maxVal=$(max "$@")
    if [[ "$minVal" == "$maxVal" ]]; then echo 1; else echo 0; fi
}
