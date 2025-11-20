#!/bin/bash
#
# claude_cli.sh - Wrapper for Claude CLI with MCP configuration
# Usage: claude_cli.sh [options] "prompt"
#
# Configures Claude CLI with Desktop Commander and other MCP servers
# for orchestrator-controlled execution.

set -euo pipefail

# Ensure proper PATH for node/npm
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# MCP Configuration - matches Desktop Claude's setup
MCP_CONFIG='{
  "mcpServers": {
    "desktop-commander": {
      "command": "/opt/homebrew/bin/node",
      "args": [
        "/Users/shawnhillis/Library/Application Support/Claude/Claude Extensions/ant.dir.gh.wonderwhy-er.desktopcommandermcp/dist/index.js"
      ],
      "env": {
        "PATH": "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    },
    "filesystem": {
      "command": "/opt/homebrew/bin/npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/shawnhillis/bin",
        "/Users/shawnhillis/Documents/AI/Claude"
      ],
      "env": {
        "PATH": "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    },
    "codex": {
      "command": "/opt/homebrew/bin/codex",
      "args": [
        "--full-auto",
        "mcp-server"
      ],
      "env": {
        "PATH": "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      }
    }
  }
}'

# Parse options
INTERACTIVE=false
OUTPUT_FILE=""
NO_MCP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --output|-o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --no-mcp)
            NO_MCP=true
            shift
            ;;
        --help|-h)
            echo "Usage: claude_cli.sh [options] \"prompt\""
            echo ""
            echo "Options:"
            echo "  -i, --interactive    Run in interactive mode (don't redirect stdin)"
            echo "  -o, --output FILE    Write output to file"
            echo "  --no-mcp            Run without MCP configuration"
            echo "  -h, --help          Show this help"
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Build command
CMD="/usr/local/bin/claude"

if [[ "$NO_MCP" == "false" ]]; then
    CMD="$CMD --mcp-config '$MCP_CONFIG'"
fi

# Add prompt if provided
if [[ $# -gt 0 ]]; then
    CMD="$CMD \"$*\""
fi

# Setup logging
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/claude_cli_${TIMESTAMP}.log"

# Log the command being executed
echo "=== Claude CLI Session: $(date) ===" >> "$LOG_FILE"
echo "Command: $CMD" >> "$LOG_FILE"
echo "====================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Handle stdin/stdout based on mode
if [[ "$INTERACTIVE" == "true" ]]; then
    # Interactive mode - let user interact, log output
    eval "$CMD" 2>&1 | tee -a "$LOG_FILE"
else
    # Non-interactive mode - redirect stdin, log output
    if [[ -n "$OUTPUT_FILE" ]]; then
        eval "$CMD" </dev/null 2>&1 | tee "$OUTPUT_FILE" >> "$LOG_FILE"
    else
        eval "$CMD" </dev/null 2>&1 | tee -a "$LOG_FILE"
    fi
fi

echo "" >> "$LOG_FILE"
echo "=== Session ended: $(date) ===" >> "$LOG_FILE"
