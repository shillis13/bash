#!/bin/bash
# claude.sh - Wrapper script for Claude CLI with auto-coordination initialization

# Add homebrew to PATH for node and claude
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# Set environment variable to disable custom prompts and prompt commands
export DISABLE_PROMPT_CMD=1
export CLAUDECODE=1

# Use full path to claude executable
CLAUDE_BIN="/opt/homebrew/bin/claude"

# If no arguments provided, auto-initialize coordination
if [ $# -eq 0 ]; then
    # Simple instruction: initialize coordination
    exec "$CLAUDE_BIN" "Initialize coordination: read ~/.claude/CLAUDE.md coordination section and follow the setup steps, then check for pending broadcasts and direct tasks"
else
    # Pass through any provided arguments
    exec "$CLAUDE_BIN" "$@"
fi
