#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: codex.sh
#
# DESCRIPTION:
#   Launches the Codex CLI inside the repo's bash framework with a controlled
#   environment. By default a scrubbed environment (via `env -i`) is used, with
#   conveniences to selectively keep/set variables, enable workspace write
#   access, and activate virtual environments.
# ==============================================================================

# --- Bootstrap libs -----------------------------------------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# --- Dependencies -------------------------------------------------------------
load_dependencies() {
    lib_require "lib_main.sh"
    lib_require "lib_bool.sh"
    lib_require "lib_command.sh"
}

# --- Argument definitions -----------------------------------------------------
define_arguments() {
    libCmd_add -t switch      --long inherit-all -v "cdx_inherit_all" -d "$FALSE" -m once \
        -u "Skip env scrub (inherit current environment)"
    libCmd_add -t switch      --long read-only   -v "cdx_read_only"   -d "$FALSE" -m once \
        -u "Run without workspace write access"
    libCmd_add -t switch      --long write       -v "cdx_write"       -d "$FALSE" -m once \
        -u "Explicitly enable workspace write access"
    libCmd_add -t value       --long keep        -v "cdx_keep_items"                  -m multi \
        -u "Comma-separated environment variables to keep"
    libCmd_add -t value       --long set         -v "cdx_set_items"                   -m multi \
        -u "Comma-separated KEY=VALUE pairs to inject"
    libCmd_add -t value       --long venv        -v "cdx_venv_arg"                    -m once \
        -u "Path to Python virtual environment to activate"
    libCmd_add -t value       --long model       -v "cdx_model"                       -m once \
        -u "Model name passed through to Codex"
}

# --- Helpers ------------------------------------------------------------------
_trim() {
    local value="$1"
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    printf '%s' "$value"
}

_spec_for_option() {
    local token="$1"
    local lookup=""

    if [[ "$token" == --* ]]; then
        lookup="${token%%=*}"
        lookup="${lookup#--}"
        printf '%s' "${g_libCmd_argSpec[$lookup]-}"
        return
    fi

    if [[ "$token" == -* && "$token" != '-' ]]; then
        local short_flag="${token:1}"
        local spec_key
        for spec_key in "${!g_libCmd_argSpec[@]}"; do
            IFS=":" read -r _ _ _ _ _ _ short_name _ <<<"${g_libCmd_argSpec[$spec_key]}"
            if [[ "$short_name" == "$short_flag" ]]; then
                printf '%s' "${g_libCmd_argSpec[$spec_key]}"
                return
            fi
        done
    fi
}

_collect_passthrough_args() {
    local passthrough=()
    local token

    while (( "$#" )); do
        token="$1"
        shift

        if [[ "$token" == "--" ]]; then
            passthrough+=("$@")
            break
        fi

        if [[ "$token" == -* ]]; then
            local spec
            spec=$(_spec_for_option "$token")
            if [[ -n "$spec" ]]; then
                IFS=":" read -r argType _ _ _ _ _ _ _ <<<"$spec"
                if [[ "$argType" == "switch" ]]; then
                    continue
                fi

                if [[ "$token" == --* && "$token" == *=* ]]; then
                    continue
                fi

                if (( "$#" > 0 )); then
                    shift
                    continue
                fi
            fi
        fi

        passthrough+=("$token")
    done

    printf '%s\n' "${passthrough[@]}"
}

_determine_keep_list() {
    local -a combined=()
    local entry

    if declare -p cdx_keep_items >/dev/null 2>&1; then
        combined+=("${cdx_keep_items[@]}")
    fi

    local item
    for entry in "${combined[@]}"; do
        IFS=',' read -r -a parts <<<"$entry"
        for item in "${parts[@]}"; do
            item=$(_trim "$item")
            [[ -n "$item" ]] && printf '%s\n' "$item"
        done
    done
}

_determine_set_list() {
    local -a combined=()
    local entry

    if declare -p cdx_set_items >/dev/null 2>&1; then
        combined+=("${cdx_set_items[@]}")
    fi

    local pair
    for entry in "${combined[@]}"; do
        IFS=',' read -r -a parts <<<"$entry"
        for pair in "${parts[@]}"; do
            pair=$(_trim "$pair")
            [[ -z "$pair" ]] && continue
            printf '%s\n' "$pair"
        done
    done
}

_build_env_assignments() {
    local inherit_env="$1"
    local codex_dir="$2"
    local venv_path="$3"
    local -n out_ref="$4"
    local -n user_set_path_ref="$5"

    declare -A env_map=()
    local default_path="/usr/local/bin:/usr/bin:/bin"

    if bool_is_true "$inherit_env"; then
        env_map[TERM]="${TERM:-xterm-256color}"
        env_map[PYTHONUTF8]="${PYTHONUTF8:-1}"
        env_map[LC_ALL]="${LC_ALL:-C.UTF-8}"
        env_map[LANG]="${LANG:-C.UTF-8}"
        env_map[HOME]="${HOME:-$PWD}"
        env_map[PATH]="${PATH:-$default_path}"
    else
        env_map[TERM]="xterm-256color"
        env_map[PYTHONUTF8]="1"
        env_map[LC_ALL]="C.UTF-8"
        env_map[LANG]="C.UTF-8"
        env_map[HOME]="$PWD"
        env_map[PATH]="$default_path"
    fi

    local keep_var
    while IFS= read -r keep_var; do
        [[ -z "$keep_var" ]] && continue
        if [[ -n "${!keep_var-}" ]]; then
            env_map[$keep_var]="${!keep_var}"
        fi
    done < <(_determine_keep_list)

    user_set_path_ref=$FALSE
    local pair key value
    while IFS= read -r pair; do
        [[ -z "$pair" ]] && continue
        if [[ "$pair" != *=* ]]; then
            log --Warn "Ignoring invalid --set entry: $pair"
            continue
        fi
        key=$(_trim "${pair%%=*}")
        value="${pair#*=}"
        if [[ "$key" == "PATH" ]]; then
            user_set_path_ref=$TRUE
        fi
        env_map[$key]="$value"
    done < <(_determine_set_list)

    if [[ -n "$venv_path" ]]; then
        env_map[VIRTUAL_ENV]="$venv_path"
        local venv_bin="$venv_path/bin"
        local path_value="${env_map[PATH]-$default_path}"
        if [[ -d "$venv_bin" ]]; then
            if [[ ":$path_value:" != *":$venv_bin:"* ]]; then
                path_value="$venv_bin:$path_value"
            fi
        else
            log --Warn "Virtual env bin directory missing: $venv_bin"
        fi
        env_map[PATH]="$path_value"
    fi

    local path_value="${env_map[PATH]-$default_path}"
    if [[ -n "$codex_dir" ]]; then
        if bool_is_true "$user_set_path_ref"; then
            if [[ ":$path_value:" != *":$codex_dir:"* ]]; then
                log --Warn "PATH provided via --set does not include Codex directory ($codex_dir)."
            fi
        else
            if [[ ":$path_value:" != *":$codex_dir:"* ]]; then
                path_value="$codex_dir:$path_value"
            fi
            env_map[PATH]="$path_value"
        fi
    fi

    for key in "${!env_map[@]}"; do
        out_ref+=("$key=${env_map[$key]}")
    done
}

_announce_mode() {
    local allow_write="$1"
    local inherit_env="$2"
    local venv_path="$3"

    if bool_is_true "$inherit_env"; then
        log --Info "Environment: inherit current shell"
    else
        log --Info "Environment: scrubbed via env -i"
    fi

    if bool_is_true "$allow_write"; then
        log --Info "Sandbox: workspace-write"
    else
        log --Info "Sandbox: read-only"
    fi

    if [[ -n "$venv_path" ]]; then
        log --Info "Virtual env: $venv_path"
    else
        log --Info "Virtual env: (none)"
    fi
}

# --- Main Worker --------------------------------------------------------------
_codex_main() {
    log_entry

    if ! command -v codex >/dev/null 2>&1; then
        log --Error "codex executable not found in PATH"
        log_exit
        return 127
    fi

    local codex_path
    codex_path="$(command -v codex)"
    local codex_dir
    codex_dir="$(cd -- "$(dirname -- "$codex_path")" &>/dev/null && pwd)"

    local inherit_env="$FALSE"
    if bool_is_true "$cdx_inherit_all"; then
        inherit_env="$TRUE"
    fi

    local allow_write="$TRUE"
    if bool_is_true "$cdx_read_only"; then
        allow_write="$FALSE"
    fi
    if bool_is_true "$cdx_write"; then
        allow_write="$TRUE"
    fi

    local venv_path=""
    if [[ -n "${cdx_venv_arg:-}" ]]; then
        if [[ -d "$cdx_venv_arg" ]]; then
            venv_path="$(cd -- "$cdx_venv_arg" &>/dev/null && pwd)"
        else
            log --Error "Provided venv path not found: $cdx_venv_arg"
            log_exit
            return 1
        fi
    elif [[ -d "${PWD}/.venv" ]]; then
        venv_path="${PWD}/.venv"
    fi

    _announce_mode "$allow_write" "$inherit_env" "$venv_path"

    local -a env_assignments=()
    local user_set_path=$FALSE
    _build_env_assignments "$inherit_env" "$codex_dir" "$venv_path" env_assignments user_set_path

    local -a passthrough=()
    if mapfile -t passthrough < <(_collect_passthrough_args "$@"); then
        true
    fi

    local -a env_cmd
    if bool_is_true "$inherit_env"; then
        env_cmd=(env)
    else
        env_cmd=(env -i)
    fi

    local entry
    for entry in "${env_assignments[@]}"; do
        env_cmd+=("$entry")
    done

    local -a codex_cmd=("codex")
    if bool_is_true "$allow_write"; then
        codex_cmd+=("--sandbox" "workspace-write")
    fi
    codex_cmd+=("--ask-for-approval" "on-request")
    if [[ -n "${cdx_model:-}" ]]; then
        codex_cmd+=("--model" "$cdx_model")
    fi
    codex_cmd+=("--")
    codex_cmd+=("${passthrough[@]}")

    local -a full_cmd=("${env_cmd[@]}" "${codex_cmd[@]}")
    local cmd_str=""
    local part
    for part in "${full_cmd[@]}"; do
        printf -v part '%q' "$part"
        cmd_str+="$part "
    done
    cmd_str=${cmd_str% }

    if (( g_dry_run )); then
        log --Info "MODE: Dry Run (use -x/--exec to launch Codex)"
    else
        log --Info "MODE: Execute"
    fi

    log --Info "Launching Codex"
    runCommand "$cmd_str"

    log_exit
}

# --- Main Orchestration -------------------------------------------------------
main() {
    load_dependencies
    if ! initializeScript "$@"; then
        return 1
    fi
    _codex_main "$@"
}

# --- Entrypoint ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi
