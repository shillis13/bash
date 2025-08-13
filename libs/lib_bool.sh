#!/usr/bin/env bash
# lib_bool.sh — canonical booleans for Bash scripts
# -----------------------------------------------------------------------------
# Decision (one rule to rule them all):
#   • Store booleans as integers 0/1
#   • Check them with arithmetic (( … ))
#   • Expose TRUE=1 / FALSE=0 constants
#   • Parse env-like strings (“true/false/yes/no/1/0”) only at the edges
#
# Rationale:
#   • Uniform mental model; avoids string/quoting pitfalls
#   • Works with arithmetic, bit ops, and short-circuits: ((flag && cond))
#   • Faster and clearer than string tests like [[ "$x" == "true" ]]
#
# Version: 1.0
# Requires: Bash ≥ 4.0 (for ${var,,}); functions with namerefs fall back if < 4.3
# -----------------------------------------------------------------------------


# ---- Canonical constants -----------------------------------------------------
# Note: not exported by default. Export if children need them:
#   export TRUE FALSE
declare -ri TRUE=1
declare -ri FALSE=0


# ---- API ---------------------------------------------------------------------
# bool STRING -> prints 1 (true) or 0 (false)
#   Accepts: 1/0, true/false, t/f, yes/no, y/n, on/off (case-insensitive).
#   Unknown/empty -> 0
bool() {
  local v="${1-0}"
  [[ "${v,,}" =~ ^(1|true|t|yes|y|on)$ ]] && printf 1 || printf 0
}

# bool_set VAR [VALUE]
#   Coerces VALUE to 0/1 (using bool) and stores it into VAR as an integer.
#   Scope note: respects existing scope. If you need a global from within a
#   function, declare it first: `declare -g myflag; bool_set myflag 1`
bool_set() {
  local name="$1" ; local value="${2-0}"
  printf -v "$name" '%d' "$(bool "$value")"
  # Mark as integer without altering scope (global vs local)
  declare -i "$name" >/dev/null 2>&1 || true
}

# bool_toggle VAR
#   Toggles VAR between 0 and 1. Uses namerefs on ≥4.3, safe fallback otherwise.
bool_toggle() {
  if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) )); then
    local -n __b_ref="$1"
    __b_ref=$(( ! __b_ref ))
  else
    # Fallback without nameref
    eval "$1=\$(( ! $1 ))"
  fi
}

# bool_return VAR
#   Returns shell-success for true (1→return 0) and failure for false (0→return 1).
bool_return() {
  if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) )); then
    local -n __b_ref="$1"
    return $(( __b_ref ? 0 : 1 ))
  else
    # Fallback without nameref
    eval 'return $(( '"$1"' ? 0 : 1 ))'
  fi
}


# -----------------------------------------------------------------------------
# USAGE EXAMPLES
# -----------------------------------------------------------------------------
# Define / default flags (edge parsing once)
#   bool_set ShowHelp      "${ShowHelp:-0}"
#   bool_set g_no_color    "${g_no_color:-false}"
#   bool_set LogShowColor  1
#
# Checks
#   if (( ShowHelp )); then
#     echo "showing help"
#   fi
#   if (( g_no_color )); then
#     echo "no color"
#   fi
#   if (( LogShowColor )); then
#     echo "color on"
#   fi
#
# Set / clear / toggle
#   LogShowColor=$TRUE
#   LogShowColor=$FALSE
#   bool_toggle LogShowColor
#
# Arithmetic combos
#   if (( always || level <= LoggingLevel )); then
#     ...
#   fi
#
# Bridging exit-status ↔ integer boolean
#   some_check; rc=$?
#   # rc==0 (success) → ok=1; rc>0 → ok=0
#   ok=$(( ! rc ))
#
#   # Return a boolean flag from a function
#   myfunc() {
#     local ready=$FALSE
#     (( size > 10 )) && ready=$TRUE
#     bool_return ready
#   }
#
# Loop note:
#   `while true; do ...; done` refers to the builtin command `true` (OK).
#   This library does not replace that; it only standardizes *variables*.
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# REFACTOR CHEAT-SHEET (old → new)
# -----------------------------------------------------------------------------
# Replace stringy comparisons with arithmetic:
#
#   if [[ "$ShowHelp" == "true" ]]; then
#   → if (( ShowHelp )); then
#
#   if [[ "${g_no_color:-false}" == "true" ]]; then
#   → bool_set g_no_color "${g_no_color:-false}"
#     if (( g_no_color )); then
#
#   LogShowColor=true
#   → bool_set LogShowColor 1    # or: LogShowColor=$TRUE
#
#   -Always)  always=true;   shift;;
#   → -Always)  always=$TRUE;   shift;;
#
#   if [[ "$always" == true ]] || (( $level <= $LoggingLevel )); then
#   → if (( always || level <= LoggingLevel )); then
#
# Sourced guard lines where only presence matters:
#   if declare -p "$isSourcedName" >/dev/null 2>&1; then
#     return 0
#   else
#     declare -g "$isSourcedName=true"
#   fi
#   →
#   if declare -p "$isSourcedName" &>/dev/null; then
#     return 0
#   else
#     # value is irrelevant; keep integer for sanity
#     declare -g "$isSourcedName"
#     bool_set "$isSourcedName" 1
#   fi
#
# Safe mechanical assists (review diffs!):
#   # A) true/false assignments → TRUE/FALSE (skip loops using the builtins)
#   perl -pi.bak -e '
#     next if /^\s*#/;
#     next if /\bwhile\s+true\b|\buntil\s+false\b/;
#     s/\b([A-Za-z_]\w*)\s*=\s*"?(true|false)"?\b/$1=\U$2\E/g;
#   ' *.sh
#
#   # B) string equality checks → arithmetic checks
#   perl -pi.bak -e '
#     next if /^\s*#/;
#     s/\[\[\s*"\$?{?([A-Za-z_]\w*)}?"\s*==\s*"true"\s*\]\]/(( $1 ))/g;
#     s/\[\[\s*"\$?{?([A-Za-z_]\w*)}?"\s*!=\s*"true"\s*\]\]/(( ! $1 ))/g;
#     s/\[\[\s*\$?{?([A-Za-z_]\w*)}?\s*==\s*true\s*\]\]/(( $1 ))/g;
#     s/\[\[\s*\$?{?([A-Za-z_]\w*)}?\s*!=\s*true\s*\]\]/(( ! $1 ))/g;
#   ' *.sh
#
#   # C) defaults false/true → constants
#   perl -pi.bak -e '
#     s/:-\s*"?false"?/:-\$FALSE/g;
#     s/:-\s*"?true"?/:-\$TRUE/g;
#   ' *.sh
#
# Manual follow-ups:
#   • Verify any place you truly needed the literal string "true"/"false".
#   • Keep `while true` / `until false` loops intact.
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# QUICK START (paste into your loader once)
# -----------------------------------------------------------------------------
#   # source this file early:
#   source "/path/to/lib_bool.sh"
#
#   # define defaults from env:
#   bool_set g_no_color "${g_no_color:-false}"
#   bool_set LogShowColor "${LogShowColor:-1}"
#
#   # use:
#   if (( ! g_no_color && LogShowColor )); then enable_colors; fi
# -----------------------------------------------------------------------------


# If the file is executed instead of sourced, do nothing.
# (Helps when a user accidentally runs it.)
return 0 2>/dev/null || exit 0


