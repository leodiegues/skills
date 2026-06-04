---
name: pickup
description: Resume work from a handoff document written by the `handoff` skill. Use when the user says "pick up handoff", "resume from handoff", invokes /pickup, or otherwise references a handoff doc in the Obsidian vault (or the legacy ~/.claude/handoffs/).
argument-hint: "Slug or partial match of the handoff to resume"
---

Resume a paused session from a handoff doc in the Obsidian vault (with a fallback to the legacy `~/.claude/handoffs/`). The value of this skill is the checklist — load suggested skills, verify referenced artifacts, re-confirm scope — not the file read itself.

## Steps

1. **Require an arg.** If the user invoked the skill with no slug or partial match, tell them an arg is required (e.g. `auth`, `vector-store`) and stop.

2. **Resolve the arg** to a handoff file. Collect candidate `.md` files from these roots, then match the arg as a case-insensitive substring of the filename stem (stems are now `<YYYY-MM-DD>-<slug>`; matching the slug portion still works):

   ```bash
   VAULT="${OBSIDIAN_VAULT:-$HOME/vault}"
   slug=$(git remote get-url origin 2>/dev/null | sed -E 's#\.git$##' \
          | awk -F'[/:]' '{print $(NF-1)"/"$NF}')   # current repo, if any
   { find "$VAULT/30-projects" -type f -path '*/handoffs/*.md' 2>/dev/null   # all project handoffs
     find "$VAULT/00-inbox" "$HOME/.claude/handoffs" -maxdepth 1 \           # inbox + legacy
          -type f -name '*.md' 2>/dev/null
   } | xargs ls -t 2>/dev/null                                              # newest first
   ```

   Use `find`, **not** a `*.md` glob: a missing/empty root (e.g. the current repo has no `handoffs/` yet) makes a glob a hard error in zsh and aborts the command. On an ambiguous match, prefer the file under `$VAULT/30-projects/$slug/handoffs/`. Then:
   - 0 matches → tell the user, list the 5 newest handoffs as hints, stop.
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

7. **Do not act** until the user confirms. After confirmation, defer to whatever workflow skill the handoff suggested (typically `pair-programming`).
