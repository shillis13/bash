#!/usr/local/bin/bash

# Use of local here okay since this file is never directly executed
local filename="$(basename "${BASH_SOURCE[0]}")"
local isSourcedName="sourced_${filename/./_}"

if declare -p "$isSourcedName" > /dev/null 2>&1; then 
    return 1
else
    declare "$isSourcedName=$filename"
fi

declare -g -r SrcPrefix="sourced_"

thisFile() {
    echo "$(basename "${BASH_SOURCE[1]}")"
}

thisCaller() {
    echo "$(basename "${BASH_SOURCE[2]}")" 
}

thisScript() {
    echo "$(basename "$0")"
}

# thisInitialScript() {
# }

# {{{ guard() 
# *******************************************************************
# * guard
# *     filename
# *     When used, checks to see if current file had already been sourced
# *     
# * Returns:
# *     1 if already sourced (error condition), 0 otherwise
# *     Unless this is the base/original executing script, then this 
# *     will exit (1) cause it means a circular reference
# *
# * Bash scripts can put this at the top of file:
# *     # If guard has been defined to prevent duplicate sourcing, then use it
# *     if declare -g -f $(guarded) > /dev/null && ${?} -eq 1 ; then return 1; fi
# *
# *******************************************************************
guarded() {
    local filename="$(basename "${BASH_SOURCE[1]}")"
    local sourceName=""

    if [[ ! -z $1 ]]; then
        filename=$1
    fi

    sourceName="${SrcPrefix}${filename}"
    if declare -g -r sourceName > /dev/null; then echo 1; fi
    
    echo 0
}
# }}}


# {{{ sourceFile() 
# ******************************************************************* # * sourcefile <file>
# *     Checks whether the <file> has already been sourced by sourceFile 
# *     (doesn't protected against `source <fle>`
# *
# * Returns: 0 if file successfully sourced, 1 otherwise (error)
# *
# * Note: SourcedFiles is a global area declared in wasAlreadySrcd()
# *
# *******************************************************************
sourceFile() {
    local thisFilename="$(basename '${BASH_SOURCE[1]}')"
    local pathname="$(basename '${BASH_SOURCE[1]}')"
    local filename="$(basename '${BASH_SOURCE[1]}')"
    local sourceName="${SrcPrefix}${filename}"

    if [[ ! -z $1 ]]; then
        pathname="$1"
        filename="$(basename '$pathname')"
        sourceName="${SrcPrefix}${filename}"
    fi

    if declare -g -r $(guarded $filename) > /dev/null && ${?} -eq 1 ; then  
        echo "WARN: $pathname already sourced."
        return 1
    else
        echo $(source "$pathname")
    fi
    
}
# }}} sourceFile()

