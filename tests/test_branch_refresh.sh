#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/gh_branch_refresh.sh"

git_setup_identity() {
    git config user.email "ci@example.com"
    git config user.name "CI Bot"
}

run_test() {
    local name="$1"
    shift
    if "$@"; then
        echo "PASS: $name"
    else
        echo "FAIL: $name"
        return 1
    fi
}

test_rebase_mode() {
    local tmp
    tmp=$(mktemp -d)
    (
        set -euo pipefail
        trap 'rm -rf "$tmp"' EXIT
        git init --bare "$tmp/remote.git"
        git clone "$tmp/remote.git" "$tmp/work"
        pushd "$tmp/work" >/dev/null
        git_setup_identity
        touch README.md
        git add README.md
        git commit -m "initial"
        git branch -M main
        git push -u origin main

        git checkout -b feature/rebase
        echo "feature" > feature.txt
        git add feature.txt
        git commit -m "feature work"
        git push -u origin feature/rebase

        git checkout main
        echo "main" >> README.md
        git add README.md
        git commit -m "main update"
        git push origin main

        git checkout feature/rebase
        "$SCRIPT" --head feature/rebase --src main --mode rebase
        git fetch origin feature/rebase
        local local_head remote_head
        local_head=$(git rev-parse HEAD)
        remote_head=$(git rev-parse origin/feature/rebase)
        [[ "$local_head" == "$remote_head" ]]
        set -- $(git rev-list --parents -1 HEAD)
        [[ $# -eq 2 ]]
        popd >/dev/null
    )
}

test_merge_mode() {
    local tmp
    tmp=$(mktemp -d)
    (
        set -euo pipefail
        trap 'rm -rf "$tmp"' EXIT
        git init --bare "$tmp/remote.git"
        git clone "$tmp/remote.git" "$tmp/work"
        pushd "$tmp/work" >/dev/null
        git_setup_identity
        echo "main" > file.txt
        git add file.txt
        git commit -m "initial"
        git branch -M main
        git push -u origin main

        git checkout -b feature/merge
        echo "branch" > branch.txt
        git add branch.txt
        git commit -m "branch commit"
        git push -u origin feature/merge

        git checkout main
        echo "update" >> file.txt
        git add file.txt
        git commit -m "main advance"
        git push origin main

        git checkout feature/merge
        "$SCRIPT" --head feature/merge --src main --mode merge
        git fetch origin feature/merge
        local local_head remote_head
        local_head=$(git rev-parse HEAD)
        remote_head=$(git rev-parse origin/feature/merge)
        [[ "$local_head" == "$remote_head" ]]
        set -- $(git rev-list --parents -1 HEAD)
        [[ $# -eq 3 ]]
        popd >/dev/null
    )
}

test_tick_mode() {
    local tmp
    tmp=$(mktemp -d)
    (
        set -euo pipefail
        trap 'rm -rf "$tmp"' EXIT
        git init --bare "$tmp/remote.git"
        git clone "$tmp/remote.git" "$tmp/work"
        pushd "$tmp/work" >/dev/null
        git_setup_identity
        echo "base" > base.txt
        git add base.txt
        git commit -m "initial"
        git branch -M main
        git push -u origin main

        git checkout -b feature/tick
        echo "line" >> base.txt
        git add base.txt
        git commit -m "branch work"
        git push -u origin feature/tick

        local before
        before=$(git rev-parse origin/feature/tick)
        "$SCRIPT" --head feature/tick --src main --mode tick
        git fetch origin feature/tick
        local after
        after=$(git rev-parse origin/feature/tick)
        [[ "$before" != "$after" ]]
        local local_head
        local_head=$(git rev-parse HEAD)
        [[ "$local_head" == "$after" ]]
        local diff_file
        diff_file="$tmp/diff.txt"
        git diff-tree --no-commit-id --name-only -r HEAD >"$diff_file" || true
        if [[ -s "$diff_file" ]]; then
            cat "$diff_file" >&2
            return 1
        fi
        rm -f "$diff_file"
        popd >/dev/null
    )
}

main() {
    local failures=0
    run_test "branch refresh rebase" test_rebase_mode || failures=1
    run_test "branch refresh merge" test_merge_mode || failures=1
    run_test "branch refresh tick" test_tick_mode || failures=1
    return $failures
}

main
