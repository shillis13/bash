#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_logging.sh
#
# DESCRIPTION: A logging library with bitmask levels, color, and file support.
#
# REQUIREMENTS:
#   - lib_colors.sh
# ==============================================================================

# --- Required Sourcing ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_core.sh"

# Sourcing Guard
# Create a sanitized, unique variable name from the filename.
isSourcedName="$(sourced_name ${BASH_SOURCE[0]})" 
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 0; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
load_dependencies() {
    lib_require "lib_thisFile.sh"
    lib_require "lib_colors.sh"
    
    # --- Self-Registration ---
    # Register hooks with the main library to be called at the correct time.
    if function_exists "register_hooks"; then
        register_hooks --define libLogging_define_arguments --apply libLogging_apply_args
    fi

    _setColors
}

# ==============================================================================
# GLOBALS
# ==============================================================================

# --- Log Levels (Powers of Two for Bitmasking) ---
readonly LogLvl_None=0
readonly LogLvl_Error=1
readonly LogLvl_Warn=2
readonly LogLvl_Instr=4
readonly LogLvl_Info=8
readonly LogLvl_Debug=16
readonly LogLvl_EntryExit=32
readonly LogLvl_All=64 # Sum of all levels above

# --- Configuration Globals ---
#LoggingLevel=${LogLvl_EntryExit} # Default numeric level
#LogLevelStr="EntryExit"         # Default string for the command-line arg
LoggingLevel=${LogLvl_Info} # Default numeric level
LogLevelStr="INFO"         # Default string for the command-line arg
LogFile=""
LogShowColor=true

# Colors are initially nothing because lib_colors has not been initialized  yet
c_error=""
c_instr=""
c_warn=""
c_info=""
c_debug=""
c_entryexit=""

# --- Log Colors ---
function _setColors() {
    c_error="${c_bold}${c_red}"
    c_instr="${c_bold}${c_magenta}"
    c_warn="${c_bold}${c_yellow}"
    c_info="${c_bold}${c_green}"
    c_debug="${c_cyan}"
    c_entryexit="${c_blue}"
}

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: libLogging_define_arguments
#
# DESCRIPTION: Defines command-line arguments for logging functionality.
# ------------------------------------------------------------------------------
libLogging_define_arguments() {
    # echo "Logging: libLogging_define_arguments"
    libCmd_add -t value --long logLevel -v "LogLevelStr" -d "Info" -m once -u "Set the logging level (None, Error, Warn, Info, Debug, All)."
    libCmd_add -t value --long logFile  -v "LogFile"     -r n      -m once -u "Redirect all log output to the specified file."
}

# ------------------------------------------------------------------------------
# FUNCTION: libLogging_apply_args
#
# DESCRIPTION: Applies logic based on parsed logging arguments.
# ------------------------------------------------------------------------------
libLogging_apply_args() {
    echo "Logging: libLogging_apply_args: SetLogLevel $LogLevelStr"
    Stack_prettyPrint --max 10
    SetLogLevel "$LogLevelStr"
}

# ------------------------------------------------------------------------------
# FUNCTION: ToString_LogLvl
# DESCRIPTION: Converts a log level number to its string representation.
# ------------------------------------------------------------------------------
ToString_LogLvl() {
    if   [[ "$1" == "$LogLvl_None"  ]]; then  echo "NONE"
    elif [[ "$1" == "$LogLvl_Error" ]]; then  echo "ERROR"
    elif [[ "$1" == "$LogLvl_Warn"  ]]; then  echo "WARN"
    elif [[ "$1" == "$LogLvl_Instr" ]]; then  echo "INSTR"
    elif [[ "$1" == "$LogLvl_Info"  ]]; then  echo "INFO"
    elif [[ "$1" == "$LogLvl_Debug" ]]; then  echo "DEBUG"
    elif [[ "$1" == "$LogLvl_All"   ]]; then  echo "ALL"
    elif [[ "$1" == "$LogLvl_EntryExit" ]]; then echo "TRACE"
    else echo "UNKNOWN"
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: ToLogLvl_FromString
# DESCRIPTION: Converts a log level string to its numeric value.
# ------------------------------------------------------------------------------
ToLogLvl_FromString() {
    local level_str
    # Remove leading '-' or '--' (one or more dashes)
    level_str=$(echo "$1" | sed 's/^--*//; s/^\s*//; s/\s*$//')
    level_str=$(echo "$level_str" | tr '[:lower:]' '[:upper:]')
    if   [[ "$level_str" == "NONE"  ]]; then   echo "$LogLvl_None"
    elif [[ "$level_str" == "ERROR" ]]; then   echo "$LogLvl_Error"
    # elif [[ "$level_str" == "WARN"  ]]; then   echo "$((LogLvl_Error | LogLvl_Warn))"
    # elif [[ "$level_str" == "INSTR" ]]; then   echo "$((LogLvl_Error | LogLvl_Warn | LogLvl_Instr))"
    # elif [[ "$level_str" == "INFO"  ]]; then   echo "$((LogLvl_Error | LogLvl_Warn | LogLvl_Instr | LogLvl_Info))"
    # elif [[ "$level_str" == "DEBUG" ]]; then   echo "$((LogLvl_Error | LogLvl_Warn | LogLvl_Instr | LogLvl_Info | LogLvl_Debug))"
    elif [[ "$level_str" == "WARN"  ]]; then   echo "$LogLvl_Warn"
    elif [[ "$level_str" == "INSTR" ]]; then   echo "$LogLvl_Instr"
    elif [[ "$level_str" == "INFO"  ]]; then   echo "$LogLvl_Info"
    elif [[ "$level_str" == "DEBUG" ]]; then   echo "$LogLvl_Debug"
    elif [[ "$level_str" == "ALL"   ]]; then   echo "$LogLvl_All"
    elif [[ "$level_str" == "ENTRYEXIT" ]]; then echo "$LogLvl_EntryExit"
    else  
        echo "$LogLvl_Info"
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: log_set_level_from_string
# DESCRIPTION: Sets the global log level from a string.
# ------------------------------------------------------------------------------
SetLogLevel() {
    echo "SetLogLevel: $1"
    LogLevel=$(ToLogLvl_FromString "$1")
}

# ------------------------------------------------------------------------------
# FUNCTION: _log_get_metadata
#
# DESCRIPTION:
#   An internal, extensible function to generate the metadata prefix for a
#   log message.
#
# PARAMETERS:
#   $1 (integer): The log level of the message.
#   $2 (integer, optional): The stack frame index of the original caller (default 0).
# ------------------------------------------------------------------------------
_log_get_metadata() {
    local msgLogLevel=$1
    local caller_idx=${2:-0}
    caller_idx=$((caller_idx + 1))
    local meta_str=""

    # 1. Timestamp
    meta_str+=$(date +"[%Y-%m-%d %H:%M:%S] ")

    # 2. Log Level Tag
    local level_tag
    level_tag=$(ToString_LogLvl "$msgLogLevel")
    meta_str+="[${level_tag}] "

    # 3. Caller Info (File, Line, Function)
    local func_name="${FUNCNAME[$caller_idx]}"
    local line_num="${BASH_LINENO[$((caller_idx-1))]}"
    local file_name
    file_name=$(thisCaller "$caller_idx")

    if [[ -z "$func_name" || "$func_name" == "main" || "$func_name" == "source" ]]; then
        func_name="<script>"
    else
        func_name="${func_name}()"
    fi
    meta_str+="[${file_name}:${line_num} ${func_name}] "

    echo "$meta_str"
}

# ------------------------------------------------------------------------------
# FUNCTION: log
#
# DESCRIPTION:
#   The core logging function. Prints a formatted message to stderr and/or a
#   log file based on a bitmask level check.
#
# USAGE:
#   log <LEVEL> [-MsgOnly] [-Always] "My message"
# ------------------------------------------------------------------------------
log() {
    # echo "Log: " "$@"
    local msgLogLevel=""
    local caller_idx=0
    # If first arg is a number, treat as caller_idx
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        caller_idx=$1
        shift
    fi
    level=$(ToLogLvl_FromString "$1")
    shift
    local msg_only=false
    local always=false

    # Parse flags
    while true; do
        case "$1" in
            -MsgOnly) msg_only=true; shift;;
            -Always)  always=true;   shift;;
            *) break;;
        esac
    done

    # Check if the message should be logged
    # if [[ "$always" == true ]] || (( (LogLevel & msgLogLevel) != 0 )); then
    if [[ "$always" == true ]] || (( $level <= $LoggingLevel )); then
        local msg="$*"
        local out_str=""
        local file_out_str=""

        # Only show metadata for non-MsgOnly and non-Instr
        if [[ "$msg_only" == true ]] || [[ "$level" == "$LogLvl_Instr" ]]; then
            out_str="$msg"
            file_out_str="$msg"
        else
            caller_idx=$((caller_idx + 1))
            file_out_str=$(_log_get_metadata "$level" "$caller_idx")
            file_out_str+="$msg"
            out_str="$file_out_str"
        fi

        # Add color for console output if enabled
        if [[ "$LogShowColor" == true ]]; then
            local color
            if   [[ "$level" == "$LogLvl_Error" ]]; then     color="$c_error"
            elif [[ "$level" == "$LogLvl_Warn"  ]]; then     color="$c_warn"
            elif [[ "$level" == "$LogLvl_Instr" ]]; then     color="$c_instr"
            elif [[ "$level" == "$LogLvl_Info"  ]]; then     color="$c_info"
            elif [[ "$level" == "$LogLvl_Debug" ]]; then     color="$c_debug"
            elif [[ "$level" == "$LogLvl_EntryExit" ]]; then color="$c_entryexit"
            fi
            out_str="${color}${out_str}${c_reset}"
        fi

        # Print to stderr and file
        echo -e "$out_str" >&2
        if [[ -n "$LogFile" ]]; then
            echo -e "$file_out_str" >> "$LogFile"
        fi
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: log_banner
# DESCRIPTION: Prints a message inside a highly visible banner.
# ------------------------------------------------------------------------------
log_banner() {
    local msg=" $1 "
    local banner_width=80
    local banner_char="#"
    local banner
    banner=$(printf "%*s" "$banner_width" "")
    banner=${banner// /$banner_char}

    # Banners should always be visible
    log -Always -MsgOnly "$banner"
    log -Always -MsgOnly "$msg"
    log  -Always -MsgOnly "$banner"
}

# ------------------------------------------------------------------------------
# FUNCTION: log_entry / log_exit
# DESCRIPTION: Convenience functions for tracing function entry and exit.
# ------------------------------------------------------------------------------
log_entry() {
    local caller_idx=1
    local msg=""
    if [[ $# -gt 0 ]] ; then msg="${1}" ; fi
    log $caller_idx "EntryExit" "--> ENTER: ${FUNCNAME[1]} $msg"
}

log_exit() {
    local caller_idx=1
    local msg=""
    if [[ $# -gt 0 ]] ; then msg="${1}" ; fi
    log $caller_idx "EntryExit" "<-- EXIT:  ${FUNCNAME[1]} $msg"
}

# Source the dependencies
load_dependencies
