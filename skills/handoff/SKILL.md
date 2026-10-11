---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Handoffs live in the Obsidian vault.

## Where to save it

The path is **derived, never invented**. Run the bundled script (path relative to this skill's directory) with the session's repo as the working directory:

```bash
scripts/handoff-dir.sh
```

It prints the target directory and creates it if needed: `$VAULT/30-projects/<org>/<repo>/handoffs` inside a repo with a git remote (`<org>/<repo>` is derived from the remote), or `$VAULT/00-inbox` when there is no repo or remote.

The filename is `<date>-<slug>.md`, where `<date>` is today as `YYYY-MM-DD` (`date +%F`) and `<slug>` is a short, kebab-case description of the handoff topic — ≤6 words, derived from the session's actual focus (e.g. `fix-auth-redirect`, `vector-store-migration`). Full path: `<dir>/<date>-<slug>.md`, with `<dir>` as printed by the script. If that file already exists, pick a slightly different slug rather than overwriting it.

## Frontmatter (mandatory)

The vault requires YAML frontmatter on every doc. Emit this block as the **first thing in the file**, before any prose (write it inline — do not rely on Obsidian Templater):

```yaml
---
type: handoff
project: <org>/<repo>     # the derived slug; OMIT this line entirely for the inbox fallback
status: open
agent: claude-code
date: <YYYY-MM-DD>
---
```

Add an optional `package: <name>` line only when the work is clearly scoped to one sub-package of a monorepo.

## The body

After the frontmatter, summarise the conversation so a fresh agent can continue.

- Suggest the skills the next session should load, if any.
- Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.
- If the user passed arguments, treat them as a description of what the next session will focus on and tailor both the slug and the doc accordingly.
