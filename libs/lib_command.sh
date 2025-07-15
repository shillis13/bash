#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides a robust wrapper for executing shell commands.
# Defaults to a safe "dry run" mode unless explicitly told to execute.

# --- Required Sourcing ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_core.sh"

# Sourcing Guard
# Create a sanitized, unique variable name from the filename.
isSourcedName="$(sourced_name ${BASH_SOURCE[0]})" 
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 0; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
load_dependencies() {
    lib_require "lib_logging.sh"
}

# --- Globals ---
declare -g g_run_quiet="false"
declare -g -r ON_ERR_EXIT="on_err_exit"
declare -g -r ON_ERR_CONT="on_err_cont"

# --- Functions ---
runCommand() {
    local perform_exec=0
    local doOnFailure="$ON_ERR_EXIT" # Default error mode
    local command_str=""

    while (( "$#" )); do
        case "$1" in
            --exec|-x)
                perform_exec=1
                shift
                ;;
            "$ON_ERR_EXIT"|"$ON_ERR_CONT")
                doOnFailure=$1
                shift
                ;;
            *)
                break # Not a flag for us, must be the start of the command
                ;;
        esac
    done

    command_str="$*"
    if [[ -z "$command_str" ]]; then
        log --warn "runCommand called with no command."
        return 1
    fi

    if [[ "$perform_exec" -eq 1 ]]; then
        if [[ "$g_run_quiet" != "true" ]]; then
            log_banner "Executing: ${command_str}"
        fi
        local return_code=0
        eval "${command_str}"
        return_code=$?
        if [[ "$return_code" -ne 0 ]]; then
            log --error "Command failed with exit code $return_code (${doOnFailure}): ${command_str}"
            if [[ "$doOnFailure" == "$ON_ERR_EXIT" ]]; then
                exit 1
            fi
        fi
        return $return_code
    else
        log_banner "Dry Run: ${command_str}"
    fi
}

# Source the dependencies
load_dependencies
