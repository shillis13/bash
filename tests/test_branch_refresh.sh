#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_DIR=$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; }

setup_repo() {
    local root; root=$(mktemp -d)
    TEST_REMOTE="$root/remote.git"
    TEST_WORKTREE="$root/work"
    git init --bare "$TEST_REMOTE" >/dev/null 2>&1
    git clone "$TEST_REMOTE" "$TEST_WORKTREE" >/dev/null 2>&1
    pushd "$TEST_WORKTREE" >/dev/null 2>&1
    git config user.name "Test User"
    git config user.email "test@example.com"
    git checkout -b main >/dev/null 2>&1
    popd >/dev/null 2>&1
}

cleanup_repo() {
    [[ -n "${TEST_WORKTREE:-}" ]] && rm -rf "$(dirname "$TEST_WORKTREE")"
}

test_rebase_mode() {
    setup_repo
    pushd "$TEST_WORKTREE" >/dev/null 2>&1

    echo "base" >file.txt
    git add file.txt
    git commit -m "base" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1

    git checkout -b feature >/dev/null 2>&1
    echo "feature" >>file.txt
    git add file.txt
    git commit -m "feature work" >/dev/null 2>&1
    git push -u origin feature >/dev/null 2>&1

    git checkout main >/dev/null 2>&1
    echo "upstream" >main_only.txt
    git add main_only.txt
    git commit -m "upstream update" >/dev/null 2>&1
    git push >/dev/null 2>&1

    git checkout feature >/dev/null 2>&1
    if ! "$REPO_DIR/gh_branch_refresh.sh" --head feature --mode rebase >/dev/null 2>&1; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    local base
    base=$(git merge-base feature origin/main)
    if [[ "$base" != "$(git rev-parse origin/main)" ]]; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    if [[ "$(git rev-parse feature)" != "$(git rev-parse origin/feature)" ]]; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    popd >/dev/null 2>&1
    cleanup_repo
    return 0
}

test_merge_mode() {
    setup_repo
    pushd "$TEST_WORKTREE" >/dev/null 2>&1

    echo "base" >file.txt
    git add file.txt
    git commit -m "base" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1

    git checkout -b feature >/dev/null 2>&1
    echo "feature" >>file.txt
    git add file.txt
    git commit -m "feature work" >/dev/null 2>&1
    git push -u origin feature >/dev/null 2>&1

    git checkout main >/dev/null 2>&1
    echo "upstream" >main_only.txt
    git add main_only.txt
    git commit -m "upstream update" >/dev/null 2>&1
    git push >/dev/null 2>&1

    git checkout feature >/dev/null 2>&1
    if ! "$REPO_DIR/gh_branch_refresh.sh" --head feature --mode merge >/dev/null 2>&1; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    if [[ "$(git rev-parse feature)" != "$(git rev-parse origin/feature)" ]]; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    if [[ "$(git rev-parse main)" != "$(git rev-parse origin/main)" ]]; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    popd >/dev/null 2>&1
    cleanup_repo
    return 0
}

test_tick_mode() {
    setup_repo
    pushd "$TEST_WORKTREE" >/dev/null 2>&1

    echo "base" >file.txt
    git add file.txt
    git commit -m "base" >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1

    git checkout -b feature >/dev/null 2>&1
    git push -u origin feature >/dev/null 2>&1

    local before
    before=$(git rev-parse feature)

    if ! "$REPO_DIR/gh_branch_refresh.sh" --head feature --mode tick >/dev/null 2>&1; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    local after
    after=$(git rev-parse feature)
    if [[ "$before" == "$after" ]]; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    if [[ "$(git log -1 --pretty=%B)" != "chore: tick feature against main" ]]; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    if [[ "$(git rev-parse feature)" != "$(git rev-parse origin/feature)" ]]; then
        popd >/dev/null 2>&1
        cleanup_repo
        return 1
    fi

    popd >/dev/null 2>&1
    cleanup_repo
    return 0
}

main() {
    local status=0
    if test_rebase_mode; then
        pass "branch refresh rebase"
    else
        fail "branch refresh rebase"
        status=1
    fi

    if test_merge_mode; then
        pass "branch refresh merge"
    else
        fail "branch refresh merge"
        status=1
    fi

    if test_tick_mode; then
        pass "branch refresh tick"
    else
        fail "branch refresh tick"
        status=1
    fi

    exit $status
}

main "$@"
