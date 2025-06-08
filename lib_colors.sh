Color_Type_Tput="tput"  # Constant string for using terminal database
Color_Type_Ansi="ansi"  # Constant string for using ANSI escape codes
                        # ANSI escape codes not yet implemented
Use_Color_Type="tput"  # Select color type

# ******************************************************
# {{{ initialize colors
fcn_init_colors() {
    if [ -z "$Use_Color_Type" ] || [ "$Use_Color_Type" != false ]; then
        if [ "$Use_Color_Type" == "$Color_Type_Tput" ]; then
            Fcn_Define_Colors_Tp
            log_debug "$(thisFile):$LINENO: Using color type: $Use_Color_Type." >&2
        else 
            if [ "$Use_Color_Type" == "$Other_Colors" ]; then
                log_debug "$(thisFile):$LINENO: No colors defined." >&2
            fi
        fi
    else
        log_debug "$(thisFile):$LINENO: variable Use_Color_Type is false or not defined" >&2
    fi
} # }}}
# ******************************************************

# ******************************************************
# * {{{ Terminal color codes 
# * 
# ******************************************************
Fcn_Define_Colors_Tp() {
    Tp_Bg_Reset="$(tput setab 9)"
    # Tp_Fg_Reset="$(tput setaf 9)"
    Tp_Fg_Reset="$(tput setaf 9)$(tput sgr0)"
    Color_Reset="$Tp_Fg_Reset"

    # tput setaf = Set Foreground Colors
    Tp_Fg_Black="$(tput setaf 0)"
    Tp_Fg_Red="$(tput setaf 1)"
    Tp_Fg_Green="$(tput setaf 2)"
    Tp_Fg_Yellow="$(tput setaf 3)"
    Tp_Fg_Blue="$(tput setaf 4)"
    Tp_Fg_Magenta="$(tput setaf 5)"
    Tp_Fg_Cyan="$(tput setaf 6)"
    Tp_Fg_White="$(tput setaf 7)"

    # tput setab = Set Background Colors
    Tp_Bg_Black="$(tput setab 0)"
    Tp_Bg_Red="$(tput setab 1)"
    Tp_Bg_Green="$(tput setab 2)"
    Tp_Bg_Yellow="$(tput setab 3)"
    Tp_Bg_Blue="$(tput setab 4)"
    Tp_Bg_Magenta="$(tput setab 5)"
    Tp_Bg_Cyan="$(tput setab 6)"
    Tp_Bg_White="$(tput setab 7)"

    Color_Debug="$Tp_Fg_Blue"
    Color_Instr="$Tp_Fg_Green"
    Color_Info="$Tp_Fg_White"
    Color_Warn="$Tp_Fg_Yellow"
    Color_Error="$Tp_Fg_Red"
    Color_Success="$Tp_Fg_Cyan"
    Color_Trace="$Tp_Fg_Yellow"

    Tp_Bg_Black="$(tput setab 0)"
    Tp_Fg_White="$(tput setaf 7)"
}
# }}}
# ******************************************************

fcn_init_colors
