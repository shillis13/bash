#!/usr/local/bin/bash
#set -x

args=("${@}")

thisFile="runBashFcn.sh"
fcns=()
usages=()
declare -i i  # index into fcns() and usages()
i=0

# *******************************************************************
# * {{{ sourceFile 
# *
# * Source file script file, looking in cwd, home dir, and path
# ****************************************************
sourceFile() {
    # if [ -z "$1" && ! source "$1" --test-file ]; then
    if [ -z "$1" ] || [ ! -f "$1" ] || ! source "$1"; then

        bashFile=$1
        lib_path="./${bashFile}"
        [[ -f "$lib_path" ]] || lib_path="$HOME/${bashFile}"
        [[ -f "$lib_path" ]] || lib_path=$(which ${bashFile})
        [[ -f "$lib_path" ]] || { echo "${Color_Warning}${bashFile} not found.${Color_Reset}" ; }
        source "$lib_path"
        echo "Sourced lib: $lib_path"
    else
        echo "Sourced file: $1"
    fi
    return ${?}
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ bash-run-fcn() Execute a function
# *
# *******************************************************************
fcns[i++]="run-bash-fcn"
usages[i]="run-bash-fcn <fcn> <arg> ..."
bash-run-fcn() {
    # Check if the function exists (bash specific)
    if declare -f "$1" > /dev/null
    then
        # call arguments verbatim
        "$@"
    else
        # Show a helpful error
        echo "'$1' is not a known function name" >&2
        exit 1
    fi
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ bash-run-script-fcn() 
# * Source a bash script file and then execute fcn
# * 
# *******************************************************************
fcns[i++]="run-bash-script-fcn"
usages[i]="run-bash-script-fcn <source> <fcn> <arg> ..."
bash-run-script-fcn() {
    if [ -z "$1" ]; then
        scriptFile="$1"
        shift
        if [ -f "$scriptFile" ] && [ -x "$scriptFile" ]; then
            source "${scriptFile}" && $@
        fi
    fi
    
    if [ ! -f "$1" ] || [ ! -x "$1" ]; then
        echo "Error: $1 does not exist or is not executable." >&2
        exit 1
    fi
}
# }}} 
# *******************************************************************

# *******************************************************************
# * Usage() {{{
# * Print the usages for bash functions found
# *
# *******************************************************************
usage(){
    if [ ${#usages[@]} -gt 0 ]; then
        for i in "${!usages[@]}"; do
            echo "${usages[$i]}"
        done
    fi
}
# }}} 
# *******************************************************************

# *******************************************************************
# * main_rbf() {{{
# * 
# * main_run_bash_function
# *
# *******************************************************************
main_rbf() {
    echo "main_rbf()"
    if [ $# -gt 0 ]; then
        # Determine if usage or a function was passed on the cmd line
        if [ ! -z "$1" ] && [ "$1" == "usage" ]; then
            shift
            usage "$@"
        else
            maybeFcn="$1"
            cmdFound=0
            for fcn in "${!fcns[@]}"; do
                if [ "${fcns[$fcn]}" = "${maybeFcn}" ]; then
                    cmdFound=1
                    "$@" 
                fi
            done

            if [ ! $cmdFound -eq 1 ]; then
                sourceFile $1
                if [[ ${?} -eq 0 ]]; then
                    shift
                    "$@"
                fi
            fi
        fi
    fi
}
# }}} 
# *******************************************************************

sourceFile bashLibrary_base.sh ${args[@]}
main_rbf ${args[@]}
