#!/usr/local/bin/bash
# set -x

#
# Part of the Bash library (Bl) suite
#
# The base or root library that inludes the rest
#
thisFile="${BASH_SOURCE[0]}"
shift
args=("${@}")

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

# *******************************************************************
# * {{{ Bl_SourceLibs
# *
# *******************************************************************
Bl_SourceLibs() {
    if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi

    local args="${@}"
    srcFiles=()

    while [ -n "$1" ]; do
        if [ "$1" == "--srcFile" ]; then 
            # Db "Echo: $thisFile: \$1 = $1"
            shift 
            srcFiles+=("$1")
        fi
        shift
    done

    echo "Source files = ${srcFiles[@]}."
    for file in "${srcFiles[@]}"; do 
        if [ -z "${SourcedFiles[$file]}" ]; then 
            if declare -f sourceFile &> /dev/null; then 
                # echo "sourceFile $file ${args[@]}"; 
                sourceFile "$file" "${args[@]}"; 
            else 
                # echo "source $file ${args[@]}"; 
                source "$file" "${args[@]}"; 
            fi
            SourcedFiles[$file]="$file"
        fi
    done
}
BlBase_SourceLibs() {
    local args=("${@}")
    # filesToSrc=(bashLibrary_trace.sh bashLibrary_debug.sh bashLibrary_sources.sh bashLibrary_pkgFcns.sh bashLibrary_cmdArgs.sh bashLibrary_files.sh) # <--- Edit this line or pass in files to source
    filesToSrc=(bashLibrary_trace.sh bashLibrary_debug.sh bashLibrary_colors.sh bashLibrary_pkgFcns.sh bashLibrary_cmdArgs.sh ) # <--- Edit this line or pass in files to source
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

##################################
#   Functions: ( | egrep "\(\) {" | cut -d'(' -f1 )
#       Bl_SourceLibs
#       Command Optons
#       run_command
#       parse_args_for_run_command
#       checkSudoOrRoot
#       min max equals
#       getDtWithFracSecs
#       getCurrentDir()
#       Bl_Get_file_info  [<file_path>]
#   
##################################

# *******************************************************************
# * {{{ Command Optons
# * 
# ******************************************************
cleanUp=""
quiet=""
dry_run=""
on_err_exit="on_err_exit"
on_err_cont="on_err_cont"

Vi_Fold_Begin="{{{"
Vi_Fold_End="}}}"

# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ run_command
# * run_command with with arguments and exit/continue
# * Returns the success/failure of the command ${?}
# * Follows --quiet and --dry_run
# *
# *     run_command on_err_exit "touch \"${service_file}\" "
# *     run_command on_err_cont apt-get install -y somepackage
# *     run_command "echo \"This is so cool.\" | tee output.txt"
# *
# *	If neither on_err_exit or on_err_cont are specified 
# *	then default to on_err_exit
# ****************************************************
fcns[i++]="run_command"
usages[i]="run_command <${on_err_cont}|${on_err_exit}> <program> <args ...>"
run_command() {
    doOnFailure=${1}
    command=${@:2}

    if [[ "${doOnFailure}" != $on_err_cont && "${doOnFailure}" != $on_err_exit  ]]; then
    	doOnFailure=$on_err_exit
    	command=${@:1}
    fi

    # Record/printout command
    if [ -z "$quiet" ] || [ "$quiet" != "true" ]; then
        stdbuf -o0 printf "-> %s\n" "${command[@]}"  
    fi

    # Execute command - but not if $dry_run is true
    # $dry_run isn't set, so execute the command
    # Or if it's set, but $dry_run is neither "true" nor true
    if [ -z "$dry_run" ] || ( [ "$dry_run" != "true" ] && [ $dry_run != true ] ); then
        if [ "$quiet" == "true" ]; then
            eval "${command[@]}" 2>&1 > /dev/null
        else
            eval "${command[@]}" 
        fi
    fi

    # If the command failed
    if [[ "${?}" -ne 0 ]]; then
        if [ -z "$quiet" ] || [ "$quiet" != "true" ]; then
            echo "${Color_Error}Command failed(${doOnFailure}): ${command}${Color_Reset}${Color_White}"
        fi

        if [[ "${doOnFailure}" == $on_err_exit ]]; then
            exit 1
        fi
    fi

    return ${?}
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ parse_args_for_run_command
# * Parse the run_command args
# *     - Parses all the command line args
# *
# ****************************************************
parse_args_for_run_command() {
    while [[ $# -gt 0 ]]
    do
        key="$1"
        case $key in
            -u|--clean-up)
                cleanUp=true
                shift
                ;;
            -r|--dryRun)
                dryRun=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -h|--help)
                usage_runCmds
                exit 0
                ;;
            *)
                # echo "Invalid flag: $1"
                # exit 1
                shift
                ;;
        esac
    done
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ usage_runCmds
# * Check if executing as root or with sudo
# * Any
# ****************************************************
usage_runCmds() {
    echo "run_command options:"
    echo -e "-h|--help \t print usage info"
    echo -e "-q|--quiet \t run commands with minimal output"
    echo -e "-r|--dryRun \t print the commands but don't execute them"
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ checkSudoOrRoot
# * Check if executing as root or with sudo
# * Any
# ****************************************************
fcns[i++]="checkSudoOrRoot"
usages[i]="checkSudoOrRoot [x]"
checkSudoOrRoot() {
    result=0
    if [[ "$(id -u)" -ne 0 ]]; then
        run_command echo "${Color_Error}This script requires root or sudo access.${Color_Reset}"
        result=1
        if [ -z "$1" ]; then
            exit $result
        fi
    fi
    return $result
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ min max equals
# * min, max values
# * equals
# *
# *     minVaue=$(min 1 2 ace two)
# *     areAllEqual=$(equal 1 2 ace two)
# ****************************************************
fcns[i++]="min"
usages[i]="min <args ...>"
min() {
    echo "$@" | tr ' ' '\n' | sort -g | head -n 1
}
fcns[i++]="max"
usages[i]="max <args ...>"
max() {
    echo "$@" | tr ' ' '\n' | sort -rg | head -n 1
}
fcns[i++]="equals"
usages[i]="equals <args ...>"
equals() {
    minVal=$(min $@)
    maxVal=$(max $@)
    if [ $minVal == $maxVal ]
    then
        echo 1
    else 
        echo 0
    fi
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ getDtWithFracSecs
# &
# * Get Date-Time with fractional seconds
# ****************************************************
fcns[i++]="getDtWithFracSecs"
usages[i]="getDtWithFracSecs"
getDtWithFracSecs() {
    fractSec=$(echo "scale=2; (`date +%N` / 1000000000)"  | bc -s)
    date=`date +"%a %F %T"`$fractSec

    echo ${date}
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ getCurrentDir() 
# *
# *******************************************************************
getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Bl_Get_file_info  [<file_path>]
# *
# * Returns an array of: basename dirname full-path owner permissions size 
# * creation_date modification-date file_type
# * for <file_path> or current executing script file if no param provided
# *
# * Call the function and store the results in an array:
# *     declare -A file_info_array
# *     file_info_array=($(get_file_info "$@"))
# *
# * Access the information from the array
# *     echo "Basename: ${file_info_array[basename]}"
# *     echo "Dirname: ${file_info_array[dirname]}"
# *     echo "Full path: ${file_info_array[full_path]}"
# *     echo "Owner: ${file_info_array[owner]}"
# *     echo "Permissions: ${file_info_array[permissions]}"
# *     echo "Size: ${file_info_array[size]}"
# *     echo "Creation date: ${file_info_array[creation_date]}"
# *     echo "Modification date: ${file_info_array[modification_date]}"
# *     echo "File type: ${file_info_array[type]}"
# *
fcns[i++]="Bl_Get_file_info"
usages[i]="Bl_Get_file_info"
# *******************************************************************
Bl_Get_file_info() {
    #local file_path="${1:-$0}" # Use the current executing script file if no file path is provided
    local file_path=""
    if [ -n ${1} ]; then file_path=${1}
    else file_path=$(basename "${BASH_SOURCE[0]}"); fi

    local basename=$(basename "$file_path")
    local dirname=$(dirname "$file_path")
    local owner=$(stat -c %U "$file_path")
    local permissions=$(stat -c %A "$file_path")
    local size=$(stat -c %s "$file_path")
    local creation_date=$(stat -c %w "$file_path")
    local modification_date=$(stat -c %y "$file_path")
    local type=$(file -b "$file_path")

    # Return the information in an associative array
    declare -A file_info
    file_info=(
        [basename]=$basename
        [dirname]=$dirname
        [full_path]=$file_path
        [owner]=$owner
        [permissions]=$permissions
        [size]=$size
        [creation_date]=$creation_date
        [modification_date]=$modification_date
        [type]=$file_type
    )
    echo "${file_info[@]}"
}
# }}} 
# *******************************************************************

# echo "BlBase_SourceLibs ${args[@]}"
BlBase_SourceLibs "${args[@]}"
