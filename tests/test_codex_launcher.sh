#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)

PASS_COUNT=0
FAIL_COUNT=0

TMP_ROOT=$(mktemp -d)
FAKE_BIN="${TMP_ROOT}/bin"
LOG_FILE="${TMP_ROOT}/codex.log"
mkdir -p "$FAKE_BIN"
: > "$LOG_FILE"

create_fake_codex() {
    cat <<'CODEx' > "${FAKE_BIN}/codex"
#!/usr/bin/env bash
log_file="${CODEX_LOG_FILE:-}"
if [[ -z "$log_file" ]]; then
    echo "CODEX_LOG_FILE not set" >&2
    exit 1
fi
{
    echo "----"
    env | sort
    printf 'ARGS:%s\n' "$*"
} >> "$log_file"
CODEx
    chmod +x "${FAKE_BIN}/codex"
}

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

create_fake_codex

last_block() {
    awk 'BEGIN{block=0} /^----$/ {block++; next} {data[block]=data[block] $0 ORS} END{printf "%s", data[block]}' "$LOG_FILE"
}

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

assert_contains() {
    local haystack="$1"
    local needle="$2"
    grep -Fq -- "$needle" <<<"$haystack"
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    if grep -Fq -- "$needle" <<<"$haystack"; then
        return 1
    fi
    return 0
}

test_default_write_mode() {
    > "$LOG_FILE"
    TEST_ENV_PERSIST="should_not_inherit" PATH="${FAKE_BIN}:$PATH" \
        "${REPO_ROOT}/codex.sh" --exec --set CODEX_LOG_FILE="${LOG_FILE}" default-arg >/dev/null 2>&1
    local block
    block="$(last_block)"
    assert_contains "$block" "TERM=xterm-256color" &&
        assert_contains "$block" "PYTHONUTF8=1" &&
        assert_contains "$block" "LC_ALL=C.UTF-8" &&
        assert_contains "$block" "LANG=C.UTF-8" &&
        assert_contains "$block" "ARGS:--sandbox workspace-write --ask-for-approval on-request -- default-arg" &&
        assert_not_contains "$block" "TEST_ENV_PERSIST=should_not_inherit" &&
        assert_contains "$block" "PATH=${FAKE_BIN}:"
}

test_read_only_keep_set() {
    > "$LOG_FILE"
    TEST_ENV_PERSIST="should_survive" PATH="${FAKE_BIN}:$PATH" \
        "${REPO_ROOT}/codex.sh" --exec --read-only --keep TEST_ENV_PERSIST \
        --set CODEX_LOG_FILE="${LOG_FILE}" --set EXTRA=VALUE readonly >/dev/null 2>&1
    local block
    block="$(last_block)"
    assert_not_contains "$block" "--sandbox workspace-write" &&
        assert_contains "$block" "ARGS:--ask-for-approval on-request -- readonly" &&
        assert_contains "$block" "TEST_ENV_PERSIST=should_survive" &&
        assert_contains "$block" "EXTRA=VALUE"
}

test_inherit_all() {
    > "$LOG_FILE"
    INHERIT_ONLY=present CODEX_LOG_FILE="${LOG_FILE}" PATH="${FAKE_BIN}:$PATH" \
        "${REPO_ROOT}/codex.sh" --exec --inherit-all inherit >/dev/null 2>&1
    local block
    block="$(last_block)"
    assert_contains "$block" "INHERIT_ONLY=present" &&
        assert_contains "$block" "ARGS:--sandbox workspace-write --ask-for-approval on-request -- inherit"
}

test_auto_venv_detection() {
    local workspace
    workspace="$(mktemp -d)"
    mkdir -p "${workspace}/.venv/bin"
    pushd "$workspace" >/dev/null
    > "$LOG_FILE"
    PATH="${FAKE_BIN}:$PATH" "${REPO_ROOT}/codex.sh" --exec --set CODEX_LOG_FILE="${LOG_FILE}" \
        --model demo-model venv-arg >/dev/null 2>&1
    popd >/dev/null
    rm -rf "$workspace"
    local block
    block="$(last_block)"
    assert_contains "$block" "VIRTUAL_ENV=${workspace}/.venv" &&
        assert_contains "$block" "${workspace}/.venv/bin" &&
        assert_contains "$block" "--model demo-model" &&
        assert_contains "$block" "ARGS:--sandbox workspace-write --ask-for-approval on-request"
}

run_case "default write mode" test_default_write_mode
run_case "read-only with keep/set" test_read_only_keep_set
run_case "inherit-all" test_inherit_all
run_case "auto venv detection" test_auto_venv_detection

if (( FAIL_COUNT > 0 )); then
    exit 1
fi

echo "All tests passed ($PASS_COUNT)."
