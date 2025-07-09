#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_colors.sh
#
# DESCRIPTION: Defines standard color variables for use in scripts.
# ==============================================================================

# --- Guard ---
[[ -z "$LIB_COLORS_LOADED" ]] && readonly LIB_COLORS_LOADED=1 || return 0

# ==============================================================================
# GLOBALS
# ==============================================================================

# Check if stdout is a terminal
if [[ -t 1 ]]; then
    # --- Style ---
    readonly c_reset='\e[0m'
    readonly c_bold='\e[1m'
    readonly c_dim='\e[2m'
    readonly c_underline='\e[4m'
    readonly c_blink='\e[5m'

    # --- Foreground Colors ---
    readonly c_fg_black='\e[30m'
    readonly c_fg_red='\e[31m'
    readonly c_fg_green='\e[32m'
    readonly c_fg_yellow='\e[33m'
    readonly c_fg_blue='\e[34m'
    readonly c_fg_magenta='\e[35m'
    readonly c_fg_cyan='\e[36m'
    readonly c_fg_white='\e[37m'
    readonly c_fg_gray='\e[90m'

    # --- Common Combinations ---
    readonly c_red="${c_bold}${c_fg_red}"
    readonly c_green="${c_bold}${c_fg_green}"
    readonly c_yellow="${c_bold}${c_fg_yellow}"
    readonly c_blue="${c_bold}${c_fg_blue}"
    readonly c_magenta="${c_bold}${c_fg_magenta}"
    readonly c_cyan="${c_bold}${c_fg_cyan}"
    readonly c_white="${c_bold}${c_fg_white}"
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
    libCmd_add -t switch -f n --long no-color -v "g_no_color" -d "false" -m once -u "Disable all color output."
}

# ------------------------------------------------------------------------------
# FUNCTION: libColors_apply_args
#
# DESCRIPTION:
#   Applies the logic for color-related arguments after parsing.
# ------------------------------------------------------------------------------
libColors_apply_args() {
    if [[ "${g_no_color:-false}" == "true" ]]; then
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

# --- Self-Registration ---
# Register the hook functions with the main library.
if function_exists "lib_register_hooks"; then
    lib_register_hooks --define libColors_define_arguments --apply libColors_apply_args
fi


