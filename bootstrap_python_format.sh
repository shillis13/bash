#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$PWD}"
DEPTH=6
FORMATTER="ruff"
FORCE=0

usage(){ cat <<'EOF'
Usage: bootstrap_python_format.sh [ROOT] [-d DEPTH] [--formatter ruff|black] [--force]
EOF
}
# Parse flags
if [[ $# -gt 0 && "$1" != "-"* ]]; then ROOT="$1"; shift; fi
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--depth) DEPTH="${2:?}"; shift 2;;
        --formatter) FORMATTER="${2:?}"; shift 2;;
        --force) FORCE=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown option: $1"; usage; exit 2;;
    esac
done
[[ "$FORMATTER" =~ ^(ruff|black)$ ]] || { echo "Invalid --formatter: $FORMATTER"; exit 2; }

have(){ command -v "$1" >/dev/null 2>&1; }
timestamp(){ date +%Y%m%d-%H%M%S; }
bak(){ local f="$1"; [[ -e "$f" ]] && mv -v "$f" "$f.bak.$(timestamp)"; }

pyproject_ruff(){ cat <<'TOML'
[tool.ruff]
line-length = 100
[tool.ruff.lint]
select = ["E","F","I","B","UP"]
[tool.ruff.format]
indent-style = "space"
quote-style  = "double"
TOML
}
pyproject_black(){ cat <<'TOML'
[tool.ruff]
line-length = 100
[tool.ruff.lint]
select = ["E","F","I","B","UP"]
[tool.black]
line-length = 100
target-version = ["py311"]
TOML
}
precommit_ruff(){ cat <<'YAML'
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
YAML
}
precommit_black(){ cat <<'YAML'
repos:
  - repo: https://github.com/psf/black
    rev: 24.10.0
    hooks:
      - id: black
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
        args: [--fix]
YAML
}

declare -a CANDIDATES
# 1) repos with a visible .git dir/file (fast path)
while IFS= read -r -d '' p; do CANDIDATES+=("$(dirname "$p")"); done < <(
    find "$ROOT" -maxdepth "$DEPTH" \( -type d -name .git -o -type f -name .git \) -print0
)
# 2) ask git for each directory (fallback) — processed one-by-one to avoid ARG_MAX
while IFS= read -r -d '' d; do
    if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        CANDIDATES+=("$d")
    fi
done < <(find "$ROOT" -maxdepth "$DEPTH" -type d -print0)

# uniq + sort
mapfile -t CANDIDATES < <(printf '%s\n' "${CANDIDATES[@]}" | awk '!seen[$0]++' | sort -u)
[[ ${#CANDIDATES[@]} -eq 0 ]] && { echo "No git repos found under $ROOT (depth $DEPTH)."; exit 0; }

stats_total=0; stats_cfg=0; stats_hooks=0; stats_skip=0
for repo in "${CANDIDATES[@]}"; do
    ((stats_total++))
    root="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -z "$root" ]] && { ((stats_skip++)); continue; }
    echo "==> $root"
    changed=0

    py="$root/pyproject.toml"
    if [[ -e "$py" && $FORCE -eq 0 ]]; then
        echo "    pyproject.toml exists (keep)"
    else
        [[ -e "$py" && $FORCE -eq 1 ]] && bak "$py"
        if [[ "$FORMATTER" == "ruff" ]]; then pyproject_ruff >"$py"; else pyproject_black >"$py"; fi
        echo "    wrote pyproject.toml ($FORMATTER)"
        changed=1
    fi

    pc="$root/.pre-commit-config.yaml"
    if [[ -e "$pc" && $FORCE -eq 0 ]]; then
        echo "    .pre-commit-config.yaml exists (keep)"
    else
        [[ -e "$pc" && $FORCE -eq 1 ]] && bak "$pc"
        if [[ "$FORMATTER" == "ruff" ]]; then precommit_ruff >"$pc"; else precommit_black >"$pc"; fi
        echo "    wrote .pre-commit-config.yaml"
        changed=1
    fi

    if have pre-commit; then
        ( cd "$root" && pre-commit install --install-hooks >/dev/null )
        echo "    pre-commit hook installed"
        ((stats_hooks++))
    else
        echo "    (pre-commit not found; run: pipx install pre-commit || pip install pre-commit)"
    fi

    (( changed == 1 )) && ((stats_cfg++)) || true
done

echo
echo "Summary: repos seen=${stats_total}, configured(new/updated)=${stats_cfg}, hooks installed=${stats_hooks}, skipped=${stats_skip}"
echo "Done."


