#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides common filesystem utility functions.

# Sourcing Guard
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename/./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_thisFile.sh"
lib_require "lib_logging.sh"

# --- Functions ---

# Checks if a path exists and is a regular file.
file_exists() {
  local item="$1"
  if [[ -f "$item" ]] && [[ ! -L "$item" ]]; then
    return 0 # Success
  fi
  return 1 # Failure
}

# Checks if a path exists and is a writable directory.
dir_exists_and_writable() {
  local item="$1"
  if [[ -d "$item" ]] && [[ -w "$item" ]]; then
    return 0 # Success
  fi
  return 1 # Failure
}


