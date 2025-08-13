#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_stackTrace.sh
#
# DESCRIPTION: Provides functions for capturing and displaying the call stack.
#
# REQUIREMENTS:
#   - lib_colors.sh
#   - lib_format.sh
#   - lib_logging.sh
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
    lib_require "lib_colors.sh"
    lib_require "lib_format.sh"
    lib_require "lib_logging.sh"
}

# ==============================================================================
# GLOBALS
# ==============================================================================

# Default maximum widths for the columns in the pretty-printed stack trace.
# These can be overridden by calling Stack_setMaxWidths.
g_stack_max_width_file=40
g_stack_max_width_func=35
g_stack_max_width_line=5

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCTION: Stack_setMaxWidths
#
# DESCRIPTION:
#   Sets the maximum column widths for the pretty-printed stack trace output.
#
# USAGE:
#   Stack_setMaxWidths [--file W] [--func W] [--line W]
#
# PARAMETERS:
#   --file (integer): Max width for the file path column.
#   --func (integer): Max width for the function name column.
#   --line (integer): Max width for the line number column.
# ------------------------------------------------------------------------------
Stack_setMaxWidths() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file) g_stack_max_width_file=$2; shift 2 ;;
            --func) g_stack_max_width_func=$2; shift 2 ;;
            --line) g_stack_max_width_line=$2; shift 2 ;;
            *) log --warn "Unknown argument to Stack_setMaxWidths: $1"; shift ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# FUNCTION: Stack_get
#
# DESCRIPTION:
#   Retrieves the current call stack and stores it in a provided array variable.
#   Each array element is a string in the format "file:line:function".
#
# USAGE:
#   Stack_get <array_name> [--skip N] [--max M]
#
# PARAMETERS:
#   array_name (string): The name of the array to populate with stack data.
#   --skip N (integer, optional): Skips the first N frames of the stack.
#   --max M (integer, optional): Returns at most M frames.
# ------------------------------------------------------------------------------
Stack_get() {
    if [[ -z "$1" ]]; then
        log --error "Stack_get requires an array name to store the result."
        return 1
    fi
    local -n stack_ref=$1
    shift

    local skip=0
    local max=-1

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip) skip=$2; shift 2 ;;
            --max) max=$2; shift 2 ;;
            *) shift ;;
        esac
    done

    # Start at index 1 to skip this function (Stack_get) itself.
    # The user's --skip value is added to this baseline.
    local current_frame_index=1
    local frames_collected=0

    # Clear the target array
    stack_ref=()

    while true; do
        # Retrieve frame data using `caller`
        local frame_info
        frame_info=$(caller $current_frame_index)
        if [[ -z "$frame_info" ]]; then
            break # No more frames in the stack
        fi

        # Skip the requested number of frames
        if [[ $current_frame_index -le $skip ]]; then
            ((current_frame_index++))
            continue
        fi

        # Parse the frame data: <line> <function> <file>
        local line_num function_name file_path
        read -r line_num function_name file_path <<< "$frame_info"

        # Tidy up common values
        [[ "$function_name" == "main" ]] && function_name="<main>"
        [[ "$function_name" == "source" ]] && function_name="<source>"
        file_path=$(basename "$file_path")

        stack_ref+=("${file_path}:${line_num}:${function_name}")
        ((frames_collected++))

        # Stop if max frames have been collected
        if [[ $max -ne -1 && $frames_collected -ge $max ]]; then
            break
        fi

        ((current_frame_index++))
    done
}

# ------------------------------------------------------------------------------
# FUNCTION: Stack_prettyPrint
#
# DESCRIPTION:
#   Prints a formatted, colored, and aligned stack trace to the console.
#
# USAGE:
#   Stack_prettyPrint [--skip N] [--max M] [--no-color]
#
# PARAMETERS:
#   --skip N (integer, optional): Skips the first N frames. Skips 1 by default
#                                 to exclude the call to this function.
#   --max M (integer, optional): Returns at most M frames.
#   --no-color (switch, optional): Disables colored output.
# ------------------------------------------------------------------------------
Stack_prettyPrint() {
    local use_color=$TRUE
    # Skip this prettyPrint function itself by default.
    local skip=1
    local max=-1

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-color) use_color=$FALSE; shift ;;
            --skip) skip=$2; shift 2 ;;
            --max) max=$2; shift 2 ;;
            *) shift ;;
        esac
    done

    local stack_data
    Stack_get stack_data --skip "$skip" --max "$max"

    if [[ ${#stack_data[@]} -eq 0 ]]; then
        return
    fi

    # --- Calculate column widths based on content ---
    local max_file=0 max_func=0 max_line=0
    local file line func
    for frame in "${stack_data[@]}"; do
        IFS=':' read -r file line func <<< "$frame"
        [[ ${#file} -gt $max_file ]] && max_file=${#file}
        [[ ${#func} -gt $max_func ]] && max_func=${#func}
        [[ ${#line} -gt $max_line ]] && max_line=${#line}
    done

    # --- Apply global max width constraints ---
    [[ $max_file -gt $g_stack_max_width_file ]] && max_file=$g_stack_max_width_file
    [[ $max_func -gt $g_stack_max_width_func ]] && max_func=$g_stack_max_width_func
    [[ $max_line -gt $g_stack_max_width_line ]] && max_line=$g_stack_max_width_line

    # --- Print Header ---
    local header_file header_func header_line
    header_file=$(PadText "File" "$max_file" "center")
    header_func=$(PadText "Function" "$max_func" "center")
    header_line=$(PadText "Line" "$max_line" "center")

    if (( use_color )); then
        printf "%s%s  %s  %s%s\n" "${c_bold}${c_cyan}" "$header_file" "$header_func" "$header_line" "${c_reset}"
    else
        printf "%s  %s  %s\n" "$header_file" "$header_func" "$header_line"
    fi

    # --- Print stack frames ---
    for frame in "${stack_data[@]}"; do
        IFS=':' read -r file line func <<< "$frame"

        local p_file p_func p_line
        p_file=$(PadText "$file" "$max_file" "left" " ")
        p_func=$(PadText "$func" "$max_func" "left" " ")
        p_line=$(PadText "$line" "$max_line" "right" " ")

        if (( use_color )); then
            printf "%s%s%s  %s%s%s  %s%s%s\n" "${c_yellow}" "$p_file" "${c_reset}" "${c_green}" "$p_func" "${c_reset}" "${c_cyan}" "$p_line" "${c_reset}"
        else
            printf "%s  %s  %s\n" "$p_file" "$p_func" "$p_line"
        fi
    done
}

# ------------------------------------------------------------------------------
# FUNCTION: Stack_getLine
#
# DESCRIPTION:
#   Returns a single line from the stack trace by its index.
#
# USAGE:
#   Stack_getLine <index> [--skip N]
#
# PARAMETERS:
#   index (integer): The 0-based index of the stack frame to retrieve.
#   --skip N (integer, optional): Skips the first N frames before indexing.
#
# OUTPUT:
#   Prints the requested stack frame line to stdout.
# ------------------------------------------------------------------------------
Stack_getLine() {
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        log --error "Stack_getLine requires a numeric index as the first argument."
        return 1
    fi
    local index=$1
    shift

    local stack_data
    # Pass the remaining arguments (--skip) to Stack_get
    Stack_get stack_data "$@"

    if [[ $index -ge 0 && $index -lt ${#stack_data[@]} ]]; then
        echo "${stack_data[$index]}"
    else
        log --error "Stack trace index ($index) is out of bounds."
        return 1
    fi
}

# Source dependencies
load_dependencies
