#!/usr/local/bin/bash
# set -x

thisFile="${BASH_SOURCE[0]}"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi

source bashLibrary_base.sh "${args[@]}"

# *******************************************************************
# * {{{ Script global variables
# *
# *******************************************************************
CLEAN_PYTHON=false
CLEAN_ROOT="."
# }}}
# *******************************************************************



# *******************************************************************
# * {{{ main
# *
# *******************************************************************
main() {
    local args=("$@")

    MyUser=$(whoami)
    theDate=$(date +%y-%m-%d_%H:%M:%S)
    #tmpDir="/tmp/${MyUser}_${theDate}"

    NOT="${Color_Warning}NOT${Color_Reset}"

    echo "\$\@ = $@"
    echo "Args = ${args[@]}"
    parse_args_for_run_command "${args[@]}"

    echo "Args = ${args[@]}"
    parse_args_clean "${args[@]}"

    if [ $CLEAN_PYTHON ]; then
        clean_python_cache $CLEAN_ROOT
    else
        log_warn "Not cleaning python"
    fi

    #if [ -z $cleanUp ]; then run_command \rm -rf $tmpDir; fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ parse_args_clean
# *
# * @desc: Parse command-line flags
# *******************************************************************
parse_args_clean() {
    echo "parse_args_clean: args = $@"    
    CLEAN_PYTHON=false
    CLEAN_ROOT="."
    
    while [[ $# -gt 0 ]]
    do
        key="$1"
        if [ "x$key" == "x-p" ] || [ "x$key" == "x--python" ]; then
            CLEAN_PYTHON=true
        elif [ "x$key" == "x-d" ] || [ "x$key" == "x--Dir" ]; then
            shift
            CLEAN_ROOT="$1"
        fi
	shift
    done
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ clean_python_cache
# *
# *******************************************************************
clean_python_cache() {
    Dir=$1
    if [ -d $Dir ]; then
        echo "${Color_Info}Cleaning Python Cache.${Color_Reset}"

        echo "${Color_Info}find $Dir -type d -name '__pycache__' -exec rm -rf {} ${Color_Reset}"
        #run_command find $Dir -type d -name "__pycache__" -exec rm -rf {} \;
        
        echo "${Color_Info}find $Dir -type f -name \"*.pyc\" -delete ${Color_Reset}"
        #run_command find $Dir -type f -name "*.pyc" -delete
    else
        Db_Error "Directory not found: $Dir"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ usage
# *
# *******************************************************************
usage() {
    echo "Usage: $0 [-p|--python] [-d|--dir]"
    echo "Options:"
    #echo " -a, --all Clean all"
    echo " -p, --python Clean python caches"
    echo " -r, --dryRun Print the commands to install & configure without executing them. Default: false"
    echo " -q, --quiet Supress printouts. Default: False"
    echo " -h, --help Show this help message and exit"
    #echo -e "\nNote: this script needs to run as root or with sudo"
}
# }}}
# *******************************************************************

echo "main ${args[@]}"
main ${args[@]}


