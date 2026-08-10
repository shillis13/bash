#!/bin/bash
#========================================
# sync_ai_repos.sh
# Syncs all AI repos (ai_root + submodules) with origin/main
# Pull first (with rebase), then push
#========================================

set +e  # Continue on error — individual repo failures are tracked and reported at the end

AI_ROOT="${HOME}/AI/ai_root"
BRANCH="main"
REMOTE="origin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a FAILED_REPOS=()

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }


#----------------------------------------
# sync_repo: Syncs a single repository
# Args: $1 = repo path, $2 = repo name
#----------------------------------------
sync_repo() {
    local repo_path="$1"
    local repo_name="$2"
    
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Syncing: ${repo_name}"
    log_info "Path: ${repo_path}"
    
    # .git can be a directory (normal repo) or file (submodule pointer)
    if [[ ! -e "${repo_path}/.git" ]]; then
        log_error "Not a git repository: ${repo_path}"
        FAILED_REPOS+=("${repo_name}")
        ((FAIL_COUNT++))
        return 1
    fi
    
    cd "${repo_path}" || return 1
    
    # Check current branch
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    
    if [[ "${current_branch}" != "${BRANCH}" ]]; then
        log_warn "On branch '${current_branch}', not '${BRANCH}'"
        log_info "Switching to ${BRANCH}..."
        git checkout "${BRANCH}" 2>/dev/null || {
            log_error "Failed to switch to ${BRANCH}"
            FAILED_REPOS+=("${repo_name}")
            ((FAIL_COUNT++))
            return 1
        }
    fi

    # Check for uncommitted changes - commit them
    local has_changes=false
    if ! git diff --quiet HEAD 2>/dev/null; then
        has_changes=true
    fi
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        has_changes=true
    fi
    
    if [[ "${has_changes}" == "true" ]]; then
        log_info "Uncommitted changes detected - committing..."
        git add -A
        git commit -m "sync: auto-commit $(date +%Y-%m-%d_%H%M%S)" || {
            log_error "Failed to commit changes"
            FAILED_REPOS+=("${repo_name}")
            ((FAIL_COUNT++))
            return 1
        }
    fi
    
    # Fetch latest from remote
    log_info "Fetching from ${REMOTE}..."
    git fetch "${REMOTE}" 2>/dev/null || {
        log_error "Failed to fetch from ${REMOTE}"
        FAILED_REPOS+=("${repo_name}")
        ((FAIL_COUNT++))
        return 1
    }
    
    # Pull with rebase (most reliable for avoiding merge commits)
    log_info "Pulling (rebase) from ${REMOTE}/${BRANCH}..."
    git pull --rebase "${REMOTE}" "${BRANCH}" 2>/dev/null || {
        log_error "Pull failed - may have conflicts"
        git rebase --abort 2>/dev/null
        FAILED_REPOS+=("${repo_name}")
        ((FAIL_COUNT++))
        return 1
    }
    
    # Push local commits
    log_info "Pushing to ${REMOTE}/${BRANCH}..."
    git push "${REMOTE}" "${BRANCH}" 2>/dev/null || {
        log_warn "Push failed or nothing to push"
    }
    
    log_success "Synced: ${repo_name}"
    ((SUCCESS_COUNT++))
    return 0
}


#----------------------------------------
# usage: state what this script DOES, so the danger is visible before it runs.
# (Mechanism is documented inside the function, next to the code it describes.)
#----------------------------------------
usage() {
    # Colour variables hold REAL ANSI bytes (via $'...') rather than the literal
    # "\033[...m" text the log_* helpers rely on, so every line below can be printed
    # with '%s' — which does NOT interpret anything.
    #
    # This used printf '%b', which interprets backslash escapes in whatever it is given
    # — including AI_ROOT, which derives from HOME. A HOME containing the literal
    # characters \033[35m therefore injected real terminal control bytes into piped
    # help (GG round 2). Data goes through %s; only trusted constants carry escapes.
    #
    # fd 1 is the right stream to test even when the caller does `usage >&2`: a function
    # redirection makes fd 1 refer to stderr inside the function. The previous
    # USAGE_TO_STDERR variable was both unnecessary and let the caller's environment
    # influence the decision (GG).
    local Y="" R="" B="" N=""
    if [[ -t 1 ]]; then
        Y=$'\033[1;33m'; R=$'\033[0;31m'; B=$'\033[0;34m'; N=$'\033[0m'
    fi

    printf '%s\n' "${Y}sync_ai_repos${N} — commit, pull --rebase, and push EVERY AI repo."
    printf '%s\n' ""
    printf '%s\n' "${R}THIS SCRIPT WRITES AND PUBLISHES. IT IS NOT A STATUS COMMAND.${N}"
    printf '%s\n' "In each repository listed below it runs ${R}git add -A${N} and commits ALL"
    printf '%s\n' "uncommitted work — staged, unstaged and untracked — as a single"
    printf '%s\n' "\"sync: auto-commit\" with no todo reference, then rebases on"
    printf '%s\n' "${REMOTE}/${BRANCH} and pushes."
    printf '%s\n' ""
    printf '%s\n' "There is no dry-run and no confirmation. Work that is half-finished,"
    printf '%s\n' "under review, or deliberately being held WILL be committed and pushed."
    printf '%s\n' ""
    printf '%s\n' "${B}Usage:${N}"
    printf '%s\n' "  sync_ai_repos [-h|--help]"
    printf '%s\n' ""
    printf '%s\n' "  No other options are accepted. An unrecognised argument is an error"
    printf '%s\n' "  and nothing is synced."
    printf '%s\n' ""
    printf '%s\n' "${B}Repositories affected:${N}"
    printf '%s\n' "  Submodules under ${AI_ROOT}:"
    printf '%s\n' "    ai_comms, ai_general, ai_memories, ai_story_teller, ai_chat_artifacts"
    printf '%s\n' "  Standalone:"
    printf '%s\n' "    ~/bin/bash, ~/bin/python, ~/_configs, ~/AI/uai_toolkit, ~/AI/ai_toolkit"
    printf '%s\n' "  Then the parent repo ${AI_ROOT} itself, including submodule pointers."
    printf '%s\n' ""
    printf '%s\n' "${B}To inspect without changing anything, use git directly:${N}"
    printf '%s\n' "  git -C ${AI_ROOT}/ai_general status --short"
    printf '%s\n' "  git -C ${AI_ROOT} submodule foreach 'git status --short'"
    printf '%s\n' ""
    printf '%s\n' "${B}Exit codes:${N}"
    printf '%s\n' "  0  no failure that this script counts as one."
    printf '%s\n' "     ${R}This does NOT mean everything synced.${N} A failed PUSH is logged as a"
    printf '%s\n' "     warning and still counts as success, and a missing repository is"
    printf '%s\n' "     counted as skipped. Both can exit 0. Read the summary, not the exit code."
    printf '%s\n' "  1  one or more repos failed the checks it does count (listed in the summary)"
    printf '%s\n' "  2  bad usage — nothing was synced"
    printf '%s\n' ""
    printf '%s\n' "${Y}Why this help exists:${N} on 2026-08-09 this script ignored its arguments"
    printf '%s\n' "entirely, so running it with --help performed a FULL SYNC: 199 files"
    printf '%s\n' "committed and pushed in ai_general alone, including work that was blocked"
    printf '%s\n' "in review. A read-only probe published other people's unfinished work."
    printf '%s\n' "See todo_0810."
}

#----------------------------------------
# Arguments — parsed BEFORE anything else happens.
#
# The script previously did "main \"$@\"" into a main() that never read them, so EVERY
# argument (--help, --dry-run, a typo) ran a full commit-and-push across 11 repos.
#
# Unknown arguments are a hard error rather than being ignored. Accepting only --help
# would fix the one instance and leave the class: --dry-run would still sync everything,
# which is the exact shape of what went wrong. This also matches the existing convention
# in this repo — see find_git_repos.sh.
#----------------------------------------
parse_args() {
    local ER="" EN=""
    if [[ -t 2 ]]; then ER=$'\033[0;31m'; EN=$'\033[0m'; fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            *)
                # '%s' for the argument: it is caller-controlled, and '%b' interpreted
                # backslash escapes in it, so `--bad\033[31mRED` put real control bytes
                # on stderr (GG round 2).
                printf '%s\n' "${ER}[ERROR]${EN} Unknown option: $1" >&2
                printf '%s\n' "${ER}[ERROR]${EN} Nothing was synced." >&2
                printf '%s\n' "" >&2
                usage >&2
                exit 2
                ;;
        esac
    done
}


#----------------------------------------
# Main execution
#----------------------------------------
main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║       AI Repos Sync Script             ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    log_info "AI Root: ${AI_ROOT}"
    log_info "Branch: ${BRANCH}"
    log_info "Remote: ${REMOTE}"
    
    if [[ ! -d "${AI_ROOT}" ]]; then
        log_error "AI root directory not found: ${AI_ROOT}"
        exit 1
    fi

    cd "${AI_ROOT}"
    
    # Submodules defined in .gitmodules
    # NOTE: ai_chatgpt and ai_claude were demoted from submodules (2026-03-22)
    #       ai_general/docs was demoted from submodule (2026-03-22)
    #       Platform dirs moved to ai_platforms/ (2026-03-22)
    local submodules=(
        "ai_comms"
        "ai_general"
        "ai_memories"
        "ai_story_teller"
        "ai_chat_artifacts"
    )

    # Additional standalone repos to sync
    local additional_repos=(
        "${HOME}/bin/bash"
        "${HOME}/bin/python"
        "${HOME}/_configs"
        "${HOME}/AI/uai_toolkit"
        "${HOME}/AI/ai_toolkit"
    )

    # First sync all submodules
    log_info "Syncing ${#submodules[@]} submodules..."

    for submod in "${submodules[@]}"; do
        local submod_path="${AI_ROOT}/${submod}"
        if [[ -d "${submod_path}" ]]; then
            sync_repo "${submod_path}" "${submod}"
        else
            log_warn "Submodule directory not found: ${submod}"
            ((SKIP_COUNT++))
        fi
    done

    # Sync additional standalone repos
    log_info ""
    log_info "Syncing ${#additional_repos[@]} additional repos..."

    for repo_path in "${additional_repos[@]}"; do
        local repo_name
        repo_name=$(basename "${repo_path}")
        if [[ -d "${repo_path}" ]]; then
            sync_repo "${repo_path}" "${repo_name}"
        else
            log_warn "Additional repo not found: ${repo_path}"
            ((SKIP_COUNT++))
        fi
    done
    
    # Then sync the parent repo (ai_root)
    log_info ""
    log_info "Now syncing parent repo (ai_root)..."
    
    # Update submodule references in parent
    cd "${AI_ROOT}"
    git add -A  # Stage any submodule pointer changes
    
    if ! git diff --cached --quiet 2>/dev/null; then
        log_info "Submodule references changed - committing..."
        git commit -m "chore: update submodule references $(date +%Y-%m-%d)" || true
    fi
    
    sync_repo "${AI_ROOT}" "ai_root (parent)"

    # Print summary
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║             Sync Summary               ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    log_success "Successful: ${SUCCESS_COUNT}"
    [[ ${FAIL_COUNT} -gt 0 ]] && log_error "Failed: ${FAIL_COUNT}"
    [[ ${SKIP_COUNT} -gt 0 ]] && log_warn "Skipped: ${SKIP_COUNT}"

    # Update repo status for prompt
    ~/bin/ai/utils/repo_status.py -b --show-clean -q -o ~/.repo_status 2>/dev/null || true

    if [[ ${#FAILED_REPOS[@]} -gt 0 ]]; then
        echo ""
        log_error "Failed repos:"
        for repo in "${FAILED_REPOS[@]}"; do
            echo "  - ${repo}"
        done
        exit 1
    fi
    
    echo ""
    log_success "All repos synced successfully!"
    exit 0
}

# Arguments are resolved FIRST. "main \"$@\"" alone was the whole defect: main() never
# looked at them, so --help ran the sync (todo_0810).
parse_args "$@"
main
