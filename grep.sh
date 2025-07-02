#!/usr/bin/env bash

# ==============================================================================
# SCRIPT: grep.sh
#
# DESCRIPTION: A powerful CLI tool that uses the lib_grep library to find
#              common data patterns in files or export the regex patterns.
# ==============================================================================

# --- Sourcing the Library ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR/libs/lib_main.sh"

# --- Script-Specific Logic ---

define_arguments() {
    # Incorporate arguments from the logging library
    lib_logging_initialize

    # --- Mode Flags ---
    libCmd_add -t switch --long getRegex -v "getRegex_mode" -m once \
        -u "Print the regex pattern instead of searching. Use with a search flag."

    # --- Search Flags ---
    libCmd_add -t switch --long ipv4 -v "search_ipv4" -m once -u "Search for IPv4 addresses."
    libCmd_add -t switch --long dates -v "search_dates" -m once -u "Search for multiple common date formats."
    libCmd_add -t switch --long date-ymd -v "search_date_ymd" -m once -u "Search for YYYY-MM-DD dates."
    libCmd_add -t switch --long time-24h -v "search_time_24h" -m once -u "Search for HH:MM:SS timestamps."
    
    # --- Standard Flags ---
    libCmd_add -t switch -f h --long help -v "showHelp" -d "false" -m once -u "Display this help message."
}

main() {
    if ! lib_initializeScript "$@"; then
        return 1
    fi
    # After getopt processing, remaining args are positional
    local inputFile="$1"


    # --- Mode 1: Get Regex ---
    if [[ "$getRegex_mode" == "true" ]]; then
        lib_require "lib_grep.sh"
        if [[ "$search_ipv4" == "true" ]]; then echo "$GREP_REGEX_IPV4"; return 0; fi
        if [[ "$search_date_ymd" == "true" ]]; then echo "$GREP_REGEX_DATE_YMD"; return 0; fi
        if [[ "$search_time_24h" == "true" ]]; then echo "$GREP_REGEX_TIME_24H"; return 0; fi
        log_error "You must specify which regex to get, e.g., --getRegex --ipv4"
        return 1
    fi

    # --- Mode 2: Search File ---
    if [[ -z "$inputFile" ]]; then
        log_error "You must specify an input file to search."
        libCmd_usage
        return 1
    fi

    lib_require "lib_grep.sh"

    if [[ "$search_ipv4" == "true" ]]; then
        grepIpv4Addresses "$inputFile"
    elif [[ "$search_dates" == "true" ]]; then
        grepDates "$inputFile"
    elif [[ "$search_date_ymd" == "true" ]]; then
        getLinesMatching "$inputFile" "$GREP_REGEX_DATE_YMD"
    elif [[ "$search_time_24h" == "true" ]]; then
        getLinesMatching "$inputFile" "$GREP_REGEX_TIME_24H"
    else
        log_error "No search mode specified. Use a flag like --ipv4 or --dates."
        libCmd_usage
        return 1
    fi
}

# --- Main Execution Guard ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi

