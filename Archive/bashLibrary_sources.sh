#!/usr/local/bin/bash
# set -x

args=("${@}")

thisFile="${BASH_SOURCE[0]}"
# thisFile="bashLibrary_sources.sh"
# echo "bashLibrary_sources.sh:  Entered $thisFile"

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

# {{{ # Guard Header
# If guard has been defined, then use it
#if declare -f "guard" > /dev/null ; then 
    #guard 
    #guardResult=${?} 
    #if [ $guardResult -gt 0 ]; then return 1; fi
#fi
# }}}

# *******************************************************************
#   Functions:
#       - guard() 
#       - sourceFile()
#       - wasAlreadySrcd()
#   
# *******************************************************************

# {{{ SourceLibs 
# *******************************************************************
# * @name: _Bl_SourceLibs
# *
# * @desc:  Private-esque function to source the scripts necessary for 
# *         these functions
# *******************************************************************
Bl_SourceLibs() {
    if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi

    srcFiles=(bashLibrary_debug.sh) # <--- Edit this line
    for file in "${srcFiles[@]}"; do 
        if [ -z "${SourcedFiles[$file]}" ]; then 
            if delcare -f sourceFile &> /dev/null; then 
                # echo "Echo: $thisFile: sourceFile $file"; 
                sourceFile "$file"; 
            else 
                # echo "Echo: $thisFile: source $file"; 
                source "$file"; 
            fi
            SourcedFiles[$file]="$file"
        fi
    done
}
# }}}

# {{{ guard() - may be OBE/no longer needed
# *******************************************************************
# * guard
# *     No parameters
# *     When used, checks to see if current file had already been sourced
# *     
# * Returns:
# *     1 if already sourced (error condition), 0 otherwise
# *     Unless this is the base/original executing script, then this 
# *     will exit (1) cause it means a circular reference
# *
# * Bash scripts can put this at the top of file:
# *     # If guard has been defined to prevent duplicate sourcing, then use it
# *     if declare -f "guard" > /dev/null && guard && ${?} -eq 1 ; then return 1; fi
# *
# *******************************************************************
guard() {
    local thisFile=$(basename "${BASH_SOURCE[0]}")
    local theOrigin=$(basename "$0")
    local guardVal=0      # 0 => not sourced yet, so not guarded

    # for i in "${!BASH_SOURCE[@]}"; do
    #    echo "BASH_SOURCE[$i] = ${BASH_SOURCE[$i]}"
    # done

    wasAlreadySrcd $thisFile
    wasSrcd=${?}

    # If the file hasn't been sourced yet (wasSrcd = 0)
    if [ "$wasSrcd" -eq 0 ]; then
        # First time here, so good to go
        SourcedFiles[$thisFile]="$thisFile"
        guardVal=0
    else
        # So was previously sourced, But now what?  If this is somehow executing 
        # (vs. sourcing), then we can't return.  So exit instead as a circular reference error
        if [ "${thisFile}" == "${theOrigin}" ]; then
            # We're executing, not sourcing, so can't return - but HOW did this happen??
            Db_Error "Guard: $thisFile was already src in an executing context.  Can't return so exit."
            exit 1
        else
            # We're sourcing or running a function, so we can return with 1 implying error
            Db_Info "Guard: $thisFile was already sourced, so returning 1"
            guardVal=1
        fi
    fi

    return $guardVal
}
# }}} guard()

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
    Db_Entry "${@}"
    fileWasSourced=1    # 1 = failure/NOT sourced, 0 = success

    if [ -n "$1" ]; then
        fileToSource="$1"
        baseFilename=$(basename "$fileToSource")
        
        # Does the file exist
        if [ -f $fileToSource ]; then  
            wasAlreadySrcd "$fileToSource"
            wasSrcd=${?}
            
            # Was it already sourced?  wasSrcd = 1
            if [ $wasSrcd -eq 0 ]; then
                Db "source $fileToSource"
                source "$fileToSource"
                SourcedFiles[$fileToSource]="$fileToSource"
                fileWasSourced=0
            fi
        else
            Db "$fileToSource was aleady sourced"
            fileWasSourcedreturn=1
        fi
    fi

    # Return the pass 0/fail 1 result
    return $fileWasSourced
}
# }}} sourceFile()

# {{{ wasAlreadySrcd()
# *******************************************************************
# * wasAlreadySrcd <file>
# *
# * Determine if the passed in file had already been sourced for this 
# * execution environment.
# *
# * Returns 1 if it had been, 0 otherwise
# *******************************************************************
wasAlreadySrcd() {
    Db_Entry
    # Default answer
    local wasSrcd=0
   
    # If $1 is non-zero-length or ! empty, more checking to be done
    if [ -n "${1}" ]; then
        # If SourcedFiles is zero-length/empty, not sourced - but declare SourcedFiles
        if [ -z "${SourcedFiles}" ]; then 
            declare -A -gg SourcedFiles
            SourcedFiles[0]="zero"

        else
            # SrcFiles existed, some checking
            theFileToBeSrcd=$(basename "${1}")

            # If that file is in the list, then yes  -> already sourced
            if [ -n "${SourcedFiles[$theFileToBeSrcd]}" ]; then
                wasSrcd=1
            else
                Db_Error "$0:$LINENO: Why are we here?"
            fi
        fi
    else
        Db_Error "$0:$LINENO: Why are we here?"
    fi

    return $wasSrcd
}
# }}} wasAlreadySrcd()
