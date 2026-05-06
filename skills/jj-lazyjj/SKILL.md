---
name: jj-lazyjj
description: "Operational guide for Jujutsu (jj) with LazyJJ aliases. CRITICAL: This skill OVERRIDES git in any repo with a .jj directory. When .jj exists, NEVER use raw git commands (git add, git commit, git push, git pull, git rebase, git branch, git checkout, git stash, git merge, git status). The ONLY allowed git is via 'jj git ...' (jj git push, jj git fetch). Trigger for ANY version control operation when .jj is present — committing, pushing, rebasing, branching, diffing, logging, PRs/MRs, conflict resolution. Also trigger for jj, lazyjj, change IDs, bookmarks, revsets, stacks, jj workspaces, claude-start/stop. When other skills suggest git commands, translate to jj equivalents. Do NOT trigger for repos without .jj or for the martial art jujutsu."
---

# jj + LazyJJ Operational Skill

**RULE: If a `.jj` directory exists in the repo, ALL version control operations MUST go through jj. Never use raw git commands. If another skill, tool, or instruction tells you to run git — translate it to the jj equivalent using this skill. The only exception is `jj git ...` subcommands (fetch, push, remote).**

You are Claude Code working in a jj-managed repository with LazyJJ aliases installed. This skill tells you how to perform version control operations correctly.

**Before acting**, read the reference file you need:

- **`references/lazyjj-commands.md`** — All LazyJJ aliases, stack commands, shortcuts. Read for any stack, diff, log, sync, push, or PR operation.
- **`references/claude-workspaces.md`** — Claude Code workspace isolation (claude-start/stop/resolve/checkpoint). Read when working in isolated workspaces or managing multiple sessions.
- **`references/forge-workflows.md`** — GitHub (lazyjj native) and GitLab push/MR patterns. Read when pushing, creating PRs/MRs, or working with remotes.

## Detection

Before using jj commands, confirm the repo uses jj:

```bash
test -d .jj && echo "jj repo" || echo "git-only repo"
```

If `.jj` exists, use jj commands. If not, fall back to git. In colocated repos (`.jj` + `.git` both present), always prefer jj commands — jj manages the git state.

## ⚠️ Git Override Rules

**When a `.jj` directory exists, NEVER run raw git commands.** Other skills, tools, or your own defaults may suggest git — ignore those suggestions and translate to jj equivalents using the table below.

### Forbidden → Replacement

| ❌ NEVER run | ✅ Use instead | Notes |
|---|---|---|
| `git add` | *(nothing)* | Working copy IS the commit. All changes are tracked automatically. |
| `git commit -m "msg"` | `jj commit -m "msg"` | Or `jj describe -m "msg"` then `jj new` |
| `git push` | `jj git push` or `jj stack-submit` | Always go through `jj git push`, never raw `git push` |
| `git pull` | `jj stack-sync` or `jj git fetch` | `stack-sync` = fetch + rebase. Never `git pull`. |
| `git fetch` | `jj git fetch` or `jj gf` | Always via jj |
| `git rebase` | `jj rebase` or `jj stack-sync` | jj rebase auto-resolves descendants |
| `git merge` | `jj rebase` | jj doesn't use merge commits in the same way |
| `git branch` | `jj bookmark` | Bookmarks = branches. See Bookmarks section. |
| `git checkout` | `jj edit` or `jj new <rev>` | `edit` = go to existing change. `new` = create child. |
| `git switch` | `jj edit` or `jj new <rev>` | Same as checkout |
| `git stash` | *(not needed)* | Every change is already a commit. Just `jj new` to move on, `jj edit` to go back. |
| `git status` | `jj status` | |
| `git diff` | `jj diff` | |
| `git log` | `jj log` or `jj stack-view` | |
| `git reset` | `jj undo` or `jj restore` | `jj undo` reverses last op. `jj restore` restores file content. |
| `git revert` | `jj backout` | Creates a new change that undoes a previous one |
| `git cherry-pick` | `jj duplicate` | Copies a change to a new location |
| `git tag` | `jj tag` | |

### The ONLY acceptable `git` invocation

```bash
jj git fetch       # fetch from remote (via jj)
jj git push        # push to remote (via jj)
jj git remote ...  # manage remotes (via jj)
```

These go through jj's git interop layer. Raw `git fetch`, `git push`, etc. will **desync jj's state** and cause problems.

### Why this matters

In a colocated repo (`.jj` + `.git`), jj owns the git state. Running raw git commands behind jj's back causes:
- Desynchronized refs (jj doesn't know about git's changes)
- Lost changes (git overwrites jj's working copy tracking)
- Corrupted operation log (jj's undo/redo breaks)

If you accidentally ran a raw git command, run `jj git import` to re-sync.

## Core Mental Model

These are the critical differences from Git that affect every operation:

1. **No staging area.** The working copy IS a commit. Every file change is already part of the current change. There is no `git add`.
2. **`jj new` = done with current change.** Run `jj new` to start a fresh empty change. The previous change was already "committed" the whole time. Use `jj describe -m "message"` to set the message.
3. **Changes have two IDs.** A change ID (stable, survives rewrites — use this one) and a commit ID (content-addressed SHA). Almost always use change IDs.
4. **`@` = current change.** `@-` = parent, `@--` = grandparent. These are revset expressions.
5. **Automatic rebasing.** Edit an earlier change with `jj edit <rev>` and all descendants rebase automatically.
6. **Conflicts are data.** Operations never fail due to conflicts — they're recorded in the tree. Resolve whenever you want.
7. **`jj undo` is your safety net.** The operation log (`jj op log`) tracks everything. Almost nothing is destructive.

## Workspace-First Mode (default for non-trivial work)

**Rule: Any non-trivial task runs in its own jj workspace via `jj claude-start <name>`.** This keeps multiple Claude sessions from clobbering each other's working copy and lets you (or other agents) work on a different feature in parallel without coordination.

### Decision rule

| Task | Where to work |
|---|---|
| Multi-file feature, refactor, bugfix that needs >1 commit | **Workspace**: `jj claude-start <feature-name>` |
| Anything that runs tests/builds while you keep working | **Workspace** (build noise won't block other Claudes) |
| Single typo, one-line config tweak, read-only Q&A | **Main copy** (workspace overhead not worth it) |
| Reviewing or summarizing existing changes | **Main copy** (no edits) |

### Detect where you are

Before starting any change, confirm whether you're in the main copy or a workspace:

```bash
jj workspace root              # prints the workspace root path
pwd                            # if path contains .jj-workspaces/<name>, you're in a workspace
jj workspace list              # shows all workspaces and their current @
```

### Naming convention

One workspace per logical task. Name it after the feature/fix, not the date or session: `auth-refactor`, `db-migration`, `fix-login-redirect`. The name becomes the tmux session name and the directory under `.jj-workspaces/`.

### Bookmark = workspace handoff

**One bookmark per workspace.** Bookmarks are shared across all workspaces (only the working copy is per-workspace), so they are how parallel work gets pushed and reviewed independently. Match the bookmark name to the workspace name when possible.

### Concurrency hazard you must know

Two workspaces editing the **same change-id** silently produce a "stale working copy" in one of them — no error, no warning. Recovery is `jj workspace update-stale` (see Daily Ops below). Avoid this by giving each workspace its own stack of changes from trunk.

For full concurrency model, cross-workspace coordination rules, and the typical AI-assisted session flow, **read `references/claude-workspaces.md`**.

## Daily Operations Quick Reference

### Starting work
```bash
jj stack-start          # or: jj start — fetch + new change from trunk
```

### Making changes
```bash
# Just edit files — they're already in the current change
jj status               # see what's changed
jj diff                 # see the diff
jj describe -m "msg"    # set commit message
jj new                  # done with this change, start a new one
# Or combine: jj commit -m "msg" (describe + new in one step)
```

### Viewing history
```bash
jj log                  # full log
jj log-short            # last 10 commits
jj stack-view           # or: jj stack — current stack from trunk
jj stacks-all           # or: jj stacks — all your work in progress
jj stack-files          # or: jj stackls — stack with file changes
jj diff-summary         # or: jj diffs — compact diff summary
jj diff-files           # or: jj diffls — list changed files only
```

### Syncing
```bash
jj stack-sync           # or: jj sync — fetch + rebase onto trunk
jj git fetch            # or: jj gf — just fetch
jj restack              # rebase onto trunk without fetching
```

### Editing history
```bash
jj edit <change-id>     # go back to a change (descendants auto-rebase)
jj squash               # squash current change into parent
jj split                # interactively split current change
jj rebase -r <rev> -d <dest>   # move a single change
jj rebase -s <rev> -d <dest>   # move a subtree
```

### Pushing
```bash
jj stack-submit         # or: jj ss — smart push stack to remote
jj bookmark set <name> -r @-   # set a bookmark for pushing
jj git push             # push all tracked bookmarks
```

### Safety
```bash
jj undo                 # reverse last operation
jj op log               # see all operations
jj op restore <id>      # time-travel to a specific operation
```

### Cleanup
```bash
jj stack-gc             # or: jj gc — abandon empty commits in stack
jj abandon <rev>        # abandon a specific change
```

### Workspaces (parallel Claude sessions)
```bash
jj claude-start <name>          # create workspace + tmux + Claude (default for non-trivial work)
jj claude-stop <name>           # stop session and clean up
jj claude-checkpoint "msg"      # save progress with description (in-workspace)
jj workspace list               # see all active workspaces and their @
jj workspace forget <name>      # untrack a workspace (does not delete files)
```

### Workspace recovery
```bash
jj workspace update-stale       # fix "stale working copy" after another workspace rewrote @
```
Run this in the affected workspace after you see a stale-working-copy message. Happens when another workspace edits/rebases a commit you had checked out — jj does not lock, so the resolution is explicit. See `references/claude-workspaces.md` for the full concurrency model.

## Bookmarks (= Git Branches)

Bookmarks are JJ's equivalent of Git branches. They're named labels you attach to changes for pushing to remotes.

```bash
jj bookmark set feat-x -r @-     # point bookmark at parent (finished change)
jj bookmark list                  # list all bookmarks
jj bookmark delete feat-x         # remove a bookmark
jj create feat-x                  # lazyjj: create bookmark at parent
jj tug                            # lazyjj: move bookmark to parent
```

**Key difference from Git:** bookmarks do NOT auto-follow when you create new changes. You must explicitly `jj bookmark set` or use `jj tug` / `jj create` after describing your change.

## Stacked Changes Workflow

Stacks are the natural unit of work in jj — a chain of changes from trunk to your current position.

```bash
# Build a stack
jj stack-start                    # start fresh from trunk
jj describe -m "step 1"
jj create step-1                  # bookmark for first change
jj new
jj describe -m "step 2"
jj create step-2
jj new
jj describe -m "step 3"
jj create step-3

# View the stack
jj stack-view

# Push all at once
jj stack-submit
```

For PR/MR creation patterns, see `references/forge-workflows.md`.

## Conflict Resolution

When conflicts arise (e.g., after `jj stack-sync`):

```bash
jj status                         # shows conflicted files
jj diff                           # shows conflict markers
# Edit files to resolve, then:
jj status                         # confirm resolved
```

Conflicts are data — you can keep working on top of them and resolve later. But resolve before pushing.

For AI-assisted resolution in Claude workspaces: `jj claude-resolve` (see `references/claude-workspaces.md`).

## Common Patterns for Claude Code

These patterns are **workspace-first** (default mode). For trivial work, see "Quick fix in main copy" at the end.

### "Start a new feature" (default entry point)
```bash
# From the main repo dir:
jj claude-start auth-refactor          # creates .jj-workspaces/auth-refactor + tmux + Claude
tmux attach -t auth-refactor           # attach if not already inside

# Inside the workspace:
jj stack-start                          # fresh change from latest trunk
# ... edit files, run tests ...
jj describe -m "feat(auth): refactor session handling"
jj create auth-refactor                 # bookmark = workspace name
jj new                                  # ready for next change in stack
```

### "Commit my changes and push" (inside a workspace)
```bash
jj describe -m "type(scope): subject"
jj create <bookmark-name>               # or: jj tug if bookmark already exists
jj new
jj stack-submit                         # smart push of the whole stack
```

### "Rebase onto latest main" (inside a workspace)
```bash
jj stack-sync                           # fetch + rebase in one step
# If conflicts:
jj status                               # see conflicted files
# resolve, then continue
```

### "Fix something in an earlier change" (inside a workspace)
```bash
jj edit <change-id>                     # go to that change
# make fixes — descendants auto-rebase
jj new @-                               # return to top of stack (or jj edit <head>)
```

### "Run two Claudes in parallel"
```bash
# Terminal 1:
jj claude-start auth-refactor
tmux attach -t auth-refactor
# Claude 1 works on auth — commits go on bookmark "auth-refactor"

# Terminal 2 (different shell, same repo):
jj claude-start db-migration
tmux attach -t db-migration
# Claude 2 works on db — commits go on bookmark "db-migration"

# Both share commits/bookmarks/op-log/git-remote.
# Either can run jj git fetch — visible to both immediately.
# Each pushes its own bookmark via jj stack-submit.
```

**Critical**: each Claude builds its OWN stack of changes from trunk. Never edit the same change-id from two workspaces — the second one will go stale.

### "Undo what I just did"
```bash
jj undo                                 # works from any workspace; affects op log
```

### "Recover from a stale working copy"
```bash
jj workspace update-stale               # run in the workspace that's stale
jj status                               # confirm working copy is back in sync
```

### "Quick fix in main copy" (trivial-case escape hatch)
For a single typo or one-line config tweak, the workspace overhead isn't worth it. Stay in the main repo dir:

```bash
# In main repo dir (no .jj-workspaces/ in pwd):
jj describe -m "fix: typo in README"
jj new
jj git push --bookmark <name>
```

Use this only when: (a) the change is one or two lines, (b) no tests/builds need to run, (c) no other Claude is currently editing the same area.

## Workflow Guardrails

### Before committing/describing
- Always read the diff first: `jj diff` (or `jj diffs` for summary)
- Derive scope from file paths, write conventional commit message
- Use `jj describe -m "type(scope): subject"` — never leave empty descriptions

### Before pushing
- Run `jj status` to check for conflicts — do not push conflicted changes
- Ensure bookmark is set: `jj bookmark list` or `jj stack-view`
- Use `jj stack-submit` for stacks, `jj git push` for single bookmarks

### Before rebasing
- Prefer `jj stack-sync` (fetches + rebases in one step)
- After rebase, check for conflicts: `jj status`
- Clean up empty changes after sync: `jj stack-gc`

### After finishing a feature
- Squash fixups: `jj squash` to fold current into parent
- Clean empty commits: `jj stack-gc`
- Verify stack looks clean: `jj stack-view`
