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
if declare -p "$isSourcedName" > /dev/null 2>&1; then
    return 0
else
    declare -g "$isSourcedName"
    bool_set "$isSourcedName" 1
fi

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
    #functions="$(declare -F)"
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
#   register_hooks --define <func_name> --apply <func_name>
# ------------------------------------------------------------------------------
register_hooks() {
    log_entry
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --define) g_arg_define_funcs+=("$2"); shift 2;;
            --apply)  g_arg_apply_funcs+=("$2");  shift 2;;
            *) shift;;
        esac
    done
    log_exit
}

# ==============================================================================
# MAIN INITIALIZATION FUNCTION
# ==============================================================================
initializeScript() {
    #echo "Main: initializeScript"
    log_entry
    # --- 1. Define arguments by calling registered hook functions ---
    log --Debug " --- 1. Define arguments by calling registered hook functions: ${#g_arg_define_funcs[@]} ---"
    for func in "${g_arg_define_funcs[@]}"; do
        if function_exists "$func"; then
            log --Debug "Calling registered fcn: $func"
            "$func"
        else
            log --Warn "WARN: Registered define function '$func' does not exist." >&2
        fi
    done

    # --- 2. Define arguments from the calling script ---
    log --Debug " --- 2. Define arguments from the calling script ---"
    if ! function_exists "define_arguments"; then
        log --Warn "Script should (must?) contain a 'define_arguments' function."
        #return 1
    else
        define_arguments
    fi

    # --- 3. Parse all defined arguments ---
    log --Debug " --- 3. Parse all defined arguments: ${@} ---"
    if ! libCmd_parse "$@"; then
        log --Error "Failed to parse command-line arguments. Use --help for usage."
        Stack_prettyPrint --skip 1
        log_exit
        return 1
    fi

    # --- 4. Apply logic by calling registered hook functions ---
    log --Debug " --- 4. Apply logic by calling registered hook functions: ${#g_arg_apply_funcs[@]} ---"
    for func in "${g_arg_apply_funcs[@]}"; do
        if function_exists "$func"; then
            log --Debug "Calling registered apply fcn: $func"
            "$func"
        else
            log --Warn " Registered apply function '$func' does not exist." >&2
        fi
    done

    log_exit
    return 0
}

# ------------------------------------------------------------------------------
# Usage Example:
#   load_dependencies() { lib_require "lib_main.sh"; }
#   main() {
#       load_dependencies
#       initializeScript "$@"
#       # script logic
#   }
#   [[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Call the load_dependencies function so the common libraries are ready for the
# calling script.  This mirrors the explicit initialization pattern while still
# providing an optional compatibility path below.
# ------------------------------------------------------------------------------
if function_exists "load_dependencies"; then
    load_dependencies
fi

# ------------------------------------------------------------------------------
# Compatibility: legacy scripts that relied on lib_main automatically
# initializing can opt-in by exporting LIB_MAIN_AUTO_INIT=1 before sourcing this
# file.  New scripts should call initializeScript explicitly.
# ------------------------------------------------------------------------------
if [[ -n "${LIB_MAIN_AUTO_INIT:-}" && "${LIB_MAIN_AUTO_INIT}" != "0" ]]; then
    initializeScript "$@"
fi
