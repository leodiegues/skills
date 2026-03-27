# Skills

A collection of operational skills for AI coding agents (Claude Code, etc.). Each skill teaches an agent how to perform specific workflows correctly — version control, tooling, CI/CD, and more.

## Available Skills

| Skill | Description |
|-------|-------------|
| [jj-lazyjj](skills/jj-lazyjj/SKILL.md) | Jujutsu (jj) version control with LazyJJ aliases — stacks, bookmarks, sync, push, stacked PRs, Claude workspaces |
| [commit-msg](skills/commit-msg/SKILL.md) | Conventional commit message generation from diffs — type detection, scope derivation, monorepo support |
| [typescript-tsdoc](skills/typescript-tsdoc/SKILL.md) | TSDoc documentation conventions for TypeScript — what to document, tag usage, examples by context |

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
