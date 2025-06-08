#!/usr/local/bin/bash

#
# Part of the Bash library (Bl) suite
#
# Provides helper functions to specify script-specifc command line
# optons and helper functions for parsing cmd line args.
args=("$@")

thisFile="${BASH_SOURCE[0]}"
# Db "Echo: Entered $thisFile..."

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

# *******************************************************************
# {{{ Globals
# *
# * @name: Bl_CmdArgsGlobals()
# *
# * @desc:  Private-esque function to define and declare the global 
# *         variables necessary for these set of functions
# *******************************************************************
Bl_CmdArgsGlobals() {
    # declare -g -A Bl_ArgSpec  # associative array to store argument specifications
    typeset -Ag Bl_ArgSpec # TODO
    Bl_ArgSpec=()
}
# }}} Globals 
# *******************************************************************

# *******************************************************************
# {{{ Bl_CmdArgsAdd
# *
# * @name Bl_CmdArgsAdd <-t type> <-f flag> <-v varName> [-d defaultVal ] \
# *     [-r <y = Required/n = Not reqiured>] [-m <multi|single|once> ] [-u "usage string"]
# *
# * @desc: Add a cmd line arge specification
# *
# * @flag: -t type=value|switch
# * @flag: -r <y/n> Required?
# * @flag: -f flag
# * @flag: -v variableName
# * @flag: -d defaultValue
# *
# * @example: Bl_CmdArgsAdd -t value  -f i -n install_pkg  -r y -m multi -r y \
# *     -u "install pkg and its dependencies"
# * @example: Bl_CmdArgsAdd -t switch -f b -n useBinary -d false  -r n -m single 
# *     -u "use binary format"
# * @example: Bl_CmdArgsAdd -t value  -f v -n verboseLevel -d 0 -m once
# *
# *******************************************************************
Bl_CmdArgsAdd() {
    Db_Entry
    while getopts ":t:f:v:d:r:m:u:" opt; do
        case $opt in
            t) argType=$OPTARG ;;
            f) flag=$OPTARG ;;
            v) varName=$OPTARG ;;
            d) defaultValue=$OPTARG ;;
            r) required=$OPTARG ;;
            m) multiplicity=$OPTARG ;;
            u) usage=$OPTARG ;;
            *) ;;
        esac
    done
    if [ -z "$argType" ] || [ -z "$flag" ] || [ -z "$varName" ]; then
        echo "Error: Invalid argument specification."
        return 1
    fi
    if [ -z "$defaultValue" ]; then defaultValue=""; fi
    if [ -z "$required" ]; then required="n"; fi
    if [ -z "$multiplicity" ]; then multiplicity="multi"; fi
    if [ -z "$usage" ]; then usage=""; fi
    Bl_ArgSpec[$flag]="$argType:$varName:$defaultValue:$required:$multiplicity:$usage"
}
# }}}
# *******************************************************************

# *******************************************************************
# {{{ Bl_CmdArgsParse
# *
# * @name Bl_CmdArgsParse
# *
# * @desc: Parse the cmd line arg spec
# *
# *******************************************************************
# {{{ Bl_CmdArgsParseOld() {
Bl_CmdArgsParseOld() {
    # Db_Entry
    # local args=("$@")
    while getopts ":$(echo ${!Bl_ArgSpec[@]} | tr -d ':'):" opt; do
        flag=$opt
        argSpec=${Bl_ArgSpec[$flag]}
        argType=$(echo "$argSpec" | awk '{print $1}')
        varName=$(echo "$argSpec" | awk '{print $2}')
        defaultValue=$(echo "$argSpec" | awk '{print $3}')
        required=$(echo "$argSpec" | awk '{print $4}')
        multiplicity=$(echo "$argSpec" | awk '{print $5}')
        usage=$(echo "$argSpec" | awk '{print $6}')
        if [ $argType = "switch" ]; then
            value=true
        else
            value="$OPTARG"
        fi
        if [ "$multiplicity" = "multi" ]; then
            if [ -z "${!varName}" ]; then
                eval "$varName=(\"$value\")"
            else
                eval "$varName+=(\"$value\")"
            fi
        else
            eval "$varName='$value'"
        fi
    done

    shift "$((OPTIND - 1))"
    for flag in "${!Bl_ArgSpec[@]}"; do
        argSpec=${Bl_ArgSpec[$flag]}
        IFS=':' read -r varName defaultValue required multiplicity usage <<< "$argSpec"
        echo -e "\t-$flag $varName: $usage {default: $defaultValue} {required: $required} {multiplicity: $multiplicity}"
    
        if [ -z "${!varName}" ]; then
            if [ "$required" = "y" ]; then
                echo "Error: -$flag $varName is required."
                cmdArgsUsage
                exit 1
            fi

            if [ "$multiplicity" = "multi" ]; then
                eval "$varName=()"
            else
                eval "$varName='$defaultValue'"
            fi
        elif [ "$multiplicity" = "once" ] && [ ${#varName[@]} -gt 1 ]; then
            echo "Error: Only one instance of -$flag $varName allowed."
            cmdArgsUsage
            exit 1
        fi
    done
}
# }}}
Bl_CmdArgsParse() {
    while getopts ":$(echo "${!Bl_ArgSpec[@]}" | tr -d ':'):" opt; do
        flag=$opt
        argSpec=${Bl_ArgSpec[$flag]}
        argType=$(echo "$argSpec" | awk '{print $1}')
        varName=$(echo "$argSpec" | awk '{print $2}')
        defaultValue=$(echo "$argSpec" | awk '{print $3}')
        required=$(echo "$argSpec" | awk '{print $4}')
        multiplicity=$(echo "$argSpec" | awk '{print $5}')
        usage=$(echo "$argSpec" | awk '{print $6}')
        if [ "$argType" = "switch" ]; then
            value=true
        else
            value="$OPTARG"
        fi
        if [ "$multiplicity" = "multi" ]; then
            if [ -z "${!varName}" ]; then
                eval "$varName=("$value")"
            else
                eval "$varName+=("$value")"
            fi
        else
            eval "$varName='$value'"
        fi
    done

    shift $((OPTIND - 1))
    for flag in "${!Bl_ArgSpec[@]}"; do
        argSpec=${Bl_ArgSpec[$flag]}
        IFS=':' read -r varName defaultValue required multiplicity usage <<< "$argSpec"
        echo -e "\t-$flag $varName: $usage {default: $defaultValue} {required: $required} {multiplicity: $multiplicity}"

        if [ -z "${!varName}" ]; then
            if [ "$required" = "y" ]; then
                echo "Error: -$flag $varName is required."
                Bl_CmdArgsUsage
                exit 1
            fi

            if [ "$multiplicity" = "multi" ]; then
                eval "$varName=()"
            else
                eval "$varName='$defaultValue'"
            fi
        elif [ "$multiplicity" = "once" ] && [ "$multiplicity" = "multi" ]; then
            echo "Error: Only one instance of -$flag $varName allowed."
            Bl_CmdArgsUsage
            exit 1
        fi
    done
}
# }}} Bl_CmdArgsParse
# *******************************************************************

# *******************************************************************
# {{{ Bl_CmdArgsUsage
# *
# * @name Bl_CmdArgsUsage
# *
# * @desc: Print the usage as defined in the cmd args spec
# *
# *******************************************************************
Bl_CmdArgsUsage() {
    Db_Entry
    echo "Usage: $0 [options]"
    for flag in "${!Bl_ArgSpec[@]}"; do
        argSpec=${Bl_ArgSpec[$flag]}
        IFS=':' read -r varName defaultValue required multiplicity usage <<< "$argSpec"
        echo -e "\t-$flag $varName: $usage {default: $defaultValue} {required: $required} {multiplicity: $multiplicity}"
    done
}
# }}} Bl_CmdArgsUsage
# *******************************************************************

Bl_CmdArgsGlobals ${args[@]}
Bl_SourceLibs ${args[@]}

# {{{ Examples
######################################
# Example usages
#
######################################
# Define the arguments using Bl_CmdArgsAdd
#   Bl_CmdArgsAdd -t value  -f i -n install_pkg  -r y      -m multi -r y   -u "install pkg and its dependencies"
#   Bl_CmdArgsAdd -t switch -f b -n useBinary    -d false  -r n     -m single -u "use binary format"
#   Bl_CmdArgsAdd -t value  -f v -n verboseLevel -d 0      -m once
#
# Parse the command line arguments using Bl_CmdArgsParse
#   Bl_CmdArgsParse -i docker -b -i snap -b -v 2
#
# Access the parsed arguments
#   echo "install_pkg: ${install_pkg[@]}" # prints "install_pkg: docker snap"
#   echo "useBinary: $useBinary" # prints "useBinary: true"
#   echo "verboseLevel: $verboseLevel" # prints "verboseLevel: 2"
#
# Iterating over array variables (e.g., install_pkg)
#
# For loop:
#   for pkg in "${install_pkg[@]}"; do
#       echo "Package: $pkg"
#   done
#
# Directly access by index:
#   echo "First package: ${install_pkg[0]}"
#   echo "Second package: ${install_pkg[1]}"
#
# Get length:
#   length=${#install_pkg[@]}
#   echo "Number of packages: $length"
#
# Loop over with index:
#   for i in "${!install_pkg[@]}"
#   do
#       echo "Index: $i, Value: ${install_pkg[$i]}"
#   done
# }}} Examples
