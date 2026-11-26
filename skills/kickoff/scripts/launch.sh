#!/usr/bin/env bash
# Start a new agent session in its own worktree and submit the kickoff prompt
# read from stdin. The provider is picked from the calling session:
#   t3    (inside T3 Code)   — a new T3 Code thread in a new worktree.
#   herdr (inside a herdr pane) — a worktrunk worktree opened as a child herdr
#                                 workspace, with this session's agent started there.
#   rex   (inside a Rex terminal) — a worktrunk worktree opened in a new tab of
#                                   this Rex session, with this session's agent started there.
#   hc    (inside a Herdr app or herdr-core terminal) — a worktrunk worktree opened as a new
#         space in the Herdr window, with this session's agent started there; with no window
#         on this machine, as an hc terminal with no parent. With --parent, as a child
#         terminal of this one instead: listed under it, typing its notes into it.
# The agent is the CLI running this script: codex, opencode, claude or agy.
#   launch.sh --host
#   launch.sh <branch> [--base REF] [--label TEXT] [--reuse] [--parent] < kickoff
# Prints one JSON line: provider, branch, then per provider
#   --host: provider, plus terminal (hc) and cli (all but t3)
#   t3:    thread_id, link, path
#   herdr: path, workspace_id, pane_id, agent, cli
#   rex:   path, session_id, window_id, block_id, cli
#   hc:    path, space_id, tab_id, terminal, name, parent, cli
set -euo pipefail

die() { echo "kickoff: $*" >&2; exit 1; }

branch="" base="" label="" reuse=0 parent=0 host_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --host)   host_only=1; shift ;;
    --base)   [ $# -ge 2 ] || die "--base requires a ref"; base="$2"; shift 2 ;;
    --label)  [ $# -ge 2 ] || die "--label requires text"; label="$2"; shift 2 ;;
    --reuse)  reuse=1; shift ;;
    --parent) parent=1; shift ;;
    -*)       die "unknown option: $1" ;;
    *)        branch="$1"; shift ;;
  esac
done
if [ "$host_only" = 0 ]; then
  [ -n "$branch" ] || die "usage: launch.sh <branch> [--base REF] [--label TEXT] [--reuse] [--parent] < kickoff"
  [ "$reuse" = 0 ] || [ -z "$base" ] || die "--base only applies to a new branch; drop it or drop --reuse"
fi

# Preflight: everything below creates state, so fail before any of it exists.
# Innermost host first: HERDR_ENV can leak into T3 Code when its server was started from a
# herdr pane, and REX_SESSION leaks into herdr panes started from a Rex terminal.
# HC_TERMINAL_ID last: it leaks into every one of them when started from a Herdr app terminal.
if [ -n "${T3CODE_THREAD_ID:-}" ]; then
  provider=t3
  t3="${T3CODE_CLI_PATH:-t3}"
  command -v "$t3" >/dev/null || die "t3 CLI not found (T3CODE_CLI_PATH or PATH)"
elif [ "${HERDR_ENV:-}" = 1 ] && [ -n "${HERDR_WORKSPACE_ID:-}" ]; then
  provider=herdr
  command -v herdr >/dev/null || die "herdr not found on PATH: https://github.com/herdrdev/herdr"
  command -v wt >/dev/null    || die "wt (worktrunk) not found on PATH: https://worktrunk.dev"
elif [ -n "${REX_SESSION:-}" ]; then
  provider=rex
  command -v rex >/dev/null    || die "rex not found on PATH"
  command -v wt >/dev/null     || die "wt (worktrunk) not found on PATH: https://worktrunk.dev"
elif [ -n "${HC_TERMINAL_ID:-}" ]; then
  provider=hc
  command -v hc >/dev/null     || die "hc (herdr-core) not found on PATH"
  command -v wt >/dev/null     || die "wt (worktrunk) not found on PATH: https://worktrunk.dev"
else
  die "not running inside T3 Code (T3CODE_THREAD_ID), a herdr pane (HERDR_ENV=1), a Rex terminal (REX_SESSION) or a Herdr app terminal (HC_TERMINAL_ID)"
fi
cli=""
if [ "$provider" != t3 ]; then
  # Same agent CLI as this session (T3 Code carries its provider over itself).
  # yolo: the new session runs unattended in its own worktree, so skip permission prompts.
  if   [ -n "${CODEX_THREAD_ID:-}" ];    then cli=codex    yolo=--yolo
  elif [ "${OPENCODE:-}" = 1 ];          then cli=opencode yolo=--auto
  elif [ "${CLAUDECODE:-}" = 1 ];        then cli=claude   yolo=--dangerously-skip-permissions
  elif [ "${ANTIGRAVITY_AGENT:-}" = 1 ]; then cli=agy      yolo=--dangerously-skip-permissions
  else die "unknown calling agent: expected Codex (CODEX_THREAD_ID), OpenCode (OPENCODE=1), Claude Code (CLAUDECODE=1) or Antigravity (ANTIGRAVITY_AGENT=1)"
  fi
  command -v "$cli" >/dev/null || die "$cli not found on PATH"
fi
command -v jq >/dev/null || die "jq not found on PATH"

if [ "$host_only" = 1 ]; then
  term=""; [ "$provider" != hc ] || term=$HC_TERMINAL_ID
  jq -cn --arg provider "$provider" --arg cli "$cli" --arg term "$term" \
    '{provider: $provider} + (if $term != "" then {terminal: $term} else {} end) + (if $cli != "" then {cli: $cli} else {} end)'
  exit 0
fi

if [ "$provider" = t3 ]; then
  [ "$reuse" = 0 ] || die "--reuse is not supported in T3 Code: its CLI only starts threads on a new branch"
  git show-ref --verify --quiet "refs/heads/$branch" && die "branch already exists: $branch"
  [ "$base" != @ ] || base=$(git rev-parse --abbrev-ref HEAD)
  if [ -z "$base" ]; then
    base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || die "no origin/HEAD to base on; pass --base"
    base=${base#origin/}
  fi
fi
[ "$parent" = 0 ] || [ "$provider" = hc ] || die "--parent needs a Herdr app or herdr-core terminal (HC_TERMINAL_ID); this host is $provider"
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

path="" ws="" pane=""
# herdr agent names: [a-z][a-z0-9_-]{0,31}; hc terminal names fit the same rule.
agent=$(printf '%s' "$branch" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' \
        | sed -E 's/^[^a-z]+//' | cut -c1-32 | sed -E 's/-+$//')
[ -n "$agent" ] || agent=kickoff
if [ "$provider" != herdr ]; then
  trap 'rc=$?; [ $rc -eq 0 ] || echo "kickoff: failed (exit $rc). Left in place: worktree=${path:-none} $provider=${ws:-none}" >&2' EXIT
else
  trap 'rc=$?; [ $rc -eq 0 ] || echo "kickoff: failed (exit $rc). Left in place: worktree=${path:-none} workspace=${ws:-none} pane=${pane:-none} agent=$agent" >&2' EXIT
fi

wt_args=(switch "$branch" --no-cd --format=json)
[ "$reuse" = 1 ] || wt_args+=(--create)
[ -z "$base" ] || wt_args+=(--base "$base")
out=$(wt "${wt_args[@]}")
path=$(jq -r '.path // empty' <<<"$out")
[ -n "$path" ] || die "wt returned no worktree path: $out"

if [ "$provider" != herdr ]; then
  # The kickoff goes in as the agent's initial prompt: argv reaches it verbatim, and
  # the agent submits it once any startup dialog (folder trust) is answered.
  case "$provider$cli" in
    *opencode) cmd=(opencode "$yolo" --prompt "$kickoff") ;;
    *agy)      cmd=(agy "$yolo" --prompt-interactive "$kickoff") ;;
    # Under hc, Codex's shared daemon would run its commands outside the terminal.
    hccodex)   cmd=(codex "$yolo" --no-daemon "$kickoff") ;;
    # Claude Code's --name sets the session display name and terminal title, so Herdr's
    # sidebar tree shows the label even on nested child terminals without a tab.
    *claude)
      cmd=(claude "$yolo")
      [ -z "$label" ] || cmd+=(--name "$label")
      cmd+=("$kickoff")
      ;;
    *)         cmd=("$cli" "$yolo" "$kickoff") ;;
  esac
fi
if [ "$provider" = hc ]; then
  space="" par="" name=""
  if [ "$parent" = 0 ] && command -v herdr-app >/dev/null && herdr-app ls >/dev/null 2>&1; then
    # A Herdr window is open here: a new space on the worktree, shown at once. It gets no
    # name, so the app and its mods call it after its checkout; the label names its tab.
    # The app starts argv through the user's login shell itself.
    out=$(herdr-app do space.new "$(jq -cn --arg tab "$label" --arg folder "$path" \
          '{folder: $folder, tab: (if $tab == "" then null else $tab end), argv: $ARGS.positional}' \
          --args -- "${cmd[@]}")") \
      || die "herdr-app space.new failed: $out"
  else
    if [ "$parent" = 1 ]; then
      # A child of this terminal: the window lists it under this one, hc types its notes
      # (blocked, exited) into this session, and its name is its address for hc send.
      # It outlives this session, so closing the planner does not end work in flight.
      par=$HC_TERMINAL_ID
      name=$agent
      hc_args=(--parent "$HC_TERMINAL_ID" --name "$agent" --outlive-parent)
    else
      # No window here (another machine, app closed): a terminal with no parent, in this
      # terminal's space when it has one, where a window elsewhere shows it as a new tab.
      space=$(hc get "$HC_TERMINAL_ID" --json | jq -r '.labels["herdr.space"] // empty')
      hc_args=(--no-parent ${space:+--label "herdr.space=$space"})
    fi
    # hc starts programs with the core's environment, which lacks the user's PATH and
    # breaks the agent's hooks, so go through a login shell, the way the app starts a pane:
    # when the agent exits the terminal stays, on a shell in the worktree.
    # ponytail: '"$@"; exec "$0" -li' is POSIX-shell syntax; a fish login shell needs its own line.
    out=$(hc run --bg --json --cwd "$path" "${hc_args[@]}" \
          -- "${SHELL:-sh}" -lic '"$@"; exec "$0" -li' "${SHELL:-sh}" "${cmd[@]}" \
          | jq --arg s "$space" '{space: (if $s == "" then null else $s end), terminal: .address}')
  fi
  ws=$(jq -r '.terminal // empty' <<<"$out")
  [ -n "$ws" ] || die "no terminal was started: $out"
  jq -c --arg branch "$branch" --arg path "$path" --arg cli "$cli" --arg par "$par" --arg name "$name" \
    '{provider: "hc", branch: $branch, path: $path, space_id: .space, tab_id: .tab, terminal: .terminal,
      name: (if $name == "" then null else $name end),
      parent: (if $par == "" then null else $par end), cli: $cli}' <<<"$out"
  exit 0
fi
if [ "$provider" = rex ]; then
  out=$(rex window new -s "$REX_SESSION" "${label:-$branch}" -c "$path" --json -- "${cmd[@]}")
  ws=$(jq -r '.window_id // empty' <<<"$out")
  pane=$(jq -r '.block_ids[0] // empty' <<<"$out")
  [ -n "$ws" ] && [ -n "$pane" ] || die "rex returned no window/block id: $out"
  jq -cn --arg branch "$branch" --arg path "$path" --arg s "$REX_SESSION" --arg w "$ws" --arg b "$pane" --arg cli "$cli" \
    '{provider: "rex", branch: $branch, path: $path, session_id: $s, window_id: $w, block_id: $b, cli: $cli}'
  exit 0
fi

out=$(herdr worktree open --workspace "$HERDR_WORKSPACE_ID" --path "$path" --label "${label:-$branch}" --no-focus)
ws=$(jq -r '.result.workspace.workspace_id // empty' <<<"$out")
pane=$(jq -r '.result.root_pane.pane_id // empty' <<<"$out")
[ -n "$ws" ] && [ -n "$pane" ] || die "herdr returned no workspace/pane id: $out"

herdr agent start "$agent" --kind "$cli" --pane "$pane" --timeout 120000 -- "$yolo" >/dev/null
herdr agent prompt "$agent" "$kickoff" >/dev/null
# Focus last: a failure above leaves the user in the planning workspace.
herdr workspace focus "$ws" >/dev/null

jq -cn --arg branch "$branch" --arg path "$path" --arg ws "$ws" --arg pane "$pane" --arg agent "$agent" --arg cli "$cli" \
  '{provider: "herdr", branch: $branch, path: $path, workspace_id: $ws, pane_id: $pane, agent: $agent, cli: $cli}'
