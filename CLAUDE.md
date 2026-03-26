# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A collection of Claude Code skills (AI operational guides). Each skill teaches Claude Code how to perform specific workflows correctly.

## Version Control

This is a jj (Jujutsu) colocated repo. **Never use raw git commands.** Use `jj` for all version control operations. See the `jj-lazyjj` skill in this repo for the full reference.

## Skill Structure

Each skill lives in `skills/<skill-name>/` with this layout:

```
skills/<skill-name>/
  SKILL.md              # Main skill file with YAML frontmatter (name, description) and operational content
  references/           # Optional supporting reference docs
    *.md
```

The YAML frontmatter in `SKILL.md` has three fields:
- `name`: skill identifier (used for invocation)
- `description`: trigger description — tells Claude Code WHEN to activate the skill and what it covers
- The body contains the operational instructions Claude Code follows when the skill is active

## Writing Skills

- The `description` field is critical — it controls when Claude Code activates the skill. Be explicit about triggers and anti-triggers.
- Reference files in `references/` hold detailed lookup tables, command references, or workflow guides that the main skill tells Claude to read on demand (keeps the main skill focused).
- Skills should be operational (tell Claude what to DO), not educational (don't explain concepts for the user to read).
