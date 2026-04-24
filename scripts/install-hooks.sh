#!/usr/bin/env bash
# Install repo hooks into .git/hooks/.
# Usage: scripts/install-hooks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  echo "error: not a git repository ($REPO_ROOT/.git missing). Run 'git init' first." >&2
  exit 1
fi

for hook in "$REPO_ROOT"/hooks/*; do
  [[ -f "$hook" ]] || continue
  name="$(basename "$hook")"
  dest="$REPO_ROOT/.git/hooks/$name"
  cp "$hook" "$dest"
  chmod +x "$dest"
  echo "installed: $dest"
done
