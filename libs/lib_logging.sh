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

# --- Guard ---
[[ -z "$LIB_LOGGING_LOADED" ]] && readonly LIB_LOGGING_LOADED=1 || return 0

# --- Dependencies ---
# This check ensures we can source dependencies even if this script is sourced
# from a different directory.
LIB_LOGGING_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
if [[ -f "$LIB_LOGGING_DIR/lib_colors.sh" ]]; then
    source "$LIB_LOGGING_DIR/lib_colors.sh"
fi

# ==============================================================================
# GLOBALS
# ==============================================================================

# --- Log Levels (Powers of Two for Bitmasking) ---
readonly g_log_lvl_none=0
readonly g_log_lvl_error=1
readonly g_log_lvl_warn=2
readonly g_log_lvl_instr=4
readonly g_log_lvl_info=8
readonly g_log_lvl_debug=16
readonly g_log_lvl_entryexit=32
readonly g_log_lvl_all=63 # Sum of all levels above

# --- Configuration Globals ---
g_log_level=${g_log_lvl_info} # Default numeric level
g_log_level_str="Info"         # Default string for the command-line arg
g_log_file=""
g_log_show_color=true

# --- Log Colors ---
c_error="${c_bold}${c_red}"
c_instr="${c_bold}${c_magenta}"
c_warn="${c_bold}${c_yellow}"
c_info="${c_bold}${c_green}"
c_debug="${c_cyan}"
c_entryexit="${c_blue}"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: libLogging_define_arguments
#
# DESCRIPTION: Defines command-line arguments for logging functionality.
# ------------------------------------------------------------------------------
libLogging_define_arguments() {
    libCmd_add -t value --long logLevel -v "g_log_level_str" -d "Info" -m once -u "Set the logging level (None, Error, Warn, Info, Debug, All)."
    libCmd_add -t value --long logFile   -v "g_log_file"      -r n     -m once -u "Redirect all log output to the specified file."
}

# ------------------------------------------------------------------------------
# FUNCTION: libLogging_apply_args
#
# DESCRIPTION: Applies logic based on parsed logging arguments.
# ------------------------------------------------------------------------------
libLogging_apply_args() {
    log_set_level_from_string "$g_log_level_str"
}

# ------------------------------------------------------------------------------
# FUNCTION: log_level_to_string
# DESCRIPTION: Converts a log level number to its string representation.
# ------------------------------------------------------------------------------
log_level_to_string() {
    case $1 in
        $g_log_lvl_error)     echo "ERROR";;
        $g_log_lvl_warn)      echo "WARN";;
        $g_log_lvl_instr)     echo "INSTR";;
        $g_log_lvl_info)      echo "INFO";;
        $g_log_lvl_debug)     echo "DEBUG";;
        $g_log_lvl_entryexit) echo "TRACE";;
        *)                    echo "UNKNOWN";;
    esac
}

# ------------------------------------------------------------------------------
# FUNCTION: log_level_from_string
# DESCRIPTION: Converts a log level string to its numeric value.
# ------------------------------------------------------------------------------
log_level_from_string() {
    local level_str
    level_str=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    case "$level_str" in
        "NONE")      echo $g_log_lvl_none;;
        "ERROR")     echo $g_log_lvl_error;;
        "WARN")      echo $((g_log_lvl_error | g_log_lvl_warn));;
        "INSTR")     echo $((g_log_lvl_error | g_log_lvl_warn | g_log_lvl_instr));;
        "INFO")      echo $((g_log_lvl_error | g_log_lvl_warn | g_log_lvl_instr | g_log_lvl_info));;
        "DEBUG")     echo $((g_log_lvl_error | g_log_lvl_warn | g_log_lvl_instr | g_log_lvl_info | g_log_lvl_debug));;
        "ENTRYEXIT") echo $g_log_lvl_all;;
        "ALL")       echo $g_log_lvl_all;;
        *)           echo $g_log_lvl_info;; # Default
    esac
}

# ------------------------------------------------------------------------------
# FUNCTION: log_set_level_from_string
# DESCRIPTION: Sets the global log level from a string.
# ------------------------------------------------------------------------------
log_set_level_from_string() {
    g_log_level=$(log_level_from_string "$1")
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
#   $2 (integer): The stack frame index of the original caller.
# ------------------------------------------------------------------------------
_log_get_metadata() {
    local level=$1
    local caller_idx=$2
    local meta_str=""

    # 1. Timestamp
    meta_str+=$(date +"[%Y-%m-%d %H:%M:%S] ")

    # 2. Log Level Tag
    local level_tag
    level_tag=$(log_level_to_string "$level")
    meta_str+="[${level_tag}] "

    # 3. Caller Info (File, Line, Function)
    local func_name="${FUNCNAME[$caller_idx]}"
    local line_num="${BASH_LINENO[$((caller_idx-1))]}"
    local file_name
    file_name=$(basename "${BASH_SOURCE[$caller_idx]}")

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
    local level=$1
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
    if [[ "$always" == true || ((g_log_level & level)) -ne 0 ]]; then
        local msg="$*"
        local out_str=""
        local file_out_str=""

        if [[ "$msg_only" == true ]]; then
            out_str="$msg"
            file_out_str="$msg"
        else
            # Determine the correct caller index on the stack
            local caller_idx=1
            if [[ "${FUNCNAME[1]}" == "log_entry" || "${FUNCNAME[1]}" == "log_exit" || "${FUNCNAME[1]}" == "log_banner" ]]; then
                caller_idx=2
            fi

            # Get metadata and append the message
            file_out_str=$(_log_get_metadata "$level" "$caller_idx")
            file_out_str+="$msg"
            out_str="$file_out_str"

            # Add color for console output if enabled
            if [[ "$g_log_show_color" == true ]]; then
                local color
                case $level in
                    $g_log_lvl_error)     color="$c_error";;
                    $g_log_lvl_warn)      color="$c_warn";;
                    $g_log_lvl_instr)     color="$c_instr";;
                    $g_log_lvl_info)      color="$c_info";;
                    $g_log_lvl_debug)     color="$c_debug";;
                    $g_log_lvl_entryexit) color="$c_entryexit";;
                esac
                out_str="${color}${out_str}${c_reset}"
            fi
        fi

        # Print to stderr and file
        echo -e "$out_str" >&2
        if [[ -n "$g_log_file" ]]; then
            echo -e "$file_out_str" >> "$g_log_file"
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
    log $g_log_lvl_info -Always -MsgOnly "$banner"
    log $g_log_lvl_info -Always -MsgOnly "$msg"
    log $g_log_lvl_info -Always -MsgOnly "$banner"
}

# ------------------------------------------------------------------------------
# FUNCTION: log_entry / log_exit
# DESCRIPTION: Convenience functions for tracing function entry and exit.
# ------------------------------------------------------------------------------
log_entry() {
    log $g_log_lvl_entryexit "--> ENTER: ${FUNCNAME[1]}"
}

log_exit() {
    log $g_log_lvl_entryexit "<-- EXIT:  ${FUNCNAME[1]}"
}

# --- Self-Registration ---
# Register hooks with the main library to be called at the correct time.
if function_exists "lib_register_hooks"; then
    lib_register_hooks --define libLogging_define_arguments --apply libLogging_apply_args
fi


