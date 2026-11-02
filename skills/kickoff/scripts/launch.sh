#!/usr/bin/env bash
# Start a new agent session in its own worktree and submit the kickoff prompt
# read from stdin. The provider is picked from the calling session:
#   t3    (inside T3 Code)   — a new T3 Code thread in a new worktree.
#   herdr (inside a herdr pane) — a worktrunk worktree opened as a child herdr
#                                 workspace, with Claude started there.
#   launch.sh <branch> [--base REF] [--label TEXT] [--reuse] < kickoff
# Prints one JSON line: provider, branch, then per provider
#   t3:    thread_id, link, path
#   herdr: path, workspace_id, pane_id, agent
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
# T3 first: HERDR_ENV can leak into T3 Code when its server was started from a herdr pane.
if [ -n "${T3CODE_THREAD_ID:-}" ]; then
  provider=t3
  t3="${T3CODE_CLI_PATH:-t3}"
  command -v "$t3" >/dev/null || die "t3 CLI not found (T3CODE_CLI_PATH or PATH)"
  [ "$reuse" = 0 ] || die "--reuse is not supported in T3 Code: its CLI only starts threads on a new branch"
  git show-ref --verify --quiet "refs/heads/$branch" && die "branch already exists: $branch"
  [ "$base" != @ ] || base=$(git rev-parse --abbrev-ref HEAD)
  if [ -z "$base" ]; then
    base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || die "no origin/HEAD to base on; pass --base"
    base=${base#origin/}
  fi
elif [ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_WORKSPACE_ID:-}" ]; then
  provider=herdr
  command -v herdr >/dev/null || die "herdr not found on PATH: https://github.com/herdrdev/herdr"
  command -v wt >/dev/null    || die "wt (worktrunk) not found on PATH: https://worktrunk.dev"
else
  die "not running inside T3 Code (T3CODE_THREAD_ID) or a herdr pane (HERDR_ENV=1)"
fi
command -v jq >/dev/null || die "jq not found on PATH"
[ -t 0 ] && die "no kickoff prompt: pipe it on stdin"
kickoff=$(cat)
[ -n "$kickoff" ] || die "empty kickoff prompt on stdin"

if [ "$provider" = t3 ]; then
  # Same project, provider and model as this thread, so the kickoff's slash commands land.
  read -r project prov model < <("$t3" thread show "$T3CODE_THREAD_ID" --json --messages 0 \
    | jq -r '.thread | "\(.projectId // "") \(.providerInstanceId // "") \(.model // "")"')
  [ -n "$project" ] || die "could not resolve this thread's T3 Code project"
  out=$(printf '%s' "$kickoff" | "$t3" thread start "$project" - --json \
        --title "${label:-$branch}" --worktree "$base" --branch "$branch" \
        ${prov:+--provider "$prov"} ${model:+--model "$model"})
  id=$(jq -r '(.thread // .).threadId // empty' <<<"$out")
  [ -n "$id" ] || die "t3 returned no thread id: $out"
  # start --json carries only the id; link and worktree path come from show.
  "$t3" thread show "$id" --json --messages 0 | jq -c --arg branch "$branch" \
    '.thread | {provider: "t3", branch: $branch, thread_id: .threadId, link: .link, path: .worktreePath}'
  exit 0
fi

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
  '{provider: "herdr", branch: $branch, path: $path, workspace_id: $ws, pane_id: $pane, agent: $agent}'
