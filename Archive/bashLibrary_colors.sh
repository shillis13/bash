#!/usr/local/bin/bash

thisFile="bashLibrary_colors.sh"

# ******************************************************
# * {{{ Terminal color codes 
# * 
# ******************************************************
TP_COLORS="tput"
Use_Colors=$Tp_Colors

if [ -z "$Use_Colors" ] || [ "$Use_Colors" != false ]; then
    if [ "$Use_Colors" == "$TP_COLORS" ]; then
        Use_Colors_Tp
    else 
        if [ "$Use_Colors" == "$Other_Colors" ]; then
            echo ""
        fi
    fi
fi

Use_Colors_Tp() {
    Tp_Bg_Reset="$(tput setab 9)"
    Tp_Fg_Reset="$(tput setaf 9)"
    Color_Reset="$(Tp_Fg_Reset)"

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

    Color_Instr="$(Tp_Fg_Green)"
    Color_Info="$(Tp_Fg_White)"
    Color_Warning="$(Tp_Fg_Yellow)"
    Color_Error="$(Tp_Fg_Red)"
    Color_Success="$(Tp_Fg_Cyan)"

    Tp_Bg_Black="$(tput setab 0)"
    Tp_Fg_White="$(tput setaf 7)"
}
# }}}
# ******************************************************

