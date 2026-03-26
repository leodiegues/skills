# Claude Code Workspaces with jj

LazyJJ provides workspace isolation for Claude Code sessions using jj's native workspace feature. Each workspace gets its own working copy while sharing the same repository state.

## Prerequisites

- Claude Code CLI: `npm install -g @anthropic-ai/claude-code`
- tmux (recommended, not required)

## Commands

| Command | Shortcut | Purpose |
|---|---|---|
| `claude-start <name>` | `clstart` | Create isolated jj workspace + tmux session |
| `claude-stop <name>` | `clstop` | Stop session and clean up workspace |
| `claude-resolve` | `clresolve` | AI-assisted conflict resolution |
| `claude-checkpoint <msg>` | — | Save progress with description |

---

## Starting a Workspace

```bash
jj claude-start my-feature
# Output: Started tmux session: my-feature
# Attach with: tmux attach -t my-feature
```

This creates:
1. A jj workspace at `.jj-workspaces/my-feature` (isolated working copy)
2. A tmux session running Claude Code in that directory

### Without tmux

If tmux is not installed, the workspace is still created:

```bash
jj claude-start my-feature
# tmux not available - start Claude manually:
cd .jj-workspaces/my-feature
claude
```

---

## Stopping a Workspace

```bash
jj claude-stop my-feature
```

This cleans up the tmux session and workspace.

---

## Checkpointing

While working, save progress:

```bash
jj claude-checkpoint "got auth working"
```

This describes the current commit and creates a new one — a quick save point you can return to.

---

## Conflict Resolution

After a rebase that produces conflicts:

```bash
jj claude-resolve
```

Runs Claude on each conflicted file to help resolve it. Use this after `jj stack-sync` or `jj rebase` when conflicts appear.

---

## Multiple Concurrent Sessions

jj workspaces allow multiple Claude sessions on different features simultaneously:

```bash
jj claude-start feature-a
jj claude-start feature-b

# List all workspaces
jj workspace list

# Attach to a specific session
tmux attach -t feature-a
```

Each workspace has its own working copy but shares the same repo state (commits, bookmarks, etc.). Changes in one workspace are visible to others via the commit graph.

---

## Cleaning Up Old Workspaces

```bash
# List all workspaces
jj workspace list

# Forget a workspace (removes jj's tracking, not the directory)
jj workspace forget workspace-name

# Remove the directory
rm -rf .jj-workspaces/workspace-name
```

---

## Why This Combination Works

### Safe Experimentation
jj's operation log means Claude can try things without risk:

```bash
jj undo                  # reverse Claude's last action
jj op log                # see what Claude did
jj op restore <id>       # jump back to any point
```

### Workspace Isolation
Each Claude session works in its own workspace — no interference between concurrent sessions or with your main working copy.

### First-Class Conflicts
jj's conflict model means Claude can attempt merges/rebases without blocking. Conflicts are recorded, not errors. Resolve when convenient.

### Checkpointing
`jj claude-checkpoint` creates natural save points in the commit graph. Combined with `jj op log`, this gives complete history of what Claude did and when.

---

## Typical AI-Assisted Session

```bash
# Start fresh from trunk
jj stack-start

# Start a Claude workspace for the feature
jj claude-start auth-feature

# Attach to Claude session
tmux attach -t auth-feature

# ... Claude implements the feature ...

# Checkpoint periodically
jj claude-checkpoint "basic auth flow done"

# When done, stop the workspace
jj claude-stop auth-feature

# Review Claude's work
jj stack-view
jj diff

# Clean up if needed
jj squash
jj stack-gc

# Push for review
jj stack-submit        # GitHub
# or for GitLab: jj git push --bookmark auth-feature
```
