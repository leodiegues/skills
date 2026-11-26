---
name: teardown
description: Tear down finished work — the inverse of kickoff. Runs the repo's own teardown steps if it documents any, removes the worktree this session runs in (or a nested Herdr child builder's worktree when invoked from its parent session, or switches the main checkout off its feature branch), deletes the branch if it is merged, then closes the tab, pane, or child terminal: the herdr workspace or pane, the Rex tab or pane, the Herdr app (herdr-core, `hc`) space, pane, or child terminal, or nothing in T3 Code and other hosts. Refuses on the default branch, on main/master and on a detached HEAD. Use when the user invokes /teardown from the session whose work is done, or from a Herdr parent session targeting one of its nested child builders. Do NOT use to clean up unrelated worktrees or branches, to prune stale branches in bulk, or to abandon work in progress.
argument-hint: "[--terminal <id-or-name>] [--force] [--delete-branch] [--close-pane]"
compatibility: Requires `git` and `jq`. Uses the `wt` CLI (https://worktrunk.dev) when present, plain git otherwise. Closes the session's tab or pane in herdr (https://github.com/herdrdev/herdr), Rex and the Herdr app (`herdr-app`, `hc`), and supports tearing down nested `hc` child terminals from their parent session; other hosts get the git teardown only
disable-model-invocation: true
---

Remove finished work and close its session. Normally it acts on this session's own checkout (run from the session that did the work). In the Herdr app (`$HC_TERMINAL_ID`), a parent/orchestrator session can also tear down its own **nested child builder(s)** with `--terminal <id-or-name>`, leaving the parent session open.

When tearing down this session itself, the close ends this session and takes its messages with it, so the run is the last thing this session does. Anything the user has to decide is raised by stopping before the run, never as a note on the way out. When the check is clean and the target is unambiguous, do not ask for confirmation: invoking `/teardown` is the confirmation.

## 0. Resolve a nested child target (Herdr parent session only)

Skip this step when tearing down this session's own feature branch, or when running inside an inner host (`T3CODE_THREAD_ID`, `HERDR_ENV=1`, `REX_BLOCK`) where `HC_TERMINAL_ID` may have leaked.

If the user named a child terminal (by ID, name, or issue/branch) **or** invoked `/teardown` while on the default branch inside a Herdr session (`$HC_TERMINAL_ID`), list this session's nested children with `hc ls --all --json | jq --arg p "${HC_TERMINAL_ID:-}" '[.terminals[] | select($p != "" and .parent == $p)]'`:

- **User named one** → match it among this session's children and pass `--terminal <id-or-name>` in steps 1 and 3. Never target a terminal that is not a child of this session.
- **None named, 1 child** → ask once or confirm if ambiguous; if the user clearly meant "tear down my child", pass `--terminal <id>`.
- **None named, 2+ children** → list them (name, address, state, cwd) and ask which child(ren) to tear down before running step 1.
- **No children** → continue to step 1 (which will refuse on the default branch as usual).

## 1. Check

Run the bundled script (path relative to this skill's directory) from the session's working directory (add `--terminal <id-or-name>` when tearing down a nested child from its parent):

```bash
scripts/teardown.sh --check
# or, from a Herdr parent session for a nested child:
scripts/teardown.sh --terminal <id-or-name> --check
```

It changes nothing and prints one JSON line: `branch`, `default_branch`, `path`, `linked_worktree`, `dirty`, `local_only_commits`, `host`, `closes`.

- **It refuses** (default branch, `main`/`master`, detached HEAD, `--terminal` is not a child of this session, or the child sits in the main checkout instead of a linked worktree) → there is nothing safe to tear down. Relay the message and stop. Do not switch branches, `cd` into another worktree, or run the removal by hand to get past it.
- **`dirty` is not empty** → stop and show the files. Ask whether to commit, stash, or lose them. Only "lose them" allows `--force`, and only in a linked worktree; in the main checkout the user clears them first.
- **`local_only_commits` > 0** → those commits are on no remote and not on the default branch. They are not lost: an unmerged branch is kept. Don't stop for it.

## 2. Run the repo's own teardown

The script knows git and the host, nothing about the project. Find what this repo says to do when work ends:

- its agent instructions (`AGENTS.md`, `CLAUDE.md`, in context or in the worktree) and contributing docs: any section on teardown, cleanup, or finishing a branch
- a teardown, clean, or down task in its task runner (`justfile`, `Makefile`, `package.json` scripts, `mise.toml`)
- `wt hook show`: the `pre-remove` and `post-remove` hooks listed there run on their own in step 3, so don't repeat them

Run what you find now, from the worktree `path` returned by `--check` (for a child, that is the child's worktree, not the parent's checkout), before it is removed: stop dev servers and containers, drop a per-branch database or preview environment, whatever the repo lists. If a step fails, stop and report; don't go on to step 3.

Where the repo's instructions conflict with this skill (it keeps merged branches, it wants the pane left open), the repo wins: stop short of that part or tell the user what was left.

If the repo says nothing, move on. Don't invent cleanup it didn't ask for.

## 3. Run

```bash
scripts/teardown.sh
# or, for a nested child from its parent:
scripts/teardown.sh --terminal <id-or-name>
```

| Option | Use only when |
| --- | --- |
| `--terminal <id-or-name>` | tearing down one of this Herdr session's nested child builders from the parent session |
| `--force` | the user said to lose the uncommitted changes in this worktree |
| `--delete-branch` | the user said to delete the branch even though it is not merged |
| `--close-pane` | the branch is in the main checkout and the user asked to close the pane anyway |

It rechecks the guards, fetches the default branch (so a PR merged on the forge counts as merged), steps out of the worktree, removes it with `wt remove` (hooks run, a squash-merged branch counts as merged) or with plain git when `wt` is missing (then the branch is also deleted when it is fully pushed to its upstream), prints one JSON line (`branch`, `path`, `worktree`, `branch_outcome`, `host`, `closes`), then closes the host. If the git part fails, nothing closes.

What closes, by `host`:

- **herdr** — the workspace when it is this worktree's workspace, otherwise only the calling pane.
- **rex** — the tab when this pane is alone in it, otherwise only the calling pane.
- **hc** (Herdr app, herdr-core) — the space when its folder is this worktree and this is the only terminal in it; otherwise only the calling pane. With no pane in a Herdr window on this machine (a remote machine, the app closed, a child terminal listed under its parent), the terminal's program is ended (`hc kill`). With `--terminal`, the same rule applies to the child terminal only (nothing to kill if it already finished); this parent session stays open.
- **t3** — nothing: the `t3` CLI cannot archive a thread. Archive it with a T3 Code tool if this session has one; otherwise tell the user to archive the thread.
- **none** — nothing. Close it with the host's own CLI if this session knows it (`tmux kill-pane`), otherwise tell the user to close it.

A branch in the main checkout keeps its pane: the checkout is still there, now on the default branch.

## 4. If this session is still here

Report from the JSON: the repo teardown steps that ran, what was removed, `branch_outcome` (`deleted`, or `retained_unmerged` — the branch stays; delete it with `git branch -D <branch>` only when asked), and what closed or is left for the user to close.

If this session's own worktree was removed (not `--terminal`), its working directory no longer exists: run nothing more in it and end the turn. With `--terminal`, the parent session's checkout is untouched and stays ready for the next command.

On failure the script prints the reason and leaves the terminal open. Read it before retrying; never retry with `--force` or `--delete-branch` on your own.
