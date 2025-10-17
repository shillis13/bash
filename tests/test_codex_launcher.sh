#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_DIR=$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; }

_write_stub() {
    local dir="$1"
    cat <<'STUB' >"$dir/codex"
#!/usr/bin/env bash
: "${CODEX_STUB_OUT:?}"
printf 'ARGS:%s\n' "$*" >"$CODEX_STUB_OUT"
(env | sort) >>"$CODEX_STUB_OUT"
STUB
    chmod +x "$dir/codex"
}

test_default_scrub() {
    local tmp; tmp=$(mktemp -d)
    mkdir -p "$tmp/bin"
    local out="$tmp/out.txt"
    _write_stub "$tmp/bin"

    local prev_path="$PATH"
    PATH="$tmp/bin:$PATH" "$REPO_DIR/codex.sh" --set "CODEX_STUB_OUT=$out" -- foo bar >/dev/null 2>&1 || return 1

    if [[ ! -f "$out" ]]; then
        return 1
    fi

    if ! grep -q 'ARGS:--sandbox workspace-write --ask-for-approval on-request -- foo bar' "$out"; then
        return 1
    fi

    if ! grep -q '^TERM=xterm-256color' "$out"; then
        return 1
    fi

    if grep -q '^HOME=' "$out"; then
        return 1
    fi

    PATH="$prev_path"
    rm -rf "$tmp"
    return 0
}

test_inherit_and_model() {
    local tmp; tmp=$(mktemp -d)
    mkdir -p "$tmp/bin"
    local out="$tmp/out.txt"
    _write_stub "$tmp/bin"

    local prev_path="$PATH"
    PATH="$tmp/bin:$PATH" "$REPO_DIR/codex.sh" --inherit-all --read-only --keep HOME,USER --set "CODEX_STUB_OUT=$out" --model test-model >/dev/null 2>&1 || return 1

    if ! grep -q 'ARGS:--ask-for-approval on-request --' "$out"; then
        return 1
    fi
    if grep -q -- '--sandbox workspace-write' "$out"; then
        return 1
    fi
    if ! grep -q -- '--model test-model' "$out"; then
        return 1
    fi
    if ! grep -q '^HOME=' "$out"; then
        return 1
    fi
    if ! grep -q '^CODEX_STUB_OUT=' "$out"; then
        return 1
    fi
    if ! grep -q '^PATH=' "$out"; then
        return 1
    fi

    PATH="$prev_path"
    rm -rf "$tmp"
    return 0
}

test_venv_path() {
    local tmp; tmp=$(mktemp -d)
    mkdir -p "$tmp/bin" "$tmp/venv/bin"
    touch "$tmp/venv/bin/activate"
    local out="$tmp/out.txt"
    _write_stub "$tmp/bin"

    local prev_path="$PATH"
    PATH="$tmp/bin:$PATH" "$REPO_DIR/codex.sh" --venv "$tmp/venv" --set "CODEX_STUB_OUT=$out" --read-only >/dev/null 2>&1 || return 1

    if ! grep -q "^VIRTUAL_ENV=$tmp/venv" "$out"; then
        return 1
    fi
    if ! grep -q "^PATH=.*$tmp/venv/bin" "$out"; then
        return 1
    fi

    PATH="$prev_path"
    rm -rf "$tmp"
    return 0
}

main() {
    local status=0
    if test_default_scrub; then
        pass "codex scrubbed env"
    else
        fail "codex scrubbed env"
        status=1
    fi

    if test_inherit_and_model; then
        pass "codex inherit mode"
    else
        fail "codex inherit mode"
        status=1
    fi

    if test_venv_path; then
        pass "codex venv"
    else
        fail "codex venv"
        status=1
    fi

    exit $status
}

main "$@"
