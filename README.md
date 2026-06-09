# Skills

A collection of operational skills for AI coding agents (Claude Code, etc.). Each skill teaches an agent how to perform specific workflows correctly — version control, tooling, CI/CD, and more.

## Available Skills

| Skill | Description |
|-------|-------------|
| [jj-lazyjj](skills/jj-lazyjj/SKILL.md) | Jujutsu (jj) version control with LazyJJ aliases — stacks, bookmarks, sync, push, stacked PRs, Claude workspaces |
| [commit-msg](skills/commit-msg/SKILL.md) | Conventional commit message generation from diffs — type detection, scope derivation, monorepo support |
| [typescript-tsdoc](skills/typescript-tsdoc/SKILL.md) | TSDoc documentation conventions for TypeScript — what to document, tag usage, examples by context |
| [python-testing](skills/python-testing/SKILL.md) | Python testing with pytest — fixtures, mocking, async tests, coverage, and modern testing ecosystem |
| [python-docstrings](skills/python-docstrings/SKILL.md) | Python docstring generation using Google convention — add, fix, or convert docstrings for modules, classes, and functions |
| [pair-programming](skills/pair-programming/SKILL.md) | Approval-gated pair programming workflow — plan-first, AskUserQuestion clarifications, visuals required |
| [handoff](skills/handoff/SKILL.md) | Compact the current conversation into a handoff document so a fresh agent or session can pick up the work |
| [pickup](skills/pickup/SKILL.md) | Resume work from a handoff document — the inverse of `handoff`, restores context from the Obsidian vault (with a legacy `~/.claude/handoffs/` fallback) |
| [codebase-explorer](skills/codebase-explorer/SKILL.md) | Map-and-quiz codebase exploration for unfamiliar repos — 4-phase workflow (recon → map → quiz → deepen) producing an HTML artifact with Mermaid diagrams and active-recall quiz; explicitly NOT for refactoring or feature work |
| [daily-update](skills/daily-update/SKILL.md) | Slack-ready daily standup generator — auto-drafts today's work from git/PRs, asks what's missing, formats today's update / tomorrow's plans / open PRs with paste-safe `•` bullets |
| [obsidian-vault](skills/obsidian-vault/SKILL.md) | File, clip, and find notes in the personal Obsidian vault from any session — routes by zone, derives `<org>/<repo>` project paths, matches live frontmatter, guards sacred zones; defers handoff/pickup/daily-update |

> The `handoff` skill is heavily inspired by (and nearly identical to) [mattpocock/skills `handoff`](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md).
>
> The `obsidian-vault` skill is adapted (with substantial enhancements) from [mattpocock/skills `obsidian-vault`](https://github.com/mattpocock/skills/blob/main/skills/personal/obsidian-vault/SKILL.md) — re-targeted to this vault's lifecycle-folder contract, audience routing, derived paths, and live-frontmatter matching.

## How Skills Work

Skills are loaded by AI coding agents at runtime. When a skill's trigger conditions match (e.g., a `.jj` directory is detected), the agent reads the skill and follows its instructions.

Each skill lives in `skills/<name>/` and contains:

- **`SKILL.md`** — The main skill with YAML frontmatter (`name`, `description`) and operational instructions
- **`references/`** — Optional supporting docs (command references, workflow guides) that the skill loads on demand

### Installing Skills

Add this repository's skills to your Claude Code configuration. Skills are detected and activated automatically based on their `description` trigger conditions.

## Contributing

1. Create a new directory under `skills/` with your skill name
2. Add a `SKILL.md` with proper frontmatter — the `description` field controls when the skill activates, so be explicit about triggers and anti-triggers
3. Put detailed reference material in `references/` to keep the main skill focused
4. Skills should be operational (tell the agent what to *do*), not educational

## License

[MIT](LICENSE)
