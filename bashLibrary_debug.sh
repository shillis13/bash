#!/usr/local/bin/bash
# set -x

# Part of Bl (Bash library) suite
#
# Provides a framework and functions for logging out of various
# debugging levels and runtime change of which logging levels 
# to output.  This library includes:
# 
# - Helper functions to printout messages of the different Log
#   levels (e.g., Db(), Db_Warn(), Db_Error(), etc.
#
# - Inclusion of StakeTrace library to enable the tracking and 
#   logging of an application-controlled type of stack trace.  
#   Helper functions Db_ENTRY() and DB_Exit() alls the application
#   to a stack of function calls, similar to a process stack.
#
# - Indents logs messages base on stack trace level
#

args=("$@")

# thisFile="${BASH_SOURCE[0]}"
thisFile="bashLibrary_debug.sh"
# echo "* Echo: Entered $thisFile..."

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

# *******************************************************************
# * {{{ @name: Bl_SourceLibs
# *
# * @desc:  Private-esque function to source the scripts necessary for 
# *         these functions
# *******************************************************************
Bl_SourceLibs() {
    if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi

    local args="${@}"
    # Db "$thisFile->Bl_SourceLibs: args = ${args[@]}"
    srcFiles=()

    while [ -n "$1" ]; do
        if [ "$1" == "--srcFile" ]; then 
            # Db "$thisFile: \$1 = $1"
            shift 
            srcFiles+=("$1")
        fi
        shift
    done

    # Db "srcFiles = ${srcFiles[@]}"

    for file in "${srcFiles[@]}"; do 
        if [ -z "${SourcedFiles[$file]}" ]; then 
            if declare -f sourceFile &> /dev/null; then 
                # Db "sourceFile $file ${args[@]}"; 
                sourceFile "$file" "${args[@]}"; 
            else 
                # Db "source $file ${args[@]}"; 
                source "$file" "${args[@]}"; 
            fi
            SourcedFiles[$file]="$file"
        fi
    done
}

BlDebug_SourceLibs() {
    local args=("${@}")
    filesToSrc=(bashLibrary_trace.sh)
    #

    # for f in $filesToSrc; do
    for file in "${filesToSrc[@]}"; do 
        args+=("--srcFile")
        args+=("$file")
    done
    Bl_SourceLibs "${args[@]}"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ @name: Bl_Globals()
# *
# * @desc:  Private-esque function to define and declare the global 
# *         variables necessary for these set of functions
# *******************************************************************
Bl_Globals() {

    ##########################################################################
    ### 
    ### The equivalency of puplic-static variables
    ###
    ###
    ##########################################################################
    declare -g DEBUG_ALL=255
    declare -g DEBUG_TRACE=32
    declare -g DEBUG_ENTRY=16
    declare -g DEBUG_DEBUG=8
    declare -g DEBUG_INFO=4
    declare -g DEBUG_WARN=2
    declare -g DEBUG_ERROR=1
    declare -g DEBUG_NONE=0
    declare -g DEBUG_RESET=0
    # Stored as bits in $Debug_Levels
    if [ -z "$Debug_Levels"  ]; then declare -g Debug_Levels=$DEBUG_WARN; fi


    ##########################################################################
    ### 
    ### Intended to be the equivalency of private-static variables
    ###
    ###
    ##########################################################################
    declare -g _Db_Indent_Char=' '
    declare -g _Db_Indent_Level=0

    declare -g Db_LogFile=""

    declare -g -A Db_Colors
    declare -g -A Db_Stack
}
# }}} Globals
# *******************************************************************

# *******************************************************************
# * {{{ @name: Db <db_level> <msg>
# *
# * @param: db_levels opt int @default $DEBUG_DEBUG
# * @param: msg opt string @default ""
# *
# *******************************************************************
Db() {
    # echo "Echo: Db $@"
    local db_level=$DEBUG_DEBUG
    local db_level_str="DEBUG"
    local msg=""

    if   [ -n "$2" ]; then msg=$2; db_level=$1
    elif [ -n "$1" ]; then msg=$1; fi

    local -i debugLevelIsOn=$(_Db_AreLevelsOn $db_level)

    if [ $debugLevelIsOn == 1 ]; then
        local stack_trace_line=$(Db_GetStackTraceAtIndex 2 2 1)
        Db_PrintMsg "$db_level" "$db_level_str" "$stack_trace_line" "$msg"
    fi
}
# }}} Db() - maybe remove?
# *******************************************************************

# *******************************************************************
# * {{{ @name: Db_Warn [<msg>]
# *
# * @param: msg opt string @default ""
# *
# *******************************************************************
Db_Warn() {
    # echo "Echo: Db_Warn $@"
    local db_level=$DEBUG_WARN
    local -i debugLevelIsOn=$(_Db_AreLevelsOn $db_level)

    if [ $debugLevelIsOn == 1 ]; then
        local stack_trace_line=$(Db_GetStackTraceAtIndex 2 2 1)
        local db_level_str="WARN"

        local msg=""
        if [ -n "$1" ]; then msg=$1; fi

        Db_PrintMsg "$db_level" "$db_level_str" "$stack_trace_line" "$msg"
        # Db_PrintStackTrace
    else 
        # echo "Echo: Db_Warn not turned on"
        echo -n ""
    fi
}
# }}} Db_Warn()
# *******************************************************************

# *******************************************************************
# * {{{ @name: Db_Error [<msg>]
# *
# * @param: msg opt string @default ""
# *
# *******************************************************************
Db_Error() {
    # echo "Echo: Db_Error $@"
    local db_level=$DEBUG_ERROR
    local -i debugLevelIsOn=$(_Db_AreLevelsOn $db_level)

    if [ $debugLevelIsOn == 1 ]; then
        local stack_trace_line=$(Db_GetStackTraceAtIndex 2 2 1)
        local db_level_str="ERROR"

        local msg=""
        if [ -n "$1" ]; then msg=$1; fi

        Db_PrintMsg "$db_level" "$db_level_str" "$stack_trace_line" "$msg"
        # Db_PrintStackTrace
    else 
        # echo "Echo: Db_Error not turned on"
        echo -n ""
    fi
}
# }}} Db_Error()
# *******************************************************************

# *******************************************************************
# *  {{{ @name: Db_Info [<msg>]
# *
# * @param: msg opt string @default ""
# *
# *******************************************************************
Db_Info() {
    # echo "Echo: Db_Info $@"
    local db_level=$DEBUG_INFO
    local -i debugLevelIsOn=$(_Db_AreLevelsOn $db_level)

    if [ $debugLevelIsOn == 1 ]; then
        local stack_trace_line=$(Db_GetStackTraceAtIndex 2 2 1)
        local db_level_str=" INFO"

        local msg=""
        if [ -n "$1" ]; then msg=$1; fi

        Db_PrintMsg "$db_level" "$db_level_str" "$stack_trace_line" "$msg"
    else 
        # echo "Echo: Db_Info not turned on"
        echo -n ""
    fi
}
# }}} Db_Info()
# *******************************************************************

# *******************************************************************
# * {{{ @name: Db_Entry [<msg>]
# *
# *
# *******************************************************************
Db_Entry() {
    local db_level=$DEBUG_ENTRY
    local db_level_str="ENTRY"

    if [ -z "$DEBUG_ENTRY" ]; then echo "Echo: Db_Entry: DEBUG_ENTRY is not set = $DEBUG_ENTRY"; fi 

    local -i debugLevelIsOn=$(_Db_AreLevelsOn $db_level)
    # echo "Echo: Db_Entry(): _Db_AreLevelsOn $db_level=$debugLevelIsOn"

    if [ $debugLevelIsOn == 1 ]; then
        # Db_PrintStackTrace
        local stack_trace_line=$(Db_GetStackTraceAtIndex 2 2 1)
        local msg=" "
        if [ -n "$1" ]; then msg=$1; fi

        stack+=("$stack_trace_line")
        trap _DB_EXIT EXIT

        Db_PrintMsg  "$db_level" "$db_level_str" "$stack_trace_line" "$msg" 
        _Db_Indent_Level=$((_Db_Indent_Level + 1))
    else
        # echo "Echo: Db_Entry not turned on"
        echo -n ""
    fi

}
# }}} 
# *******************************************************************

# *******************************************************************
# {{{ Db_PrintMsg()
# * @name: Db_PrintMsg <db_level> <db_level_str> <stack_line> <msg>
# *
# *
# *******************************************************************
Db_PrintMsg() {
    if [ -z "${3}" ]; then return 1; fi
    local db_level=${1}

    local -i debugLevelIsOn=$(_Db_AreLevelsOn $db_level)

    if [ $debugLevelIsOn == 1 ]; then
        local db_level_str=${2}
        local stack_line=${3}
        local msg=" "
        if [ -n "${4}" ]; then msg=${4}; fi

        local color="${Db_Colors[$db_level]}"
        local colorReset="${Db_Colors[$DEBUG_RESET]}"

        # If indent level hasn't be set yet, then print a stack trace to see why
        if [ -z "$_Db_Indent_Level" ]; then 
            echo "Debug framework not initialized??"
            Db_PrintStackTrace
        fi

        local padding=$(_Db_Padding $(($_Db_Indent_Level * 2)) )

        # IFS=':' read -r file func lineno <<< "$stack_line"

        if [ -z "$Db_LogFile" ]; then
            # exec 3>&1
            echo -n ""
        else
            # exec 3>$Db_LogFile
            echo -n ""
        fi

        # printf "%s%s[%s] [ %s ] : %s %s\n" "$color" "${padding}" "$db_level_str" "$stack_line" "$msg" "$colorReset" >%3
        printf "%s%s[%s] [ %s ] : %s %s\n" "$color" "${padding}" "$db_level_str" "$stack_line" "$msg" "$colorReset"

    else
        # echo "Echo: PrintMsg(): DebugLevel $db_level is  not turned on"
        echo -n ""
    fi
}
# }}} 
# *******************************************************************

# *******************************************************************
# {{{ Db_Padding()
# * @name: Db_Padding <pad_width> <pad_char>
# *
# * @desc: Print out a padding of pad_width copies of pad_char
# *
# *******************************************************************
_Db_Padding() {
    local pad=""
    local pad_width=0
    local pad_char="$_Db_Indent_Char"

    if [ -n "$1" ]; then pad_width=$1; fi
    if [ -n "$2" ]; then  pad_char=$2; fi
    if [ $pad_width -gt 0 ]; then 
        pad=$(printf "%*s" $((pad_width - 0)) | tr ' ' "$pad_char")
    fi
    echo $pad
}
# }}}
# *******************************************************************

# *******************************************************************
# {{{ Db_Trace()
# * @name: Db_Trace
# *
# * @desc: Print out the stack trace as captured by Db_Entry calls
# *
# *****************************************((**************************
Db_Trace() {
    local -i debugLevelIsOn=$(_Db_AreLevelsOn $DEBUG_TRACE)

    if [ $debugLevelIsOn == 1 ]; then
        printf "%s[Trace]" "${Db_Colors[$DEBUG_TRACE]}" "${Db_Colors[$DEBUG_RESET]}"
        local i
        for i in "${!stack[@]}"; do
            local padding=$(_Db_Padding $(( (i + 1) * 2 )) )
            printf "\n%s %s %s" "${padding}" "${_Db_Indent_Char}" "${stack[i]}"
        done
        printf "%s\n" "${Db_Colors[$DEBUG_RESET]}"
        # Db_PrintStackTrace  
    fi
}
# }}} Db_Trace()
# *******************************************************************

# *******************************************************************
# {{{ Update and check Debug Levels
# * @name: _Db_AreLevelsOn <db_levels>
# *
# * @param: <db_levels> req int
# *
# * @return <1|0> 1 = true the Debug Levels as represented by <db_levels 
# * are all turned on.  
# *
# *******************************************************************
_Db_AreLevelsOn() {
    # echo "Echo: _Db_AreLevelsOn ${@}"
    local retVal=0
    local level=""

    if [ -n "${1}" ]; then 
        level=${1}
    else 
        # echo "Echo: ERR: _Db_AreLevelsOn(): no debug level specified"
        Db_PrintStackTrace
        retVal=0
    fi
    if [ -z "${Debug_Levels}" ]; then 
        # echo "Echo: ERR: _Db_AreLevelsOn(): global Debug_Levels variable not yet defined"
        Db_PrintStackTrace
        retVal=0
    fi

    if [ $(($Debug_Levels & $level)) == 0 ]; then
        retVal=0
    else
        retVal=1
    fi

    # echo "Echo: _Db_AreLevelsOn(): $Debug_Levels & $level = $retVal"
    echo $retVal
    return $retVal
}

# *******************************************************************
# * @name: Db_getLowestLevelOn <db_levels_flag> 
# *
# * @param: <db_levels_flag> opt int 
# *
# *******************************************************************
Db_getLowestLevelOn() {
    local debug_levels_on=0
    local lowestLevel=0

    if [ -n "$DEBUG_LEVEL" ]; then debug_levels_on=$DEBUG_LEVEL; fi
    if [ -n "$1" ]; then debug_levels_on=$1; fi

    local i=0
    for (( i=0; i<=8; i++ )); do
        local level_on=$(( debug_levels_on & (1 << i) ))
        if [ $level_on -ne 0 ]; then
            lowestLevel=$((2**i))
            break
        fi
    done

    echo $lowestLevel
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ @name: Db_turnLevelsOn <db_levels>
# *
# * @param: <db_levels> req int the DEBUG level to turn on
# *
# * @echo / return : Turn a spcified DB Level on 
# *
# *******************************************************************
Db_turnLevelsOn() {
    local results=0

    if [ -n "$1" ]; then
        local level=$1
        Debug_Levels=$((Debug_Levels | level))
    fi
    echo "Echo: DebugLevel=$Debug_Levels"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ @name: _Db_GetLevelName <db_level>
# *
# * @desc: Return 
# *
# * @param: <db_level> req int the debug levels flags to 
# *
# *
# *******************************************************************
_Db_GetLevelName() {
    local results=0
    local level=0

    if [ -n "$1" ]; then
        level=$1
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ @name: _DB_EXIT
# *
# * @Note: essentially a const, private method; not one used explicitly
# *
# *******************************************************************
_DB_EXIT() {
    if [ -z "$_Db_Indent_Level" ]; then declare -gi _Db_Indent_Level=0;
        else _Db_Indent_Level=$(($_Db_Indent_Level - 1)); fi
    if [ $_Db_Indent_Level -lt 0 ]; then _Db_Indent_Level=0; fi

    local stack_trace_line="${stack[-1]}" # get last stack entry added by Db_Entry
    unset 'stack[-1]' # remove the last stack entry

    local -i debugLevelIsOn=$(_Db_AreLevelsOn $DEBUG_ENTRY)

    if [ $debugLevelIsOn == 1 ]; then
        local db_level=$DEBUG_ENTRY
        local db_level_str=" EXIT"
        local msg=" "

        Db_PrintMsg "$db_level" "$db_level_str" "$stack_trace_line" "$msg"
    fi
}
# }}} _DB_EXIT()
# *******************************************************************

# *******************************************************************
# * {{{ @name: Db_Init [<db_level>] [<IndentStr>]
# *
# * @param: <db_flags> opt int/bitflags
# * @param: <IndentStr> opt str in indent debug print outs
# *
# *******************************************************************
Db_Init() {
    # echo "Db_Init ${@}"
    local args=("$@")

    Bl_Globals
    Db_parse_args ${args[@]}

    if [ -z "$Debug_Levels"  ]; then declare -g Debug_Levels=$DEBUG_ALL; fi
    if [ -z "$_Db_Indent_Level" ]; then declare -g _Db_Indent_Level=0; fi
    if [ -z "$_Db_Indent_Char"   ]; then declare -g _Db_Indent_Char=" "; fi

    # if [ -n "$1" ]; then Debug_Levels=$1; fi
    # if [ -n "$2" ]; then _Db_Indent_Char=$2; fi

    # Check if terminal supports color
    # Get the number of colors supported by the terminal
    local colors=$(tput colors)
    if [ $colors -gt 0 ] && tput setaf 0 &> /dev/null; then
        red=$(tput setaf 1)
        green=$(tput setaf 2)
        yellow=$(tput setaf 3)
        blue=$(tput setaf 4)
        magenta=$(tput setaf 5)
        cyan=$(tput setaf 6)
        white=$(tput setaf 7)
        reset=$(tput sgr0)
    else
        red=""
        green=""
        yellow=""
        blue=""
        magenta=""
        cyan=""
        white=""
        reset=""
    fi

    Db_Colors=(
        [$DEBUG_TRACE]=$(echo $cyan)
        [$DEBUG_ENTRY]=$(echo $cyan)
        [$DEBUG_DEBUG]=$(echo $cyan)
        [$DEBUG_INFO]=$(echo $white)
        [$DEBUG_WARN]=$(echo $yellow)
        [$DEBUG_ERROR]=$(echo $red)
        [$DEBUG_RESET]=$(echo $reset)
    )

    Bl_SourceLibs ${args[@]}
    Db_Info "DB_Init Completed: Debug_Levels = $Debug_Levels"
}
# }}} Db_Init()
# *******************************************************************

# *******************************************************************
# {{{ Db_parse_args
# * Parse command line args
# *
# *******************************************************************
Db_parse_args() {
    #echo "Echo: Db_parse_args: ${@}"
    local f="Db_parse_args"
    while [[ $# -gt 0 ]]
    do
        # Set debug level
        if [[ "$1" == "--debugLevel" ]]; then
            if [ -z "$Debug_Levels"  ]; then declare -g Debug_Levels=0; fi
            Db_turnLevelsOn $2
            shift 
            echo "Debug_Levels=$Debug_levels"
        fi

        # Log to a file
        if [[ "$1" == "--dbLogFile" ]]; then
            if [ -z "$Db_LogFile"  ]; then declare -g Db_LogFile=""; fi
            Db_LogFile=$2
            shift 
        fi

        # Print help
        if [[ "$1" == "--help" ]]; then
            helpTopic=$(echo $2 | tr '[:upper:]' '[:lower:]')
            if [[ "$helpTopic" == "debug" ]]; then
                Db_print_usage
            fi
            shift 
        fi

        shift
    done
}
# }}} Db_parse_args()
# *******************************************************************

# Db "args = ${args[@]}"
if [ -z "$Db_Initialized" ]; then Db_Init ${args[@]}; declare -g Db_Initialized=1; fi

