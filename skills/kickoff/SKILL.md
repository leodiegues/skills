---
name: kickoff
description: Send finished planning to execution — create a worktrunk worktree for a work item (Linear issue or project, GitLab/GitHub issue, plan file, or the plan agreed in this session), open it as a child herdr workspace of the current one, and start a Claude session there with a kickoff prompt. Use when the user invokes /kickoff after planning in the parent herdr workspace.
argument-hint: "[issue, project, or plan reference]"
compatibility: Requires the `wt` CLI (https://worktrunk.dev), `jq`, and a session running inside a herdr pane (https://github.com/herdrdev/herdr)
disable-model-invocation: true
---

Hand the work planned in this session to a fresh Claude session that runs in its own worktree, inside a child herdr workspace grouped under this one. This session stays the planning session: it does not move, and it does not start implementing.

## 1. Resolve the work item

Use the argument if there is one, otherwise the conversation: an issue id or URL (Linear, GitLab, GitHub), a Linear project, a plan file, or the plan just agreed here. Fetch its title and body with whatever this session has (a tracker MCP server, `glab`, `gh`) so the branch name and kickoff are grounded in the real item.

If nothing identifies the work, or two candidates fit, ask. A worktree on the wrong item costs more to undo than one question.

**Several issues** (a project, an epic, a plan with independent parts): list them and ask whether they share one worktree or get one each. One each means running step 4 once per issue.

## 2. Pick the branch

Use the tracker's own name when it offers one (Linear's `branchName`, GitLab's `<iid>-<slug>`). Otherwise write a short one consistent with existing branches (`wt list`).

The worktree is based on the default branch. If the plan depends on commits that only exist on the current branch, ask before passing `--base @`.

## 3. Build the kickoff prompt

The kickoff is the first message the new session receives, and the only context it gets from here. Pick the first that fits; ask when more than one does or none does:

1. **A skill owns implementing this kind of item** — a project or team skill in this session's skill list whose description covers it (an "implement this issue" skill, say). The kickoff is that slash command with the item reference.
2. **The plan lives in this conversation** — run `/handoff` here first, then the kickoff is `/pickup <slug>`.
3. **The plan already lives somewhere durable** — a plan file, or an issue that is the full spec. The kickoff names the path or URL and says to execute it.

Keep it short and point at artifacts rather than pasting them; the new session can read files and fetch issues itself.

## 4. Launch

Pipe the kickoff into the bundled script (path relative to this skill's directory), with the repo as the working directory:

```bash
scripts/launch.sh <branch> --label "<issue id + short title>" <<'EOF'
<kickoff prompt>
EOF
```

Options: `--base <ref>` for a non-default base, `--reuse` to enter a branch that already exists.

It checks its requirements before creating anything, then creates the worktree (`wt`), opens it as a workspace grouped under the current one, starts Claude in that workspace's root pane, submits the kickoff, and moves focus to the new workspace. On success it prints one JSON line: `branch`, `path`, `workspace_id`, `pane_id`, `agent`.

On failure it prints what was left in place. Read that before retrying — a second blind run stacks a second worktree or workspace on the first:

- **Branch already exists** → ask whether to reuse it, then rerun with `--reuse`.
- **`agent_not_ready`** → Claude started but is waiting on a dialog (usually folder trust) in the new workspace. Tell the user to answer it there; once the agent is idle, submit the kickoff with `herdr agent prompt <agent> "<kickoff>"` and `herdr workspace focus <workspace_id>`.
- **A missing requirement** → relay the script's message and stop.

## 5. Report

Give the branch, worktree path, workspace id, and agent name. Don't wait on the new session or read its output unless asked; it is the user's to drive now.

Everything created persists after this session. Remove it only when asked: `herdr worktree remove --workspace <workspace_id>` closes the workspace and deletes the checkout; the branch stays.
