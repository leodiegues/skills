#!/usr/bin/env bash
# Create a worktrunk worktree, open it as a child herdr workspace of the calling
# workspace, start Claude there and submit the kickoff prompt read from stdin.
#   launch.sh <branch> [--base REF] [--label TEXT] [--reuse] < kickoff
# Prints one JSON line: branch, path, workspace_id, pane_id, agent.
set -euo pipefail

die() { echo "kickoff: $*" >&2; exit 1; }

branch="" base="" label="" reuse=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base)  base="${2:-}"; shift 2 ;;
    --label) label="${2:-}"; shift 2 ;;
    --reuse) reuse=1; shift ;;
    -*)      die "unknown option: $1" ;;
    *)       branch="$1"; shift ;;
  esac
done
[ -n "$branch" ] || die "usage: launch.sh <branch> [--base REF] [--label TEXT] [--reuse] < kickoff"
[ "$reuse" = 0 ] || [ -z "$base" ] || die "--base only applies to a new branch; drop it or drop --reuse"

# Preflight: everything below creates state, so fail before any of it exists.
[ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_WORKSPACE_ID:-}" ] \
  || die "not running inside a herdr pane (HERDR_ENV=1). Start this session from herdr: https://github.com/herdrdev/herdr"
command -v herdr >/dev/null || die "herdr not found on PATH: https://github.com/herdrdev/herdr"
command -v wt >/dev/null    || die "wt (worktrunk) not found on PATH: https://worktrunk.dev"
command -v jq >/dev/null    || die "jq not found on PATH"
[ -t 0 ] && die "no kickoff prompt: pipe it on stdin"
kickoff=$(cat)
[ -n "$kickoff" ] || die "empty kickoff prompt on stdin"

# herdr agent names: [a-z][a-z0-9_-]{0,31}
agent=$(printf '%s' "$branch" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' \
        | sed -E 's/^[^a-z]+//' | cut -c1-32 | sed -E 's/-+$//')
[ -n "$agent" ] || agent=kickoff

path="" ws="" pane=""
trap 'rc=$?; [ $rc -eq 0 ] || echo "kickoff: failed (exit $rc). Left in place: worktree=${path:-none} workspace=${ws:-none} pane=${pane:-none} agent=$agent" >&2' EXIT

wt_args=(switch "$branch" --no-cd --format=json)
[ "$reuse" = 1 ] || wt_args+=(--create)
[ -z "$base" ] || wt_args+=(--base "$base")
out=$(wt "${wt_args[@]}")
path=$(jq -r '.path // empty' <<<"$out")
[ -n "$path" ] || die "wt returned no worktree path: $out"

out=$(herdr worktree open --workspace "$HERDR_WORKSPACE_ID" --path "$path" --label "${label:-$branch}" --no-focus)
ws=$(jq -r '.result.workspace.workspace_id // empty' <<<"$out")
pane=$(jq -r '.result.root_pane.pane_id // empty' <<<"$out")
[ -n "$ws" ] && [ -n "$pane" ] || die "herdr returned no workspace/pane id: $out"

herdr agent start "$agent" --kind claude --pane "$pane" --timeout 120000 >/dev/null
herdr agent prompt "$agent" "$kickoff" >/dev/null
# Focus last: a failure above leaves the user in the planning workspace.
herdr workspace focus "$ws" >/dev/null

jq -cn --arg branch "$branch" --arg path "$path" --arg ws "$ws" --arg pane "$pane" --arg agent "$agent" \
  '{branch: $branch, path: $path, workspace_id: $ws, pane_id: $pane, agent: $agent}'
