#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: gpush.sh
#
# DESCRIPTION:
#   Smart git commit/push wrapper that also detects and commits/pushes
#   submodule changes automatically. Useful for repos with nested submodules.
#
#   • Adds, commits, and pushes submodules first (if any changes exist).
#   • Then commits/pushes the parent repo pointer update.
#   • Defaults to DRY-RUN (from lib_command.sh). Use -x/--exec to apply.
#
# USAGE:
#   ./gpush.sh [options] [commit message]
#
#   Options (script-specific; lib options like -x/--exec are included via hooks):
#         --no-add      Skip "git add ."
#         --amend       Amend last commit with staged changes & message
#   -s, --signoff       Add Signed-off-by trailer
#   -t, --tags          Also push tags
#   -m, --message MSG   Commit message (default ".")
#   -q, --quiet         Suppress run banners (still logs)
#
#   Execution mode (from lib_command.sh):
#   -x, --exec          Execute commands instead of dry-run (default is dry-run)
# ==============================================================================

# --- Bootstrap libs -----------------------------------------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# --- Dependencies -------------------------------------------------------------
load_dependencies() {
    lib_require "lib_main.sh"
    lib_require "lib_bool.sh"
    lib_require "lib_command.sh"   # ensures runCommand and -x/--exec hook are registered
}

# --- Argument definitions -----------------------------------------------------
define_arguments() {
    libCmd_add -t switch      --long no-add   -v "gp_no_add"    -d "$FALSE" -m once -u "Skip 'git add .'"
    libCmd_add -t switch      --long amend    -v "gp_amend"     -d "$FALSE" -m once -u "Amend last commit with staged changes and message"
    libCmd_add -t switch -f s --long signoff  -v "gp_signoff"   -d "$FALSE" -m once -u "Add Signed-off-by trailer"
    libCmd_add -t switch -f t --long tags     -v "gp_push_tags" -d "$FALSE" -m once -u "Also push tags"
    libCmd_add -t value  -f m --long message  -v "gp_message"   -d "."      -m once -u "Commit message (default '.')"
    libCmd_add -t switch -f q --long quiet    -v "gp_quiet"     -d "$FALSE" -m once -u "Suppress run banners"
    # NOTE: -x/--exec is provided by lib_command.sh via register_hooks
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

    if ! git submodule status &>/dev/null; then return 0; fi

    local changed_subs
    changed_subs=$(git submodule foreach --quiet 'git diff --quiet || echo $path')
    [[ -z "$changed_subs" ]] && return 0

    log --Info "Detected submodule changes:"
    echo "$changed_subs" | while read -r sub; do
    [[ -z "$sub" ]] && continue
    log --Info "→ committing in submodule: $sub"
    # Stage everything in submodule
    runCommand "git -C \"$sub\" add ."

    # Only commit if something is staged
    if ! git -C "$sub" diff --cached --quiet; then
        local esc_msg; printf -v esc_msg %q "$comment"
        runCommand "git -C \"$sub\" commit -m $esc_msg"
        runCommand "git -C \"$sub\" push"
    fi
done

log --Info "Refreshing submodule pointers in main repo."
runCommand "git submodule update --remote"
runCommand "git add ."
}

# --- Main Worker --------------------------------------------------------------
_gpush_main() {
    log_entry

    # Quiet banners if requested
    if bool_is_true "$gp_quiet"; then
        g_run_quiet=$TRUE
    fi

    # Compose commit message (flag overrides positional if both provided)
    local comment="$gp_message"
    if [[ -z "$comment" || "$comment" == "." ]]; then
        local msg_from_pos; msg_from_pos=$(_first_positional_message "$@")
        [[ -n "$msg_from_pos" ]] && comment="$msg_from_pos"
        [[ -z "$comment" ]] && comment="."
    fi

    # Sanity checks
    if ! command -v git >/dev/null 2>&1; then log --Error "git not found"; log_exit; return 127; fi
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then log --Error "Not in git repo"; log_exit; return 128; fi

    # Repo context
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

    # Announce mode (reads lib global g_dry_run)
    if (( g_dry_run )); then
        log --Info "MODE: Dry Run (use -x/--exec to apply)"
    else
        log --Info "MODE: Execute"
    fi
    log --Info "repo=${repo} branch=${branch} remote=${remote:-'(none)'}"

    # --- Commit/Pull Submodules First (if any dirty) ---
    _commit_submodules "$comment"

    # --- Main repo add/commit/push ---
    if ! bool_is_true "$gp_no_add"; then
        runCommand "git add ."
    fi

    if ! git diff --cached --quiet; then
        local esc_msg; printf -v esc_msg %q "$comment"
        local cmd="git commit -m $esc_msg"
        if bool_is_true "$gp_amend";   then cmd="git commit --amend -m $esc_msg"; fi
        if bool_is_true "$gp_signoff"; then cmd="$cmd --signoff"; fi
        runCommand "$cmd" || { log --Error "commit failed"; log_exit; return 1; }
    else
        log --Info "Nothing staged to commit"
    fi

    if [[ -n "$remote" ]]; then
        runCommand "git push -u \"$remote\" \"$branch\""
    else
        log --Error "No remote configured"
    fi

    if bool_is_true "$gp_push_tags"; then
        runCommand "git push --tags"
    fi

    if (( ! g_dry_run )); then
        log --Info "done ✓ (HEAD=$(git rev-parse --short HEAD 2>/dev/null))"
    fi

    log_exit
}

# --- Main Orchestration -------------------------------------------------------
main() {
    load_dependencies
    if ! initializeScript "$@"; then
        return 1
    fi
    _gpush_main "$@"
}

# --- Entrypoint ---------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi


