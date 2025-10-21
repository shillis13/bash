#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
MAXDEPTH=6

usage() {
    cat <<'EOF'
Usage: find_git_repos.sh [ROOT] [-d|--max-depth N]
  ROOT defaults to current directory.
  N defaults to 6.
Examples:
  find_git_repos.sh
  find_git_repos.sh ~/code
  find_git_repos.sh ~/code -d 12
EOF
}

# Allow optional ROOT positional first
if [[ $# -gt 0 && "$1" != -* ]]; then
    ROOT="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--max-depth)
            [[ $# -ge 2 ]] || { echo "Error: missing depth for $1" >&2; exit 1; }
            MAXDEPTH="$2"
            [[ "$MAXDEPTH" =~ ^[0-9]+$ ]] || { echo "Error: depth must be a non-negative integer" >&2; exit 1; }
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 2
            ;;
    esac
done

if [[ ! -d "$ROOT" ]]; then
    echo "Error: ROOT '$ROOT' is not a directory" >&2
    exit 1
fi

repos=()
keys=()

add_repo() {
    local candidate="$1"
    [[ -n "$candidate" ]] || return

    local abs
    if abs="$(cd "$candidate" 2>/dev/null && pwd -P)"; then
        :
    else
        return
    fi

    local existing
    for existing in "${keys[@]}"; do
        if [[ "$existing" == "$abs" ]]; then
            return
        fi
    done

    repos+=("$candidate")
    keys+=("$abs")
}

# 1) Fast path: capture visible .git directories/files
while IFS= read -r -d '' git_entry; do
    add_repo "$(dirname "$git_entry")"
done < <(find "$ROOT" -maxdepth "$MAXDEPTH" \( -type d -name .git -o -type f -name .git \) -print0)

# 2) Fallback: ask git directly for directories that might hide their .git data
while IFS= read -r -d '' dir; do
    toplevel="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$toplevel" ]]; then
        add_repo "$toplevel"
        continue
    fi

    gitdir="$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null || true)"
    [[ -n "$gitdir" ]] || continue
    add_repo "$gitdir"
done < <(
    find "$ROOT" -maxdepth "$MAXDEPTH" \
        \( -name .git -o -name node_modules -o -name .venv -o -name dist -o -name build \) -prune -o \
        -type d -print0
)

printf '%s\n' "${repos[@]}"
