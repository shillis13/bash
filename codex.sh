#!/usr/bin/env bash
# ============================================================================== 
# SCRIPT: codex.sh
#
# DESCRIPTION:
#   Framework-native launcher for the Codex CLI. Provides a clean default
#   environment, optional workspace write access, venv activation, and
#   pass-through argument handling. Mirrors the repository's lib-based entry
#   conventions.
# ============================================================================== 

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# Sourcing guard
isSourcedName="$(sourced_name ${BASH_SOURCE[0]})"
if declare -p "$isSourcedName" >/dev/null 2>&1; then
    return 0
else
    declare -g "$isSourcedName"=1
fi

load_dependencies() {
    lib_require "lib_main.sh"
    lib_require "lib_bool.sh"
    lib_require "lib_logging.sh"
}

declare -a g_codex_keep=()
declare -a g_codex_set_pairs=()

_trim() {
    local value="$1"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    printf '%s' "$value"
}

_split_csv_append() {
    local csv="$1"; shift
    local -n target_ref="$1"
    local part
    IFS=',' read -ra parts <<< "$csv"
    for part in "${parts[@]}"; do
        part=$(_trim "$part")
        [[ -z "$part" ]] && continue
        target_ref+=("$part")
    done
}

define_arguments() {
    libCmd_add -t switch --long write       -v "codex_opt_write"      -d "$FALSE" -m once -u "Allow workspace writes (default)"
    libCmd_add -t switch --long read-only   -v "codex_opt_read_only"  -d "$FALSE" -m once -u "Force read-only sandbox"
    libCmd_add -t switch --long inherit-all -v "codex_opt_inherit"    -d "$FALSE" -m once -u "Skip env scrub and inherit current env"
    libCmd_add -t value  --long keep        -v "g_codex_keep"         -m multi    -u "Comma-separated env vars to preserve"
    libCmd_add -t value  --long set         -v "g_codex_set_pairs"    -m multi    -u "Comma-separated KEY=VALUE pairs to inject"
    libCmd_add -t value  --long venv        -v "codex_opt_venv"       -m once     -u "Virtualenv path to activate (defaults to ./.venv)"
    libCmd_add -t value  --long model       -v "codex_opt_model"      -m once     -u "Model name to pass to Codex"
}

_print_help() {
    log_banner "Codex launcher"
    log --MsgOnly "Usage: $(thisScript) [options] [--] [codex args]"
    libCmd_usage
    log --MsgOnly ""
    log --MsgOnly "Examples:"
    log --MsgOnly "  $(thisScript) -- --task 'List files'"
    log --MsgOnly "  $(thisScript) --read-only --model gpt-4o -- --task 'Read README'"
    log --MsgOnly "  $(thisScript) --keep HOME,USER --set EDITOR=vim -- --task 'Open file'"
    log --MsgOnly "  $(thisScript) --venv .venv --write -- --task 'Run tests'"
}

_prepare_env_assignments() {
    local -n _env_ref="$1"
    local inherit_flag="$2"
    local venv_path="$3"

    if (( ! inherit_flag )); then
        _env_ref+=("TERM=xterm-256color")
        _env_ref+=("PYTHONUTF8=1")
        _env_ref+=("LC_ALL=C.UTF-8")
        _env_ref+=("LANG=C.UTF-8")
    fi

    local path_value="$PATH"
    if [[ -n "$venv_path" ]]; then
        if [[ ! -d "$venv_path" ]]; then
            log --Warn "Requested venv '$venv_path' not found. Skipping activation."
        elif [[ ! -f "$venv_path/bin/activate" ]]; then
            log --Warn "Venv '$venv_path' has no activate script. Skipping activation."
        else
            log --Info "Activating virtual environment: $venv_path"
            path_value="$venv_path/bin:${path_value}"
            _env_ref+=("VIRTUAL_ENV=$venv_path")
        fi
    fi

    if [[ -n "$path_value" ]]; then
        _env_ref+=("PATH=$path_value")
    fi

    local -a _tmp_keep=()
    local item name
    for item in "${g_codex_keep[@]}"; do
        _split_csv_append "$item" _tmp_keep
    done

    if [[ ${#_tmp_keep[@]} -gt 0 ]]; then
        declare -A seen=()
        for name in "${_tmp_keep[@]}"; do
            if [[ -n "${seen[$name]}" ]]; then
                continue
            fi
            seen[$name]=1
            if [[ -n "${!name+x}" ]]; then
                _env_ref+=("$name=${!name}")
            else
                log --Warn "Environment variable '$name' not set; cannot keep."
            fi
        done
    fi

    local -a pairs=()
    local entry key value
    for item in "${g_codex_set_pairs[@]}"; do
        pairs=()
        _split_csv_append "$item" pairs
        for entry in "${pairs[@]}"; do
            if [[ "$entry" != *=* ]]; then
                log --Warn "Ignoring malformed --set entry: $entry"
                continue
            fi
            key="${entry%%=*}"
            value="${entry#*=}"
            key=$(_trim "$key")
            _env_ref+=("$key=$value")
        done
    done
}

_build_codex_command() {
    local -n _cmd_ref="$1"
    local allow_write="$2"
    local model_name="$3"

    _cmd_ref+=("codex")
    if (( allow_write )); then
        _cmd_ref+=("--sandbox" "workspace-write")
    fi
    _cmd_ref+=("--ask-for-approval" "on-request")
    if [[ -n "$model_name" ]]; then
        _cmd_ref+=("--model" "$model_name")
    fi
    _cmd_ref+=("--")
}

_run_codex() {
    local inherit_flag="$1"
    shift
    local env_assignments=("$@")
    local cmd=("${g_codex_cmd[@]}")

    if (( inherit_flag )); then
        local assignment
        for assignment in "${env_assignments[@]}"; do
            export "$assignment"
        done
        log --Info "Launching Codex with inherited environment"
        log --Debug "Command: ${cmd[*]} ${g_codex_args[*]}"
        "${cmd[@]}" "${g_codex_args[@]}"
    else
        log --Info "Launching Codex with scrubbed environment"
        log --Debug "Command: env -i ${env_assignments[*]} ${cmd[*]} ${g_codex_args[*]}"
        env -i "${env_assignments[@]}" "${cmd[@]}" "${g_codex_args[@]}"
    fi
}

_collect_positional_args() {
    local -n result_ref="$1"
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    result_ref+=("$1")
                    shift
                done
                break
                ;;
            --write|--read-only|--inherit-all|--exec|--dry-run|--help)
                shift
                ;;
            --keep|--set|--venv|--model)
                shift
                [[ $# -gt 0 ]] && shift
                ;;
            --keep=*|--set=*|--venv=*|--model=*)
                shift
                ;;
            -?*)
                shift
                ;;
            *)
                result_ref+=("$1")
                shift
                ;;
        esac
    done
}

main() {
    load_dependencies

    if ! initializeScript "$@"; then
        return 1
    fi

    if (( ShowHelp )); then
        _print_help
        return 0
    fi

    if ! command -v codex >/dev/null 2>&1; then
        log --Error "codex command not found in PATH"
        return 127
    fi

    local allow_write=$TRUE
    if bool_is_true "$codex_opt_read_only"; then
        allow_write=$FALSE
    elif bool_is_true "$codex_opt_write"; then
        allow_write=$TRUE
    fi

    local inherit_flag=$FALSE
    if bool_is_true "$codex_opt_inherit"; then
        inherit_flag=$TRUE
    fi

    local venv_path="$codex_opt_venv"
    if [[ -z "$venv_path" && -d "${SCRIPT_DIR}/.venv" ]]; then
        venv_path="${SCRIPT_DIR}/.venv"
    fi

    if (( allow_write )); then
        log --Info "Sandbox mode: workspace-write"
    else
        log --Info "Sandbox mode: read-only"
    fi

    if (( inherit_flag )); then
        log --Info "Environment mode: inherit"
    else
        log --Info "Environment mode: scrub"
    fi

    if [[ -n "$codex_opt_model" ]]; then
        log --Info "Model: $codex_opt_model"
    fi

    declare -a env_assignments=()
    _prepare_env_assignments env_assignments "$inherit_flag" "$venv_path"

    g_codex_cmd=()
    _build_codex_command g_codex_cmd "$allow_write" "$codex_opt_model"

    g_codex_args=()
    local -a original_argv=("$@")
    _collect_positional_args g_codex_args "${original_argv[@]}"

    if ! _run_codex "$inherit_flag" "${env_assignments[@]}"; then
        log --Error "Codex invocation failed"
        return 1
    fi

    log --Info "Codex completed successfully"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
