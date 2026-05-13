---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

Save it to `~/.claude/handoffs/<slug>.md` where `<slug>` is a short, kebab-case description of the handoff topic — ≤6 words, derived from the session's actual focus (e.g. `port-handoff-skill`, `fix-auth-redirect`, `vector-store-migration`). Run `mkdir -p ~/.claude/handoffs` before writing. If a file at that path already exists, pick a slightly different slug rather than overwriting it.

Suggest the skills to be used, if any, by the next session.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor both the slug and the doc accordingly.
