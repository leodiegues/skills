# Skills

A collection of operational skills for AI coding agents (Claude Code, etc.). Each skill teaches an agent how to perform specific workflows correctly — session handoff, note filing, model delegation, and more.

## Available Skills

| Skill | Description |
|-------|-------------|
| [delegate](skills/delegate/SKILL.md) | Model orchestration for Fable 5 sessions — plan and judge yourself, hand exploration, implementation, and deeper code review to Opus 5 / Sonnet 5 subagents |
| [kickoff](skills/kickoff/SKILL.md) | Send a finished plan to execution — creates a [worktrunk](https://worktrunk.dev) worktree for the work item (Linear, GitLab, GitHub, or a plan file), opens it in the host the session runs in (a T3 Code thread, a child [herdr](https://github.com/herdrdev/herdr) workspace, a Rex tab, or — in the Herdr app — a separate space or a child session nested under this one), and starts an agent session there with a kickoff prompt |
| [teardown](skills/teardown/SKILL.md) | Tear down finished work — the inverse of `kickoff`: removes the session's worktree (or a nested Herdr child builder's worktree from its parent session, or switches the main checkout off its feature branch), deletes the branch if merged, and closes the session's [herdr](https://github.com/herdrdev/herdr) workspace, Rex tab, or Herdr app space/child terminal. Refuses on the default branch |
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

The plugin depends on the [worktrunk](https://github.com/max-sixty/worktrunk) plugin, so add its marketplace first: `/plugin marketplace add max-sixty/worktrunk`. The `kickoff` skill also needs `jq` and a session started inside T3 Code, herdr, Rex, or the Herdr app (herdr-core), with that host's CLI (`t3`, `herdr`, `rex`, or `hc` and `herdr-app`) and, outside T3 Code, `wt` on `PATH`; it checks for them before doing anything.

### Mermaid rendering mod

The plugin also ships a Claude Code mod (`hooks/`) that draws ` ```mermaid ` blocks in Claude's replies as diagrams: an inline image in kitty, Ghostty and iTerm2 3.5+ (fullscreen), SVG in the desktop app, VS Code and mobile. It renders with [mermaid-rs-renderer](https://github.com/1jehuang/mermaid-rs-renderer) (`cargo install mermaid-rs-renderer`, provides `mmdr`); without `mmdr`, or on a diagram it can't parse, the reply shows the code block as usual. In other terminals that support kitty graphics but that Claude Code doesn't recognise (e.g. Rex), add `"CLAUDE_CODE_FORCE_TERMINAL_IMAGES": "1"` to `env` in `~/.claude/settings.json`.

It also follows the [Agent Plugins](https://agent-plugins.org/) format (root `plugin.json` + `skills/`), so any compatible client can load the repository directory as a plugin.

Skills are detected and activated automatically based on their `description` trigger conditions.

## Contributing

1. Create a new directory under `skills/` with your skill name
2. Add a `SKILL.md` with proper frontmatter — the `description` field controls when the skill activates, so be explicit about triggers and anti-triggers
3. Put detailed reference material in `references/` to keep the main skill focused
4. Skills should be operational (tell the agent what to *do*), not educational

## License

[MIT](LICENSE)
