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

load_dependencies() {
    lib_require "lib_logging.sh"
    if function_exists "register_hooks"; then
        register_hooks --define libCommand_define_arguments --apply libCommand_apply_args
    fi
}

# --- Globals ---
declare -g g_run_quiet="false"
declare -g g_dry_run="true"
declare -g -r ON_ERR_EXIT="on_err_exit"
declare -g -r ON_ERR_CONT="on_err_cont"

# --- Argument Hooks ---
libCommand_define_arguments() {
    libCmd_add -t switch -f x --long exec -v "libCommand_exec" -d "false" -m once \
        -u "Execute commands instead of performing a dry run"
}

libCommand_apply_args() {
    if [[ "$libCommand_exec" == "true" ]]; then
        g_dry_run="false"
    fi
}

# --- Functions ---
runCommand() {
    local dry_run="$g_dry_run"
    local doOnFailure="$ON_ERR_EXIT" # Default error mode
    local command_str=""

    while (( "$#" )); do
        case "$1" in
            --exec|-x)
                dry_run="false"
                shift
                ;;
            --dry-run|-n)
                dry_run="true"
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

    if [[ "$dry_run" == "false" ]]; then
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
