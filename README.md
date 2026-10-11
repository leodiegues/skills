# Skills

A collection of operational skills for AI coding agents (Claude Code, etc.). Each skill teaches an agent how to perform specific workflows correctly — session handoff, note filing, model delegation, and more.

## Available Skills

| Skill | Description |
|-------|-------------|
| [delegate](skills/delegate/SKILL.md) | Model orchestration for Fable 5 sessions — plan and judge yourself, hand exploration, implementation, and deeper code review to Opus 5 / Sonnet 5 subagents |
| [kickoff](skills/kickoff/SKILL.md) | Send a finished plan to execution — creates a [worktrunk](https://worktrunk.dev) worktree for the work item (Linear, GitLab, GitHub, or a plan file), opens it as a child [herdr](https://github.com/herdrdev/herdr) workspace, and starts a Claude session there with a kickoff prompt |
| [handoff](skills/handoff/SKILL.md) | Compact the current conversation into a handoff document so a fresh agent or session can pick up the work |
| [pickup](skills/pickup/SKILL.md) | Resume work from a handoff document — the inverse of `handoff`, restores context from the Obsidian vault (with a legacy `~/.claude/handoffs/` fallback) |
| [obsidian-vault](skills/obsidian-vault/SKILL.md) | File, clip, and find notes in the personal Obsidian vault from any session — routes by zone, derives `<org>/<repo>` project paths, matches live frontmatter, guards sacred zones; defers handoff/pickup |

> The `handoff` skill is heavily inspired by (and nearly identical to) [mattpocock/skills `handoff`](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md).
>
> The `obsidian-vault` skill is adapted (with substantial enhancements) from [mattpocock/skills `obsidian-vault`](https://github.com/mattpocock/skills/blob/main/skills/personal/obsidian-vault/SKILL.md) — re-targeted to this vault's lifecycle-folder contract, audience routing, derived paths, and live-frontmatter matching.

## How Skills Work

Skills are loaded by AI coding agents at runtime. When a skill's trigger conditions match (e.g., you ask to hand off a session), the agent reads the skill and follows its instructions.

Each skill lives in `skills/<name>/` and contains:

- **`SKILL.md`** — The main skill with YAML frontmatter (`name`, `description`) and operational instructions
- **`references/`** — Optional supporting docs (command references, workflow guides) that the skill loads on demand
- **`scripts/`** — Optional executable scripts the skill runs instead of inlining shell

### Installing Skills

This repository is a plugin. In Claude Code, add it as a marketplace and install:

```
/plugin marketplace add leodiegues/skills
/plugin install leodiegues-skills@leodiegues
```

The plugin depends on the [worktrunk](https://github.com/max-sixty/worktrunk) plugin, so add its marketplace first: `/plugin marketplace add max-sixty/worktrunk`. The `kickoff` skill also needs the `wt`, `herdr`, and `jq` binaries on `PATH` and a session started inside herdr; it checks for them before doing anything.

It also follows the [Agent Plugins](https://agent-plugins.org/) format (root `plugin.json` + `skills/`), so any compatible client can load the repository directory as a plugin.

Skills are detected and activated automatically based on their `description` trigger conditions.

## Contributing

1. Create a new directory under `skills/` with your skill name
2. Add a `SKILL.md` with proper frontmatter — the `description` field controls when the skill activates, so be explicit about triggers and anti-triggers
3. Put detailed reference material in `references/` to keep the main skill focused
4. Skills should be operational (tell the agent what to *do*), not educational

## License

[MIT](LICENSE)
