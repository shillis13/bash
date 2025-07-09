#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_types.sh
#
# DESCRIPTION: A library for checking variable types and file system node types.
# ==============================================================================

# --- Guard ---
[[ -z "$LIB_TYPES_LOADED" ]] && readonly LIB_TYPES_LOADED=1 || return 0

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION: Variable Type and Value Checks
# ------------------------------------------------------------------------------

inArray() {
    local needle="$1"
    shift
    local haystack=("$@")
    local i
    for i in "${!haystack[@]}"; do
       if [[ "${haystack[$i]}" == "${needle}" ]]; then
           echo "$i"
           return 0 # Found
       fi
    done
    echo "-1"
    return 1 # Not found
}

is_string() { [[ -n "$1" ]]; }

is_array() {
    # Check if a variable is declared as an array
    declare -p "$1" 2>/dev/null | grep -q 'declare -a'
}

is_empty() { [[ -z "$1" ]]; }

is_not_empty() { [[ -n "$1" ]]; }

is_int() { [[ "$1" =~ ^-?[0-9]+$ ]]; }

is_float() { [[ "$1" =~ ^-?[0-9]+\.[0-9]+$ ]]; }

is_num() { is_int "$1" || is_float "$1"; }

