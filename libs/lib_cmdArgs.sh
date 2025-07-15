#!/usr/bin/env bash
#
# Part of the 'lib' suite.
# Provides a powerful framework for defining and parsing command-line arguments.

# Sourcing Guard
filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename/./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then return 1; else declare -g "$isSourcedName=true"; fi

# --- Dependencies ---
source "$(dirname "${BASH_SOURCE[0]}")/lib_thisFile.sh"
lib_require "lib_logging.sh"

# --- Globals ---
declare -g -r _CMD_ARGS_DELIMITER=$'\x1F'
declare -g -A g_libCmd_argSpec
g_libCmd_argSpec=()

# --- Functions ---
libCmd_add() {
    log_entry
    local argType="" short_flag="" varName="" defaultValue="" required="n" multiplicity="multi" usage="" long_opt=""
    while (( "$#" )); do
        case "$1" in
            -t) argType="$2"; shift 2 ;;
            -f) short_flag="$2"; shift 2 ;;
            --long) long_opt="$2"; shift 2 ;;
            -v) varName="$2"; shift 2 ;;
            -d) defaultValue="$2"; shift 2 ;;
            -r) required="$2"; shift 2 ;;
            -m) multiplicity="$2"; shift 2 ;;
            -u) usage="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$short_flag" ]] && [[ -z "$long_opt" ]]; then
        log --Error "Argument spec must have a short (-f) or long (--long) flag."
        log_exit
        return 1
    fi
    if [[ -z "$varName" ]]; then
        log --Error "Argument spec for flag '--${long_opt:-$short_flag}' must include a variable name with -v."
        log_exit
        return 1
    fi

    local key="${long_opt:-$short_flag}"
    log --Debug "g_libCmd_argSpec['$key']=$argType$_CMD_ARGS_DELIMITER$varName$_CMD_ARGS_DELIMITER$defaultValue$_CMD_ARGS_DELIMITER$required$_CMD_ARGS_DELIMITER$multiplicity$_CMD_ARGS_DELIMITER$usage$_CMD_ARGS_DELIMITER$short_flag$_CMD_ARGS_DELIMITER$long_opt"
    g_libCmd_argSpec["$key"]="$argType$_CMD_ARGS_DELIMITER$varName$_CMD_ARGS_DELIMITER$defaultValue$_CMD_ARGS_DELIMITER$required$_CMD_ARGS_DELIMITER$multiplicity$_CMD_ARGS_DELIMITER$usage$_CMD_ARGS_DELIMITER$short_flag$_CMD_ARGS_DELIMITER$long_opt"
    log_exit
}

libCmd_parse() {
    log_entry
    while (( "$#" )); do
        local key="$1"
        local arg_key=""
        local value_from_equals=""
        case "$key" in
            --?*=*)
                arg_key="${key%%=*}"; arg_key="${arg_key/--/}"
                value_from_equals="${key#*=}"
                ;;
            --?*)
                arg_key="${key/--/}"
                ;;
            -?*)
                short_opt="${key:1}"
                for k in "${!g_libCmd_argSpec[@]}"; do
                    if [[ "$(echo "${g_libCmd_argSpec[$k]}" | cut -d$"$_CMD_ARGS_DELIMITER" -f7)" == "$short_opt" ]]; then
                        arg_key="$k"
                        break
                    fi
                done
                ;;
            *) break ;;
        esac

        if [[ -z "$arg_key" ]] || [[ -z "${g_libCmd_argSpec[$arg_key]}" ]]; then
            log --Warn "Unknown option: $key"
            shift
            continue
        fi

        local arg_spec="${g_libCmd_argSpec[$arg_key]}"
        IFS="$_CMD_ARGS_DELIMITER" read -r argType varName _ _ multiplicity _ _ <<< "$arg_spec"
        local value=""
        if [[ "$argType" == "switch" ]]; then
            value="true"; shift
        else
            if [[ -n "$value_from_equals" ]]; then
                value="$value_from_equals"; shift
            else
                value="$2"; shift 2
            fi
        fi
        if [[ "$multiplicity" == "multi" ]]; then
            eval "$varName+=(\"$value\")"
        else
            eval "$varName=\"$value\""
        fi
    done

    for key in "${!g_libCmd_argSpec[@]}"; do
        IFS="$_CMD_ARGS_DELIMITER" read -r _ varName defaultValue required multiplicity _ _ _ <<< "${g_libCmd_argSpec[$key]}"
        if ! declare -p "$varName" > /dev/null 2>&1; then
            if [[ "$required" == "y" ]]; then
                log --Error "Required argument '--$key' is missing."
                return 1
            fi
            if [[ "$multiplicity" != "multi" ]]; then
                eval "$varName='$defaultValue'"
            fi
        fi
    done
    log_exit
    return 0
}

libCmd_usage() {
    log_banner "Usage: $(thisScript) [options]"
    for key in "${!g_libCmd_argSpec[@]}"; do
        IFS="$_CMD_ARGS_DELIMITER" read -r _ varName def req mult usage short long <<< "${g_libCmd_argSpec[$key]}"
        local flags
        if [[ -n "$short" ]]; then flags="-${short}"; fi
        if [[ -n "$long" ]]; then [[ -n "$flags" ]] && flags+=", "; flags+="--${long}"; fi

        local formatted_line
        formatted_line=$(printf "  %-25s %s" "$flags" "$usage")
        log --MsgOnly "$formatted_line"
    done
}


