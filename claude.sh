#!/bin/bash
# claude.sh - Wrapper script for Claude CLI with logging

# Add homebrew to PATH for node and claude
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# Set environment variable to disable custom prompts and prompt commands
export DISABLE_PROMPT_CMD=1
export CLAUDECODE=1

# Pass through terminal session identification variables if they exist
[[ -n "${TERM_SESSION_ID:-}" ]] && export TERM_SESSION_ID
[[ -n "${ITERM_SESSION_ID:-}" ]] && export ITERM_SESSION_ID
[[ -n "${TERMINFO_DIRS:-}" ]] && export TERMINFO_DIRS
[[ -n "${LC_TERMINAL:-}" ]] && export LC_TERMINAL
[[ -n "${TERM_PROGRAM:-}" ]] && export TERM_PROGRAM

# Use full path to claude executable
CLAUDE_BIN="$HOME/.claude/local/claude"

# Setup logging
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/claude_${TIMESTAMP}.log"

# Log session start
echo "=== Claude Session: $(date) ===" >> "$LOG_FILE"
echo "Arguments: $@" >> "$LOG_FILE"
echo "====================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Check if --print flag is present in arguments
has_print_flag=false
for arg in "$@"; do
    if [ "$arg" = "--print" ] || [ "$arg" = "-p" ]; then
        has_print_flag=true
        break
    fi
done

# If --print flag is present, or if stdin is provided, don't use script
if [ "$has_print_flag" = true ] || [ ! -t 0 ]; then
    # Non-interactive mode: pass through with regular logging
    echo "Mode: Non-interactive (--print or stdin)" >> "$LOG_FILE"
    "$CLAUDE_BIN" "$@" 2>&1 | tee -a "$LOG_FILE"
else
    # Interactive mode: use script command for full terminal capture
    echo "Mode: Interactive" >> "$LOG_FILE"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS version of script
        script -F "$LOG_FILE" "$CLAUDE_BIN" "$@"
    else
        # Linux version of script
        script -f -q -c "$CLAUDE_BIN $*" "$LOG_FILE"
    fi
fi

# Log session end
EXIT_CODE=$?
echo "" >> "$LOG_FILE"
echo "=== Session ended: $(date) (exit code: $EXIT_CODE) ===" >> "$LOG_FILE"
exit $EXIT_CODE
