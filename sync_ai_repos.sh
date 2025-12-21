#!/bin/bash
#========================================
# sync_ai_repos.sh
# Syncs all AI repos (ai_root + submodules) with origin/main
# Pull first (with rebase), then push
#========================================

set -e  # Exit on error

AI_ROOT="${HOME}/Documents/AI/ai_root"
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
    local submodules=(
        "ai_chatgpt"
        "ai_claude"
        "ai_comms"
        "ai_general"
        "ai_memories"
        "ai_story_teller"
        "ai_chat_artifacts"
        "ai_general/docs"
    )

    # Additional standalone repos to sync
    local additional_repos=(
        "${HOME}/bin/bash"
        "${HOME}/bin/python"
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

# Run main
main "$@"
