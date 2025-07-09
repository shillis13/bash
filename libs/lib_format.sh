#!/usr/bin/env bash
#
# Part of the 'lib' suite.
# Provides functions for formatting and coloring output.

# Sourcing Guard
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename/./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_thisFile.sh"
lib_require "lib_colors.sh"

#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_format.sh
#
# DESCRIPTION: A library of text formatting and printing functions.
#
# REQUIREMENTS:
#   - lib_logging.sh
# ==============================================================================

# --- Guard ---
[[ -z "$LIB_FORMAT_LOADED" ]] && readonly LIB_FORMAT_LOADED=1 || return 0

# --- Dependencies ---
LIB_FORMAT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$LIB_FORMAT_DIR/lib_logging.sh"

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# --- Functions ---
format_color_by_threshold() {
    local value="$1"
    local warn_thresh="$2"
    local err_thresh="$3"

    # bc -l is used for floating point comparison
    if (( $(echo "$value >= $err_thresh" | bc -l) )); then
        echo "$Color_Error"
    elif (( $(echo "$value >= $warn_thresh" | bc -l) )); then
        echo "$Color_Warn"
    else
        echo "$Color_Success"
    fi
}

# ------------------------------------------------------------------------------
# FUNCTION: format  
#
# DESCRIPTION:
# This function returns the number GigaBytes equal to the number memory pages 
# of the specified size.
# ------------------------------------------------------------------------------
format_pages_to_gb() {
    local pages="$1"
    local page_size="$2"
    echo "scale=2; ($pages * $page_size) / (1024*1024*1024)" | bc
}

# ------------------------------------------------------------------------------
# FUNCTION: libFormat_padText
#
# DESCRIPTION:
#   Pads a string to a specific width with a chosen character and alignment.
#   If the text is longer than the width, it is truncated.
#
# USAGE:
#   padded_string=$(libFormat_padText "text" width "alignment" "pad_char")
#
# PARAMETERS:
#   $1 (string): The text to pad.
#   $2 (integer): The total desired width of the output string.
#   $3 (string, optional): Alignment: "left", "right", or "center".
#                          (Default: "left").
#   $4 (string, optional): The character to use for padding. (Default: " ").
#
# OUTPUT:
#   Prints the padded/truncated string to stdout.
# ------------------------------------------------------------------------------
PadText() {
    local text="$1"
    local width="$2"
    local align="${3:-left}"
    local pad_char="${4:- }"

    local text_len=${#text}
    
    # Truncate if text is longer than the desired width
    if (( text_len > width )); then
        echo -n "${text:0:$width}"
        return
    fi

    local pad_len=$((width - text_len))
    
    # Create a padding string of the required length
    local padding
    padding=$(printf "%*s" "$pad_len" "")
    padding=${padding// /$pad_char}

    case "$align" in
        right)
            echo -n "${padding}${text}"
            ;;
        center)
            local left_len=$((pad_len / 2))
            local right_len=$((pad_len - left_len))
            local left_pad=${padding:0:$left_len}
            local right_pad=${padding:0:$right_len}
            echo -n "${left_pad}${text}${right_pad}"
            ;;
        *) # left
            echo -n "${text}${padding}"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# FUNCTION: FormatArray
#
# DESCRIPTION:
#   Prints the contents of an array with aligned indices and values.
#
# USAGE:
#   FormatArray <array_name_as_string>
#
# PARAMETERS:
#   $1 (string): The name of the array to print.
#
# REQUIRES:
#   Bash 4.3+ (for nameref `-n`)
# ------------------------------------------------------------------------------
FormatArray() {
    local array_name="$1"
    
    # Check if the variable is a declared array
    if ! (declare -p "$array_name" 2>/dev/null | grep -q 'declare -a'); then
        log --error "Variable '$array_name' is not a valid array or does not exist."
        return 1
    fi

    # Use nameref to create a local reference to the user's array
    declare -n arr_ref="$array_name"

    if [[ ${#arr_ref[@]} -eq 0 ]]; then
        log --info "Array '$array_name' is empty."
        return 0
    fi

    # Determine the maximum width needed for the array indices for alignment
    local max_index_width=0
    local i
    for i in "${!arr_ref[@]}"; do
        if [[ ${#i} -gt $max_index_width ]]; then
            max_index_width=${#i}
        fi
    done

    log --info "Contents of array: $array_name"
    for i in "${!arr_ref[@]}"; do
        local padded_index
        padded_index=$(libFormat_padText "$i" "$max_index_width" "right")
        printf "  [%s] = %s\n" "$padded_index" "${arr_ref[$i]}"
    done
}

