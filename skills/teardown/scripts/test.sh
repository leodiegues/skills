#!/usr/bin/env bash
# Self-check for teardown.sh in a throwaway repo. No host is set, so nothing gets closed.
set -euo pipefail
td="$(cd "$(dirname "$0")" && pwd)/teardown.sh"
tmp=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$tmp"' EXIT
run() { env -u T3CODE_THREAD_ID -u HERDR_ENV -u REX_BLOCK "$td" "$@"; }
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
[ "$(cd "$tmp/bare-feat" && run | jq -r .worktree)" = removed ] || fail "bare-layout worktree outcome"
[ ! -d "$tmp/bare-feat" ] || fail "bare-layout worktree not removed"
[ -d "$tmp/bare-main" ] || fail "default-branch worktree was removed"
echo ok
