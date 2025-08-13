#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_colors.sh
#
# DESCRIPTION: Defines standard color variables for use in scripts.
# ==============================================================================

# --- Required Sourcing ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_core.sh"

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
    nothing=""
    
    # --- Self-Registration ---
    # Register the hook functions with the main library.
    if function_exists "register_hooks"; then
        register_hooks --define libColors_define_arguments --apply libColors_apply_args
    fi
}

# ==============================================================================
# GLOBALS
# ==============================================================================
    # --- Style ---
    # c_reset='\x1b[0m'
    # c_bold='\x1b[1m'
    # c_dim='\x1b[2m'
    # c_underline='\x1b[4m'
    # c_blink='\x1b[5m'

    # --- Foreground Colors ---
    # c_fg_black='\x1b[30m'
    # c_fg_red='\x1b[31m'
    # c_fg_green='\x1b[32m'
    # c_fg_yellow='\x1b[33m'
    # c_fg_blue='\x1b[34m'
    # c_fg_magenta='\x1b[35m'
    # c_fg_cyan='\x1b[36m'
    # c_fg_white='\x1b[37m'
    # c_fg_gray='\x1b[90m'

# Check if stdout is a terminal
if [[ -t 1 ]]; then
    # --- Style ---
    c_reset=$'\x1b[0m'
    c_bold=$'\x1b[1m'
    c_dim=$'\x1b[2m'
    c_underline=$'\x1b[4m'
    c_blink=$'\x1b[5m'

    # --- Foreground Colors ---
    c_fg_black=$'\x1b[30m'
    c_fg_red=$'\x1b[31m'
    c_fg_green=$'\x1b[32m'
    c_fg_yellow=$'\x1b[33m'
    c_fg_blue=$'\x1b[34m'
    c_fg_magenta=$'\x1b[35m'
    c_fg_cyan=$'\x1b[36m'
    c_fg_white=$'\x1b[37m'
    c_fg_gray=$'\x1b[90m'

    # --- Common Combinations ---
    c_red="${c_bold}${c_fg_red}"
    c_green="${c_bold}${c_fg_green}"
    c_yellow="${c_bold}${c_fg_yellow}"
    c_blue="${c_bold}${c_fg_blue}"
    c_magenta="${c_bold}${c_fg_magenta}"
    c_cyan="${c_bold}${c_fg_cyan}"
    c_white="${c_bold}${c_fg_white}"
fi

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: libColors_define_arguments
#
# DESCRIPTION:
#   Defines the command-line arguments related to color output.
# ------------------------------------------------------------------------------
libColors_define_arguments() {
    libCmd_add -t switch -f n --long no-color -v "g_no_color" -d "$FALSE" -m once -u "Disable all color output."
}

# ------------------------------------------------------------------------------
# FUNCTION: libColors_apply_args
#
# DESCRIPTION:
#   Applies the logic for color-related arguments after parsing.
# ------------------------------------------------------------------------------
libColors_apply_args() {
    if (( g_no_color )); then
        disable_colors
    fi
}


# ------------------------------------------------------------------------------
# FUNCTION: disable_colors
#
# DESCRIPTION:
#   Disables color output by setting all color variables to empty strings.
# ------------------------------------------------------------------------------
disable_colors() {
    # --- Style ---
    c_reset=''
    c_bold=''
    c_dim=''
    c_underline=''
    c_blink=''
    # --- Foreground Colors ---
    c_fg_black=''
    c_fg_red=''
    c_fg_green=''
    c_fg_yellow=''
    c_fg_blue=''
    c_fg_magenta=''
    c_fg_cyan=''
    c_fg_white=''
    c_fg_gray=''
    # --- Common Combinations ---
    c_red=''
    c_green=''
    c_yellow=''
    c_blue=''
    c_magenta=''
    c_cyan=''
    c_white=''
}

# Load dependencies first
load_dependencies



