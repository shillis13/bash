#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_mathUtils.sh
#
# DESCRIPTION: A library of mathematical and numeric utility functions.
# ==============================================================================

# --- Required Sourcing ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_core.sh"

# Sourcing Guard
# Create a sanitized, unique variable name from the filename.
isSourcedName="$(sourced_name ${BASH_SOURCE[0]})"
if declare -p "$isSourcedName" > /dev/null 2>&1; then
    return 0
else
    declare -g "$isSourcedName"
    bool_set "$isSourcedName" 1
fi

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: min / max
#
# DESCRIPTION:
#   Finds the minimum or maximum numeric value from a list of arguments.
#
# USAGE:
#   min 10 5 20
#   max 10 5 20
# ------------------------------------------------------------------------------
min() {
    echo "$@" | tr ' ' '\n' | sort -g | head -n 1
}

max() {
    echo "$@" | tr ' ' '\n' | sort -rg | head -n 1
}

# ------------------------------------------------------------------------------
# FUNCTION: equals
#
# DESCRIPTION:
#   Checks if two numbers are equal within a given threshold.
#   Uses 'bc' for floating point arithmetic if available.
#
# USAGE:
#   equals <val1> <val2> [threshold]
#
# RETURNS:
#   Prints 1 if they are equal, 0 otherwise.
# ------------------------------------------------------------------------------
equals() {
    local val1="$1"
    local val2="$2"
    # Default threshold is a small epsilon to handle floating point inaccuracies.
    local threshold="${3:-0.00001}"

    # Check if bc is installed for robust floating-point comparison
    if command -v bc &> /dev/null; then
        local result
        result=$(echo "if (define abs(x) {if (x<0) {return -x}; return x}; abs($val1 - $val2) <= $threshold) 1 else 0" | bc)
        echo "$result"
        return 0
    fi

    # --- Fallback logic if 'bc' is not installed ---
    # This provides a "best effort" string comparison. It cannot handle
    # thresholds and will fail on different numeric representations (e.g., 5 vs 5.0).
    log --Warn "Command 'bc' not found. Using string comparison for equals()."
    if [[ "$val1" == "$val2" ]]; then
        echo 1
    else
        echo 0
    fi
}


