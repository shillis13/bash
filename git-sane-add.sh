#!/bin/bash
# Adds only "sane" files under ~/bin/python to Git staging

ROOT="$HOME/bin/python"
cd "$ROOT" || { echo "Invalid path: $ROOT"; exit 1; }

echo "Scanning: $ROOT"

# Find all files, excluding nested git repos
find . \
  -type d -name ".git" -prune -o \
  -type f \
  -print |
while read -r file; do
  # Skip files ignored by .gitignore
  if git check-ignore -q "$file"; then
    echo "IGNORED: $file"
    continue
  fi

  # Skip messy junk explicitly (expand as needed)
  case "$file" in
    *~|*.bak|*.tmp|*.swp|*.log|*.DS_Store|*.class|Thumbs.db)
      echo "SKIPPED (messy): $file"
      continue
      ;;
  esac

  # Add the file to staging
  git add "$file"
  echo "ADDED: $file"
done

