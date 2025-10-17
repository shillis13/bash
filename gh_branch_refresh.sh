#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: gh_branch_refresh.sh
#
# DESCRIPTION:
#   Refreshes a local branch from a source branch using rebase, merge, or a tick
#   (empty commit) to retrigger CI. Operates entirely on local git state while
#   pushing updates to the remote.
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
    libCmd_add -t value  --long head -v "gbr_head_branch" -r y -m once \
        -u "Branch to refresh (must exist locally)"
    libCmd_add -t value  --long src  -v "gbr_src_branch"  -d "main" -m once \
        -u "Source branch to sync from (default: main)"
    libCmd_add -t value  --long mode -v "gbr_mode"        -d "rebase" -m once \
        -u "Sync mode: rebase, merge, or tick"
}

# --- Helpers ------------------------------------------------------------------
_require_git_repo() {
    if ! command -v git >/dev/null 2>&1; then
        log --Error "git executable not found"
        return 127
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log --Error "Not inside a git repository"
        return 128
    fi
    return 0
}

_validate_branches() {
    local head_branch="$1"
    local src_branch="$2"

    if ! git show-ref --verify --quiet "refs/heads/$head_branch"; then
        log --Error "Local branch not found: $head_branch"
        return 1
    fi

    if ! git ls-remote --exit-code origin "refs/heads/$src_branch" >/dev/null 2>&1; then
        log --Error "Remote branch not found: origin/$src_branch"
        return 1
    fi

    return 0
}

_log_mode() {
    local mode="$1"
    local head="$2"
    local src="$3"

    if (( g_dry_run )); then
        log --Info "MODE: Dry Run (use -x/--exec to apply changes)"
    else
        log --Info "MODE: Execute"
    fi
    log --Info "mode=$mode head=$head src=$src"
}

_run_git_command() {
    local cmd="$1"
    log --Debug "Running: $cmd"
    runCommand "$cmd"
}

_refresh_rebase() {
    local head="$1"
    local src="$2"

    _run_git_command "git fetch origin"
    _run_git_command "git switch $(printf '%q' "$head")"
    _run_git_command "git rebase origin/$(printf '%q' "$src")"
    local push_cmd
    printf -v push_cmd 'git push --force-with-lease origin %q' "$head"
    _run_git_command "$push_cmd"
}

_refresh_merge() {
    local head="$1"
    local src="$2"

    _run_git_command "git fetch origin"
    _run_git_command "git switch $(printf '%q' "$head")"
    _run_git_command "git merge --no-edit origin/$(printf '%q' "$src")"
    local push_cmd
    printf -v push_cmd 'git push origin %q' "$head"
    _run_git_command "$push_cmd"
}

_refresh_tick() {
    local head="$1"

    _run_git_command "git fetch origin"
    _run_git_command "git switch $(printf '%q' "$head")"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local message
    printf -v message 'chore: tick %s (%s)' "$head" "$timestamp"
    local commit_cmd
    printf -v commit_cmd 'git commit --allow-empty -m %q' "$message"
    _run_git_command "$commit_cmd"
    local push_cmd
    printf -v push_cmd 'git push origin %q' "$head"
    _run_git_command "$push_cmd"
}

_dispatch_mode() {
    local mode="$1"
    local head="$2"
    local src="$3"

    case "$mode" in
        rebase) _refresh_rebase "$head" "$src" ;;
        merge)  _refresh_merge "$head" "$src" ;;
        tick)   _refresh_tick "$head" ;;
        *)
            log --Error "Unknown mode: $mode"
            return 1
            ;;
    esac
}

# --- Main Worker --------------------------------------------------------------
_gh_branch_refresh_main() {
    log_entry

    if ! _require_git_repo; then
        log_exit
        return 1
    fi

    local head_branch="$gbr_head_branch"
    local src_branch="$gbr_src_branch"
    local mode="${gbr_mode,,}"

    if ! _validate_branches "$head_branch" "$src_branch"; then
        log_exit
        return 1
    fi

    _log_mode "$mode" "$head_branch" "$src_branch"

    if ! _dispatch_mode "$mode" "$head_branch" "$src_branch"; then
        log_exit
        return 1
    fi

    log --Info "Branch refresh complete"
    log_exit
}

# --- Main Orchestration -------------------------------------------------------
main() {
    load_dependencies
    if ! initializeScript "$@"; then
        return 1
    fi
    _gh_branch_refresh_main
}

# --- Entrypoint ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi
