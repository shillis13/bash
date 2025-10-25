#!/bin/bash
# Helper script to log commands and outputs with timestamped log files

# Create log directory if it doesn't exist
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

# Generate log filename with date-time stamp
LOG_FILE="$LOG_DIR/claude_commands_$(date '+%Y%m%d_%H%M%S').log"

# If this is a new session, create a symlink to the latest log
LATEST_LINK="$LOG_DIR/claude_commands_latest.log"
ln -sf "$LOG_FILE" "$LATEST_LINK"

# Function to log a command and its output
log_cmd() {
    echo "" >> "$LOG_FILE"
    echo "=================================================================================" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMMAND: $@" >> "$LOG_FILE"
    echo "Working Directory: $(pwd)" >> "$LOG_FILE"
    echo "=================================================================================" >> "$LOG_FILE"
    
    # Execute the command and capture both stdout and stderr
    output=$("$@" 2>&1)
    exit_code=$?
    
    echo "$output" >> "$LOG_FILE"
    echo "Exit Code: $exit_code" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Also output to stdout so Claude can see it
    echo "$output"
    return $exit_code
}

# If script is called with arguments, execute them
if [ $# -gt 0 ]; then
    log_cmd "$@"
else
    echo "Usage: $0 <command> [arguments...]"
    echo "Log file: $LOG_FILE"
    echo "Latest log: $LATEST_LINK"
fi