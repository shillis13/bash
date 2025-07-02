#!/usr/bin/env bash
#
# Part of the 'lib' suite.
# Provides functions for formatting and coloring output.

# Sourcing Guard
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename/./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_thisFile.sh"
lib_require "lib_colors.sh"

# --- Functions ---
format_color_by_threshold() {
    local value="$1"
    local warn_thresh="$2"
    local err_thresh="$3"

    # bc -l is used for floating point comparison
    if (( $(echo "$value >= $err_thresh" | bc -l) )); then
        echo "$Color_Error"
    elif (( $(echo "$value >= $warn_thresh" | bc -l) )); then
        echo "$Color_Warn"
    else
        echo "$Color_Success"
    fi
}

# This function now only returns the raw number for the caller to format.
format_pages_to_gb() {
    local pages="$1"
    local page_size="$2"
    echo "scale=2; ($pages * $page_size) / (1024*1024*1024)" | bc
}

