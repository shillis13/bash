#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# SCRIPT: gpull.sh
# PURPOSE: Pull latest changes from the current git branch, showing context
#          (repo, branch, remote), with optional dry-run or apply execution mode.
#          Implements the explicit initialization pattern for the bash framework.
# -----------------------------------------------------------------------------

# --- Framework Bootstrap ------------------------------------------------------
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/libs/lib_core.sh"

# --- Argument Definitions -----------------------------------------------------
define_arguments() {
    libCmd_add -t switch -f n --long dry-run   -v "gp_dry_run" -d "$FALSE" -m once -u "Show commands without executing"
    libCmd_add -t switch -f a --long apply     -v "gp_apply"   -d "$FALSE" -m once -u "Actually execute commands (overrides dry-run)"
    libCmd_add -t switch -f f --long fetch     -v "gp_fetch"   -d "$FALSE" -m once -u "Run git fetch before pull"
    libCmd_add -t value  -f r --long remote    -v "gp_remote"  -d "origin" -m once -u "Remote name to pull from"
    libCmd_add -t value  -f b --long branch    -v "gp_branch"  -d ""       -m once -u "Branch name to pull (default: current)"
}

# --- Dependencies -------------------------------------------------------------
load_dependencies() {
    lib_require "lib_bool.sh"
    lib_require "lib_main.sh"
}

# --- Main Orchestration --------------------------------------------------------
main() {
    load_dependencies
    if ! initializeScript "$@"; then
        return 1
    fi

    _gpull_main "$@"
}

# --- Main Logic ---------------------------------------------------------------
_gpull_main() {
    local branch remote cmd

    # Determine current branch if not set
    branch=${gp_branch:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}
    remote=${gp_remote:-origin}

    log_entry "git-pull" "repo=$(basename $(git rev-parse --show-toplevel 2>/dev/null)) branch=$branch remote=$remote"

    if bool_is_true "$gp_fetch"; then
        runCommand "git fetch $remote"
    fi

    cmd="git pull $remote $branch"

    if bool_is_true "$gp_apply"; then
        runCommand "$cmd"
    elif bool_is_true "$gp_dry_run"; then
        log "DRY RUN — would execute: $cmd"
    else
        log "INFO — neither --apply nor --dry-run specified; defaulting to dry run"
        log "Would execute: $cmd"
    fi

    log_exit
}

# --- Entry Point --------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    source "${SCRIPT_DIR}/libs/lib_main.sh" "$@"
    main "$@"
fi

