#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides specialized functions for finding common data patterns (IPs, dates, etc.)

# Sourcing Guard
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename/./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_thisFile.sh"
lib_require "lib_logging.sh"

# ==============================================================================
# 1. REGEX PATTERN DEFINITIONS
# ==============================================================================
declare -g -r GREP_REGEX_IPV4='([0-9]{1,3}\.){3}[0-9]{1,3}'
declare -g -r GREP_REGEX_DATE_YMD='[0-9]{4}-[0-9]{2}-[0-9]{2}' # yyyy-MM-DD
declare -g -r GREP_REGEX_DATE_COMMONLOG='[0-9]{2}/[A-Z][a-z]{2}/[0-9]{4}' # DD/Mon/YYYY
declare -g -r GREP_REGEX_TIME_24H='[0-9]{2}:[0-9]{2}:[0-9]{2}' # HH:MM:SS


# ==============================================================================
# 2. GENERIC GREP FUNCTION
# ==============================================================================
getLinesMatching() {
    local input_file="$1"
    local regex_pattern="$2"

    if [[ -z "$input_file" ]] || [[ -z "$regex_pattern" ]]; then
        log --error "Usage: getLinesMatching <file> <regex_pattern>"
        return 1
    fi
    if [[ ! -f "$input_file" ]] || [[ ! -r "$input_file" ]]; then
        log --error "Input file not found or is not readable: $input_file"
        return 1
    fi

    log --debug "Searching for pattern '$regex_pattern' in '$input_file'..."
    while IFS= read -r line; do
        if [[ "$line" =~ $regex_pattern ]]; then
            echo "$line"
        fi
    done < "$input_file"
    return 0
}

# ==============================================================================
# 3. SPECIALIZED DATA FUNCTIONS
# ==============================================================================
grepIpv4Addresses() {
    log --info "Searching for IPv4 addresses in '$1'..."
    getLinesMatching "$1" "$GREP_REGEX_IPV4"
}

grepDates() {
    local input_file="$1"
    if [[ ! -f "$input_file" ]] || [[ ! -r "$input_file" ]]; then
        log --error "Input file not found or is not readable: $input_file"
        return 1
    fi

    log --info "Searching for multiple date formats in '$1'..."
    while IFS= read -r line; do
        if [[ "$line" =~ $GREP_REGEX_DATE_YMD ]] || [[ "$line" =~ $GREP_REGEX_DATE_COMMONLOG ]]; then
            echo "$line"
        fi
    done < "$input_file"
    return 0
}

