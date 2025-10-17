#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)

PASS_COUNT=0
FAIL_COUNT=0

run_case() {
    local name="$1"
    shift
    if "$@"; then
        echo "PASS: $name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $name"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

setup_remote_repo() {
    local base
    base=$(mktemp -d)
    local remote="$base/remote.git"
    git init --bare "$remote" >/dev/null

    git clone "$remote" "$base/seed" >/dev/null 2>&1
    pushd "$base/seed" >/dev/null
    git config user.email tester@example.com
    git config user.name "Test User"

    echo "base" > README.md
    git add README.md
    git commit -m "initial" >/dev/null 2>&1
    git branch -M main
    git push origin main >/dev/null 2>&1

    git checkout -b feature >/dev/null 2>&1
    echo "feature" > feature.txt
    git add feature.txt
    git commit -m "feature work" >/dev/null 2>&1
    git push origin feature >/dev/null 2>&1

    git checkout main >/dev/null 2>&1
    echo "upstream" >> README.md
    git commit -am "upstream main" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1
    popd >/dev/null
    rm -rf "$base/seed"

    printf '%s\n' "$base"
}

cleanup_repo() {
    local base="$1"
    rm -rf "$base"
}

test_rebase_mode() {
    local base
    base=$(setup_remote_repo)
    local remote="$base/remote.git"

    git clone "$remote" "$base/rebase" >/dev/null 2>&1
    pushd "$base/rebase" >/dev/null
    git config user.email tester@example.com
    git config user.name "Test User"
    git checkout feature >/dev/null 2>&1

    if ! "$REPO_ROOT/gh_branch_refresh.sh" --exec --head feature --src main --mode rebase >/dev/null 2>&1; then
        popd >/dev/null
        cleanup_repo "$base"
        return 1
    fi

    git fetch origin >/dev/null 2>&1
    local count
    count=$(git rev-list --count origin/main..origin/feature)
    local merge_check
    merge_check=$(git log origin/feature --merges -1 --pretty=format:%s 2>/dev/null || true)
    popd >/dev/null
    cleanup_repo "$base"

    [[ "$count" -eq 1 ]] && [[ -z "$merge_check" ]]
}

test_merge_mode() {
    local base
    base=$(setup_remote_repo)
    local remote="$base/remote.git"

    git clone "$remote" "$base/merge" >/dev/null 2>&1
    pushd "$base/merge" >/dev/null
    git config user.email tester@example.com
    git config user.name "Test User"
    git checkout feature >/dev/null 2>&1

    if ! "$REPO_ROOT/gh_branch_refresh.sh" --exec --head feature --src main --mode merge >/dev/null 2>&1; then
        popd >/dev/null
        cleanup_repo "$base"
        return 1
    fi

    git fetch origin >/dev/null 2>&1
    local merge_msg
    merge_msg=$(git log origin/feature --merges -1 --pretty=format:%s)
    popd >/dev/null
    cleanup_repo "$base"

    if [[ -z "$merge_msg" ]]; then
        return 1
    fi
    if [[ "$merge_msg" == "Merge branch 'main' into feature" ]]; then
        return 0
    fi
    if [[ "$merge_msg" == "Merge remote-tracking branch 'origin/main' into feature" ]]; then
        return 0
    fi
    return 1
}

test_tick_mode() {
    local base
    base=$(setup_remote_repo)
    local remote="$base/remote.git"

    git clone "$remote" "$base/tick" >/dev/null 2>&1
    pushd "$base/tick" >/dev/null
    git config user.email tester@example.com
    git config user.name "Test User"
    git checkout feature >/dev/null 2>&1

    if ! "$REPO_ROOT/gh_branch_refresh.sh" --exec --head feature --mode tick >/dev/null 2>&1; then
        popd >/dev/null
        cleanup_repo "$base"
        return 1
    fi

    git fetch origin >/dev/null 2>&1
    local last_msg
    last_msg=$(git log origin/feature -1 --pretty=format:%s)
    local diff_files
    diff_files=$(git diff-tree --no-commit-id --name-only -r origin/feature)
    popd >/dev/null
    cleanup_repo "$base"

    [[ "$last_msg" == chore:\ tick\ feature* ]] && [[ -z "$diff_files" ]]
}

run_case "rebase mode" test_rebase_mode
run_case "merge mode" test_merge_mode
run_case "tick mode" test_tick_mode

if (( FAIL_COUNT > 0 )); then
    exit 1
fi

echo "All tests passed ($PASS_COUNT)."
