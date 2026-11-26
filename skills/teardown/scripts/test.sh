#!/usr/bin/env bash
# Self-check for teardown.sh in a throwaway repo. No host is set outside --check, so nothing gets closed.
set -euo pipefail
td="$(cd "$(dirname "$0")" && pwd)/teardown.sh"
tmp=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$tmp"' EXIT
run() { env -u T3CODE_THREAD_ID -u HERDR_ENV -u REX_BLOCK -u HC_TERMINAL_ID "$td" "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
# refuses <expected message> [args]: must fail, and for that reason.
refuses() { local why=$1 out; shift; if out=$(run "$@" 2>&1); then fail "not refused: $why"; fi
  case "$out" in *"$why"*) ;; *) fail "refused for the wrong reason, wanted '$why': $out" ;; esac; }

git init -q -b main "$tmp/repo"; cd "$tmp/repo"
git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
commit() { git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m work; }

refuses "on main: nothing to tear down"
[ "$(git branch --show-current)" = main ] || fail "default branch moved"
git switch -q --detach; refuses "detached HEAD: nothing to tear down"; git switch -q main

# Linked worktree: dirty is refused, clean is removed, merged branch is deleted.
git worktree add -q -b merged "$tmp/merged"; cd "$tmp/merged"; touch x
refuses "uncommitted changes"; [ -e x ] || fail "dirty worktree was touched"; rm x
[ "$(run --check | jq -c '[.linked_worktree, .closes, .host]')" = '[true,"","none"]' ] || fail "--check output"
[ -d "$tmp/merged" ] || fail "--check removed the worktree"
[ "$(run | jq -r .branch_outcome)" = deleted ] || fail "merged branch not deleted"
[ ! -d "$tmp/merged" ] || fail "worktree not removed"

# Linked worktree with unmerged work: worktree goes, branch stays.
cd "$tmp/repo"; git worktree add -q -b unmerged "$tmp/unmerged"
echo hi > "$tmp/unmerged/f"; git -C "$tmp/unmerged" add f; commit "$tmp/unmerged"
[ "$(cd "$tmp/unmerged" && run | jq -r .branch_outcome)" = retained_unmerged ] || fail "unmerged branch outcome"
git show-ref --verify --quiet refs/heads/unmerged || fail "unmerged branch was deleted"

# Herdr app host, against stubs: the space when it is this worktree's and this terminal is
# alone in it, else the pane; with no window, the terminal's program.
mkdir "$tmp/bin"
cat > "$tmp/bin/hc" <<EOF
#!/bin/sh
if [ "\$1" = get ]; then cat "$tmp/hc-get.json"; exit 0; fi
echo "\$*" >> "$tmp/hc.log"
EOF
printf '#!/bin/sh\nif [ "$1" = ls ]; then cat "%s/ls.json"; exit 0; fi\necho "$*" >> "%s/app.log"\n' "$tmp" "$tmp" > "$tmp/bin/herdr-app"
chmod +x "$tmp/bin/hc" "$tmp/bin/herdr-app"
git worktree add -q -b hc "$tmp/hc"; cd "$tmp/hc"
# hc_closes <space folder> <other terminals in the space, as JSON>
hc_closes() { jq -n --arg f "$1" --argjson more "$2" \
    '{spaces: [{id: "sp1", folder: $f, tabs: [{terminals: ([{terminal: "t1", pane: "p1"}] + $more)}]}]}' > "$tmp/ls.json"
  PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 "$td" --check | jq -r .closes; }
case "$(hc_closes "$tmp/hc" '[]')" in *space.close*sp1*) ;; *) fail "hc: own space not closed" ;; esac
case "$(hc_closes "$tmp/hc" '[{"terminal": "t2", "pane": "p2"}]')" in *pane.close*p1*) ;; *) fail "hc: shared space closed" ;; esac
case "$(hc_closes "$tmp/other" '[]')" in *pane.close*p1*) ;; *) fail "hc: foreign space closed" ;; esac
rm "$tmp/ls.json"
[ "$(PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 "$td" --check | jq -r .closes)" = "hc kill t1" ] || fail "hc: no window"
cd "$tmp/repo"

# Herdr parent tearing down a nested child builder via --terminal.
git worktree add -q -b child-live "$tmp/child-live"
jq -n --arg cwd "$tmp/child-live" '{address: "t2", name: "child-live", parent: "t1", state: "live", cwd: $cwd}' > "$tmp/hc-get.json"
# Refuses without HC_TERMINAL_ID, when HC_TERMINAL_ID leaked into an inner host, or when not a child.
refuses "HC_TERMINAL_ID" --terminal t2 --check
if out=$(PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 REX_SESSION=s1 REX_BLOCK=b1 "$td" --terminal t2 --check 2>&1); then fail "hc: leaked HC_TERMINAL_ID not refused"; fi
case "$out" in *"HC_TERMINAL_ID"*) ;; *) fail "hc: wrong leaked-host error: $out" ;; esac
if out=$(PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t99 "$td" --terminal t2 --check 2>&1); then fail "hc: foreign child not refused"; fi
case "$out" in *"not a child of this session"*) ;; *) fail "hc: wrong foreign child error: $out" ;; esac
# Live child without a pane: closes with hc kill t2, removes worktree and merged branch.
[ "$(PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 "$td" --terminal child-live --check | jq -c '[.branch, .host, .closes]')" = '["child-live","hc","hc kill t2"]' ] || fail "hc: child --check"
# Kept child (has a pane in parent's space): closes only the child's pane, never the parent's space.
jq -n --arg f "$tmp/repo" '{spaces: [{id: "sp1", folder: $f, tabs: [{terminals: [{terminal: "t1", pane: "p1"}, {terminal: "t2", pane: "p2"}]}]}]}' > "$tmp/ls.json"
case "$(PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 "$td" --terminal t2 --check | jq -r .closes)" in *pane.close*p2*) ;; *) fail "hc: kept child pane not closed" ;; esac
rm "$tmp/ls.json"
# Actual run removes the child worktree, deletes the merged branch, and kills t2 while parent stays on main.
: > "$tmp/hc.log"
[ "$(PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 "$td" --terminal child-live | jq -r .branch_outcome)" = deleted ] || fail "hc: child branch not deleted"
[ ! -d "$tmp/child-live" ] || fail "hc: child worktree not removed"
[ "$(cat "$tmp/hc.log")" = "kill t2" ] || fail "hc: child not killed: $(cat "$tmp/hc.log")"
[ "$(git branch --show-current)" = main ] || fail "hc: parent branch moved"
# Finished child: removes worktree with nothing to kill.
git worktree add -q -b child-done "$tmp/child-done"
jq -n --arg cwd "$tmp/child-done" '{address: "t3", name: "child-done", parent: "t1", state: "finished", cwd: $cwd}' > "$tmp/hc-get.json"
: > "$tmp/hc.log"
[ "$(PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 "$td" --terminal t3 --check | jq -r .closes)" = "" ] || fail "hc: finished child close"
[ "$(PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 "$td" --terminal t3 | jq -r .branch_outcome)" = deleted ] || fail "hc: finished child branch"
[ ! -d "$tmp/child-done" ] || fail "hc: finished child worktree not removed"
[ ! -s "$tmp/hc.log" ] || fail "hc: killed already-finished child"
# Child sitting in the main checkout (even on a feature branch) is refused from parent.
git switch -q -c main-feat
jq -n --arg cwd "$tmp/repo" '{address: "t4", name: "main-feat", parent: "t1", state: "live", cwd: $cwd}' > "$tmp/hc-get.json"
if out=$(PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 "$td" --terminal t4 --check 2>&1); then fail "hc: main-checkout child not refused"; fi
case "$out" in *"not a linked worktree"*) ;; *) fail "hc: wrong main-checkout child error: $out" ;; esac
git switch -q main; git branch -q -d main-feat

# Branch in the main checkout: back on main, merged branch deleted.
git switch -q -c inplace
[ "$(run | jq -r .branch_outcome)" = deleted ] || fail "in-place branch not deleted"
[ "$(git branch --show-current)" = main ] || fail "main checkout not back on main"

# Bare layout: every checkout is a linked worktree, the default branch included.
git clone -q --bare "$tmp/repo" "$tmp/bare"
git -C "$tmp/bare" worktree add -q "$tmp/bare-main" main
git -C "$tmp/bare" worktree add -q -b feat "$tmp/bare-feat"
(cd "$tmp/bare-main" && refuses "on main: nothing to tear down")
[ -d "$tmp/bare-main" ] || fail "default-branch worktree was removed"
# Child sharing the parent's own linked worktree in a bare layout is refused.
jq -n --arg cwd "$tmp/bare-feat" '{address: "t5", name: "same-wt", parent: "t1", state: "live", cwd: $cwd}' > "$tmp/hc-get.json"
if out=$(cd "$tmp/bare-feat" && PATH="$tmp/bin:$PATH" HC_TERMINAL_ID=t1 "$td" --terminal t5 --check 2>&1); then fail "hc: bare same-worktree child not refused"; fi
case "$out" in *"this session's own worktree"*) ;; *) fail "hc: wrong bare same-worktree error: $out" ;; esac
[ "$(cd "$tmp/bare-feat" && run | jq -r .worktree)" = removed ] || fail "bare-layout worktree outcome"
[ ! -d "$tmp/bare-feat" ] || fail "bare-layout worktree not removed"
[ -d "$tmp/bare-main" ] || fail "default-branch worktree was removed"
echo ok
