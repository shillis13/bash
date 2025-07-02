#!/usr/local/bin/bash

# Initialize locally global variables
search_string=""
replacement_string=""
remove_vowels="false"

# *******************************************************************
# * {{{ usage()
# *
# * Define function cmd line args
#
rf_defineArgs() {
    Bl_CmgArgsAdd -t value -f ss -v search_string -u "Regex/String to search" -m single -d ""
    Bl_CmgArgsAdd -t value -f rs -v replacement_string -u "replacement string" -m single -d ""
    Bl_CmgArgsAdd -t value -f rv -v remove_vowels -u "Remove vowels from files that match search string" -m single -d "false"
    Bl_CmgArgsAdd -t value -f remove_vowels -v remove_vowels -u "Remove vowels from files that match search string" -m single -d "false"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ rf_parse_args() 
# *
# * @desc: Parse command-line flags
# *******************************************************************
rf_parse_args() {
    while [[ $# -gt 0 ]]
    do
        key="$1"
        shift

        if [[ "$key" == "remove-vowels" ]]; then
            Db "Removing vowels from filenames"
            remove_vowels="true"
        elif [[ "$key" == "rv" ]]; then
            Db "Removing vowels from filenames"
            remove_vowels="true"
        elif [[ "$key" == "ss" ]]; then
            search_string="$1"
            Db "search_string = $search_string."
            shift
        elif [[ "$key" == "rs" ]]; then
            replacement_string="$1"
            Db "replacement_string = $replacement_string."
            shift
        fi

    done
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ rl_usage()
# *
rf_usage() {
    echo "Usage:"
    echo "renameFiles.sh [--remove-vowels] <string-to-replace> <replacement-string> "
    echo ""
    echo "Options:"
    echo "-?, -h, --help, --usage: Display this help message."
    echo "--remove-vowels: Remove all vowels from the file names that match the string to replace."
    echo ""
    echo "Description:"
    echo "Batch renames files with similar parts of their names. The string to replace and the replacement string must be specified as arguments. If the replacement string is empty, the string to replace will be deleted from the file name. If the --remove-vowels option is specified, all vowels will be removed from the file names that match the string to replace."
    echo ""
    echo "Examples:"
    echo ""
    echo "* Remove all vowels from all file names that contain the string \"image-\":"
    echo "  ./renameFiles.sh --remove-vowels \"image-\" \"\" "
    echo ""
    echo "* Rename all files with the prefix \"image-\" to have the prefix \"new-image-\":"
    echo "  ./renameFiles.sh \"image-\" \"new-image-\""
    echo ""
    exit 0
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ rl_main()
# *
# *******************************************************************
rf_main() {
    local args=("$@")
    rf_defineArgs

    parse_args_for_run_command "${args[@]}"
    parse_pkg_args "${args[@]}"
    rf_parse_args

    impl_renameFiles 

    if [ -z "$cleanUp" ]; then run_command \rm -rf $tmpDir; fi
}

# }}}
# *******************************************************************

# Print the parameters for debugging
# echo "String to replace = ${search_string}"
# echo "Replacement string = ${replacement_string}"
# echo "Remove vowels = ${remove_vowels}"

# *******************************************************************
# * {{{ renameFiles()
# *
# *******************************************************************
fcns[i++]="renameFiles"
usages[i]=rf_usage
renameFiles() {
    Db_Entry "renameFiles $0"
    rf_main "${args[@]}"
    Db_Exit
}
impl_renameFiles() {
    Db_Entry "$0"

    Db "Remove values = $remove_vowels."
    Db "search_string = $search_string."
    Db "replacement_string = $replacement_string."
    
    # Loop through all files in the current directory
    for file in *; do
        Db "Evaluating file: $file."
        # Check if the file name matches the string to replace
        if [[ "$file" == *"$search_string"* ]]; then
            # Remove vowels or replace string based on the flag
            if [[ "$remove_vowels" == "true" ]]; then
                new_file_name=$(echo "$file" | tr -d 'aeiouAEIOU')
            else
                new_file_name=$(echo "$file" | sed "s/$search_string/$replacement_string/g")
            fi

            # Rename the file if the new file name is different
            if [[ "$new_file_name" != "$file" ]]; then
                Db_Info "mv $file $new_file_name"
                run_command mv "$file" "$new_file_name"
            else
                Db "New filename equals old filename: $new_file_name"
            fi
        else
            echo -n ""
            Db "$file does not match $search_string"
        fi
    done

    echo "Files renaming comolete."
}
# }}}
# *******************************************************************

rf_main "${args[@]}"
