#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT_DIR/codex.sh"

setup_stub() {
    local base_dir="$1"
    mkdir -p "$base_dir/bin"
    cat <<'SH' > "$base_dir/bin/codex"
#!/usr/bin/env bash
set -euo pipefail
: "${CODEX_SPY_DIR:?missing CODEX_SPY_DIR}"
printf '%s\n' "$@" > "$CODEX_SPY_DIR/args.txt"
env | sort > "$CODEX_SPY_DIR/env.txt"
SH
    chmod +x "$base_dir/bin/codex"
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

test_default_scrub() {
    local tmp
    tmp=$(mktemp -d)
    (
        set -euo pipefail
        trap 'rm -rf "$tmp"' EXIT
        setup_stub "$tmp"
        export PATH="$tmp/bin:$PATH"
        export EXTRA_VAR="should_not_leak"
        "$SCRIPT" --set CODEX_SPY_DIR="$tmp" -- --hello
        grep -q '^--sandbox$' "$tmp/args.txt"
        grep -q '^workspace-write$' "$tmp/args.txt"
        grep -q '^PYTHONUTF8=1$' "$tmp/env.txt"
        grep -q '^TERM=xterm-256color$' "$tmp/env.txt"
        if grep -q '^EXTRA_VAR=' "$tmp/env.txt"; then
            echo "unexpected EXTRA_VAR" >&2
            return 1
        fi
    )
}

test_keep_and_set() {
    local tmp
    tmp=$(mktemp -d)
    (
        set -euo pipefail
        trap 'rm -rf "$tmp"' EXIT
        setup_stub "$tmp"
        export PATH="$tmp/bin:$PATH"
        export KEEP_ME="keepme"
        "$SCRIPT" --keep KEEP_ME --set CODEX_SPY_DIR="$tmp",INJECTED=value -- --noop
        grep -q '^KEEP_ME=keepme$' "$tmp/env.txt"
        grep -q '^INJECTED=value$' "$tmp/env.txt"
    )
}

test_read_only_mode() {
    local tmp
    tmp=$(mktemp -d)
    (
        set -euo pipefail
        trap 'rm -rf "$tmp"' EXIT
        setup_stub "$tmp"
        export PATH="$tmp/bin:$PATH"
        "$SCRIPT" --read-only --set CODEX_SPY_DIR="$tmp" -- --noop
        if grep -q '^--sandbox$' "$tmp/args.txt"; then
            echo "sandbox flag present in read-only mode" >&2
            return 1
        fi
    )
}

test_inherit_all() {
    local tmp
    tmp=$(mktemp -d)
    (
        set -euo pipefail
        trap 'rm -rf "$tmp"' EXIT
        setup_stub "$tmp"
        export PATH="$tmp/bin:$PATH"
        export CODEX_SPY_DIR="$tmp"
        export EXTRA_ENV="visible"
        "$SCRIPT" --inherit-all -- --noop
        grep -q '^EXTRA_ENV=visible$' "$tmp/env.txt"
    )
}

test_auto_venv() {
    local tmp
    tmp=$(mktemp -d)
    (
        set -euo pipefail
        trap 'rm -rf "$tmp"' EXIT
        setup_stub "$tmp"
        export PATH="$tmp/bin:$PATH"
        export CODEX_SPY_DIR="$tmp"
        mkdir -p "$tmp/work/.venv/bin"
        cat <<'ACT' > "$tmp/work/.venv/bin/activate"
#!/usr/bin/env bash
VIRTUAL_ENV="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VIRTUAL_ENV
export PATH="$VIRTUAL_ENV/bin:$PATH"
ACT
        chmod +x "$tmp/work/.venv/bin/activate"
        pushd "$tmp/work" >/dev/null
        "$SCRIPT" --set CODEX_SPY_DIR="$CODEX_SPY_DIR" -- --noop
        popd >/dev/null
        local expected
        expected="$(cd "$tmp/work/.venv" && pwd)"
        grep -q "^VIRTUAL_ENV=${expected}$" "$tmp/env.txt"
    )
}

test_workspace_extra_dirs() {
    local tmp
    tmp=$(mktemp -d)
    (
        set -euo pipefail
        trap 'rm -rf "$tmp"' EXIT
        setup_stub "$tmp"
        export PATH="$tmp/bin:$PATH"
        export CODEX_SPY_DIR="$tmp"
        export CODEX_ADDITIONAL_ACCESS_DIRS="/opt/data,/var/logs/"
        local workdir="$tmp/workdir"
        mkdir -p "$workdir"
        pushd "$workdir" >/dev/null
        "$SCRIPT" --set CODEX_SPY_DIR="$CODEX_SPY_DIR" -- --noop
        popd >/dev/null
        local normalized_pwd
        normalized_pwd=$(cd "$workdir" && pwd)
        local normalized_tmp=""
        if [[ -n "${TMPDIR:-}" ]]; then
            normalized_tmp="$TMPDIR"
            while [[ "$normalized_tmp" != "/" && "$normalized_tmp" == */ ]]; do
                normalized_tmp="${normalized_tmp%/}"
            done
        fi
        local -a expected_roots=("$normalized_pwd")
        if [[ -n "$normalized_tmp" ]]; then
            expected_roots+=("$normalized_tmp")
        fi
        expected_roots+=("/opt/data" "/var/logs")
        local expected_json="["
        local first=1
        local root
        for root in "${expected_roots[@]}"; do
            [[ -z "$root" ]] && continue
            local escaped="${root//\\/\\\\}"
            escaped=${escaped//\"/\\\"}
            if (( first )); then
                first=0
            else
                expected_json+=","
            fi
            expected_json+="\"$escaped\""
        done
        expected_json+="]"
        local expected_override="sandbox.workspace_write.writable_roots=${expected_json}"
        grep -Fq -- "$expected_override" "$tmp/args.txt"
    )
}

main() {
    local failures=0
    run_test "codex default scrub" test_default_scrub || failures=1
    run_test "codex keep + set" test_keep_and_set || failures=1
    run_test "codex read-only" test_read_only_mode || failures=1
    run_test "codex inherit-all" test_inherit_all || failures=1
    run_test "codex auto venv" test_auto_venv || failures=1
    run_test "codex extra sandbox dirs" test_workspace_extra_dirs || failures=1
    return $failures
}

main
