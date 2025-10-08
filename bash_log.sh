#!/usr/bin/env bash
# bash_log.sh — On-demand terminal OUTPUT logger for macOS
# - Captures exactly what the terminal shows (stdout/stderr).
# - No keystrokes, no DEBUG/PROMPT_COMMAND traps (history already has commands).
# - Live ANSI stripping so the .log is readable in vi/less/more.
# - A temporary .raw exists only while logging; removed on 'off'.

set -euo pipefail

LOGDIR="${BASH_LOG_DIR:-$HOME/.bash_logs}"
LOGFILE_VAR="BASH_LOG_FILE"
RAW_VAR="BASH_LOG_RAW"
ACTIVE_VAR="BASH_LOG_ACTIVE"
ANNOUNCED_VAR="BASH_LOG_ANNOUNCED"

mkdir -p "$LOGDIR"

status() {
    if [[ "${!ACTIVE_VAR:-}" == "1" ]]; then
        echo "Logging active: ${!LOGFILE_VAR}"
    else
        echo "Logging inactive."
    fi
}

stop_now() {
    local lf="${!LOGFILE_VAR:-}"
    local raw="${!RAW_VAR:-}"

    [[ -n "$lf" ]] && printf '=== LOG END %s pid=%s ===\n' "$(date -u +%F' '%T%z)" "$$" >>"$lf" || true

    # End the foreground 'script' parent (if still around)
    local ppid; ppid="$(ps -o ppid= -p $$ | tr -d ' ')"
    if ps -o comm= -p "$ppid" 2>/dev/null | grep -q '^script$'; then
        kill -TERM "$ppid" 2>/dev/null || true
    fi

    # Stop cleaner; remove the raw file
    [[ -n "${BASH_LOG_CLEAN_PID:-}" ]] && kill "${BASH_LOG_CLEAN_PID}" 2>/dev/null || true
    [[ -n "$raw" && -f "$raw" ]] && rm -f "$raw" || true

    unset "$ACTIVE_VAR" "$LOGFILE_VAR" "$RAW_VAR" "$ANNOUNCED_VAR" BASH_LOG_CLEAN_PID
    exit 0
}

case "${1:-}" in
    on)
        # already logging?
        if [[ "${!ACTIVE_VAR:-}" == "1" ]]; then
            echo "Already logging to ${!LOGFILE_VAR}"; exit 0
        fi
        export "$ACTIVE_VAR"=1

        ts="$(date +%Y%m%d-%H%M%S)"
        tty_id="$(basename "$(tty)" 2>/dev/null | tr -c '[:alnum:]' _ || echo tty)"
        host="${HOSTNAME:-$(hostname -s 2>/dev/null || echo Mac)}"
        logfile="$LOGDIR/${host}_${tty_id}__${ts}_$$.log"
        raw="${logfile}.raw"

        export "$LOGFILE_VAR"="$logfile"
        export "$RAW_VAR"="$raw"

        # Start cleaner in background: tail raw → strip ANSI → final .log
        : > "$raw"
        (
            stdbuf -oL -eL tail -F "$raw" \
                | perl -CSDA -pe 's/\e\[[0-?]*[ -\/]*[@-~]//g; s/\e\][^\a]*(?:\a|\e\\)//g; s/\e[P^_].*?\e\\//g' \
                >> "$logfile"
        ) & export BASH_LOG_CLEAN_PID=$!

        echo "[bash-log] recording → $logfile" >&2
        echo "[bash-log] ⚠️  Reminder: avoid viewing this file from inside this shell (feedback loop)." >&2
        printf '=== LOG START %s pid=%s tty=%s ===\n' "$(date -u +%F' '%T%z)" "$$" "$(tty)" >>"$logfile"

        # Launch a clean login bash under 'script' (NO -k → no keystrokes)
        exec /usr/bin/script -q "$raw" /usr/bin/env bash -l
        ;;

    off)
        stop_now
        ;;

    status|"")
        status
        ;;

    *)
        echo "Usage: bash_log.sh [on|off|status]"; exit 1
        ;;
esac

