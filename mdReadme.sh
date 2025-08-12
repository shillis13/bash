#!/usr/bin/env bash
#
# ==============================================================================
# SCRIPT: mdReadme.sh
#
# DESCRIPTION: A script to read Markdown Language (md) files using different 
#              parsers.
# ==============================================================================
#set -x
#set -v

# --- Globals ---
readonly g_lib_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)/libs"

# --- Required Sourcing ---
source "$g_lib_dir/lib_core.sh"

# Sourcing Guard
# Create a sanitized, unique variable name from the filename.
isSourcedName="$(sourced_name ${BASH_SOURCE[0]})" 
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
load_dependencies() {
    lib_require "lib_main.sh"
}

def_parser="glow"

# ==============================================================================
# Script-Specific Functions
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: define_arguments
#
# This function is REQUIRED by lib_initializeScript. It defines all the
# command-line arguments this specific script accepts.
# ------------------------------------------------------------------------------
define_arguments() {
    log --entryexit "Defining script-specific arguments..."
    libCmd_add -t switch -f g --long glow   -v "glow"       -d "false" -m once -u "Use glow parser to render the md text"
    libCmd_add -t switch -f m --long mdcat  -v "use_mdcat"  -d "false" -m once -u "Use mdcat parser to rendered to Markdown text"
    libCmd_add -t switch -f r --long rich   -v "use_rich"   -d "false" -m once -u "Use the python rich parse to render Markdown text"
    libCmd_add -t value  -f p --long parser -v "parser"     -d "$def_parser"  -m once -u "Use the specified parser to render Markdown text"
    libCmd_add -t value  -f a --long parser-args -v "p_args" -r n      -m once -u "Parser specific arguments, enclude in quotes \"\""
    libCmd_add -t switch -f v --long help-verbose -v "help_verbose" -d "false" -m once -u "Show the --help for each of the renders"
    libCmd_add -t switch -f h --long help   -v "showHelp"   -d "false" -m once -u "Display this help message."
}

# ------------------------------------------------------------------------------
# These functions contain the core "business logic" of the script.
# ------------------------------------------------------------------------------
select_parser() {
    local parser=""
    if [ "$use_glow" ] ;  then
        parser="glow"
    elif [ "$use_mdcat" ] ; then
        parser="mdcat"
    elif [ "$use_rich" ] ; then
        parser="rich"
    else
        parser="$def_parser"
    fi

    echo "$parser"
}

# ==============================================================================
# Main Orchestration Function
# ==============================================================================
main() {
    # 0. Load the dependencies
    load_dependencies

    # 1. Handle all script initialization with one call.
    if ! initializeScript "$@"; then
        return 1
    fi

    # The rest of the arguments are now clean for the script's own use if needed.
    # shift "$g_consumed_args"

    # 2. Determine parser to use
    local parser=""
    parser="$(select_parser)"
        
    # 3. Orchestrate the core logic, using the globally-set $g_execution_flag.
    log --debug "$hande_parser $p_args"

    runCommand "$hande_parser $p_args"

    log --debug "✅ Script finished."
}

# ==============================================================================
# Main Execution Guard
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@" "--exec"
fi
