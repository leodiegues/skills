---
name: pickup
description: Resume work from a handoff document written by the `handoff` skill. Use when the user says "pick up handoff", "resume from handoff", invokes /pickup, or otherwise references a handoff doc in the Obsidian vault (or the legacy ~/.claude/handoffs/).
argument-hint: "Slug or partial match of the handoff to resume"
disable-model-invocation: true
---

Resume a paused session from a handoff doc in the Obsidian vault (with a fallback to the legacy `~/.claude/handoffs/`). The value of this skill is the checklist — load suggested skills, verify referenced artifacts, re-confirm scope — not the file read itself.

## Steps

1. **Require an arg.** If the user invoked the skill with no slug or partial match, tell them an arg is required (e.g. `auth`, `vector-store`) and stop.

2. **Resolve the arg** to a handoff file. Run the bundled script (path relative to this skill's directory) with the arg:

   ```bash
   scripts/find-handoffs.sh "<arg>"
   ```

   It prints, newest first, every handoff whose filename stem contains the arg as a case-insensitive substring (stems are `<YYYY-MM-DD>-<slug>`; matching the slug portion works). It searches all project handoffs (`$VAULT/30-projects/<org>/<repo>/handoffs/`), the inbox (`$VAULT/00-inbox/`), and the legacy `~/.claude/handoffs/`. With no arg it lists them all. On an ambiguous match, prefer the file under the current repo's `30-projects/<org>/<repo>/handoffs/`. Then:
   - 0 matches → tell the user, list the 5 newest handoffs as hints (the script with no arg), stop.
   - 1 match → use it.
   - 2+ matches → use `AskUserQuestion` with one option per match (newest first, max 4). Label = filename stem; description = goal line (see step 6) + mtime.

3. **Read the chosen handoff** with the `Read` tool.

4. **Load every skill the doc names** via the `Skill` tool, in the order they appear. If a named skill doesn't exist, note it and continue.

5. **Verify referenced artifacts.** For each path/URL the doc references:
   - Local path → confirm it exists. Note any that are gone.
   - Git ref / commit / branch → confirm via `git log` / `git rev-parse`. Note any that are gone.
   - Don't fetch URLs — just list them for the user.

6. **Summarize to the user** in this shape, then stop. Vault handoffs open with a YAML frontmatter block (`---` … `---`) — skip it when reading the goal: the goal is the first heading or body line *after* the closing `---`, never the `---` fence. Surface `project` and `status` from the frontmatter. Legacy `~/.claude/handoffs/` docs have no frontmatter — there, fall back to the first line as the goal and show `—` for project/status.

   ```
   **Resuming**: <filename stem>
   **Project**: <frontmatter project, or "—">
   **Status**: <frontmatter status, or "—">
   **Goal**: <first heading / body line after the frontmatter>
   **Skills loaded**: <comma list, or "none">
   **Referenced artifacts**: <ok / missing breakdown>
   **Open items**: <bullets from the doc>

   Confirm before I act?
   ```

7. **Do not act** until the user confirms. After confirmation, defer to whatever workflow skill the handoff suggested.
