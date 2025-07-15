#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_main.sh
#
# DESCRIPTION: The main library entry point. It sources all other libraries
#              and provides the main script initialization function.
# ==============================================================================

# --- Globals ---
# Global variable for the library path
if [[ -z "$g_lib_dir" ]]; then 
    declare -r -g  g_lib_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
fi

# --- Required Sourcing ---
source "$g_lib_dir/lib_core.sh"

# Sourcing Guard
# Create a sanitized, unique variable name from the filename.
isSourcedName="$(sourced_name ${BASH_SOURCE[0]})" 
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 0; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
load_dependencies() {
    # The order is critical for dependencies.
    lib_require "lib_logging.sh"
    lib_require "lib_types.sh"
    lib_require "lib_grep.sh"
    lib_require "lib_utils.sh"
    lib_require "lib_mathUtils.sh"
    lib_require "lib_sysInfoUtils.sh"
    lib_require "lib_colors.sh"
    lib_require "lib_format.sh"
    lib_require "lib_cmdArgs.sh"
    lib_require "lib_command.sh"
    lib_require "lib_stackTrace.sh"
}

# ==============================================================================
# HOOK REGISTRATION SYSTEM
# ==============================================================================

# Arrays to hold the names of the functions to be called at different stages.
g_arg_define_funcs=()
g_arg_apply_funcs=()

# ------------------------------------------------------------------------------
# FUNCTION: function_exists
#
# DESCRIPTION:
#   Checks if a function with the given name has been defined in the current
#   shell environment.
#
# USAGE:
#   if function_exists "my_function"; then ...
#
# PARAMETERS:
#   $1 (string): The name of the function to check.
#
# RETURNS:
#   0 (true) if the function exists, 1 (false) otherwise.
# ------------------------------------------------------------------------------
function_exists() {
    # The `declare -F` command lists all defined function names.
    # We redirect stderr to /dev/null to suppress "not found" errors
    # and grep for an exact match of the function name.
    declare -F "$1" > /dev/null
    return $?
}

# ------------------------------------------------------------------------------
# FUNCTION: register_hooks
#
# DESCRIPTION:
#   Allows a library to register its functions to be called by the main
#   initialization sequence. This is the key to resolving circular dependencies.
#
# USAGE:
#   lib_register_hooks --define <func_name> --apply <func_name>
# ------------------------------------------------------------------------------
register_hooks() {
    echo "Main: register_hooks: $*"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --define) g_arg_define_funcs+=("$2"); shift 2;;
            --apply)  g_arg_apply_funcs+=("$2");  shift 2;;
            *) shift;;
        esac
    done
}

# ==============================================================================
# MAIN INITIALIZATION FUNCTION
# ==============================================================================
initializeScript() {
    echo "Main: initializeScript"
    # --- 1. Define arguments by calling registered hook functions ---
    for func in "${g_arg_define_funcs[@]}"; do
        if function_exists "$func"; then
            echo "log --Debug Calling registered fcn: $func"
            log --Debug "Calling registered fcn: $func"
            "$func"
        else
            echo "WARN: Registered define function '$func' does not exist." >&2
        fi
    done

    # --- 2. Define arguments from the calling script ---
    if ! function_exists "define_arguments"; then
        log --Error "FATAL: Script must contain a 'define_arguments' function."
        return 1
    fi
    define_arguments

    # --- 3. Parse all defined arguments ---
    if ! libCmd_parse "$@"; then
        log --Error "Failed to parse command-line arguments. Use --help for usage."
        Stack_prettyPrint --skip 1
        return 1
    fi

    # --- 4. Apply logic by calling registered hook functions ---
    for func in "${g_arg_apply_funcs[@]}"; do
        if function_exists "$func"; then
            log --Debug "$func"
            "$func"
        else
            log --Warn " Registered apply function '$func' does not exist." >&2
        fi
    done

    return 0
}

load_dependencies
