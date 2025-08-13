#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: gpush.sh
#
# DESCRIPTION:
#   Add all changes, commit (message defaults to "."), and push.
#   Integrates with the project's bash libs for logging, argument parsing,
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
#   • Options should precede the positional message. If you prefer, use -m/--message.
#   • Dry-run honors the lib_command runCommand() semantics (no execution unless --exec).
# ==============================================================================

# --- Bootstrap libs -----------------------------------------------------------
# Compute library directory relative to this script and source lib_core first,
# so we can use lib_require and the guard/name helpers immediately.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# We want booleans; require the bool lib explicitly (lib_main does not).
lib_require "lib_bool.sh"

# --- Script argument definitions (registered later by lib_main) ---------------
# We only DEFINE here; actual parsing happens inside lib_main.initializeScript().
# define_arguments() is discovered and invoked by lib_main after it loads libs.

define_arguments() {
    # Core script options
    libCmd_add -t switch -f n --long dry-run  -v "gp_dry_run"   -d "false" -m once -u "Show actions without running them"
    libCmd_add -t switch      --long no-add   -v "gp_no_add"    -d "false" -m once -u "Skip 'git add .'"
    libCmd_add -t switch      --long amend    -v "gp_amend"     -d "false" -m once -u "Amend last commit with staged changes and message"
    libCmd_add -t switch -f s --long signoff  -v "gp_signoff"   -d "false" -m once -u "Add Signed-off-by trailer"
    libCmd_add -t switch -f t --long tags     -v "gp_push_tags" -d "false" -m once -u "Also push tags"
    libCmd_add -t value -f m  --long message  -v "gp_message"   -d "."     -m once -u "Commit message (default '.')"
    libCmd_add -t switch -f q --long quiet    -v "gp_quiet"     -d "false" -m once -u "Suppress run banners"
}

# --- Implementation -----------------------------------------------------------
# Helper: echo+eval via project runCommand; chooses --exec based on dry-run flag.
_run() {
    local do_exec=$1; shift
    local cmd_str="$*"
    if (( do_exec )); then
        runCommand --exec "$cmd_str"
    else
        runCommand "$cmd_str"
    fi
}

# Helper: capture a positional message (first non-option arg), if -m not used.
# Simple heuristic: first token not starting with '-' becomes the message start.
_first_positional_message() {
    local msg_parts=()
    for tok in "$@"; do
        if [[ "$tok" == -- ]]; then
            shift; msg_parts=("$@"); break
        fi
        if [[ "$tok" != -* ]]; then
            msg_parts=("$tok")
            shift
            msg_parts+=("$@")
            break
        fi
        shift
        # If this was -m/--message, skip its following value (already parsed by libs).
        if [[ "$tok" == "-m" || "$tok" == "--message" ]]; then
            shift
        fi
    done
    [[ ${#msg_parts[@]} -gt 0 ]] && printf '%s' "${msg_parts[*]}"
}

# Main worker
_gpush_main() {
    log_entry

    # Convert lib_cmdArgs string booleans to canonical 0/1 for logic.
    bool_set GP_DRY_RUN   "${gp_dry_run:-false}"
    bool_set GP_NO_ADD    "${gp_no_add:-false}"
    bool_set GP_AMEND     "${gp_amend:-false}"
    bool_set GP_SIGNOFF   "${gp_signoff:-false}"
    bool_set GP_PUSH_TAGS "${gp_push_tags:-false}"

    # Quiet banners if requested (lib_command checks this string var)
    if [[ "${gp_quiet:-false}" == "true" ]]; then g_run_quiet="true"; fi

    # Determine commit message precedence: --message beats positional; default "."
    local comment="$gp_message"
    if [[ -z "$comment" || "$comment" == "." ]]; then
        local msg_from_pos
        msg_from_pos=$(_first_positional_message "$@")
        if [[ -n "$msg_from_pos" ]]; then comment="$msg_from_pos"; fi
        [[ -z "$comment" ]] && comment="."
    fi

    # Preflight checks
    if ! command -v git >/dev/null 2>&1; then
        log --Error "git not found in PATH"; log_exit; return 127
    fi
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log --Error "Not inside a git repository"; log_exit; return 128
    fi

    # Repo/branch/upstream info
    local repo="$(basename "$(git rev-parse --show-toplevel)")"
    local branch upstream remote upstream_branch
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo "(detached)")
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
    if [[ -n "$upstream" ]]; then
        remote=${upstream%%/*}
        upstream_branch=${upstream#*/}
    else
        if git remote | grep -qx origin; then
            remote=origin
        else
            remote=$(git remote | head -n1)
        fi
        upstream_branch="$branch"
    fi

    log --Info "repo=${repo} branch=${branch} remote=${remote:-'(none)'} upstream=${upstream:-'(none)'}"
    (( GP_DRY_RUN )) && log --Info "DRY RUN — no changes will be made"

    # Add
    if (( ! GP_NO_ADD )); then
        _run $(( ! GP_DRY_RUN )) git add . || { log --Error "git add failed"; log_exit; return 1; }
    else
        log --Debug "Skipping add (--no-add)"
    fi

    # Commit if anything is staged
    if ! git diff --cached --quiet; then
        # Build commit command with safe-escaped message.
        local esc_msg; printf -v esc_msg %q "$comment"
        local commit_cmd=(git commit -m "$esc_msg")
        (( GP_AMEND ))   && commit_cmd=(git commit --amend -m "$esc_msg")
        (( GP_SIGNOFF )) && commit_cmd+=(--signoff)
        _run $(( ! GP_DRY_RUN )) "${commit_cmd[*]}" || { log --Error "git commit failed"; log_exit; return 1; }
    else
        log --Info "Nothing staged to commit (skipping commit)"
    fi

    # Push
    if [[ -n "$upstream" ]]; then
        _run $(( ! GP_DRY_RUN )) git push || { log --Error "git push failed"; log_exit; return 1; }
    else
        if [[ -n "$remote" && "$branch" != "(detached)" ]]; then
            log --Warn "No upstream set — pushing with tracking to ${remote} ${branch}"
            _run $(( ! GP_DRY_RUN )) git push -u "$remote" "$branch" || { log --Error "git push -u failed"; log_exit; return 1; }
        else
            log --Error "Cannot determine remote/branch to push (detached HEAD or no remotes)"
            log_exit; return 1
        fi
    fi

    # Optional: tags
    if (( GP_PUSH_TAGS )); then
        _run $(( ! GP_DRY_RUN )) git push --tags || { log --Error "git push --tags failed"; log_exit; return 1; }
    fi

    # Friendly summary
    if (( ! GP_DRY_RUN )); then
        local last
        last=$(git rev-parse --short HEAD 2>/dev/null || true)
        [[ -n "$last" ]] && log --Info "done ✓ (HEAD=${last})"
    fi

    log_exit
}

# --- Load the rest of the libraries + parse args ------------------------------
# After this source, lib_main will:
#   1) load dependencies (logging/colors/cmdargs/etc.)
#   2) call our define_arguments()
#   3) parse CLI into gp_* vars
#   4) apply library hooks (e.g., logging level, colors)
source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"

# --- Entrypoint ----------------------------------------------------------------
# Call the worker with the original args so it can derive positional message.
_gpush_main "$@"


