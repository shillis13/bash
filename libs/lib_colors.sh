#!/usr/bin/env bash

# Part of the 'lib' suite.
# Defines functions and variables for terminal colors using tput.

# Sourcing Guard
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename/./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

Use_Color_Type="tput"

# Defines all color variables using tput for color-enabled terminals.
Fcn_Define_Colors_Tp() {
    # --- Direct tput Color Codes ---
    Tp_Reset="$(tput sgr0)"
    Tp_Fg_Black="$(tput setaf 0)"; Tp_Fg_Red="$(tput setaf 1)"; Tp_Fg_Green="$(tput setaf 2)"; Tp_Fg_Yellow="$(tput setaf 3)";
    Tp_Fg_Blue="$(tput setaf 4)"; Tp_Fg_Magenta="$(tput setaf 5)"; Tp_Fg_Cyan="$(tput setaf 6)"; Tp_Fg_White="$(tput setaf 7)";
    Tp_Fg_Gray="$(tput setaf 8)";
    Tp_Bg_Black="$(tput setab 0)"; Tp_Bg_Red="$(tput setab 1)"; Tp_Bg_Green="$(tput setab 2)"; Tp_Bg_Yellow="$(tput setab 3)";
    Tp_Bg_Blue="$(tput setab 4)"; Tp_Bg_Magenta="$(tput setab 5)"; Tp_Bg_Cyan="$(tput setab 6)"; Tp_Bg_White="$(tput setab 7)";

    # --- Semantic Aliases ---
    Color_Reset="$Tp_Reset"
    Color_Debug="$Tp_Fg_Gray"
    Color_Instr="$Tp_Fg_Cyan"
    Color_Info="$Tp_Fg_White"
    Color_Warn="$Tp_Fg_Yellow"
    Color_Error="$Tp_Fg_Red"
    Color_Success="$Tp_Fg_Green"
    Color_Test="$Tp_Fg_Green" # New color for test-specific logs
    Color_EntryExit="$Tp_Fg_Magenta"
}

# Defines empty color variables for non-color terminals.
Fcn_Undefine_Colors() {
    Tp_Reset=""; Tp_Fg_Black=""; Tp_Fg_Red=""; Tp_Fg_Green=""; Tp_Fg_Yellow=""; Tp_Fg_Blue=""; Tp_Fg_Magenta="";
    Tp_Fg_Cyan=""; Tp_Fg_White=""; Tp_Fg_Gray=""; Tp_Bg_Black=""; Tp_Bg_Red=""; Tp_Bg_Green=""; Tp_Bg_Yellow="";
    Tp_Bg_Blue=""; Tp_Bg_Magenta=""; Tp_Bg_Cyan=""; Tp_Bg_White="";
    Color_Reset=""; Color_Debug=""; Color_Instr=""; Color_Info=""; Color_Warn=""; Color_Error="";
    Color_Success=""; Color_Test=""; Color_EntryExit="";
}

# Initializes the color variables for the shell session.
fcn_init_colors() {
    if [[ "$Use_Color_Type" == "tput" ]] && tput setaf 1 > /dev/null 2>&1; then
        Fcn_Define_Colors_Tp
    else
        Fcn_Undefine_Colors
    fi
}

