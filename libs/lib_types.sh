#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_types.sh
#
# DESCRIPTION: A library for checking variable types and file system node types.
# ==============================================================================

# Sourcing Guard
# Create a sanitized, unique variable name from the filename.
# Not using lib_core.sh so as to not cause a dependency
source "$(dirname "${BASH_SOURCE[0]}")/lib_bool.sh"
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename//[^a-zA-Z0-9_]/_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then
    return 0
else
    declare -g "$isSourcedName"
    bool_set "$isSourcedName" 1
fi

# --- Dependencies ---

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

