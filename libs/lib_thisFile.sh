#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides introspection functions and the core dependency loader.

# Sourcing Guard
# Create a sanitized, unique variable name from the filename.
# Not using lib_core.sh so as to not cause a dependency
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename//[^a-zA-Z0-9_]/_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 0; else declare -g "$isSourcedName=true"; fi

# --- Introspection Functions ---
# ------------------------------------------------------------------------------
# FUNCTION: thisFile
# DESCRIPTION:
#   Returns the filename of the calling script/function at the stack frame Caller_Idx+0.
#   Optionally takes a Caller_Idx (default 0).
# USAGE:
#   thisFile [Caller_Idx]
# ------------------------------------------------------------------------------
thisFile() {
    local idx=${1:-0}
    idx=$((idx + 0))
    basename "${BASH_SOURCE[$idx]}"
}

# ------------------------------------------------------------------------------
# FUNCTION: thisCaller
# DESCRIPTION:
#   Returns the filename of the caller's caller at the stack frame Caller_Idx+1.
#   Optionally takes a Caller_Idx (default 0).
# USAGE:
#   thisCaller [Caller_Idx]
# ------------------------------------------------------------------------------
thisCaller() {
    local idx=${1:-0}
    idx=$((idx + 1))
    basename "${BASH_SOURCE[$idx]}"
}

# ------------------------------------------------------------------------------
# FUNCTION: thisScript
# DESCRIPTION:
#   Returns the filename of the main script ($0).
# ------------------------------------------------------------------------------
thisScript() { basename "$0"; }

