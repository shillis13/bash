#!/usr/local/bin/bash

# Part of Bl (Bash library) suite
#
# Library that adds a framework of stack tracing for debugging of 
# bash scripts.  It includes:
#
#
args=("${@}")

# thisFile="${BASH_SOURCE[0]}"
thisFile="bashLibrary_trace.sh"
# echo "Echo: Entered $thisFile..."

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

# *********************************************************************
# {{{ Db_GetFuncsByName
# * @name Db_FuncsByName
# * 
# * Return the list of already delcared functions that match the search
# * query.
# * 
# *********************************************************************
Db_GetFuncsByName() {
  local search="$1"
  local -a functions=()

  # Loop over all function names and add those that match the search value
  for func in $(declare -F | awk '{print $3}'); do
    if [[ "$func" == "${search}"* ]]; then
      functions+=("$func")
    fi
  done

  # Return the array of function names
  echo "${functions[@]}"
}
# }}}
# *********************************************************************

# *********************************************************************
# {{{ Db_PrintStackTrace()
# * @name Db_PrintStackTrace 
# * Print out the bash stack trace but slightly modified to make more
# * sense to me.
# * 
# * How it normally would print out:
# * Index    BASH_SOURCE            FUNCNAME           BASH_LINENO
# * 0        bashLibrary_debug.sh   Db_PrintStackTrace 198
# * 1        bashLibrary_debug.sh   _Db_Print          71
# * 2        bashLibrary_debug.sh   Db                 95
# * 3        bashLibrary_debug.sh   Db_Error           65
# * 4        bashLibrary_sources.sh guard              10
# * 5        testb.sh               source             57
# * 6        ./testa.sh             main               0
# *
# * How I think it should print out:
# * Index       BASH_SOURCE            FUNCNAME           BASH_LINENO
# * 0        1: bashLibrary_debug.sh   Db_PrintStackTrace 198
# * 1        2: bashLibrary_debug.sh   _Db_Print          71
# * 2        3: bashLibrary_debug.sh   Db                 95
# * 3        4: bashLibrary_sources.sh Db_Error           65
# * 4        5: testb.sh               guard              10
# * 5        6: ./testa.sh             source             57
# * 6        7: ./testa.sh             main               0
# *
# *********************************************************************
Db_PrintStackTrace() {
    local printOriginal=0
    local printModified=1
    local maxSourceLen=0
    local maxFuncLen=0
    local maxLineLen=0

    if [ -n "${1}" ]; then printOriginal=${1}; fi
    if [ -n "${2}" ]; then printOriginal=${2}; fi

    # Get the max length of the values in each column
    for (( i=0; i<${#BASH_SOURCE[@]}; i++ )); do
        sourceLen=${#BASH_SOURCE[i]}
        funcLen=${#FUNCNAME[i]}
        lineLen=${#BASH_LINENO[i]}
        if [[ $sourceLen -gt $maxSourceLen ]]; then
            maxSourceLen=$sourceLen
        fi
        if [[ $funcLen -gt $maxFuncLen ]]; then
            maxFuncLen=$funcLen
        fi
        if [[ $lineLen -gt $maxLineLen ]]; then
            maxLineLen=$lineLen
        fi
    done
   
    # Add a little bit more spacing
    maxSourceLen=$((maxSourceLen + 2))
    maxFuncLen=$((maxFuncLen + 2))
    maxLineLen=$((maxLineLen + 2))

    indexColLen=5

    # printf "%-*s %-*s %-*s %-*s\n" $indexColLen "Index" $maxSourceLen "BASH_SOURCE" $maxFuncLen "FUNCNAME" $maxLineLen "BASH_LINENO"

    if [ $printOriginal -gt 0 ]; then
        printf "\nOriginal\n"
        # Print the header
        printf "%-*s %-*s %-*s %-*s\n" $indexColLen "Index" $maxSourceLen "BASH_SOURCE" $maxFuncLen "FUNCNAME" $maxLineLen "BASH_LINENO"
        # Print each entry in the stack trace
        for (( i=0; i<${#BASH_SOURCE[@]}; i++ )); do
            printf "%-*s %-*s %-*s %-*d\n" $indexColLen "${i}" $maxSourceLen "${BASH_SOURCE[i]}" $maxFuncLen "${FUNCNAME[i]}" $maxLineLen "${BASH_LINENO[i]}"
        done
    fi

    if [ $printModified -gt 0 ]; then
        printf "\nModified\n"
        # Print the header
        printf "%-*s %-*s %-*s %-*s\n" $indexColLen "Index" $maxSourceLen "BASH_SOURCE" $maxFuncLen "FUNCNAME" $maxLineLen "BASH_LINENO"
        # Print each entry in the stack trace
        for (( i=0; i<${#BASH_SOURCE[@]}-1; i++ )); do
            printf "%-*s %-*s %-*s %-*d\n" $indexColLen "${i}" $maxSourceLen "${BASH_SOURCE[i+1]}" $maxFuncLen "${FUNCNAME[i]}" $maxLineLen "${BASH_LINENO[i]}"
        done
        printf "%-*s %-*s %-*s %-*d\n" $indexColLen "${i}" $maxSourceLen "${BASH_SOURCE[i]}" $maxFuncLen "${FUNCNAME[i]}" $maxLineLen "${BASH_LINENO[i]}"
    fi
}
# }}}
# *********************************************************************

# *******************************************************************
# {{{ Db_GetStackTraceAtIndex()
# * @name: Db_GetStackTraceAtIndex [ <stack_levels_back> ]
# * @name: Db_GetStackTraceAtIndex [ <file_index> <func_index> <lineno_index> ]
# *
# * @param: <stack_levels_back> opt int default 1
# *
# * @desc:  Get the stack trace <stack_levels_back> levels deep
# *         The value at index 0 is not interesting because it would 
# *         always be this fcn.  So default to 1 and make levels back
# *         offset from 1 instead of 0.
# *
# * @echo return:  stackIndex : file : function : linenum
# *
# *******************************************************************
Db_GetStackTraceAtIndex() {
    # echo "Echo: Db_GetStackTraceAtIndex() $@"
    local stackSize=${#BASH_SOURCE[@]}
    local returnVal=0

    local fileIndex=1
    if [ -n "$1" ]; then fileIndex=${1}; fi
    if [ $fileIndex -ge $stackSize ]; then fileIndex=$((stackSize -1)); fi

    local funcIndex=$fileIndex
    if [ -n "$2" ]; then funcIndex=${2}; fi
    if [ $funcIndex -ge $stackSize ]; then funcIndex=$((stackSize -1)); fi

    local lnumIndex=$funcIndex
    if [ -n "$3" ]; then lnumIndex=${3}; fi
    if [ $lnumIndex -ge $stackSize ]; then lnumIndex=$((stackSize -1)); fi


    printf "%s : %s : %s" "${BASH_SOURCE[$fileIndex]}" "${FUNCNAME[$funcIndex]}()" "${BASH_LINENO[$lnumIndex]}" 
    #printf "%s : %s : %s : %s" "${fileIndex}-${funcIndex}-${lnumIndex}" "${BASH_SOURCE[$fileIndex]}" "${FUNCNAME[$funcIndex]}()" "${BASH_LINENO[$lnumIndex]}" 
    return $returnVal
}
# }}}
# *******************************************************************

# *******************************************************************
# {{{ Db_StackFileAtIndex
# * @name: Db_StackFileAtIndex [ <stack_levels_back> ]
# *
# * @param: <stack_levels_back> opt int default 0
# *
# * @desc:  Get the filename of the stack trace <stack_levels_back> levels deep
# *
# *******************************************************************
Db_StackFileAtIndex() {
    local stack_levels_back=0
    local returnVal=0
    local file=""
    local func=""
    local lineno=0

    if [ -n "$1" ]; then stack_levels_back=$1; fi
    local stackItem=$(Db_GetStackTraceAtIndex $stack_levels_back)
    returnVal=${?}
    if [ $returnVal -eq 0 ]; then 
        IFS=':' read -r index file func lineno <<< "$stackItem"
        echo $file
    fi
    return $returnVal
}
# }}}
# *******************************************************************

# *******************************************************************
# {{{ Db_StackFunctionAtIndex
# * @name: Db_StackFunctionAtIndex [ <stack_levels_back> ]
# *
# * @param: <stack_levels_back> opt int default 0
# *
# * @desc:  Get the function name of the stack trace <stack_levels_back> levels deep
# *
# *******************************************************************
Db_StackFunctionAtIndex() {
    local stack_levels_back=0
    local returnVal=0
    local file=""
    local func=""
    local lineno=0

    if [ -n "$1" ]; then stack_levels_back=$1; fi
    local stackItem=$(Db_GetStackTraceAtIndex $stack_levels_back)
    returnVal=${?}
    if [ $returnVal -eq 0 ]; then 
        IFS=':' read -r index file func lineno <<< "$stackItem"
        echo $func
    fi
    return $returnVal
}
# }}}
# *******************************************************************

# *******************************************************************
# {{{ Db_StackLinenoAtIndex
# * @name: Db_StackLinenoAtIndex [ <stack_levels_back> ]
# *
# * @param: <stack_levels_back> opt int default 0
# *
# * @desc:  Get the linenum of the stack trace <stack_levels_back> levels deep
# *
# *******************************************************************
Db_StackLinenoAtIndex() {
    local stack_levels_back=0
    local returnVal=0
    local file=""
    local func=""
    local lineno=0

    if [ -n "$1" ]; then stack_levels_back=$1; fi
    local stackItem=$(Db_GetStackTraceAtIndex $stack_levels_back)
    returnVal=${?}
    if [ $returnVal -eq 0 ]; then 
        IFS=':' read -r index file func lineno <<< "$stackItem"
        echo $lineno
    fi
    return $returnVal
}
# }}}
# *******************************************************************

# *******************************************************************
# {{{ Db_StackSize
# * @name: Db_StackSize 
# *
# * @desc:  Get the current size of the stack 
# *
# *******************************************************************
Db_StackSize() {
    local stackSize=${#BASH_SOURCE[@]}
    echo $stackSize
}
# }}}
# *******************************************************************
