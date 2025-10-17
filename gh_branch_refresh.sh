#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: gh_branch_refresh.sh
#
# DESCRIPTION:
#   Refresh a local git branch from another branch on origin using rebase,
#   merge, or an empty "tick" commit to retrigger CI.
# ==============================================================================

# --- Framework Bootstrap ------------------------------------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# --- Argument Definitions -----------------------------------------------------
define_arguments() {
    libCmd_add -t value  --long head -v "ghbr_head" -r y -m once \
        -u "Branch to update (will be checked out)"
    libCmd_add -t value  --long src  -v "ghbr_src"  -d "main" -m once \
        -u "Source branch to sync from (default: main)"
    libCmd_add -t value  --long mode -v "ghbr_mode" -d "rebase" -m once \
        -u "Sync mode: rebase, merge, or tick"
}

# --- Dependencies -------------------------------------------------------------
load_dependencies() {
    lib_require "lib_bool.sh"
    lib_require "lib_main.sh"
    lib_require "lib_command.sh"
}

# --- Helpers ------------------------------------------------------------------
_ghbr_print_examples() {
    log_banner "Examples"
    log --MsgOnly "  ./gh_branch_refresh.sh --exec --head feature"
    log --MsgOnly "  ./gh_branch_refresh.sh --exec --head docs --mode merge"
    log --MsgOnly "  ./gh_branch_refresh.sh --exec --head feature --src develop"
    log --MsgOnly "  ./gh_branch_refresh.sh --exec --head chore --mode tick"
    log --MsgOnly "  ./gh_branch_refresh.sh --head feature --mode rebase --dry-run"
}

# --- Main Logic ---------------------------------------------------------------
_ghbr_refresh() {
    log_entry

    if ! command -v git >/dev/null 2>&1; then
        log --Error "git not found"
        log_exit
        return 127
    fi

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log --Error "Not inside a git repository"
        log_exit
        return 128
    fi

    local head_branch="$ghbr_head"
    local src_branch="${ghbr_src:-main}"
    local mode="${ghbr_mode:-rebase}"
    mode="${mode,,}"

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)

    log --Info "Refreshing branch '$head_branch' from origin/$src_branch via $mode"
    if (( g_dry_run )); then
        log --Info "MODE: Dry Run (use --exec to apply)"
    else
        log --Info "MODE: Execute"
    fi

    local fetch_cmd
    printf -v fetch_cmd 'git fetch %q' "origin"
    if ! runCommand "$fetch_cmd"; then
        log --Error "git fetch failed"
        log_exit
        return 1
    fi

    if [[ "$current_branch" != "$head_branch" ]]; then
        local switch_cmd
        printf -v switch_cmd 'git switch %q' "$head_branch"
        if ! runCommand "$switch_cmd"; then
            log --Error "Unable to switch to branch '$head_branch'"
            log_exit
            return 1
        fi
    fi

    local target="origin/${src_branch}"
    case "$mode" in
        rebase)
            log --Info "Rebasing $head_branch onto $target"
            local rebase_cmd
            printf -v rebase_cmd 'git rebase %q' "$target"
            if ! runCommand "$rebase_cmd"; then
                log --Error "Rebase failed"
                log_exit
                return 1
            fi
            local push_cmd
            printf -v push_cmd 'git push --force-with-lease %q %q' "origin" "$head_branch"
            if ! runCommand "$push_cmd"; then
                log --Error "Push failed"
                log_exit
                return 1
            fi
            ;;
        merge)
            log --Info "Merging $target into $head_branch"
            local merge_cmd
            printf -v merge_cmd 'git merge --no-edit %q' "$target"
            if ! runCommand "$merge_cmd"; then
                log --Error "Merge failed"
                log_exit
                return 1
            fi
            local merge_push
            printf -v merge_push 'git push %q %q' "origin" "$head_branch"
            if ! runCommand "$merge_push"; then
                log --Error "Push failed"
                log_exit
                return 1
            fi
            ;;
        tick)
            log --Info "Creating empty tick commit on $head_branch"
            local message
            printf -v message 'chore: tick %s' "$head_branch"
            local tick_cmd
            printf -v tick_cmd 'git commit --allow-empty -m %q' "$message"
            if ! runCommand "$tick_cmd"; then
                log --Error "Tick commit failed"
                log_exit
                return 1
            fi
            local tick_push
            printf -v tick_push 'git push %q %q' "origin" "$head_branch"
            if ! runCommand "$tick_push"; then
                log --Error "Push failed"
                log_exit
                return 1
            fi
            ;;
        *)
            log --Error "Invalid mode '$mode' (expected rebase, merge, or tick)"
            log_exit
            return 1
            ;;
    esac

    log --Success "Branch '$head_branch' refreshed"
    log_exit
}

# --- Main Orchestration -------------------------------------------------------
main() {
    load_dependencies
    if ! initializeScript "$@"; then
        return 1
    fi

    if (( ShowHelp )); then
        _ghbr_print_examples
        return 0
    fi

    _ghbr_refresh "$@"
}

# --- Entrypoint ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi
