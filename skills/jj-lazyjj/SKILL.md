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

### "Commit my changes and push"
```bash
jj describe -m "descriptive message"
jj bookmark set feature-name -r @
jj new
jj git push --bookmark feature-name
```

### "Create a new feature from trunk"
```bash
jj stack-start
# make changes
jj describe -m "feature description"
jj create feature-name
jj new
jj stack-submit
```

### "Rebase onto latest main"
```bash
jj stack-sync   # fetch + rebase in one step
```

### "Fix something in an earlier change"
```bash
jj edit <change-id>     # go to that change
# make fixes
jj new                  # or jj edit @ to return to where you were
# descendants auto-rebased
```

### "Undo what I just did"
```bash
jj undo
```
