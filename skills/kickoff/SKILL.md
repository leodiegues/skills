---
name: kickoff
description: Send finished planning to execution — create a worktree for a work item (Linear issue or project, GitLab/GitHub issue, plan file, or the plan agreed in this session) and start a new agent session there with a kickoff prompt: a new T3 Code thread when this session runs in T3 Code, or a child herdr workspace when it runs in a herdr pane. Use when the user invokes /kickoff after planning.
argument-hint: "[issue, project, or plan reference]"
compatibility: Requires `jq` and a session running either in T3 Code (its `t3` CLI) or inside a herdr pane (https://github.com/herdrdev/herdr) with the `wt` CLI (https://worktrunk.dev)
disable-model-invocation: true
---

Hand the work planned in this session to a fresh agent session that runs in its own worktree: a new T3 Code thread, or a child herdr workspace grouped under this one — whichever host this session runs in. This session stays the planning session: it does not move, and it does not start implementing.

## 1. Resolve the work item

Use the argument if there is one, otherwise the conversation: an issue id or URL (Linear, GitLab, GitHub), a Linear project, a plan file, or the plan just agreed here. Fetch its title and body with whatever this session has (a tracker MCP server, `glab`, `gh`) so the branch name and kickoff are grounded in the real item.

If nothing identifies the work, or two candidates fit, ask. A worktree on the wrong item costs more to undo than one question.

**Several issues** (a project, an epic, a plan with several parts): the work item is the whole set, not its first unblocked issue. Read how the issues depend on each other (the tracker's blocker relations, what the plan says about order) and pick the layout:

- **Fan-out** — the issues can be built at the same time, even if they must merge in order. One worktree and one session per issue: run steps 2–4 once per issue.
- **Chain** — an issue cannot start until the one before it is merged. One worktree and one session for the whole set, which builds the issues in order.

List the issues and ask once before launching, with the layout the dependencies point to as the recommended option. If the set fits neither (some parallel, some chained), say so in the question and let the user split it.

## 2. Pick the branch

Use the tracker's own name when it offers one (Linear's `branchName`, GitLab's `<iid>-<slug>`). Otherwise write a short one consistent with existing branches (`git branch -a`).

A chain's worktree starts on its first issue's branch; the session creates each later issue's branch in that same worktree.

The worktree is based on the default branch. If the plan depends on commits that only exist on the current branch, ask before passing `--base @`. In T3 Code the base must be pushed: the CLI branches from `origin`, so for an unpushed base start the thread with the `t3_thread_launch` tool instead (`workspaceStrategy: {type: "worktree", baseRef, branch, startFromOrigin: false}`).

## 3. Build the kickoff prompt

The kickoff is the first message the new session receives, and the only context it gets from here. Pick the first that fits; ask when more than one does or none does:

1. **A skill owns implementing this kind of item** — a project or team skill in this session's skill list whose description covers it (an "implement this issue" skill, say). The kickoff is that slash command with the item reference.
2. **The plan lives in this conversation** — run `/handoff` here first, then the kickoff is `/pickup <slug>`.
3. **The plan already lives somewhere durable** — a plan file, or an issue that is the full spec. The kickoff names the path or URL and says to execute it.

Keep it short and point at artifacts rather than pasting them; the new session can read files and fetch issues itself.

**A fan-out whose PRs must merge in order** says so in each kickoff: name the issue whose PR merges first, and tell the session to stop before its own merge until that one has landed.

**A chain's kickoff also carries the run order**, because the session outlives its first issue. Wrap the first issue's kickoff:

```text
You run <project or epic> end to end in this worktree: <url>

The issues are a serial chain: <A> → <B> → <C>. Each issue is one PR on its own branch, built in this worktree. Create no other worktree.

<kickoff for A>. When its PR is open, report it and stop. When I say it is merged, confirm the issue is Done in the tracker, then start the next issue here. Never start an issue whose blockers are not Done.
```

Add a stop-and-ask line for anything a later issue needs that does not exist yet (a branch to be pushed, a decision still open).

## 4. Launch

Pipe the kickoff into the bundled script (path relative to this skill's directory), with the repo as the working directory:

```bash
scripts/launch.sh <branch> --label "<issue id + short title>" <<'EOF'
<kickoff prompt>
EOF
```

Options: `--base <ref>` for a non-default base, `--reuse` to enter a branch that already exists. Label a chain with the project or epic, not its first issue.

It picks the provider from the environment (T3 Code first, then herdr) and checks its requirements before creating anything. On success it prints one JSON line with `provider` and `branch`, plus:

- **t3** — starts a thread in this thread's project on a new worktree (`t3 thread start --worktree <base> --branch <branch>`) with the kickoff as its first message. Adds `thread_id`, `link`, `path`. The base defaults to the default branch.
- **herdr** — creates the worktree (`wt`), opens it as a workspace grouped under the current one, starts Claude in that workspace's root pane, submits the kickoff, and moves focus to the new workspace. Adds `path`, `workspace_id`, `pane_id`, `agent`.

On failure it prints what was left in place. Read that before retrying — a second blind run stacks a second worktree or workspace on the first:

- **Branch already exists** → ask whether to reuse it, then rerun with `--reuse`. In T3 Code the script refuses `--reuse`; instead start the thread with the `t3_thread_launch` tool (`workspaceStrategy: {type: "existing_worktree", worktreePath}` if the branch has a worktree) and the kickoff as `message`.
- **`agent_not_ready`** (herdr) → Claude started but is waiting on a dialog (usually folder trust) in the new workspace. Tell the user to answer it there; once the agent is idle, submit the kickoff with `herdr agent prompt <agent> "<kickoff>"` and `herdr workspace focus <workspace_id>`.
- **A missing requirement** → relay the script's message and stop.

## 5. Report

Give the branch and worktree path, plus the thread `link` (t3) or the workspace id and agent name (herdr). Don't wait on the new session or read its output unless asked; it is the user's to drive now.

Everything created persists after this session. Remove it only when asked: in herdr, `herdr worktree remove --workspace <workspace_id>` closes the workspace and deletes the checkout; in T3 Code, archive the thread and `git worktree remove <path>`. The branch stays.
