---
name: obsidian-vault
description: Use when the user wants to save, file, clip, capture, find, recall, or organize a note in their personal Obsidian vault from any session — usually a code repo, outside the vault. Triggers like "save this to my vault", "clip this article/link", "log an idea", "add to my inbox", "find/recall my note about X", "where does this doc go?". Keywords - Obsidian, vault, note, clipping, source, idea, inbox, frontmatter, MOC, wikilink. Do NOT use for pausing/resuming a session (use the handoff / pickup skills) or daily standups (use daily-update).
---

# Obsidian Vault

Operationalizes the user's vault contract from **any** session, so notes get filed
correctly even when you're in a code repo and the vault's own `AGENTS.md` / `CLAUDE.md`
are not loaded.

**Canonical source of truth:** `$VAULT/AGENTS.md` (see "Locate the vault"). This skill
inlines the fast path; read `AGENTS.md` for anything not covered here. When this skill and
a **live note** disagree, the live note wins (the contract docs have drifted — see Frontmatter).

## Locate the vault

```bash
VAULT="${OBSIDIAN_VAULT:-$HOME/vault}"   # the env var is often unset; the fallback is load-bearing
```

Never hardcode the path. If `$VAULT` doesn't exist, ask — don't guess.

## When to defer (don't collide)

| The user wants… | Use instead |
|---|---|
| to pause / hand off a session | `handoff` skill (it owns handoff files) |
| to resume from a handoff | `pickup` skill |
| a daily standup / EOD update | `daily-update` skill |
| a spec / ADR that **drives the build** | the **repo** under `docs/specs/` — NOT the vault |

This skill handles the rest: clippings, ideas, inbox capture, drafts, and finding notes.

## Quick reference — where you may write

| Writable | `00-inbox/` · `30-projects/<org>/<repo>/drafts/` · `40-sources/` · `60-ideas/` (a repo's `handoffs/` is writable too, but **owned by the `handoff` skill** — defer) |
|---|---|
| **Sacred (ask first)** | `20-notes/` · `10-maps/` · `50-journal/` · `_templates/` · `_meta/` · `.obsidian/` |

**Never edit `20-notes/` directly** — write to `00-inbox/` or a project `drafts/`; the human
promotes durable insight. Never mass-move or mass-rename without explicit confirmation.

## Where a doc goes

Route **by kind first**, then by audience + repo-tie:

```
web clipping / external source ─▶ 40-sources/
daily log entry                ─▶ 50-journal/   (sacred — ask first)
idea / product seed            ─▶ 60-ideas/

everything else (draft, note):
   repo-tied?  ──YES─▶ 30-projects/<org>/<repo>/drafts/
   standalone? ──────▶ 00-inbox/
```

**Draft vs. handoff** (the easiest misfile): resumable working state — next steps, open threads,
where to pick up — → defer to the `handoff` skill. A finished, human-facing summary → a `draft`.

## Deriving the project path

`<org>/<repo>` is **derived from the target repo's git remote** — never invented.

```bash
# Run INSIDE the target repo. CWD TRAP: deriving from an unrelated cwd gives the wrong slug.
slug=$(git -C <repo-path> remote get-url origin | sed -E 's#\.git$##' \
  | awk -F'[/:]' '{print $(NF-1)"/"$NF}')
# git@github.com:ever-day/everday-monorepo.git  →  ever-day/everday-monorepo
```

- Stop at `<org>/<repo>` (identity nesting). Never mirror `src/packages/...` into the vault.
- Monorepo sub-package → a `package:` frontmatter field, **not** a folder.
- No remote → fall back to `30-projects/_local/<repo>/`.

**Governance:** personal projects opt in freely. Employer/client repos (e.g. Folha) stay out
of the vault unless cleared — check the target repo's `CLAUDE.md` for the opt-in block first.

## Frontmatter — match the live sibling, don't trust the template

The frontmatter blocks in `AGENTS.md` are *intent* and have **drifted** from the live vault
(handoffs use `agent:`, drafts use `author:`, `40-sources/` uses `created:` not `clipped:` and an
`author:` wikilink list). So clone a **same-kind** sibling's field set, not the template:

```bash
# Read the newest sibling OF THE SAME KIND and copy its exact frontmatter field set:
ls -t "$VAULT/<zone>"/*.md | head   # 40-sources/ is heterogeneous — an article clip and a GitHub
                                    # clip carry different fields; pick a like-for-like one to mirror
```

Starting points (override with what the sibling shows):

```yaml
# 30-projects/.../drafts/        # 40-sources/                  # 60-ideas/
type: draft                      type: reference               type: idea
project: <org>/<repo>            title: "<title>"              status: seed   # seed|exploring|promoted|dropped
status: open                     source: "<url>"   # identity  created: <YYYY-MM-DD>
author: claude-code              created: <YYYY-MM-DD>          tags: [...]
date: <YYYY-MM-DD>               tags: [...]
tags: [...]
```

**Tags:** lowercase `kebab-case`; **reuse an existing spelling** — Dataview is case-sensitive, so
`rag` ≠ `RAG`. If no existing tag fits, propose the new one to the user before writing it.

**Templates:** only `60-ideas/` and sidequests have a Templater template; drafts / notes / sources
do **not** — always clone a sibling. You're writing from outside Obsidian, so emit the block by hand.

## Naming

- **Events** (draft) → date-first: `<YYYY-MM-DD>-<kebab-slug>.md`
- **Logs** (`50-journal/`) → date only: `<YYYY-MM-DD>.md`
- **Entities** (`40-sources/`, `60-ideas/`) → title-first: `<Title>.md` — you retrieve these by
  *what they are*; the date lives in frontmatter, and for a source `source:` (the URL) is the identity key (dedupe on it).

## Finding notes

```bash
VAULT="${OBSIDIAN_VAULT:-$HOME/vault}"; [ -d "$VAULT" ] || ask   # don't search a vault that isn't there
# by filename
find "$VAULT" -name '*.md' -not -path '*/.obsidian/*' -iname '*keyword*'
# by content — for a multi-word recall, INTERSECT the terms (don't grep one and wade through noise)
grep -rIl -i 'supervisor' "$VAULT" --include='*.md' --exclude-dir='.obsidian' | xargs grep -li 'refactor'
# backlinks to a note
grep -rIl '\[\[Note Title\]\]' "$VAULT" --include='*.md'
```

Disambiguate by **zone** (a `50-journal/` hit is a daily log, a `00-inbox/` hit is unfiled, a
`30-projects/.../` hit is the project note; **deprioritize `_meta/` and `_templates/` hits — they're
*about* the vault, not content**) and by frontmatter (`status`, `created`/`date`).

**Verify a hit is a real note**, not a code-fence example, a passing mention, or a `[[wikilink]]`
target: confirm the file exists by name and the match is body content before citing it. If the
recalled title matches only mentions/examples, the note likely **was never written** — say so and
offer the nearest real notes; never invent a path. For a clipping, the `source:` URL is the
identity key, but the same article can live at multiple URLs — grep the slug and confirm, don't
trust an exact-URL match.

Navigation hubs (MOCs) live in `10-maps/`. Surface open handoffs across projects with Dataview:

````md
```dataview
TABLE project, package, status, date
FROM "30-projects"
WHERE type = "handoff" AND status = "open"
SORT date DESC
```
````

If 2+ notes plausibly match, surface the finalists (path + date + first heading) and ask — don't guess.

## Red flags — STOP

- About to hardcode `/Users/.../vault` → use `${OBSIDIAN_VAULT:-$HOME/vault}`.
- About to copy the AGENTS.md frontmatter block verbatim → read the newest **same-kind** sibling first.
- About to run `git remote` in your current cwd for a different repo → use `git -C <repo-path>`.
- About to write into `20-notes/`, `10-maps/`, or `50-journal/` → that's sacred; write to inbox/drafts or ask.
- About to coin a new tag → reuse an existing spelling, or propose the new tag to the user first.
- About to cite a grep hit as a note → confirm it's a real file with body content, not an example.
- About to file an employer/client repo's doc → confirm it's opted in (if unsure, ask).
