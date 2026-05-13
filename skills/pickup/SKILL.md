---
name: pickup
description: Resume work from a handoff document written by the `handoff` skill. Use when the user says "pick up handoff", "resume from handoff", invokes /pickup, or otherwise references a handoff doc in ~/.claude/handoffs/.
argument-hint: "Slug or partial match of the handoff to resume"
---

Resume a paused session from a handoff doc in `~/.claude/handoffs/`. The value of this skill is the checklist — load suggested skills, verify referenced artifacts, re-confirm scope — not the file read itself.

## Steps

1. **Require an arg.** If the user invoked the skill with no slug or partial match, tell them an arg is required (e.g. `auth`, `vector-store`) and stop.

2. **Resolve the arg** against filename stems in `~/.claude/handoffs/` (case-insensitive substring match).
   - 0 matches → tell the user, list the 5 newest handoffs as hints, stop.
   - 1 match → use it.
   - 2+ matches → use `AskUserQuestion` with one option per match (newest first, max 4). Label = slug; description = first line of the doc + mtime.

3. **Read the chosen handoff** with the `Read` tool.

4. **Load every skill the doc names** via the `Skill` tool, in the order they appear. If a named skill doesn't exist, note it and continue.

5. **Verify referenced artifacts.** For each path/URL the doc references:
   - Local path → confirm it exists. Note any that are gone.
   - Git ref / commit / branch → confirm via `git log` / `git rev-parse`. Note any that are gone.
   - Don't fetch URLs — just list them for the user.

6. **Summarize to the user** in this shape, then stop:

   ```
   **Resuming**: <slug>
   **Goal**: <one-line goal from the doc>
   **Skills loaded**: <comma list, or "none">
   **Referenced artifacts**: <ok / missing breakdown>
   **Open items**: <bullets from the doc>

   Confirm before I act?
   ```

7. **Do not act** until the user confirms. After confirmation, defer to whatever workflow skill the handoff suggested (typically `pair-programming`).
