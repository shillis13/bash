#!/bin/bash
# codex-coord.sh - Simplified Codex wrapper for coordination tasks
# Mirrors claude.sh behavior for consistency

# Add homebrew to PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# Set environment variable to disable custom prompts
export DISABLE_PROMPT_CMD=1

# Grant Codex access to coordination directories
export CODEX_ADDITIONAL_ACCESS_DIRS="/Users/shawnhillis/.codex,/Users/shawnhillis/Documents/AI/comms"

# Use full path to codex executable
CODEX_BIN="/opt/homebrew/bin/codex"

# If no arguments provided, auto-initialize coordination
if [ $# -eq 0 ]; then
    # Simple instruction: initialize coordination
    exec "$CODEX_BIN" "Initialize coordination: read ~/.codex/README_coordination.md to understand the coordination system, then check ~/.codex/coordination/to_execute/ for pending tasks"
else
    # Pass through any provided arguments
    exec "$CODEX_BIN" "$@"
fi
