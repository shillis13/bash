#!/usr/bin/env bash
#
# Guard for sync_ai_repos.sh's ARGUMENT GATE.
#
# WHY THIS EXISTS
# On 2026-08-09 sync_ai_repos had no argument parsing at all: `main "$@"` fed the
# arguments to a main() that never read them. Git Guardian ran `sync_ai_repos --help`
# to inspect an unfamiliar script — a read-only intent — and it performed a full sync,
# committing and pushing 199 files in ai_general alone, including work that was blocked
# in review and other sessions' unfinished changes. See todo_0810.
#
# The fix is small. The regression it prevents is not, so it is pinned here rather than
# left to a session's manual probes.
#
# EVERY case drives the PRODUCTION script. There is no source-shape grepping: deleting
# or bypassing parse_args must make these fail.
#
# HERMETIC. HOME is redirected to an empty temp dir, so the script's hardcoded
# AI_ROOT="${HOME}/AI/ai_root" cannot resolve to anything real, and a fake `git` on PATH
# records every invocation. Nothing here can touch a repository.
#
# Failure signaling: per-check evidence on stdout, NONZERO exit if anything fails.
#
# Usage: tests/test_sync_ai_repos_args.sh

set -uo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
TARGET="${SCRIPT_DIR}/../sync_ai_repos.sh"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (want '$3', got '$2')"; fi; }

[[ -f "$TARGET" ]] || { echo "FATAL: cannot find $TARGET" >&2; exit 1; }

make_env() {
    ROOT=$(mktemp -d)
    mkdir -p "$ROOT/AI" "$ROOT/bin"
    GIT_LOG="$ROOT/git_calls.log"
    # A fake git that RECORDS instead of acting. If the argument gate ever regresses,
    # this file is how we find out — without a real repository being touched.
    cat > "$ROOT/bin/git" <<STUB
#!/usr/bin/env bash
echo "\$@" >> "$GIT_LOG"
exit 0
STUB
    chmod +x "$ROOT/bin/git"
}
cleanup() { [[ -n "${ROOT:-}" ]] && rm -rf "$ROOT"; ROOT=""; }
trap cleanup EXIT

run() {  # run <args...> ; sets RC. Output lands in $ROOT/out and $ROOT/err.
    env -i HOME="$ROOT" PATH="$ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$TARGET" "$@" >"$ROOT/out" 2>"$ROOT/err"
    RC=$?
}
git_calls() { [[ -f "$GIT_LOG" ]] && wc -l < "$GIT_LOG" | tr -d ' ' || echo 0; }
banner_hit() { grep -qi "AI Repos Sync Script" "$ROOT/out" "$ROOT/err" 2>/dev/null && echo yes || echo no; }
# grep -c prints "0" AND exits 1 when there are no matches, so a `|| echo 0` fallback
# emitted TWO zeros and every escape assertion failed on a correct implementation.
# The count alone is the answer; the exit status is not an error here.
esc_count() { local n; n=$(grep -c $'\033' "$1" 2>/dev/null); echo "${n:-0}"; }

# =====================================================================
echo "1. HELP exits 0, warns, and syncs nothing"
# =====================================================================
for flag in --help -h; do
    make_env
    run "$flag"
    check "[$flag] exit 0"              "$RC" "0"
    check "[$flag] main banner NOT reached" "$(banner_hit)" "no"
    check "[$flag] git never called"    "$(git_calls)" "0"
    # The warning is the whole point: someone must learn this writes BEFORE running it.
    if grep -q "WRITES AND PUBLISHES" "$ROOT/out"; then ok "[$flag] states that it writes and publishes"; else bad "[$flag] help does not warn that it writes"; fi
    if grep -q "git add -A" "$ROOT/out"; then ok "[$flag] names the git add -A behaviour"; else bad "[$flag] help hides the add -A behaviour"; fi
    # An honest exit-code contract: 0 must NOT be described as "everything synced",
    # because a failed push is only a warning and a missing repo is only a skip.
    if grep -q "does NOT mean everything synced" "$ROOT/out"; then ok "[$flag] exit-code text is honest about push/skip"; else bad "[$flag] claims exit 0 proves a full sync"; fi
    check "[$flag] no escape bytes on stdout when piped" "$(esc_count "$ROOT/out")" "0"
    cleanup
done

# =====================================================================
echo "2. UNKNOWN arguments fail closed, and sync nothing"
# =====================================================================
# --dry-run matters most: a plausible, safe-sounding flag that used to run a full sync.
for flag in --dry-run --hepl -x --version; do
    make_env
    run "$flag"
    check "[$flag] exit 2"              "$RC" "2"
    check "[$flag] main banner NOT reached" "$(banner_hit)" "no"
    check "[$flag] git never called"    "$(git_calls)" "0"
    if grep -q "Nothing was synced" "$ROOT/err"; then ok "[$flag] says nothing was synced"; else bad "[$flag] silent about not syncing"; fi
    check "[$flag] no escape bytes on stderr when piped" "$(esc_count "$ROOT/err")" "0"
    cleanup
done

# =====================================================================
echo "3. NON-VACUITY CONTROL — with no arguments it really does reach main"
# =====================================================================
# Without this, every assertion above would pass on a script that did nothing at all.
make_env
run
check "no args: exit 1 (hermetic AI_ROOT absent)" "$RC" "1"
check "no args: main banner IS reached"           "$(banner_hit)" "yes"
if grep -q "AI root directory not found" "$ROOT/out"; then ok "no args: fails for the expected reason"; else bad "no args: failed for some other reason"; fi
cleanup

# =====================================================================
echo "4. The gate is what does it — bypassing parse_args reopens the hole"
# =====================================================================
# Drives a MUTATED COPY of the production script rather than asserting on source shape:
# with the parser bypassed, --help must once again reach main.
make_env
MUTANT="$ROOT/mutant.sh"
sed 's/^parse_args "\$@"$/: # parse_args bypassed/' "$TARGET" > "$MUTANT"
if ! grep -q "parse_args bypassed" "$MUTANT"; then
    bad "could not construct the bypass mutant — this section proved nothing"
else
    env -i HOME="$ROOT" PATH="$ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
        bash "$MUTANT" --help >"$ROOT/out" 2>"$ROOT/err"
    MRC=$?
    if [[ "$(banner_hit)" == "yes" ]]; then
        ok "bypassing parse_args DOES reach main (so section 1 is meaningful)"
    else
        bad "bypassed mutant still did not reach main — section 1 may be vacuous"
    fi
    check "bypassed mutant no longer exits 0 cleanly on --help" "$([ "$MRC" -eq 0 ] && echo zero || echo nonzero)" "nonzero"
fi
cleanup

# =====================================================================
echo "5. Caller-controlled data cannot inject terminal control bytes"
# =====================================================================
# printf '%b' interprets backslash escapes in whatever it is handed. Both the unknown
# argument and AI_ROOT (derived from HOME) were passed to it, so a value containing the
# literal characters \033[31m produced REAL escape bytes in piped output. The four
# friendly arguments in section 2 could never have found this (GG round 2).
make_env
run '--bad\033[31mRED'
check "hostile argument: exit 2"        "$RC" "2"
check "hostile argument: zero ESC on stderr" "$(esc_count "$ROOT/err")" "0"
if grep -qF -- '--bad\033[31mRED' "$ROOT/err"; then ok "the argument is echoed LITERALLY"; else bad "the argument was altered or interpreted"; fi
check "hostile argument: git never called" "$(git_calls)" "0"
cleanup

# A HOME containing the same literal sequence: AI_ROOT is built from it and printed in
# the help, so it is an injection path that no argument validation would catch.
ROOT=$(mktemp -d)
HOSTILE="$ROOT/x\033[35mHOME"
mkdir -p "$HOSTILE/AI" "$ROOT/bin"
GIT_LOG="$ROOT/git_calls.log"
cat > "$ROOT/bin/git" <<STUB
#!/usr/bin/env bash
echo "\$@" >> "$GIT_LOG"
exit 0
STUB
chmod +x "$ROOT/bin/git"
env -i HOME="$HOSTILE" PATH="$ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    bash "$TARGET" --help >"$ROOT/out" 2>"$ROOT/err"
RC=$?
check "hostile HOME: exit 0"            "$RC" "0"
check "hostile HOME: zero ESC on stdout" "$(esc_count "$ROOT/out")" "0"
if grep -qF -- 'x\033[35mHOME' "$ROOT/out"; then ok "the path is printed LITERALLY"; else bad "the path was altered or interpreted"; fi
check "hostile HOME: git never called"  "$(git_calls)" "0"
cleanup

# =====================================================================
printf '\n%s\n' "-----------------------------------------"
printf 'passed: %d   failed: %d\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
