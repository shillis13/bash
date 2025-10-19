#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SCRIPT: codex.sh
# PURPOSE: Launch Codex with the repo's Bash framework conventions. Provides a
#          scrubbed environment by default, optional workspace write access,
#          virtualenv activation, and pass-through arguments.
# -----------------------------------------------------------------------------

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# --- Globals ------------------------------------------------------------------
declare -a codex_keep_values=()
declare -a codex_set_pairs=()
declare -a _CODEX_PASSTHROUGH=()

# --- Helpers ------------------------------------------------------------------
_trim() {
    local value="$1"
    local prefix="${value%%[![:space:]]*}"
    value="${value#"$prefix"}"
    local suffix="${value##*[![:space:]]}"
    value="${value%"$suffix"}"
    printf '%s' "$value"
}

_codex_collect_passthrough() {
    local -a args=("$@")
    local -a passthrough=()
    local i=0
    while (( i < ${#args[@]} )); do
        local token="${args[i]}"
        case "$token" in
            --)
                (( i++ ))
                for (( ; i < ${#args[@]}; i++ )); do
                    passthrough+=("${args[i]}")
                done
                break
                ;;
            --write|--read-only|--inherit-all|--help|-h|-?)
                (( i++ ))
                ;;
            --keep|--set|--venv|--model)
                (( i++ ))
                if (( i < ${#args[@]} )); then
                    (( i++ ))
                fi
                ;;
            --keep=*|--set=*|--venv=*|--model=*)
                (( i++ ))
                ;;
            *)
                passthrough+=("$token")
                (( i++ ))
                ;;
        esac
    done
    _CODEX_PASSTHROUGH=("${passthrough[@]}")
}

_print_examples() {
    log --MsgOnly "Examples:"
    log --MsgOnly "  ./codex.sh --model gpt-4o-mini -- --prompt 'Hello'"
    log --MsgOnly "  ./codex.sh --read-only --keep PATH,HTTP_PROXY"
    log --MsgOnly "  ./codex.sh --set API_TOKEN=abc123 --venv .venv -- --file script.py"
    log --MsgOnly "  ./codex.sh --inherit-all -- --repl"
}

# --- Argument Definitions ------------------------------------------------------
define_arguments() {
    libCmd_add -t switch      --long write        -v "codex_flag_write"      -d "$FALSE" -m once -u "Allow workspace writes (default)"
    libCmd_add -t switch      --long read-only    -v "codex_flag_read_only"  -d "$FALSE" -m once -u "Launch without workspace write sandbox"
    libCmd_add -t switch      --long inherit-all  -v "codex_flag_inherit"    -d "$FALSE" -m once -u "Skip env scrub and inherit current shell"
    libCmd_add -t value       --long keep         -v "codex_keep_values"     -m multi -u "Comma list of environment variables to preserve"
    libCmd_add -t value       --long set          -v "codex_set_pairs"       -m multi -u "Comma list of KEY=VALUE pairs to inject"
    libCmd_add -t value       --long venv         -v "codex_venv_path"       -m once -u "Virtualenv path to activate"
    libCmd_add -t value       --long model        -v "codex_model"           -m once -u "Model name passed to Codex"
}

# --- Dependencies --------------------------------------------------------------
load_dependencies() {
    lib_require "lib_bool.sh"
    lib_require "lib_main.sh"
}

# --- Core Logic ----------------------------------------------------------------
_codex_main() {
    log_entry

    _codex_collect_passthrough "$@"

    local allow_write=$TRUE
    if (( codex_flag_read_only )); then
        allow_write=$FALSE
    fi
    if (( codex_flag_write )); then
        allow_write=$TRUE
    fi

    local inherit_all=$FALSE
    if (( codex_flag_inherit )); then
        inherit_all=$TRUE
    fi

    local venv_path="$( _trim "${codex_venv_path:-}" )"
    if [[ -z "$venv_path" && -d ".venv" ]]; then
        venv_path="$(pwd)/.venv"
    fi
    if [[ -n "$venv_path" ]]; then
        if [[ ! -f "$venv_path/bin/activate" ]]; then
            log --Error "Virtualenv activate script not found at '$venv_path/bin/activate'"
            log_exit
            return 1
        fi
        log --Info "Virtualenv: $venv_path"
    else
        log --Info "Virtualenv: none"
    fi

    if (( inherit_all )); then
        log --Info "Environment mode: inherit-current"
    else
        log --Info "Environment mode: scrubbed"
    fi

    if (( allow_write )); then
        log --Info "Sandbox: workspace-write"
    else
        log --Info "Sandbox: read-only"
    fi

    local -a keep_assignments=()
    if [[ ${#codex_keep_values[@]} -gt 0 ]]; then
        local -a keep_vars=()
        for raw in "${codex_keep_values[@]}"; do
            IFS=',' read -r -a parts <<< "$raw"
            for part in "${parts[@]}"; do
                local trimmed
                trimmed=$(_trim "$part")
                [[ -z "$trimmed" ]] && continue
                keep_vars+=("$trimmed")
            done
        done
        if [[ ${#keep_vars[@]} -gt 0 ]]; then
            log --Info "Keeping env vars: ${keep_vars[*]}"
            for var in "${keep_vars[@]}"; do
                if [[ -z "${!var+x}" ]]; then
                    log --Warn "Requested keep '$var' but it is unset"
                    continue
                fi
                keep_assignments+=("$var=${!var}")
            done
        fi
    fi

    local -a set_assignments=()
    if [[ ${#codex_set_pairs[@]} -gt 0 ]]; then
        for raw in "${codex_set_pairs[@]}"; do
            IFS=',' read -r -a pairs <<< "$raw"
            for pair in "${pairs[@]}"; do
                local trimmed
                trimmed=$(_trim "$pair")
                [[ -z "$trimmed" ]] && continue
                if [[ "$trimmed" != *=* ]]; then
                    log --Warn "Ignoring malformed --set entry '$trimmed'"
                    continue
                fi
                set_assignments+=("$trimmed")
            done
        done
    fi

    local -a codex_cmd=("codex" "--ask-for-approval" "on-request")
    if (( allow_write )); then
        codex_cmd+=("--sandbox" "workspace-write")
    fi
    if [[ -n "${codex_model:-}" ]]; then
        codex_cmd+=("--model" "${codex_model}")
    fi
    codex_cmd+=("--")
    if [[ ${#_CODEX_PASSTHROUGH[@]} -gt 0 ]]; then
        codex_cmd+=("${_CODEX_PASSTHROUGH[@]}")
    fi

    local -a exec_cmd=()
    if (( inherit_all )); then
        if [[ -n "$venv_path" ]]; then
            local quoted
            printf -v quoted '%q ' "${codex_cmd[@]}"
            local shell_cmd="source \"$venv_path/bin/activate\" && exec ${quoted% }"
            if [[ ${#set_assignments[@]} -gt 0 ]]; then
                exec_cmd=(env)
                exec_cmd+=("${set_assignments[@]}")
                exec_cmd+=("bash" "-lc" "$shell_cmd")
            else
                exec_cmd=("bash" "-lc" "$shell_cmd")
            fi
        else
            if [[ ${#set_assignments[@]} -gt 0 ]]; then
                exec_cmd=(env)
                exec_cmd+=("${set_assignments[@]}")
                exec_cmd+=("${codex_cmd[@]}")
            else
                exec_cmd=("${codex_cmd[@]}")
            fi
        fi
    else
        local path_value="${PATH:-/usr/bin:/bin:/usr/local/bin}"
        local home_value="${HOME:-$(pwd)}"
        exec_cmd=(env -i "TERM=xterm-256color" "PYTHONUTF8=1" "LC_ALL=C.UTF-8" "LANG=C.UTF-8" "PATH=${path_value}" "HOME=${home_value}")
        if [[ ${#keep_assignments[@]} -gt 0 ]]; then
            exec_cmd+=("${keep_assignments[@]}")
        fi
        if [[ ${#set_assignments[@]} -gt 0 ]]; then
            exec_cmd+=("${set_assignments[@]}")
        fi
        if [[ -n "$venv_path" ]]; then
            local quoted
            printf -v quoted '%q ' "${codex_cmd[@]}"
            local shell_cmd="source \"$venv_path/bin/activate\" && exec ${quoted% }"
            exec_cmd+=("bash" "-lc" "$shell_cmd")
        else
            exec_cmd+=("${codex_cmd[@]}")
        fi
    fi

    log --Info "Command: $(printf '%q ' "${exec_cmd[@]}")"
    "${exec_cmd[@]}"
    local exit_code=$?

    log_exit
    return $exit_code
}

# --- Orchestration -------------------------------------------------------------
main() {
    load_dependencies
    local -a original_args=("$@")
    local -a init_args=()
    for token in "$@"; do
        if [[ "$token" == "--" ]]; then
            break
        fi
        init_args+=("$token")
    done

    if ! initializeScript "${init_args[@]}"; then
        return 1
    fi

    if (( ShowHelp )); then
        libCmd_usage
        _print_examples
        return 0
    fi

    _codex_main "${original_args[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi

