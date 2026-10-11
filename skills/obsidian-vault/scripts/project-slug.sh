#!/usr/bin/env bash
# Print <org>/<repo> for a repo, derived from its git remote (SSH or HTTPS, any host).
#   git@github.com:ever-day/everday-monorepo.git → ever-day/everday-monorepo
# Pass the TARGET repo's path: deriving from an unrelated cwd gives the wrong slug.
# Prints nothing when the repo has no origin remote.
git -C "${1:-.}" remote get-url origin 2>/dev/null | sed -E 's#\.git$##' \
  | awk -F'[/:]' '{print $(NF-1)"/"$NF}'
