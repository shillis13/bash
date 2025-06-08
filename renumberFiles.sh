#!/usr/local/bin/bash

# Source logging library if available
# This library is used for logging messages at various levels.
if [ -f "$(dirname "$0")/lib_logging.sh" ]; then
    source "$(dirname "$0")/lib_logging.sh"
    set_log_level "info"
else
    echo "Logging library not found. Exiting."
    exit 1
fi

# usage() {{{
# Displays usage information for the script.
function usage() {
    log_info "Usage: $0 [options] <num_of_digits> <leading_char> <trailing_char>"
    log_info "Options:"
    log_info "  -r, --recursive: Search for files recursively in subdirectories."
    log_info "  --rename-dirs: Enable renaming of directories."
    log_info "  --dry-run: Simulate the file renaming without making any changes."
    log_info "Example:"
    log_info "  $0 3 _ . --recursive --rename-dirs --dry-run"
    log_info "The script will find and reformat numbers in filenames to ensure they have a consistent number of digits,"
    log_info "surrounded by the specified leading and trailing characters."
} #}}}

# escape_for_regex() {{{
# Escapes characters for regex use.
# Arguments:
#   $1: The string to escape
function escape_for_regex() {
    local str="$1"
    str="${str//\\/\\\\}"  # Replaces \ with \\
    str="${str//\(/\\(}"  # Replaces ( with \(
    str="${str//\)/\\)}"  # Replaces ) with \)
    echo "$str"
} #}}}

# renumber() {{{
renumber() {
    local item="$1"
    log_debug "Processing item: $item"

    if [[ $item =~ $REGEX ]]; then
        local number="${BASH_REMATCH[1]}"

        # Remove leading zeros for arithmetic expansion
        local number_no_leading_zeros=$((10#$number))

        # Use printf to format the number with leading zeros
        local formatted_number=$(printf "%0*d" $NUM_DIGITS $number_no_leading_zeros)

        local new_name="${item/$LEADING_CHAR$number$TRAILING_CHAR/$LEADING_CHAR$formatted_number$TRAILING_CHAR}"

        if [ -e "$new_name" ]; then
            log_debug "$new_name already exists. Skipping."
        else
            if [ "$DRY_RUN" == "true" ]; then
                log_info "Dry run: would execute: mv '$item' '$new_name'"
            else
                mv "$item" "$new_name"
                log_info "Renamed $item to $new_name"
            fi
        fi
    else
        log_debug "$item did not match regex $REGEX"
    fi
} #}}}

# find_and_renumber() {{{
find_and_renumber() {
    local path="$1"
    log_debug "Starting to find and renumber in path: $path"

    if [ "$RECURSIVE" == "true" ]; then
        while IFS= read -r -d '' item; do
            log_debug "Found item: $item"
            if [ "$RENAME_DIRS" == "true" ] || [ -f "$item" ]; then
                renumber "$item"
            fi
        done < <(find "$path" -depth \( -type f -or -type d \) -print0)
    else
        for item in "$path"/*; do
            log_debug "Found item: $item"
            if [ "$RENAME_DIRS" == "true" ] || [ -f "$item" ]; then
                renumber "$item"
            fi
        done
    fi
} #}}}

# parseArgs() {{{
# Parses command-line arguments passed to the script.
function parseArgs() {
    # Check for the minimum number of required arguments
    if [ "$#" -lt 3 ]; then
        usage
        exit 1
    fi

    # Initialize option flags
    DRY_RUN="false"
    RECURSIVE="false"
    RENAME_DIRS="false"

    # Parse options first
    while (( "$#" )); do
        case "$1" in
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            -r|--recursive)
                RECURSIVE="true"
                shift
                ;;
            --rename-dirs)
                RENAME_DIRS="true"
                shift
                ;;
            *)
                # Break the loop if an option is not recognized, assuming positional arguments follow
                break
                ;;
        esac
    done

    # Ensure there are enough positional arguments remaining
    if [ "$#" -lt 3 ]; then
        log_error "Insufficient arguments provided."
        usage
        exit 1
    fi

    # Assign positional arguments
    NUM_DIGITS=$1
    LEADING_CHAR="$2"
    TRAILING_CHAR="$3"
    shift 3

    # Escape characters for regex
    LEADING_CHAR_ESCAPED=$(escape_for_regex "$LEADING_CHAR")
    TRAILING_CHAR_ESCAPED=$(escape_for_regex "$TRAILING_CHAR")
    REGEX="${LEADING_CHAR_ESCAPED}([0-9]+)${TRAILING_CHAR_ESCAPED}"
} #}}}

# main() {{{
# Main function orchestrating the renaming process.
function main() {
    parseArgs "$@"
    find_and_renumber "."
    log_info "Renumbering process complete."
} #}}}

main "$@"

