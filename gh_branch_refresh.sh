#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SCRIPT: gh_branch_refresh.sh
# PURPOSE: Refresh a local branch from an origin branch using rebase, merge, or
#          tick (empty commit) workflows. Mirrors the repo's Bash framework.
# -----------------------------------------------------------------------------

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# --- Helpers ------------------------------------------------------------------
_print_examples() {
    log --MsgOnly "Examples:"
    log --MsgOnly "  ./gh_branch_refresh.sh --head feature"
    log --MsgOnly "  ./gh_branch_refresh.sh --head docs --mode merge"
    log --MsgOnly "  ./gh_branch_refresh.sh --head hotfix --src release --mode rebase"
    log --MsgOnly "  ./gh_branch_refresh.sh --head chore --mode tick"
}

# --- Argument Definitions ------------------------------------------------------
define_arguments() {
    libCmd_add -t value --long head -v "gbr_head" -r y -m once \
        -u "Local branch to refresh (will be checked out)"
    libCmd_add -t value --long src  -v "gbr_src"  -d "main" -m once \
        -u "Source branch to sync from (default: main)"
    libCmd_add -t value --long mode -v "gbr_mode" -d "rebase" -m once \
        -u "Refresh mode: rebase, merge, or tick"
}

# --- Dependencies --------------------------------------------------------------
load_dependencies() {
    lib_require "lib_bool.sh"
    lib_require "lib_main.sh"
}

# --- Core Logic ----------------------------------------------------------------
_gbr_main() {
    log_entry

    if ! command -v git &>/dev/null; then
        log --Error "git command not found"
        log_exit
        return 127
    fi

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log --Error "Not inside a git repository"
        log_exit
        return 128
    fi

    local head_branch="$gbr_head"
    local src_branch="${gbr_src:-main}"
    local mode="${gbr_mode:-rebase}"
    local remote="origin"

    case "$mode" in
        rebase|merge|tick) ;;
        *)
            log --Error "Unknown mode '$mode' (expected rebase, merge, or tick)"
            log_exit
            return 1
            ;;
    esac

    if [[ -z "$head_branch" ]]; then
        log --Error "--head is required"
        log_exit
        return 1
    fi

    log --Info "Refreshing branch '$head_branch' from '$remote/$src_branch' using mode '$mode'"

    if ! git fetch "$remote"; then
        log --Error "git fetch failed"
        log_exit
        return 1
    fi

    if ! git show-ref --verify --quiet "refs/heads/$head_branch"; then
        log --Error "Local branch '$head_branch' does not exist"
        log_exit
        return 1
    fi

    if ! git show-ref --verify --quiet "refs/remotes/$remote/$src_branch"; then
        log --Error "Remote branch '$remote/$src_branch' not found"
        log_exit
        return 1
    fi

    if ! git switch "$head_branch"; then
        log --Error "Failed to switch to branch '$head_branch'"
        log_exit
        return 1
    fi

    if [[ -n "$(git status --porcelain)" ]]; then
        log --Error "Working tree has uncommitted changes; please clean or stash first"
        log_exit
        return 1
    fi

    local result=0
    case "$mode" in
        rebase)
            log --Info "Rebasing onto $remote/$src_branch"
            if ! git rebase "$remote/$src_branch"; then
                log --Error "Rebase failed; resolve conflicts and rerun"
                log_exit
                return 1
            fi
            log --Info "Pushing with --force-with-lease"
            if ! git push --force-with-lease "$remote" "$head_branch"; then
                log --Error "Push failed"
                log_exit
                return 1
            fi
            ;;
        merge)
            log --Info "Merging $remote/$src_branch"
            if ! git merge --no-edit "$remote/$src_branch"; then
                log --Error "Merge failed"
                log_exit
                return 1
            fi
            log --Info "Pushing merge"
            if ! git push "$remote" "$head_branch"; then
                log --Error "Push failed"
                log_exit
                return 1
            fi
            ;;
        tick)
            local timestamp
            timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
            local message="chore: branch tick ($timestamp)"
            log --Info "Creating empty tick commit"
            if ! git commit --allow-empty -m "$message"; then
                log --Error "Failed to create tick commit"
                log_exit
                return 1
            fi
            log --Info "Pushing tick commit"
            if ! git push "$remote" "$head_branch"; then
                log --Error "Push failed"
                log_exit
                return 1
            fi
            ;;
    esac

    log --Info "Branch refresh complete"
    log_exit
    return $result
}

# --- Orchestration -------------------------------------------------------------
main() {
    load_dependencies
    if ! initializeScript "$@"; then
        return 1
    fi

    if (( ShowHelp )); then
        libCmd_usage
        _print_examples
        return 0
    fi

    _gbr_main "$@"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi

