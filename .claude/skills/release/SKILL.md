---
name: release
description: Repo maintenance — tag and publish the next version of the leodiegues-skills plugin (bump both manifests, tag, push, GitHub release). Run only when the user invokes /release.
argument-hint: "[major|minor|patch|X.Y.Z] (default: inferred from commits)"
disable-model-invocation: true
---

Cut the next release of the `leodiegues-skills` plugin. Run both scripts from the repo root.

## Steps

1. **Compute the version.** Pass the user's argument through, if they gave one:

   ```bash
   .claude/skills/release/scripts/next-version.sh [major|minor|patch|X.Y.Z]
   ```

   It prints the next version without the `v`. No `v*` tag yet → `0.1.0`. Otherwise it bumps the latest tag: by the argument, or inferred from the conventional commits since that tag (breaking → minor while 0.x, major from 1.0; `feat` → minor; anything else → patch). If it exits non-zero (nothing to release, bad argument), report its message and stop.

2. **Show what will ship and confirm.** Show the version and the commits going out (`git log --oneline <last-tag>..HEAD`; the whole log for the first release). Then confirm with `AskUserQuestion` — the next step pushes to `origin` and publishes a GitHub release. Never skip this, even when the user passed an explicit version.

3. **Release.**

   ```bash
   .claude/skills/release/scripts/release.sh <version>
   ```

   It writes the version to `plugin.json` and `.claude-plugin/plugin.json`, validates the plugin, commits `chore(release): v<version>`, tags `v<version>`, pushes `main` and the tag, and creates the GitHub release (notes = commit subjects since the last tag). It refuses unless it is on a clean `main` that is not behind `origin/main` and the tag is new.

   If it fails, report its message verbatim and stop. Do not work around a refusal: no force-push, no deleting or moving tags, no releasing from another branch. A failure after the commit (push or `gh` error) leaves a local release commit and tag — say so and let the user decide.

4. **Report** the tag and the release URL `gh` printed.
