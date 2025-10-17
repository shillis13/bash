#!/usr/bin/env bash
set -euo pipefail

status=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; status=1; }

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

GIT_AUTHOR_NAME="Test User"
GIT_AUTHOR_EMAIL="test@example.com"
GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

create_remote() {
    local name="$1"
    local remote_dir="$tmp_root/${name}_remote.git"
    git init --bare --initial-branch=main "$remote_dir" >/dev/null
    local bootstrap="$tmp_root/${name}_bootstrap"
    git clone "$remote_dir" "$bootstrap" >/dev/null
    (
        cd "$bootstrap"
        git config user.email "$GIT_AUTHOR_EMAIL"
        git config user.name "$GIT_AUTHOR_NAME"
        echo "base" > file.txt
        git add file.txt
        git commit -m "initial" >/dev/null
        git branch -M main >/dev/null 2>&1 || true
        git push origin main >/dev/null
    )
    rm -rf "$bootstrap"
    echo "$remote_dir"
}

update_main_remote() {
    local remote="$1"
    local message="$2"
    local workdir
    workdir=$(mktemp -d "${tmp_root}/update.XXXXXX")
    git clone "$remote" "$workdir" >/dev/null
    (
        cd "$workdir"
        git config user.email "$GIT_AUTHOR_EMAIL"
        git config user.name "$GIT_AUTHOR_NAME"
        git checkout main >/dev/null 2>&1 || git checkout -b main >/dev/null
        echo "$message" >> main.txt
        git add main.txt
        git commit -m "$message" >/dev/null
        git push origin main >/dev/null
    )
    rm -rf "$workdir"
}

# --- Rebase mode ---
remote_rebase=$(create_remote rebase)
feature_dir="$tmp_root/rebase_feature"
git clone "$remote_rebase" "$feature_dir" >/dev/null
(
    cd "$feature_dir"
    git config user.email "$GIT_AUTHOR_EMAIL"
    git config user.name "$GIT_AUTHOR_NAME"
    git checkout -b feature >/dev/null
    echo "feature work" >> file.txt
    git add file.txt
    git commit -m "feature work" >/dev/null
    git push origin feature >/dev/null
)
update_main_remote "$remote_rebase" "main update"
(
    cd "$feature_dir"
    "$repo_root/gh_branch_refresh.sh" --exec --head feature --mode rebase >/dev/null
    git fetch origin >/dev/null
    main_tip=$(git rev-parse origin/main)
    feature_tip=$(git rev-parse HEAD)
    remote_tip=$(git rev-parse origin/feature)
    if [[ "$(git merge-base "$feature_tip" "$main_tip")" == "$main_tip" && "$remote_tip" == "$feature_tip" ]]; then
        pass "Rebase mode fast-forwards onto updated main"
    else
        fail "Rebase mode did not produce expected history"
    fi
)

# --- Merge mode ---
remote_merge=$(create_remote merge)
merge_dir="$tmp_root/merge_feature"
git clone "$remote_merge" "$merge_dir" >/dev/null
(
    cd "$merge_dir"
    git config user.email "$GIT_AUTHOR_EMAIL"
    git config user.name "$GIT_AUTHOR_NAME"
    git checkout -b feature >/dev/null
    echo "feature work" >> file.txt
    git add file.txt
    git commit -m "feature work" >/dev/null
    git push origin feature >/dev/null
)
update_main_remote "$remote_merge" "main update"
(
    cd "$merge_dir"
    "$repo_root/gh_branch_refresh.sh" --exec --head feature --mode merge >/dev/null
    git fetch origin >/dev/null
    head_tip=$(git rev-parse HEAD)
    parents=$(git rev-list --parents -1 HEAD)
    remote_tip=$(git rev-parse origin/feature)
    set -- $parents
    if (( $# == 3 )) && [[ "$remote_tip" == "$head_tip" ]]; then
        pass "Merge mode creates merge commit and pushes"
    else
        fail "Merge mode did not merge as expected"
    fi
)

# --- Tick mode ---
remote_tick=$(create_remote tick)
tick_dir="$tmp_root/tick_feature"
git clone "$remote_tick" "$tick_dir" >/dev/null
(
    cd "$tick_dir"
    git config user.email "$GIT_AUTHOR_EMAIL"
    git config user.name "$GIT_AUTHOR_NAME"
    git checkout -b feature >/dev/null
    echo "feature work" >> file.txt
    git add file.txt
    git commit -m "feature work" >/dev/null
    git push origin feature >/dev/null
    "$repo_root/gh_branch_refresh.sh" --exec --head feature --mode tick >/dev/null
    git fetch origin >/dev/null
    tick_tip=$(git rev-parse HEAD)
    remote_tip=$(git rev-parse origin/feature)
    last_message=$(git log -1 --pretty=%s)
    changes=$(git diff-tree --no-commit-id --name-only -r HEAD)
    if [[ "$last_message" == "chore: tick feature" ]] && [[ -z "$changes" ]] && [[ "$tick_tip" == "$remote_tip" ]]; then
        pass "Tick mode creates empty commit and pushes"
    else
        fail "Tick mode did not create expected commit"
    fi
)

exit $status
