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
thisFile()   { "$(basename "${BASH_SOURCE[1]}")"; }
thisCaller() { "$(basename "${BASH_SOURCE[2]}")"; }
thisScript() { "$(basename "$0")"; }

