#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: gpush.sh
#
# DESCRIPTION:
#   Smart git commit/push wrapper that also detects and commits/pushes
#   submodule changes automatically.  Useful for projects that maintain
#   data or content in nested submodules (e.g., 01_chat_data/raw).
#
#   • Adds, commits, and pushes submodules first (if any changes exist).
#   • Then commits/pushes the parent repo pointer update.
#   • Behaves identically to before when no submodules are dirty.
#
#   Integrates with the project’s bash libs for logging, argument parsing,
#   dry-run execution, colors, and booleans.
#
# USAGE:
#   ./gpush.sh [options] [commit message]
#
#   Options (also shown via --help):
#     -n, --dry-run     Show actions without executing them
#         --no-add      Skip "git add ."
#         --amend       Amend last commit with current staged changes & message
#     -s, --signoff     Add Signed-off-by trailer
#     -t, --tags        Also push tags
#     -m, --message     Commit message (default ".")
#     -q, --quiet       Suppress run banners (still logs)
#     -?, --help        Show library-generated help
#
# NOTES:
#   • If any submodules contain uncommitted changes, each is committed/pushed
#     first (using the same message unless otherwise specified).
#   • After submodules are updated, the parent repo pointer is refreshed and
#     committed automatically.
#   • Options and lib integration are identical to previous versions.
# ==============================================================================

# --- Bootstrap libs -----------------------------------------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# --- Dependency Loader ---------------------------------------------------------
load_dependencies() {
    lib_require "lib_main.sh"
    lib_require "lib_bool.sh"
}

# --- Argument definitions -----------------------------------------------------
define_arguments() {
    libCmd_add -t switch -f n --long dry-run  -v "gp_dry_run"   -d "$TRUE"  -m once -u "Show actions without running them (default)"
    libCmd_add -t switch      --long apply    -v "gp_apply"     -d "$FALSE" -m once -u "Actually apply git commands (dry-run is the default)"
    libCmd_add -t switch      --long no-add   -v "gp_no_add"    -d "$FALSE" -m once -u "Skip 'git add .'"
    libCmd_add -t switch      --long amend    -v "gp_amend"     -d "$FALSE" -m once -u "Amend last commit with staged changes and message"
    libCmd_add -t switch -f s --long signoff  -v "gp_signoff"   -d "$FALSE" -m once -u "Add Signed-off-by trailer"
    libCmd_add -t switch -f t --long tags     -v "gp_push_tags" -d "$FALSE" -m once -u "Also push tags"
    libCmd_add -t value  -f m --long message  -v "gp_message"   -d "."      -m once -u "Commit message (default '.')"
    libCmd_add -t switch -f q --long quiet    -v "gp_quiet"     -d "$FALSE" -m once -u "Suppress run banners"
}

# --- Helper: run commands safely ---------------------------------------------
_run() {
    local do_exec=$1; shift
    local cmd_str="$*"
    if (( do_exec )); then
        runCommand --exec "$cmd_str"
    else
        runCommand "$cmd_str"
    fi
}

_first_positional_message() {
    local msg_parts=()
    for tok in "$@"; do
        if [[ "$tok" == -- ]]; then shift; msg_parts=("$@"); break; fi
        if [[ "$tok" != -* ]]; then msg_parts=("$tok"); shift; msg_parts+=("$@"); break; fi
        shift
        if [[ "$tok" == "-m" || "$tok" == "--message" ]]; then shift; fi
    done
    [[ ${#msg_parts[@]} -gt 0 ]] && printf '%s' "${msg_parts[*]}"
}

# --- Submodule Auto-Commit Helper --------------------------------------------
_commit_submodules() {
    local comment="$1"
    local dry_run="$2"

    if ! git submodule status &>/dev/null; then return 0; fi

    local changed_subs
    changed_subs=$(git submodule foreach --quiet 'git diff --quiet || echo $path')
    if [[ -z "$changed_subs" ]]; then return 0; fi

    log --Info "Detected submodule changes:"
    echo "$changed_subs" | while read -r sub; do
        [[ -z "$sub" ]] && continue
        log --Info "→ committing in submodule: $sub"
        (
            cd "$sub" || exit
            git add .
            if ! git diff --cached --quiet; then
                local esc_msg; printf -v esc_msg %q "$comment"
                if (( dry_run )); then
                    echo "[DRY-RUN] git commit -m $esc_msg && git push"
                else
                    git commit -m "$comment" && git push || log --Warn "Submodule $sub push failed"
                fi
            fi
        )
    done
    log --Info "Refreshing submodule pointers in main repo."
    git submodule update --remote
    git add .
}

# --- Main Worker -------------------------------------------------------------
_gpush_main() {
    log_entry
    bool_set GP_DRY_RUN   "${gp_dry_run:-$TRUE}"
    bool_set GP_NO_ADD    "${gp_no_add:-$FALSE}"
    bool_set GP_AMEND     "${gp_amend:-$FALSE}"
    bool_set GP_SIGNOFF   "${gp_signoff:-$FALSE}"
    bool_set GP_PUSH_TAGS "${gp_push_tags:-$FALSE}"
    bool_set GP_APPLY     "${gp_apply:-$FALSE}"   
    bool_set g_run_quiet  "${gp_quiet:-$FALSE}"

    # Allow --apply to override default dry-run mode
    if [[ "$GP_APPLY" == "$TRUE" ]]; then
        GP_DRY_RUN="$FALSE"
        log --Info "--apply detected; executing real changes"
    else
        log --Info "Dry-run mode active by default (use --apply to execute)"
    fi

    local comment="$gp_message"
    if [[ -z "$comment" || "$comment" == "." ]]; then
        local msg_from_pos; msg_from_pos=$(_first_positional_message "$@")
        [[ -n "$msg_from_pos" ]] && comment="$msg_from_pos"
        [[ -z "$comment" ]] && comment="."
    fi

    if ! command -v git >/dev/null 2>&1; then log --Error "git not found"; log_exit; return 127; fi
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then log --Error "Not in git repo"; log_exit; return 128; fi

    # --- Commit/Pull Submodules First ---
    local dry_flag=0
    [[ "$GP_DRY_RUN" == "$TRUE" ]] && dry_flag=1
    _commit_submodules "$comment" "$dry_flag"

    # --- Commit and Push Main Repo ---
    local repo branch upstream remote upstream_branch
    repo="$(basename "$(git rev-parse --show-toplevel)")"
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo "(detached)")
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
    if [[ -n "$upstream" ]]; then
        remote=${upstream%%/*}; upstream_branch=${upstream#*/}
    else
        remote=$(git remote | head -n1)
        upstream_branch="$branch"
    fi

    log --Info "repo=${repo} branch=${branch} remote=${remote:-'(none)'}"
    (( GP_DRY_RUN )) && log --Info "DRY RUN — no changes made"

    if (( ! GP_NO_ADD )); then _run $(( ! GP_DRY_RUN )) git add .; fi

    if ! git diff --cached --quiet; then
        local esc_msg; printf -v esc_msg %q "$comment"
        local commit_cmd=(git commit -m "$esc_msg")
        (( GP_AMEND ))   && commit_cmd=(git commit --amend -m "$esc_msg")
        (( GP_SIGNOFF )) && commit_cmd+=(--signoff)
        _run $(( ! GP_DRY_RUN )) "${commit_cmd[*]}" || { log --Error "commit failed"; return 1; }
    else
        log --Info "Nothing staged to commit"
    fi

    if [[ -n "$remote" ]]; then
        _run $(( ! GP_DRY_RUN )) git push -u "$remote" "$branch"
    else
        log --Error "No remote configured"
    fi

    (( GP_PUSH_TAGS )) && _run $(( ! GP_DRY_RUN )) git push --tags
    (( ! GP_DRY_RUN )) && log --Info "done ✓ (HEAD=$(git rev-parse --short HEAD 2>/dev/null))"

    log_exit
}

# --- Main Orchestration --------------------------------------------------------
main() {
    load_dependencies
    if ! initializeScript "$@"; then
        return 1
    fi

    _gpush_main "$@"
}

# --- Entrypoint ----------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi


