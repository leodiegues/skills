# LazyJJ Commands Reference

Complete reference for all LazyJJ aliases and shortcuts.

## Table of Contents

1. [Stack Commands](#stack-commands)
2. [Diff & Log Aliases](#diff--log-aliases)
3. [Navigation](#navigation)
4. [Sync & Rebase](#sync--rebase)
5. [Push & Bookmarks](#push--bookmarks)
6. [Cleanup](#cleanup)
7. [GitHub PR Commands](#github-pr-commands)
8. [Claude Workspace Commands](#claude-workspace-commands)
9. [Utility](#utility)
10. [Pure Shortcuts](#pure-shortcuts)

---

## Stack Commands

A "stack" = chain of commits from trunk divergence to current position.

| Command | Shortcut | What it does |
|---|---|---|
| `stack-view` | `stack` | View current stack with trunk context |
| `stack-files` | `stackls` | Stack with file changes listed per commit |
| `stacks-all` | `stacks` | View ALL your stacks (all work in progress) |
| `stacks-all-files` | `stacksls` | All stacks with file changes |
| `stack-top` | `top` | Jump to top of current stack |
| `stack-start` | `start` | Fetch latest trunk + create new change from it |
| `stack-sync` | `sync` | Fetch + rebase current stack onto trunk |
| `stack-submit` | `ss` | Smart push — push entire stack to remote |
| `stack-gc` | `gc` | Abandon empty commits in stack |
| `restack` | — | Rebase stack onto trunk WITHOUT fetching |

### stack-start

Use when beginning new work. Fetches latest trunk and creates a fresh change on top.

```bash
jj stack-start
# equivalent to: jj git fetch && jj new main
```

### stack-sync

Use to update your stack with latest upstream. Fetches and rebases.

```bash
jj stack-sync
# equivalent to: jj git fetch && jj rebase -d main
```

### stack-submit

Smart push that handles bookmarks and pushes the entire stack.

```bash
jj stack-submit
```

### stack-gc

Cleans up empty changes (no diff) in your stack.

```bash
jj stack-gc
```

---

## Diff & Log Aliases

| Command | Shortcut | JJ Equivalent | Purpose |
|---|---|---|---|
| `diff-summary` | `diffs` | `diff --summary --no-pager` | Compact diff summary |
| `diff-files` | `diffls` | `diff --name-only --no-pager` | List changed files only |
| `log-short` | — | `log --limit 10` | Quick log (last 10 commits) |

---

## Navigation

| Command | Shortcut | Purpose |
|---|---|---|
| `stack-top` | `top` | Jump to top of stack |

For general navigation, use native jj:

```bash
jj edit <change-id>    # go to a specific change
jj new <change-id>     # create new change on top of a specific change
```

---

## Sync & Rebase

| Command | Shortcut | Purpose |
|---|---|---|
| `stack-sync` | `sync` | Fetch + rebase onto trunk |
| `stack-start` | `start` | Fetch + start fresh from trunk |
| `restack` | — | Rebase onto trunk (no fetch) |

Native jj rebase variants:

```bash
jj rebase -r <rev> -d <dest>    # move a single change
jj rebase -s <rev> -d <dest>    # move a subtree (change + descendants)
jj rebase -b <rev> -d <dest>    # move a branch (all ancestors up to dest)
```

---

## Push & Bookmarks

| Command | Shortcut | Purpose |
|---|---|---|
| `stack-submit` | `ss` | Smart push entire stack |
| `tug` | — | Move bookmark to parent commit |
| `create` | — | Create new bookmark at parent commit |

### Creating bookmarks for pushing

```bash
# Option 1: lazyjj alias
jj create my-feature             # creates bookmark at @- (parent)

# Option 2: native jj
jj bookmark set my-feature -r @- # set bookmark at parent

# Option 3: after describing, move bookmark
jj describe -m "my change"
jj tug                           # moves bookmark to @-
```

### Pushing specific bookmarks

```bash
jj git push                                  # push all tracked bookmarks
jj git push --bookmark my-feature            # push specific bookmark
jj git push --bookmark my-feature --allow-new # first push of new bookmark
```

---

## Cleanup

| Command | Shortcut | Purpose |
|---|---|---|
| `stack-gc` | `gc` | Abandon empty commits in stack |

Native jj cleanup:

```bash
jj abandon <rev>                 # abandon a specific change
jj workspace forget <name>       # forget a workspace
```

---

## GitHub PR Commands

These require `gh` CLI to be installed and authenticated.

| Command | Shortcut | Purpose |
|---|---|---|
| `pr-view` | `prv` | View current PR |
| `pr-open` | `pro` | Open current PR in browser |
| `pr-stack` | — | List bookmarks in stack |
| `pr-stack-create` | `sprs` | Create/update stacked PRs |
| `pr-stack-summary` | `prs` | Generate PR stack summary (markdown) |
| `pr-stack-update` | `uprs` | Update PR comments with stack info |
| `pr-stack-md` | `prmd` | Formatted PR stack with CI/review status |
| `github-repo` | `repo` | Get GitHub repo from origin |
| `gh` | — | Run any gh command in repo context |

### Creating stacked PRs

```bash
# 1. Build your stack with bookmarks
jj stack-start
jj describe -m "step 1: database schema"
jj create db-schema
jj new
jj describe -m "step 2: user model"
jj create user-model
jj new
jj describe -m "step 3: user API"
jj create user-api

# 2. Create all PRs at once
jj pr-stack-create

# 3. Update PR descriptions with stack summary
jj pr-stack-update
```

---

## Claude Workspace Commands

See `claude-workspaces.md` for full details.

| Command | Shortcut | Purpose |
|---|---|---|
| `claude-start` | `clstart` | Create jj workspace + tmux session |
| `claude-stop` | `clstop` | Stop and clean up workspace |
| `claude-resolve` | `clresolve` | Resolve conflicts using Claude |
| `claude-checkpoint` | — | Save checkpoint with message |

---

## Pure Shortcuts

| Shortcut | Expands to |
|---|---|
| `diffs` | `diff-summary` |
| `diffls` | `diff-files` |
| `gf` | `git fetch` |
| `stack` | `stack-view` |
| `stackls` | `stack-files` |
| `stacks` | `stacks-all` |
| `stacksls` | `stacks-all-files` |
| `top` | `stack-top` |
| `start` | `stack-start` |
| `sync` | `stack-sync` |
| `ss` | `stack-submit` |
| `gc` | `stack-gc` |
| `prv` | `pr-view` |
| `pro` | `pr-open` |
| `sprs` | `pr-stack-create` |
| `prs` | `pr-stack-summary` |
| `uprs` | `pr-stack-update` |
| `prmd` | `pr-stack-md` |
| `repo` | `github-repo` |

---

## Customizing Aliases

LazyJJ config lives in `~/.config/jj/lazyjj/config/`. To override:

```bash
# Create a file that sorts AFTER lazyjj-* files
~/.config/jj/conf.d/zzz-my-overrides.toml
```

```toml
[aliases]
# Override lazyjj alias
log-short = ["log", "--limit", "20"]

# Add your own
mylog = ["log", "--limit", "5", "-T", "builtin_log_compact"]
```
