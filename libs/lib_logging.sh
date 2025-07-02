#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides a standardized logging framework, modeled after Logging.ps1.

# Sourcing Guard
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename/./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_thisFile.sh"

# --- Global Logging Configuration ---
declare -g -r -A LOG_LEVELS=([entryexit]=1 [debug]=2 [info]=3 [warn]=4 [error]=5 [none]=6)
declare -g -l -x current_logging_level="warn"
declare -g -x g_log_file_path=""

# --- Initialization Function ---
lib_logging_initialize() {
    lib_require "lib_colors.sh"
    fcn_init_colors
    libCmd_add -t value -f l --long log-level -v "logLevel" -m once \
        -u "Sets verbosity. One of: entryexit, debug, info, warn, error, none."
    libCmd_add -t value --long log-file -v "logFile" -m once \
        -u "Redirect all log output to a specified file."
}

# --- Core Logging Functions ---
set_log_level() {
    local new_level="$1"
    # If called with no argument, try to use the global $logLevel from the cmd line parser.
    if [[ -z "$new_level" ]] && [[ -n "$logLevel" ]]; then
        new_level="$logLevel"
    fi

    if [[ -n "$new_level" ]] && [[ -n "${LOG_LEVELS[$new_level]}" ]]; then
        current_logging_level=$new_level
    fi
}

set_log_file() {
    local new_log_file="$1"
    # If called with no argument, try to use the global $logFile from the cmd line parser.
    if [[ -z "$new_log_file" ]] && [[ -n "$logFile" ]]; then
        new_log_file="$logFile"
    fi

    if [[ -n "$new_log_file" ]]; then
        g_log_file_path="$new_log_file"
        mkdir -p "$(dirname "$g_log_file_path")"
        >"$g_log_file_path" # Clear the log file for the session
    fi
}

log_message() {
    local level="$1"; shift
    local -i msg_log_value=${LOG_LEVELS[$level]:-0}
    local -i current_logging_value=${LOG_LEVELS[$current_logging_level]:-4}

    if (( msg_log_value >= current_logging_value )); then
        local caller_info="$1"; shift
        local message
        local color_var="Color_${level^}"
        local color=${!color_var:-}
        message="[${level^^}] [${caller_info}] $@"

        if [[ -n "$g_log_file_path" ]]; then
            printf "%s\n" "$message" >> "$g_log_file_path"
        fi
        printf "%s%s%s\n" "$color" "$message" "${Color_Reset:-}" >&2
    fi
}

# PRIMARY LOG FUNCTION
log() {
    local level="info"; local message=""; local -a passthrough_args=()
    while (( "$#" )); do
        case "$1" in
            --error) level="error"; shift ;;
            --warn) level="warn"; shift ;;
            --info) level="info"; shift ;;
            --debug) level="debug"; shift ;;
            --entryexit) level="entryexit"; shift ;;
            *) passthrough_args+=("$1"); shift ;;
        esac
    done
    message="${passthrough_args[*]}"
    log_message "$level" "$(thisCaller):${BASH_LINENO[1]}" "$message"
}

# --- Utility Functions ---
log_always() {
    local message="[ALWAYS] $*"
    if [[ -n "$g_log_file_path" ]]; then printf "%s\n" "$message" >> "$g_log_file_path"; fi
    printf "%s%s%s\n" "${Color_Success:-}" "$message" "${Color_Reset:-}" >&2
}

log_banner() {
    local message="*** $* ***"
    if [[ -n "$g_log_file_path" ]]; then printf "%s\n" "$message" >> "$g_log_file_path"; fi
    printf "%s%s%s\n" "${Color_Instr:-}" "$message" "${Color_Reset:-}" >&2
}

entryexit_fcn() {
    local func_name="$1"; shift
    log_message "entryexit" "$(thisCaller):${BASH_LINENO[1]}" "Enter: $func_name $@"
    "$func_name" "$@"
    local return_code=$?
    log_message "entryexit" "$(thisCaller):${BASH_LINENO[1]}" "Exit: $func_name (returned: $return_code)"
    return $return_code
}

