---
name: daily-update
description: Use when the user wants to write a daily standup or end-of-day update — "daily update", "standup", "EOD post", "what did I do today". Produces a Slack-ready message covering today's work, tomorrow's plans, and open PRs.
argument-hint: "Optional rough notes to seed the update"
---

# Daily Update

Produce a Slack-ready daily standup in three sections: **today's update**, **tomorrow's plans**, **pending stuff** (open PRs). The output must paste into Slack with bullets and links intact.

## Workflow

1. **Gather today's work (auto).** In the current repo:
   - `git log --author="$(git config user.email)" --since=midnight --pretty=format:'%s'`
   - Merged PRs today: `gh pr list --state merged --author=@me --json title,url,mergedAt` then keep ones merged today.
2. **Ask PR scope** with `AskUserQuestion`: all repos vs this repo only.
   - all repos → `gh search prs --author=@me --state=open --json title,url,repository`
   - this repo → `gh pr list --author=@me --state open --json title,url`
3. **Draft "today's update"** from commits + merged PRs. Group related work, dedupe, and rewrite in plain human phrasing — never dump raw commit subjects.
4. **Ask what's missing** with `AskUserQuestion` (free-text via the "Other" field): infra/ops/discussion work not in git, plus anything to cut. If the user passed seed notes as args, fold them in first.
5. **Draft "tomorrow's plans"** from unfinished threads (open PRs, WIP, today's loose ends) plus the user's input.
6. **Format and deliver** (rules below). Print the message in chat AND copy it to the clipboard: pipe the final text through `pbcopy`.

## Slack format (exact)

- Section headers are plain lines ending in `:` — `today's update:`, `tomorrow's plans:`, `pending stuff:`. No greeting prefix.
- Bullets are the literal `• ` character (U+2022), NOT markdown `-` or `*` — markdown bullets get stripped on paste.
- Blank line between sections. No blank line between bullets.
- Pending-stuff lines: `• <friendly label>: <raw url>`. Use a raw URL so Slack auto-links it. Default the label to the PR title; let the user rename.
- No markdown bold (`**`). Keep it plain.

## Example output

```
today's update:

• Served our staging Inngest server with dedicated Redis + Postgres
• Switched Railway and Vercel vars so the self-hosted Inngest works
• Drafted the Notion integration shape for further discussion

tomorrow's plans:

• Finish the Clerk webhook on staging for full Inngest-cloud parity
• Sweep for more self-hosted Inngest bugs and integration issues

pending stuff:

• Slack + Comms MCP PR: https://github.com/ever-day/everday-monorepo/pull/125
• Oxlint replacing ESLint (not a priority): https://github.com/ever-day/everday-monorepo/pull/118
```

## Common mistakes

- Using `-` or `*` bullets → stripped on paste. Always `•`.
- Pasting raw commit subjects instead of human-readable summaries.
- Markdown links `[label](url)` → Slack shows literal brackets. Use raw URLs.
- Skipping the "what's missing" step → infra and discussion work gets dropped.
