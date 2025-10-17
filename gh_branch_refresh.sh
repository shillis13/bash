#!/usr/bin/env bash
# ============================================================================== 
# SCRIPT: gh_branch_refresh.sh
#
# DESCRIPTION:
#   Refreshes a local branch from a source branch using rebase, merge, or an
#   empty "tick" commit. Built on the repository's library framework with clear
#   logging and safety checks.
# ============================================================================== 

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

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

define_arguments() {
    libCmd_add -t value  --long head -v "gbr_head_branch" -r y -m once \
        -u "Target branch to refresh (will be checked out)"
    libCmd_add -t value  --long src  -v "gbr_source_branch" -d "main" -m once \
        -u "Source branch to sync from (default: main)"
    libCmd_add -t value  --long mode -v "gbr_mode" -d "rebase" -m once \
        -u "Sync mode: rebase, merge, or tick"
}

_print_help() {
    log_banner "Branch refresher"
    log --MsgOnly "Usage: $(thisScript) --head <branch> [--src main] [--mode rebase|merge|tick]"
    libCmd_usage
    log --MsgOnly ""
    log --MsgOnly "Examples:"
    log --MsgOnly "  $(thisScript) --head feature/login"
    log --MsgOnly "  $(thisScript) --head fix-bug --src release/1.0 --mode merge"
    log --MsgOnly "  $(thisScript) --head feature/api --mode tick"
}

_die() {
    log --Error "$1"
    return 1
}

_git() {
    log --Debug "git $*"
    if ! git "$@"; then
        log --Error "git $* failed"
        return 1
    fi
    return 0
}

_mode_rebase() {
    local head="$1" source="$2"
    log --Info "Rebasing $head onto origin/$source"
    _git rebase "origin/$source"
}

_mode_merge() {
    local head="$1" source="$2"
    log --Info "Merging origin/$source into $head"
    _git merge --no-edit "origin/$source"
}

_mode_tick() {
    local head="$1" source="$2"
    local message="chore: tick $head against ${source}"
    log --Info "Creating empty tick commit on $head"
    _git commit --allow-empty -m "$message"
}

_push_branch() {
    local head="$1" mode="$2"
    local push_args=("origin" "$head")
    if [[ "$mode" == "rebase" ]]; then
        push_args=("--force-with-lease" "origin" "$head")
    fi
    log --Info "Pushing $head to origin (${mode} mode)"
    _git push "${push_args[@]}"
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

    local head="$gbr_head_branch"
    local source="$gbr_source_branch"
    local mode="${gbr_mode,,}"

    if [[ -z "$head" ]]; then
        _die "--head is required"
        return 1
    fi

    if [[ "$mode" != "rebase" && "$mode" != "merge" && "$mode" != "tick" ]]; then
        _die "Unsupported --mode '$mode' (expected rebase, merge, or tick)"
        return 1
    fi

    if ! command -v git >/dev/null 2>&1; then
        _die "git command not found"
        return 1
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        _die "Not inside a git repository"
        return 1
    fi

    if [[ -n "$(git status --porcelain)" ]]; then
        log --Warn "Working tree is dirty. Uncommitted changes may interfere with refresh."
    fi

    if ! _git fetch origin; then
        return 1
    fi

    if ! _git switch "$head"; then
        return 1
    fi

    if ! git rev-parse --verify "origin/$source" >/dev/null 2>&1; then
        _die "Source branch origin/$source not found"
        return 1
    fi

    case "$mode" in
        rebase)
            if ! _mode_rebase "$head" "$source"; then
                return 1
            fi
            ;;
        merge)
            if ! _mode_merge "$head" "$source"; then
                return 1
            fi
            ;;
        tick)
            if ! _mode_tick "$head" "$source"; then
                return 1
            fi
            ;;
    esac

    if ! _push_branch "$head" "$mode"; then
        return 1
    fi

    log --Info "Branch '$head' refreshed from '$source' using $mode"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
