#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: codex.sh
#
# DESCRIPTION:
#   Launch Codex with a sanitized execution environment by default, optional
#   workspace write access, and transparent argument/env passthroughs.
# ==============================================================================

# --- Framework Bootstrap ------------------------------------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# --- Argument Definitions -----------------------------------------------------
define_arguments() {
    libCmd_add -t switch      --long inherit-all -v "codex_inherit_all" -d "$FALSE" -m once \
        -u "Inherit current environment instead of env -i scrub"
    libCmd_add -t switch      --long write       -v "codex_write"       -d "$TRUE"  -m once \
        -u "Allow Codex to write to the workspace (default)"
    libCmd_add -t switch      --long read-only   -v "codex_read_only"   -d "$FALSE" -m once \
        -u "Disable workspace write access"
    libCmd_add -t value       --long keep        -v "codex_keep"                      -m once \
        -u "Comma list of env vars to preserve (implies env scrub)"
    libCmd_add -t value       --long set         -v "codex_set_pairs"                 -m once \
        -u "Comma list of KEY=VALUE pairs to inject into Codex env"
    libCmd_add -t value       --long venv        -v "codex_venv"                      -m once \
        -u "Path to virtualenv to activate (defaults to ./.venv if present)"
    libCmd_add -t value       --long model       -v "codex_model"                     -m once \
        -u "Codex model to request"
}

# --- Dependencies -------------------------------------------------------------
load_dependencies() {
    lib_require "lib_bool.sh"
    lib_require "lib_main.sh"
    lib_require "lib_command.sh"
}

# --- Helpers ------------------------------------------------------------------
_codex_trim() {
    local value="$1"
    local trimmed
    trimmed="${value#${value%%[![:space:]]*}}"
    trimmed="${trimmed%${trimmed##*[![:space:]]}}"
    printf '%s' "$trimmed"
}

_codex_env_set() {
    local -n order_ref=$1
    local -n map_ref=$2
    local key="$3"
    local value="$4"

    [[ -z "$key" ]] && return
    if [[ -z "${map_ref[$key]+_}" ]]; then
        order_ref+=("$key")
    fi
    map_ref["$key"]="$value"
}

_codex_collect_positional() {
    local -a collected=()
    while (($#)); do
        case "$1" in
            --)
                shift
                collected+=("$@")
                break
                ;;
            --keep=*|--set=*|--venv=*|--model=*)
                shift
                ;;
            --keep|--set|--venv|--model)
                shift
                (( $# )) && shift
                ;;
            --write|--read-only|--inherit-all|--exec|--dry-run)
                shift
                ;;
            -x|-n)
                shift
                ;;
            --help|--?)
                shift
                ;;
            --*)
                shift
                ;;
            -*)
                shift
                ;;
            *)
                collected+=("$1")
                shift
                collected+=("$@")
                break
                ;;
        esac
    done

    local arg
    for arg in "${collected[@]}"; do
        printf '%s\0' "$arg"
    done
}

_codex_print_examples() {
    log_banner "Examples"
    log --MsgOnly "  ./codex.sh --exec -- --help"
    log --MsgOnly "  ./codex.sh --exec --model gpt-4.1-mini -- --prompt 'Hello'"
    log --MsgOnly "  ./codex.sh --exec --keep HOME,SSH_AUTH_SOCK --set CODEX_MODE=ci -- --task run"
    log --MsgOnly "  ./codex.sh --exec --venv .venv --read-only"
    log --MsgOnly "  ./codex.sh --exec --inherit-all -- --resume-session"
}

# --- Main Logic ---------------------------------------------------------------
_codex_launch() {
    log_entry

    if ! command -v codex >/dev/null 2>&1; then
        log --Error "codex binary not found in PATH"
        log_exit
        return 127
    fi

    local sanitized=$TRUE
    if bool_is_true "$codex_inherit_all"; then
        sanitized=$FALSE
    fi

    local sandbox_write=$codex_write
    if bool_is_true "$codex_read_only"; then
        sandbox_write=$FALSE
    fi

    local -a env_order=()
    declare -A env_map=()

    local default_path="${PATH:-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
    if (( sanitized )); then
        _codex_env_set env_order env_map TERM "xterm-256color"
        _codex_env_set env_order env_map PYTHONUTF8 "1"
        _codex_env_set env_order env_map LC_ALL "C.UTF-8"
        _codex_env_set env_order env_map LANG "C.UTF-8"
        _codex_env_set env_order env_map HOME "${HOME:-/tmp}"
        _codex_env_set env_order env_map PATH "$default_path"
    else
        [[ -z "${TERM:-}" ]]       && _codex_env_set env_order env_map TERM "xterm-256color"
        [[ -z "${PYTHONUTF8:-}" ]] && _codex_env_set env_order env_map PYTHONUTF8 "1"
        [[ -z "${LC_ALL:-}" ]]     && _codex_env_set env_order env_map LC_ALL "C.UTF-8"
        [[ -z "${LANG:-}" ]]       && _codex_env_set env_order env_map LANG "C.UTF-8"
    fi

    local -a keep_vars=()
    if [[ -n "${codex_keep:-}" ]]; then
        IFS=',' read -ra keep_vars <<< "$codex_keep"
        local var
        for var in "${keep_vars[@]}"; do
            var=$(_codex_trim "$var")
            [[ -z "$var" ]] && continue
            if [[ -z "${!var+x}" ]]; then
                log --Warn "Requested keep for '$var' but it is unset"
                continue
            fi
            _codex_env_set env_order env_map "$var" "${!var}"
        done
    fi

    if [[ -n "${codex_set_pairs:-}" ]]; then
        IFS=',' read -ra set_entries <<< "$codex_set_pairs"
        local entry key value
        for entry in "${set_entries[@]}"; do
            entry=$(_codex_trim "$entry")
            [[ -z "$entry" ]] && continue
            if [[ "$entry" != *=* ]]; then
                log --Error "Invalid --set entry '$entry' (expected KEY=VALUE)"
                log_exit
                return 1
            fi
            key="${entry%%=*}"
            value="${entry#*=}"
            key=$(_codex_trim "$key")
            _codex_env_set env_order env_map "$key" "$value"
        done
    fi

    local resolved_venv="${codex_venv:-}"
    if [[ -z "$resolved_venv" && -d ".venv" && -f ".venv/bin/activate" ]]; then
        resolved_venv=".venv"
    fi
    if [[ -n "$resolved_venv" ]]; then
        if [[ ! -d "$resolved_venv" ]]; then
            log --Error "Virtualenv path '$resolved_venv' does not exist"
            log_exit
            return 1
        fi
        if [[ ! -f "$resolved_venv/bin/activate" ]]; then
            log --Error "Virtualenv at '$resolved_venv' is missing bin/activate"
            log_exit
            return 1
        fi
        local venv_abs
        venv_abs=$(cd -- "$resolved_venv" && pwd)
        _codex_env_set env_order env_map VIRTUAL_ENV "$venv_abs"
        local path_seed="${env_map[PATH]:-${PATH}}"
        if (( sanitized )) && [[ -z "$path_seed" ]]; then
            path_seed="$default_path"
        fi
        local new_path="$venv_abs/bin"
        if [[ -n "$path_seed" ]]; then
            new_path+=":$path_seed"
        fi
        _codex_env_set env_order env_map PATH "$new_path"
        log --Info "Activated virtualenv: $venv_abs"
    fi

    local -a env_parts
    if (( sanitized )); then
        env_parts=(env -i)
        log --Info "Environment: scrubbed (env -i)"
    else
        env_parts=(env)
        log --Info "Environment: inherited"
    fi

    local key
    for key in "${env_order[@]}"; do
        env_parts+=("${key}=${env_map[$key]}")
    done

    if bool_is_true "$sandbox_write"; then
        log --Info "Sandbox mode: workspace-write"
    else
        log --Info "Sandbox mode: read-only"
    fi

    if [[ -n "$codex_model" ]]; then
        log --Info "Model: $codex_model"
    fi

    if (( ${#keep_vars[@]} )); then
        log --Info "Preserved env vars: ${keep_vars[*]}"
    fi

    local -a positional_args=()
    mapfile -d '' -t positional_args < <(_codex_collect_positional "$@") || positional_args=()

    local -a codex_cmd=("codex")
    if bool_is_true "$sandbox_write"; then
        codex_cmd+=("--sandbox" "workspace-write")
    fi
    codex_cmd+=("--ask-for-approval" "on-request")
    if [[ -n "$codex_model" ]]; then
        codex_cmd+=("--model" "$codex_model")
    fi
    codex_cmd+=("--")
    codex_cmd+=("${positional_args[@]}")

    local -a full_cmd=("${env_parts[@]}" "${codex_cmd[@]}")
    local cmd_str=""
    printf -v cmd_str '%q ' "${full_cmd[@]}"
    cmd_str="${cmd_str% }"

    if (( g_dry_run )); then
        log --Info "Dry run: Codex command not executed (use --exec to run)"
    fi

    if ! runCommand "$cmd_str"; then
        log --Error "Codex invocation failed"
        log_exit
        return 1
    fi

    log --Success "Codex finished"
    log_exit
}

# --- Main Orchestration -------------------------------------------------------
main() {
    load_dependencies
    if ! initializeScript "$@"; then
        return 1
    fi

    if (( ShowHelp )); then
        _codex_print_examples
        return 0
    fi

    _codex_launch "$@"
}

# --- Entrypoint ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi
