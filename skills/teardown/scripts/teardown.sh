#!/usr/bin/env bash
# Tear down the finished work this session is on, then close the tab or pane it runs in.
#   linked worktree             — remove the worktree; delete its branch if it is merged.
#   branch in the main checkout — switch to the default branch; delete the branch if merged.
# Refuses on the default branch, on main/master and on a detached HEAD: nothing to tear down.
# Uses wt (worktrunk) when it is on PATH, so its hooks run and squash merges count as merged;
# plain git otherwise.
# The host is picked from the calling session and closed last, only after the git part worked:
#   herdr — the workspace when it is this worktree's, else the calling pane.
#   rex   — the tab when the calling block is alone in it, else the calling block.
#   t3    — nothing: its CLI cannot archive a thread.
#   none  — nothing.
# A branch in the main checkout keeps its pane (the checkout is still there) unless --close-pane.
#   teardown.sh [--check] [--force] [--delete-branch] [--close-pane]
# Prints one JSON line. --check changes nothing and prints what a run would do.
set -euo pipefail

die() { echo "teardown: $*" >&2; exit 1; }

check=0 force=0 delete=0 close_main=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check)         check=1 ;;
    --force)         force=1 ;;
    --delete-branch) delete=1 ;;
    --close-pane)    close_main=1 ;;
    *)               die "usage: teardown.sh [--check] [--force] [--delete-branch] [--close-pane]" ;;
  esac
  shift
done
command -v jq >/dev/null || die "jq not found on PATH"

# Guards first: nothing below runs on a default branch.
top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git work tree"
cd "$top"
branch=$(git symbolic-ref --short -q HEAD) || die "detached HEAD: nothing to tear down"
default=$(git symbolic-ref --short -q refs/remotes/origin/HEAD || true)
default=${default#origin/}
if [ -z "$default" ] && command -v wt >/dev/null; then
  default=$(wt config state default-branch get 2>/dev/null || true)
fi
if [ -z "$default" ]; then
  for b in main master; do
    ! git show-ref --verify --quiet "refs/heads/$b" || { default=$b; break; }
  done
fi
[ -n "$default" ] || die "cannot resolve the default branch; run: git remote set-head origin --auto"
case "$branch" in
  "$default"|main|master) die "on $branch: nothing to tear down" ;;
esac

linked=false
[ "$(git rev-parse --path-format=absolute --git-dir)" = "$(git rev-parse --path-format=absolute --git-common-dir)" ] || linked=true
main=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
dirty=$(git status --porcelain)
# Commits that exist on this branch only: not on a remote, not on the default branch.
local_only=$(git rev-list --count HEAD --not --remotes "$default")

# What to close. Innermost host first, as in kickoff: HERDR_ENV can leak into T3 Code,
# and REX_* leaks into herdr panes started from a Rex terminal.
host=none close=()
if [ -n "${T3CODE_THREAD_ID:-}" ]; then
  host=t3
elif [ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_PANE_ID:-}" ]; then
  host=herdr
  command -v herdr >/dev/null || die "herdr not found on PATH"
  close=(herdr pane close "$HERDR_PANE_ID")
  if [ "$linked" = true ] && [ -n "${HERDR_WORKSPACE_ID:-}" ]; then
    ws=$(herdr worktree list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null \
         | jq -r --arg p "$top" '.result.worktrees[]? | select(.path == $p) | .open_workspace_id // empty' || true)
    [ "$ws" != "$HERDR_WORKSPACE_ID" ] || close=(herdr workspace close "$ws")
  fi
elif [ -n "${REX_BLOCK:-}" ] && [ -n "${REX_SESSION:-}" ]; then
  host=rex
  command -v rex >/dev/null || die "rex not found on PATH"
  blocks=$(rex block ls -s "$REX_SESSION" --json)
  win=$(jq -r --arg b "$REX_BLOCK" '.blocks[] | select(.block_id == $b) | .window_id' <<<"$blocks")
  [ -n "$win" ] || die "this Rex block ($REX_BLOCK) is not on the server; REX_BLOCK is stale"
  if [ "$(jq --arg w "$win" '[.blocks[] | select(.window_id == $w)] | length' <<<"$blocks")" = 1 ]; then
    close=(rex window close -s "$REX_SESSION" "$win")
  else
    close=(rex block close -s "$REX_SESSION" "$REX_BLOCK")
  fi
fi
[ "$linked" = true ] || [ "$close_main" = 1 ] || close=()
closes=${close[*]:-}

if [ "$check" = 1 ]; then
  jq -cn --arg branch "$branch" --arg default "$default" --arg path "$top" --argjson linked "$linked" \
    --arg dirty "$dirty" --argjson local_only "$local_only" --arg host "$host" --arg closes "$closes" \
    '{branch: $branch, default_branch: $default, path: $path, linked_worktree: $linked,
      dirty: ($dirty | split("\n") | map(select(. != ""))), local_only_commits: $local_only, host: $host, closes: $closes}'
  exit 0
fi

if [ -n "$dirty" ]; then
  [ "$linked" = true ] || die "uncommitted changes in the main checkout; commit, stash or discard them first:
$dirty"
  [ "$force" = 1 ] || die "uncommitted changes; commit or stash them, or rerun with --force to lose them:
$dirty"
fi

# A PR merged on the forge only counts as merged once the default branch is fetched. Best effort.
git fetch --quiet origin "$default" 2>/dev/null || true

# Step out before the worktree goes away, so the commands below keep a working directory.
if [ "$linked" = true ]; then
  cd "$main"
  worktree=removed
else
  git switch --quiet "$default"
  worktree="kept (main checkout, now on $default)"
fi

if command -v wt >/dev/null; then
  args=(remove "$branch" --foreground --format=json)
  [ "$force" = 0 ]  || args+=(--force)
  [ "$delete" = 0 ] || args+=(--force-delete)
  out=$(wt "${args[@]}")
  outcome=$(jq -r '.[0].branch_outcome // "unknown"' <<<"$out")
else
  if [ "$linked" = true ]; then
    args=(worktree remove "$top")
    [ "$force" = 0 ] || args+=(--force)
    git "${args[@]}"
  fi
  flag=-d; [ "$delete" = 0 ] || flag=-D
  # git's own rule: deleted when merged into the default branch or fully pushed to its upstream.
  # It misses squash merges of a branch with no upstream; the branch then stays, the safe side.
  if git branch --quiet "$flag" "$branch" 2>/dev/null; then outcome=deleted; else outcome=retained_unmerged; fi
fi

jq -cn --arg branch "$branch" --arg path "$top" --arg worktree "$worktree" --arg outcome "$outcome" \
  --arg host "$host" --arg closes "$closes" \
  '{branch: $branch, path: $path, worktree: $worktree, branch_outcome: $outcome, host: $host, closes: $closes}'

# Last: this ends the session that is running this script.
[ ${#close[@]} -eq 0 ] || "${close[@]}" >/dev/null
