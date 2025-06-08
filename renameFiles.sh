#!/usr/local/bin/bash
set +x
args=("$@")

# echo "$0"
# echo "args: ${args[@]}"

# Source logging library if available
# This library provides logging functionality with different levels of logging.
# if [ -f "$(dirname "$0")/lib_logging.sh" ]; then
    # source "$(dirname "$0")/lib_logging.sh" "${args[@]}"
# else
    # echo "Logging library not found. Exiting."
    # exit 1
# fi
# 
# if [[ 0 ]]; then
if [ -f "$(dirname "$0")/lib_logging.sh" ]; then
    source "$(dirname "$0")/lib_logging.sh" "${args[@]}"
    set_log_level info
    log_debug "sourced lib_logging.sh"
    echo  "sourced lib_logging.sh - echo edition"
else
    echo "Logging library not found. Exiting."
    exit 1
fi
# fi

# ##########################################
testOutput() {
    local prior_log_level=current_log_level
    set_log_level 99
    if [[ ! -z $1 ]]; then
        echo -n $1
    fi
    echo "Test 1: echo"
    log_error "Test 2"
    log_warn  "Test 3"
    log_info  "Test 4"
    log_instr "Test 5"
    set_log_level=$prior_log_level
}
testOutput "Prior to mani"

# usage() {{{
# Displays usage information for the script.
function usage() {
    log_info "Usage: renameFiles.sh [options] <string-to-replace> <replacement-string> [path]"
    log_info "Options:"
    log_info "  -?, -h, --help, --usage: Display this help message."
    log_info "  --remove-vowels: Remove all vowels from the file names that match the string to replace."
    log_info "  -r, --recursive: Search for files recursively in subdirectories."
    log_info "  --rename-dirs: Enable renaming of directories as well as files."
    log_info "  --dry-run: Simulate the file renaming without making any changes."
    log_info "Description:"
    log_info "  Batch renames files with similar parts of their names. The string to replace and the replacement"
    log_info "  string must be specified as arguments. If the replacement string is empty, the string to replace"
    log_info "  will be deleted from the file name. If the --remove-vowels option is specified, all vowels will be"
    log_info "  removed from the file names that match the string to replace."
} #}}}

# find_items() {{{
# Function to find files and directories that match a specified regex pattern.
# Arguments:
#   $1: Path to search.
#   $2: Recursive flag (true/false) to indicate if subdirectories should be included.
#   $3: Regular expression to match in the file or directory names.
find_items() {
    local path="$1"
    local recursive="$2"
    local search_str="$3"

    log_debug "find_items called with: path=$path, recursive=$recursive, search_str=$search_str" >&2

    if [ "$recursive" == "true" ]; then
        #log_debug find "$path" -type f  | grep "$search_str"
        find "$path" -type f | grep "$search_str"
    else
        #log_debug find "$path" -maxdepth 1 -type f -exec basename {} \; | grep "$search_str"
        find "$path" -maxdepth 1 -type f -exec basename {} \; | grep "$search_str"
    fi
}
#}}}

# rename_item() {{{
# Function to rename a file or directory based on a regular expression.
# Arguments:
#   $1: Item to be renamed (file or directory name).
#   $2: Regular expression to match in the item's name.
#   $3: Replacement string to substitute where the regex matches.
#   $4: Flag to indicate if vowels should be removed (true/false).
#   $5: Dry run flag to simulate renaming without making changes (true/false).
rename_item() {
    local item="$1"
    local regex="$2"
    local replacement_string="$3"
    local remove_vowels="$4"
    local dry_run="$5"

    log_debug "rename_item called with: item=$item, regex=$regex, replacement_string=$replacement_string, remove_vowels=$remove_vowels, dry_run=$dry_run"

    local dir=$(dirname $item)
    if [ "x$dir" != "x\." ]; then
        dir=""
    fi
    if [ "x$dir" != "x" ]; then
        dir="$dir\\"
    fi

    filename=$(basename $item)
    local new_item_name

    log_debug "item=$item   dir=$dir    filename=$filename"
    
    if [[ "$remove_vowels" == "true" ]]; then
        new_item_name=$(echo "$filename" | tr -d 'aeiouAEIOU')
        new_item_name="$dir$new_item_name"
    else
        # Use regex for replacement (using -E for BSD/macOS sed, or -r for GNU sed)
        new_item_name=$(echo "$filename" | sed -E "s/$regex/$replacement_string/g")
        new_item_name="$dir$new_item_name"
    fi

    if [[ "$new_item_name" != "$item" ]]; then
        if [ "$dry_run" == "true" ]; then
            log_info "Dry run: would execute: mv '$item' '$new_item_name'"
        else
            log_info "Renaming $item to $new_item_name"
            mv "$item" "$new_item_name"
        fi
    else
        log_error "New name equals old name: $new_item_name"
    fi
} #}}}

# parseArgs() {{{
# Parses command-line arguments passed to the script.
parseArgs() {
    while (( "$#" )); do
        log_debug "Processing argument: $1"
        case "$1" in
            -r|--recursive)
                recursive="true"
                log_debug "Recursive flag set to true"
                shift
                ;;
            --remove-vowels)
                remove_vowels="true"
                log_debug "Remove vowels flag set to true"
                shift
                ;;
            --rename-dirs)
                rename_dirs="true"
                log_debug "Rename dirs flag set to true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                log_debug "Dry run flag set to true"
                shift
                ;;
            -?|-h|--help|--usage)
                usage
                exit 0
                ;;
            *)
                if [[ -z "$string_to_replace" ]]; then
                    string_to_replace="$1"
                    log_debug "string_to_replace set to $string_to_replace"
                elif [[ -z "$replacement_string" ]]; then
                    replacement_string="$1"
                    log_debug "replacement_string set to $replacement_string"
                elif [ -d "$1" ] || [ -f "$1" ]; then
                    path="$1"
                    log_debug "path set to $path"
                fi
                shift
                ;;
        esac
    done
} #}}}

# main() {{{
# Main function to orchestrate the renaming process.
main() {
    parseArgs "$@"
    local total_items=$(find_items "$path" "$recursive" "$string_to_replace" | wc -l)
    local current_item=0

    log_debug "Total items to process: $total_items"

    while IFS= read -r item; do
        current_item=$((current_item + 1))
        log_debug "Processing item $current_item of $total_items"
        rename_item "$item" "$string_to_replace" "$replacement_string" "$remove_vowels" "$dry_run"
    done < <(find_items "$path" "$recursive" "$string_to_replace")

    log_info "Files renaming complete."
} #}}}

# Initialize variables
string_to_replace=""
replacement_string=""
remove_vowels="false"
path="."
recursive="false"
rename_dirs="false"
dry_run="false"


# #########################################
# Replaced log_* fcns   # {{{`
# Conditionals to optionally include elsewhere 
# Replacement log_* statements that could be used to ensure robustness
if ! declare -f log_debug > /dev/null 2>&1; then 
    log_debug() { 
        echo "DDBUG: $@" 
    } 
    echo "renameFiles: implemented log_debug"
fi
if ! declare -f log_info  > /dev/null 2>&1; then 
    log_info()  { 
        echo "INFO: $@" 
    } 
    echo "renameFiles: implemented log_infog"
fi
if ! declare -f log_warn  > /dev/null 2>&1; then 
    log_warn()  { 
        echo "WARN: $@" 
    } 
    echo "renameFiles: implemented log_warn"
fi
if ! declare -f log_error > /dev/null 2>&1; then 
    log_error() { 
        echo "ERROR: $@" 
    } 
    echo "renameFiles: implemented log_error"
fi
if ! declare -f log_instr > /dev/null 2>&1; then 
    log_instr() { 
        echo "INSTR $@" 
    } 
    echo "renameFiles: implemented log_instr"
fi
# }}}

log_debug "$(thisFile): caller=$(thisCaller) - $(basename $HOME)" 

main "$@"

