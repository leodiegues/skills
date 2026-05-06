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

# List all workspaces (shows current @ for each)
jj workspace list

# Attach to a specific session
tmux attach -t feature-a
```

This is the **default mode** for non-trivial Claude work. The next two sections explain what's safe to do in parallel and what isn't.

---

## Concurrency Model

jj workspaces use **optimistic concurrency** — there are no locks. Understanding what's shared vs per-workspace is the whole game.

### Shared across all workspaces

| State | Implication |
|---|---|
| Commit graph (all change-ids) | A commit you create in workspace A is visible in workspace B immediately |
| Bookmarks | Setting/moving a bookmark in A affects B's view of it |
| Operation log (`jj op log`) | All operations from all workspaces show in one log; `jj undo` from any workspace affects shared state |
| Git remote refs | `jj git fetch` from any workspace updates `main@origin` etc. for everyone |
| Push state | `jj git push` from any workspace pushes the shared bookmarks |

### Per-workspace (isolated)

| State | Implication |
|---|---|
| Working copy commit (`@`) | Each workspace has its own current change — they don't see each other's `@` |
| Sparse patterns | Each workspace can sparse-checkout different files |
| Filesystem files | Each workspace is a separate directory with separate file contents |

### The one hazard: stale working copy

A workspace becomes **stale** when its working-copy commit gets rewritten by another workspace. The most common trigger:

```bash
# Workspace A is editing change X (X is A's @)
# Workspace B runs:  jj edit X  (or jj rebase that touches X, or jj squash, etc.)
# → Workspace A is now STALE
# → A's filesystem still has the old X contents, but the op log moved on
```

There is no error or warning at the moment of the conflict. You only see it when you next run a jj command in A:

```
The working copy is stale (not updated since operation abc123).
Hint: Run `jj workspace update-stale` to update it.
```

**Recovery is always the same**:

```bash
# In the stale workspace:
jj workspace update-stale     # syncs working copy to the latest op-log state
jj status                     # confirm
```

If `update-stale` can't reconstruct the state (rare — happens if the original operation was abandoned), it creates a recovery commit so nothing is lost.

---

## Cross-Workspace Coordination Rules

These rules let multiple Claudes work in parallel without stepping on each other:

### 1. One bookmark per workspace

Each workspace owns its own bookmark. Match the bookmark name to the workspace name when possible:

```bash
jj claude-start auth-refactor
# Inside the workspace, the stack ends with:
jj bookmark set auth-refactor -r @-     # or: jj create auth-refactor / jj tug
```

Two workspaces sharing one bookmark = race conditions on push. Don't.

### 2. Each workspace builds its own stack from trunk

Don't `jj edit` a change-id that's the `@` of another workspace. Instead, start fresh from trunk:

```bash
jj stack-start    # fetch + new change from trunk — independent of other workspaces
```

If two features genuinely share a base commit, that base commit should be pushed and merged first, then both workspaces rebase onto the new trunk via `jj stack-sync`.

### 3. Fetch and push are free from any workspace

`jj git fetch` and `jj git push` operate on shared state. Run them from whichever workspace is convenient — the result is visible everywhere.

### 4. `jj undo` affects shared state

`jj undo` reverses the last operation in the **shared** op log, regardless of which workspace ran it. Be careful undoing from one workspace if another is mid-task — you may undo their work too. Prefer `jj op log` first to see what you're about to reverse.

### 5. Checkpoint often when working in parallel

`jj claude-checkpoint "msg"` makes a clear save point. In parallel sessions, frequent checkpoints make `jj op log` readable and `jj op restore` precise.

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

Always `jj workspace forget` **before** `rm -rf` — otherwise jj keeps the workspace in its registry and `jj workspace list` shows a phantom entry.

---

## Why This Works

- **Safe experimentation**: `jj undo` / `jj op log` / `jj op restore` give a complete time machine over the shared op log.
- **Workspace isolation for files**: Each Claude edits files in its own directory — no merge conflicts at the filesystem level.
- **First-class conflicts**: jj records conflicts in the tree rather than blocking operations, so rebases and syncs from one workspace never interrupt work in another.
- **Checkpointing**: `jj claude-checkpoint` plus the shared op log give a clean record of what every Claude did and when.

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
