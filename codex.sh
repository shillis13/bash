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

# Comma-separated absolute paths to grant Codex workspace-write access beyond the repo root.
# Set CODEX_ADDITIONAL_ACCESS_DIRS in the environment before launching Codex or edit the default
# value below to persistently add directories.
# Example when adding /srv/shared: CODEX_ADDITIONAL_ACCESS_DIRS="${CODEX_ADDITIONAL_ACCESS_DIRS:-/srv/shared}"
CODEX_ADDITIONAL_ACCESS_DIRS="${CODEX_ADDITIONAL_ACCESS_DIRS:-}"

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
    printf '  ./codex.sh --model gpt-4o-mini -- --prompt '\''Hello'\''\n'
    printf '  ./codex.sh --read-only --keep PATH,HTTP_PROXY\n'
    printf '  ./codex.sh --set API_TOKEN=abc123 --venv .venv -- --file script.py\n'
    printf '  ./codex.sh --inherit-all -- --repl\n'
}

_codex_json_string_array() {
    local -a values=("$@")
    local json="["
    local first=1
    local value
    for value in "${values[@]}"; do
        [[ -z "$value" ]] && continue
        local escaped="${value//\\/\\\\}"
        escaped=${escaped//\"/\\\"}
        if (( first )); then
            first=0
        else
            json+=","
        fi
        json+="\"$escaped\""
    done
    json+="]"
    printf '%s' "$json"
}

_codex_normalize_dir() {
    local dir="$1"
    dir=$(_trim "$dir")
    if [[ -z "$dir" || "$dir" != /* ]]; then
        return 1
    fi
    while [[ "$dir" != "/" && "$dir" == */ ]]; do
        dir="${dir%/}"
    done
    printf '%s' "$dir"
}

_codex_build_path() {
    local -a base_paths=("/opt/homebrew/bin" "/usr/local/bin" "/usr/bin" "/bin" "/usr/sbin" "/sbin")
    local result=""
    local part
    for part in "${base_paths[@]}"; do
        [[ -z "$part" ]] && continue
        case ":$result:" in
            *":$part:"*) ;;
            *)
                if [[ -z "$result" ]]; then
                    result="$part"
                else
                    result+=":$part"
                fi
                ;;
        esac
    done
    if [[ -n "${PATH:-}" ]]; then
        local -a extra_parts=()
        local IFS=':'
        read -r -a extra_parts <<< "${PATH}"
        for part in "${extra_parts[@]}"; do
            [[ -z "$part" ]] && continue
            case ":$result:" in
                *":$part:"*) ;;
                *)
                    result+=":$part"
                    ;;
            esac
        done
    fi
    printf '%s' "$result"
}

_codex_print_help() {
    libCmd_usage
    local reset="${c_reset:-}"
    local heading="${c_cyan:-}${c_bold:-}"
    local label="${c_bold:-}"
    local flag="${c_magenta:-}${c_bold:-}"
    local dim="${c_dim:-}"

    printf '\n%sOverview%s\n' "$heading" "$reset"
    printf "  Launch Codex with the repository's Bash tooling. By default it scrubs the\n"
    printf '  environment (env -i), rebuilds PATH, and enforces workspace-write sandboxing\n'
    printf '  so the Codex CLI starts from a predictable state.\n'

    printf '\n%sKey Modes%s\n' "$heading" "$reset"
    printf '  %s--write%s         Allow workspace writes inside the repo (default).\n' "$flag" "$reset"
    printf '  %s--read-only%s     Force a read-only sandbox regardless of defaults.\n' "$flag" "$reset"
    printf '  %s--inherit-all%s   Launch Codex without scrubbing the current shell env.\n' "$flag" "$reset"
    printf '  %s--venv PATH%s     Activate the given virtualenv before Codex runs.\n' "$flag" "$reset"
    printf '  %s--model NAME%s    Pass an explicit model through to Codex.\n' "$flag" "$reset"
    printf '  %s--no-color%s      Disable ANSI colors in all helper output.\n' "$flag" "$reset"

    printf '\n%sEnvironment Controls%s\n' "$heading" "$reset"
    printf '  %s--keep VARS%s     Preserve specific variables (comma separated) when scrubbing.\n' "$flag" "$reset"
    printf '  %s--set PAIRS%s     Inject KEY=VALUE pairs into the sanitized environment.\n' "$flag" "$reset"
    printf '  %sCODEX_ADDITIONAL_ACCESS_DIRS%s allows extra writable roots (absolute paths).\n' "$label" "$reset"
    printf '  PATH is rebuilt to include /opt/homebrew/bin, /usr/local/bin, and standard dirs\n'
    printf '  while preserving any unique entries from your current PATH.\n'

    printf '\n%sPass-through Arguments%s\n' "$heading" "$reset"
    printf '  Use %s--%s to separate launcher flags from the command sent to Codex. Everything\n' "$label" "$reset"
    printf '  after the delimiter is handed to the Codex CLI unchanged (e.g. prompts, files,\n'
    printf '  repl mode). Example: %s./codex.sh --read-only -- --prompt "Lint this file"%s\n' "$dim" "$reset"

    printf '\n%sExamples%s\n' "$heading" "$reset"
    _print_examples
    printf '  ./codex.sh --keep PATH,HTTP_PROXY --set FOO=bar -- --prompt "Show env"\n'
    printf '  ./codex.sh --inherit-all --venv .venv -- --repl\n'

    printf '\n%sDependencies & Notes%s\n' "$heading" "$reset"
    printf '  - Requires the Codex CLI at /opt/homebrew/bin/codex (override via PATH).\n'
    printf '  - Expects the libs/ directory to be alongside Codex.sh for shared helpers.\n'
    printf '  - Respects %sCODEX_ADDITIONAL_ACCESS_DIRS%s for extra writable directories.\n' "$label" "$reset"
    printf '  - Honors %sDISABLE_PROMPT_CMD%s to prevent prompt rewrites during execution.\n' "$label" "$reset"
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
    lib_require "lib_command.sh"
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
        log --Debug "Virtualenv: $venv_path"
    else
        log --Debug "Virtualenv: none"
    fi

    if (( inherit_all )); then
        log --Debug "Environment mode: inherit-current"
    else
        log --Debug "Environment mode: scrubbed"
    fi

    if (( allow_write )); then
        log --Debug "Sandbox: workspace-write"
    else
        log --Debug "Sandbox: read-only"
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

    local -a codex_cmd=("/opt/homebrew/bin/codex" "--ask-for-approval" "on-request")
    if (( allow_write )); then
        codex_cmd+=("--sandbox" "workspace-write")
    fi
    local -a sandbox_overrides=()
    if (( allow_write )) && [[ -n "${CODEX_ADDITIONAL_ACCESS_DIRS:-}" ]]; then
        local -a requested_dirs=()
        IFS=',' read -r -a requested_dirs <<< "$CODEX_ADDITIONAL_ACCESS_DIRS"
        local -a extra_dirs=()
        local dir
        for dir in "${requested_dirs[@]}"; do
            local normalized
            if ! normalized=$(_codex_normalize_dir "$dir"); then
                local trimmed
                trimmed=$(_trim "$dir")
                [[ -z "$trimmed" ]] && continue
                log --Warn "Ignoring sandbox dir '$trimmed' (must be an absolute path)"
                continue
            fi
            extra_dirs+=("$normalized")
        done
        if [[ ${#extra_dirs[@]} -gt 0 ]]; then
            local -a writable_roots=()
            local workspace_root
            workspace_root=$(_codex_normalize_dir "$(pwd)")
            writable_roots+=("$workspace_root")
            if [[ -n "${TMPDIR:-}" ]]; then
                local normalized_tmp
                if normalized_tmp=$(_codex_normalize_dir "$TMPDIR"); then
                    writable_roots+=("$normalized_tmp")
                fi
            fi
            for dir in "${extra_dirs[@]}"; do
                local already_present=0
                local existing
                for existing in "${writable_roots[@]}"; do
                    if [[ "$existing" == "$dir" ]]; then
                        already_present=1
                        break
                    fi
                done
                (( already_present )) && continue
                writable_roots+=("$dir")
            done
            local json_dirs
            json_dirs=$(_codex_json_string_array "${writable_roots[@]}")
            sandbox_overrides+=("-c" "sandbox.workspace_write.writable_roots=${json_dirs}")
            log --Info "Sandbox additional dirs: ${extra_dirs[*]}"
        fi
    fi
    if [[ ${#sandbox_overrides[@]} -gt 0 ]]; then
        codex_cmd+=("${sandbox_overrides[@]}")
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
                exec_cmd=(env "DISABLE_PROMPT_CMD=1")
                exec_cmd+=("${set_assignments[@]}")
                exec_cmd+=("bash" "-lc" "$shell_cmd")
            else
                exec_cmd=(env "DISABLE_PROMPT_CMD=1" "bash" "-lc" "$shell_cmd")
            fi
        else
            if [[ ${#set_assignments[@]} -gt 0 ]]; then
                exec_cmd=(env "DISABLE_PROMPT_CMD=1")
                exec_cmd+=("${set_assignments[@]}")
                exec_cmd+=("${codex_cmd[@]}")
            else
                exec_cmd=(env "DISABLE_PROMPT_CMD=1" "${codex_cmd[@]}")
            fi
        fi
    else
        local path_value
        path_value=$(_codex_build_path)
        local home_value="${HOME:-$(pwd)}"
        exec_cmd=(env -i "TERM=xterm-256color" "PYTHONUTF8=1" "LC_ALL=C.UTF-8" "LANG=C.UTF-8" "PATH=${path_value}" "HOME=${home_value}" "DISABLE_PROMPT_CMD=1")
        
        # Pass through terminal session identification variables if they exist
        [[ -n "${TERM_SESSION_ID:-}" ]] && exec_cmd+=("TERM_SESSION_ID=${TERM_SESSION_ID}")
        [[ -n "${ITERM_SESSION_ID:-}" ]] && exec_cmd+=("ITERM_SESSION_ID=${ITERM_SESSION_ID}")
        [[ -n "${TERMINFO_DIRS:-}" ]] && exec_cmd+=("TERMINFO_DIRS=${TERMINFO_DIRS}")
        [[ -n "${LC_TERMINAL:-}" ]] && exec_cmd+=("LC_TERMINAL=${LC_TERMINAL}")
        [[ -n "${TERM_PROGRAM:-}" ]] && exec_cmd+=("TERM_PROGRAM=${TERM_PROGRAM}")
        
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

    local exec_cmd_str
    printf -v exec_cmd_str '%q ' "${exec_cmd[@]}"
    exec_cmd_str="${exec_cmd_str% }"
    log --Debug "Command: ${exec_cmd_str}"

    local runner="run_command"
    if ! declare -F "$runner" >/dev/null 2>&1; then
        if declare -F runCommand >/dev/null 2>&1; then
            runner="runCommand"
        else
            log --Error "run_command function is not available"
            log_exit
            return 1
        fi
    fi

    "$runner" --exec "$exec_cmd_str"
    local exit_code=$?

    log_exit
    return $exit_code
}

# --- Orchestration -------------------------------------------------------------
main() {
    load_dependencies
    local -a original_args=("$@")
    local -a init_args=()
    local -a init_args_without_help=()
    local help_requested=0
    for token in "$@"; do
        if [[ "$token" == "--" ]]; then
            break
        fi
        init_args+=("$token")
        case "$token" in
            --help|-h|-?)
                help_requested=1
                ;;
            *)
                init_args_without_help+=("$token")
                ;;
        esac
    done

    if (( help_requested )); then
        local init_output=""
        if ! init_output=$(initializeScript "${init_args_without_help[@]}" 2>&1); then
            printf '%s\n' "$init_output" >&2
            return 1
        fi
        _codex_print_help
        return 0
    fi

    if ! initializeScript "${init_args[@]}"; then
        return 1
    fi

    if (( ShowHelp )); then
        _codex_print_help
        return 0
    fi

    _codex_main "${original_args[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi
