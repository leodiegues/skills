#!/usr/bin/env bash
# Print the directory a new handoff belongs in, creating it if needed.
#   inside a repo with a remote → $VAULT/30-projects/<org>/<repo>/handoffs
#   no repo / no remote         → $VAULT/00-inbox
VAULT="${OBSIDIAN_VAULT:-$HOME/vault}"

# Derive <org>/<repo> from the git remote. Works for SSH and HTTPS remotes, on any host.
slug=$(git remote get-url origin 2>/dev/null | sed -E 's#\.git$##' \
       | awk -F'[/:]' '{print $(NF-1)"/"$NF}')
if [ -n "$slug" ]; then
  dir="$VAULT/30-projects/$slug/handoffs"
else
  dir="$VAULT/00-inbox"
fi
mkdir -p "$dir" && echo "$dir"
