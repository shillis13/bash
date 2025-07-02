delete_history_func() {
    local query=""
    local perform_exec=0

    # Loop through all arguments to separate flags from the query.
    for arg in "$@"; do
        case "$arg" in
            --exec|-x)
                perform_exec=1
                ;;
            *)
                # Append to query string, adding a space if it's not the first word.
                if [ -n "$query" ]; then
                    query="$query $arg"
                else
                    query="$arg"
                fi
                ;;
        esac
    done

    # If no query is provided after parsing, show usage instructions and exit.
    if [ -z "$query" ]; then
        echo "Usage: delete_history_func [--exec|-x] <query>"
        echo "  Default: Performs a dry run, showing lines that would be deleted."
        echo "  --exec, -x: Actually deletes the lines from your history."
        return 1
    fi

    # Escape special characters for sed and grep to handle them literally.
    local escaped_query
    escaped_query=$(printf '%s\n' "$query" | sed 's:[][\/.^$*]:\\&:g')

    # Get the history file location, defaulting to ~/.bash_history.
    local HISTFILE=${HISTFILE:-~/.bash_history}

    if [ ! -f "$HISTFILE" ]; then
        echo "Error: History file not found at '$HISTFILE'"
        return 1
    fi

    # --- Main Logic: Execute or Perform Dry Run ---
    if [ "$perform_exec" -eq 1 ]; then
        # --- EXECUTION MODE ---
        echo "--- EXECUTING: Deleting lines containing \"$query\" ---"

        # Create a backup of the history file first as a safety measure.
        # The timestamp makes the backup name unique.
        cp "$HISTFILE" "${HISTFILE}.bak.$(date +%Y-%m-%d_%H-%M-%S)"

        # Remove lines matching the query from the history file.
        # The -i '' is for macOS compatibility; on most Linux distros, it's just -i.
        sed -i '' "/$escaped_query/d" "$HISTFILE"

        # Reload the current shell's history from the modified file.
        history -c  # Clear current session history.
        history -r  # Re-read history from HISTFILE.

        echo "Deletion complete. History has been reloaded."
        echo "A timestamped backup of the original history has been saved."
    else
        # --- DRY RUN MODE (DEFAULT) ---
        echo "--- DRY RUN: Lines in history containing \"$query\" ---"
        
        # Grep with color provides a nice, clear output of what would be deleted.
        grep --color=auto "$escaped_query" "$HISTFILE"
        
        echo "----------------------------------------------------------"
        echo "To permanently delete these lines, run again with the --exec or -x flag."
    fi
}
