#!/usr/bin/env bash

# Part of the 'lib' suite.
# Provides core, high-level orchestration functions for scripts.

# Sourcing Guard
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename/./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_thisFile.sh"
lib_require "lib_logging.sh" "lib_cmdArgs.sh" "lib_command.sh"

# --- Globals ---
declare -g g_exec_flag=""

# --- Functions ---
initializeScript() {
    if ! declare -f "define_arguments" > /dev/null; then
        log --error "Script startup error: 'define_arguments' function not found. Cannot initialize."
        return 1
    fi

    # 1. Register all arguments
    define_arguments

    # 2. Parse all registered arguments, which populates $logLevel, $logFile, etc.
    libCmd_parse "$@"

    # 3. Handle --help flag
    if [[ "${showHelp}" == "true" ]]; then
        libCmd_usage
        return 1 # Signal to the calling script that it should stop.
    fi

    # 4. FIX: Explicitly pass the parsed variables to the setter functions.
    set_logLevel "$logLevel"
    set_logFile "$logFile"

    # 5. Set up execution context
    if [[ "${execute_mode}" == "true" ]]; then
        g_exec_flag="--exec"
        log --info "EXECUTION MODE IS ENABLED."
    else
        g_exec_flag=""
        log --info "Running in DRY RUN mode. Use --exec or -x to apply changes."
    fi

    return 0
}

