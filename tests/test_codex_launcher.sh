#!/usr/bin/env bash
set -euo pipefail

status=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; status=1; }

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT

stub_dir="$tmp_root/bin"
mkdir -p "$stub_dir"
cat <<'STUB' > "$stub_dir/codex"
#!/usr/bin/env bash
output=${CODEX_STUB_OUT:-}
{
    printf 'ARGV:%s\n' "$*"
    env | sort
} > "${output:-/dev/stdout}"
STUB
chmod +x "$stub_dir/codex"

export PATH="$stub_dir:$PATH"

run_codex() {
    local outfile="$1"
    shift
    local -a args=("$@")
    local has_set=0
    for token in "${args[@]}"; do
        case "$token" in
            --set|--set=* ) has_set=1; break ;;
        esac
    done

    if (( ! has_set )); then
        args=(--set "CODEX_STUB_OUT=$outfile" "${args[@]}")
    else
        for i in "${!args[@]}"; do
            case "${args[$i]}" in
                --set)
                    args[$((i+1))]="CODEX_STUB_OUT=$outfile,${args[$((i+1))]}"
                    break
                    ;;
                --set=*)
                    args[$i]="--set=CODEX_STUB_OUT=$outfile,${args[$i]#--set=}" 
                    break
                    ;;
            esac
        done
    fi

    CODEX_STUB_OUT="$outfile" "$repo_root/codex.sh" --exec "${args[@]}"
}

default_out="$tmp_root/default.out"
KEEP_TEST=hidden run_codex "$default_out" -- --probe || fail "default invocation"
if grep -q "workspace-write" "$default_out" && \
   grep -q '^TERM=xterm-256color' "$default_out" && \
   ! grep -q '^KEEP_TEST=' "$default_out"; then
    pass "Default write mode adds sandbox and scrubs env"
else
    fail "Default write mode incorrect"
fi

readonly_out="$tmp_root/read_only.out"
run_codex "$readonly_out" --read-only -- --probe || fail "read-only invocation"
if ! grep -q 'workspace-write' "$readonly_out"; then
    pass "Read-only mode omits workspace write sandbox"
else
    fail "Read-only mode still included sandbox"
fi

keep_set_out="$tmp_root/keep_set.out"
export KEEP_TEST="preserved"
run_codex "$keep_set_out" --keep KEEP_TEST --set "SET_TEST=applied" -- --probe || fail "keep/set invocation"
if grep -q '^KEEP_TEST=preserved' "$keep_set_out" && \
   grep -q '^SET_TEST=applied' "$keep_set_out"; then
    pass "Keep and set propagate environment correctly"
else
    fail "Keep/set environment missing"
fi

venv_dir="$tmp_root/project"
mkdir -p "$venv_dir/.venv/bin"
: > "$venv_dir/.venv/bin/activate"
venv_out="$tmp_root/venv.out"
(
    cd "$venv_dir"
    run_codex "$venv_out" -- --check
) || fail "venv invocation"
venv_real="$(cd "$venv_dir/.venv" && pwd)"
if grep -q "^VIRTUAL_ENV=$venv_real$" "$venv_out" && \
   grep -Eq "^PATH=$venv_real/bin(:|$)" "$venv_out"; then
    pass "Auto virtualenv activation updates PATH"
else
    fail "Virtualenv activation missing"
fi

inherit_out="$tmp_root/inherit.out"
export INHERITED_TEST="available"
run_codex "$inherit_out" --inherit-all -- --check || fail "inherit invocation"
if grep -q '^INHERITED_TEST=available' "$inherit_out"; then
    pass "Inherited environment preserved when requested"
else
    fail "Inherited environment missing"
fi

exit $status
