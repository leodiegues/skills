# CLAUDE.md

## Plugin Packaging

The repo root is one plugin, `leodiegues-skills`, published in two formats:

- `plugin.json` — [Agent Plugins](https://agent-plugins.org/) manifest
- `.claude-plugin/plugin.json` — Claude Code manifest; keep it identical to the root `plugin.json`
- `.claude-plugin/marketplace.json` — Claude Code marketplace `leodiegues`, listing this repo (`"source": "./"`)

After changing manifests or skills, run `claude plugin validate .`. Don't edit `version` by hand — `/release` (`.claude/skills/release/`, a repo-maintenance skill that is not part of the plugin) sets it in both manifests, tags `vX.Y.Z`, and publishes from `main`. The validator warns that this root `CLAUDE.md` is not shipped as plugin context — expected, it is repo guidance only.

## Writing Skills

- Scripts live in `skills/<name>/scripts/` (chmod +x) and are self-contained per skill — never reference another skill's directory. `SKILL.md` calls them by path relative to the skill directory (`scripts/foo.sh`).
- The `description` field is critical — it controls when Claude Code activates the skill. Be explicit about triggers and anti-triggers.
- Reference files in `references/` hold detailed lookup tables, command references, or workflow guides that the main skill tells Claude to read on demand (keeps the main skill focused).
- Skills should be operational (tell Claude what to DO), not educational (don't explain concepts for the user to read).
