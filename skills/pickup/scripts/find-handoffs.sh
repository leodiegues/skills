#!/usr/bin/env bash
# List handoff docs, newest first. With an argument, keep only the files whose
# filename stem contains it (case-insensitive substring).
VAULT="${OBSIDIAN_VAULT:-$HOME/vault}"
pattern=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')

# find, not a *.md glob: a missing or empty root must not be an error.
{ find "$VAULT/30-projects" -type f -path '*/handoffs/*.md' 2>/dev/null          # all project handoffs
  find "$VAULT/00-inbox" "$HOME/.claude/handoffs" -maxdepth 1 -type f -name '*.md' 2>/dev/null   # inbox + legacy
} | while IFS= read -r f; do
  stem=$(basename "$f" .md | tr '[:upper:]' '[:lower:]')
  case "$stem" in *"$pattern"*) printf '%s\0' "$f" ;; esac
done | xargs -0 -r ls -t
