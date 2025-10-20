#!/usr/bin/env bash
set -euo pipefail
SUBMODULE_PATH="${1:-01_chats/raw}"

git rev-parse --is-inside-work-tree >/dev/null
git diff --quiet && git diff --cached --quiet || { echo "Uncommitted changes. Abort."; exit 1; }

# Only act if it's actually a submodule entry
if git config -f .gitmodules --get-regexp "submodule\..*\.path" | grep -q "$SUBMODULE_PATH"; then
  git submodule deinit -f "$SUBMODULE_PATH" || true
  [[ -e "$SUBMODULE_PATH" ]] && git rm -f "$SUBMODULE_PATH" || true
  rm -rf ".git/modules/$SUBMODULE_PATH"
  git commit -m "Remove submodule ${SUBMODULE_PATH}"
else
  echo "No submodule found at ${SUBMODULE_PATH}; nothing to do."
fi

