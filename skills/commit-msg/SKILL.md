---
name: commit-msg
description: "Generate conventional commit messages by reading the actual diff. Use this skill whenever you need to write a commit message, describe a change, or the user says 'commit', 'describe this', 'write a commit message', 'jj describe', or 'what changed'. Also trigger when running jj commit, jj describe, or git commit and no message was provided or the message needs improvement. Trigger proactively: if you just finished making changes and are about to commit/describe, use this skill to generate the message from the diff rather than writing a generic one. Works with both jj (jj describe) and git (git commit) repos."
---

# Commit Message Skill

Generate precise, conventional commit messages by reading the actual diff. Never guess — always diff first.

## Process

Every time you need to write a commit message, follow these steps in order:

### Step 1: Read the diff

```bash
# jj repo
jj diff
# or for a specific change:
jj diff -r <change-id>

# git repo (fallback)
git diff --staged
# or if nothing staged:
git diff
```

If the diff is large, also run a summary view:

```bash
# jj
jj diff --summary      # or: jj diffs (lazyjj alias)

# git
git diff --staged --stat
```

### Step 2: Detect scope from file paths

Look at which files changed and derive the scope from the **nearest package/service/app boundary** in the path.

**Monorepo patterns** (check which applies):

| Structure | Scope derivation | Example path → scope |
|---|---|---|
| `apps/<name>/...` | app name | `apps/web/src/index.ts` → `web` |
| `packages/<name>/...` | package name | `packages/utils/src/format.ts` → `utils` |
| `services/<name>/...` | service name | `services/auth/handler.ts` → `auth` |
| `libs/<name>/...` | lib name | `libs/ui/Button.tsx` → `ui` |
| `modules/<name>/...` | module name | `modules/billing/api.ts` → `billing` |
| `src/<module>/...` | module name | `src/auth/login.ts` → `auth` |

**Nx monorepo**: If `project.json` or `workspace.json` exists, scope to the Nx project name (the directory name under `apps/`, `libs/`, `packages/`).

**Multi-scope changes**: If changes span multiple packages/services:
- If one is clearly the primary change and others are incidental (e.g., updating an import), scope to the primary.
- If truly cross-cutting (config, CI, tooling), omit the scope or use a broad scope like `repo`, `ci`, `deps`.

**Root-level files**: Files at the repo root (`.gitignore`, `package.json`, `tsconfig.json`, `nx.json`, etc.) → omit scope or use `repo`.

### Step 3: Determine the commit type

| Type | When to use |
|---|---|
| `feat` | New feature, new capability, new endpoint, new UI component |
| `fix` | Bug fix, error correction, regression fix |
| `refactor` | Code restructuring with no behavior change |
| `docs` | Documentation only (README, TSDoc, comments, guides) |
| `test` | Adding or updating tests only |
| `chore` | Maintenance (deps update, config tweaks, cleanup) |
| `ci` | CI/CD pipeline changes (GitHub Actions, GitLab CI, Dockerfiles) |
| `perf` | Performance improvement |
| `build` | Build system changes (Nx config, bundler, compiler settings) |
| `style` | Formatting, linting, whitespace (no logic change) |

**When in doubt:** if it changes behavior → `feat` or `fix`. If it doesn't → `refactor`, `chore`, or `docs`.

### Step 4: Write the message

Format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Rules for the subject line:**
- Lowercase first word (no capital after the colon)
- Imperative mood: "add", "fix", "refactor" — not "added", "fixes", "refactoring"
- No period at the end
- Max 72 characters total for the first line
- Specific: describe WHAT changed, not that something changed
- English only

**Rules for the body** (optional — include when the diff is non-trivial):
- Separated from subject by a blank line
- Explain WHY the change was made, not WHAT (the diff shows what)
- Wrap at 72 characters
- Use bullet points (- ) for multiple points

**Rules for the footer** (optional):
- `BREAKING CHANGE: <description>` for breaking changes
- Issue references: `Closes #123`, `Refs #456`

### Step 5: Apply the message

```bash
# jj repo (preferred)
jj describe -m "<message>"

# git repo (fallback)
git commit -m "<message>"
```

For multi-line messages in jj:

```bash
jj describe -m "type(scope): subject

body paragraph here

- bullet point
- another point"
```

## Examples

Read `references/examples.md` for a curated set of good and bad commit messages derived from real diffs.

## Anti-patterns

**Never write these:**
- `"update code"` — says nothing
- `"fix bug"` — which bug?
- `"wip"` — describe what the WIP contains
- `"changes"` — obviously
- `"feat: add stuff"` — what stuff?
- `"refactor(app): refactor the app"` — tautology

**Subject line red flags:**
- Contains "various", "some", "multiple", "misc" → too vague, split the commit or be specific
- Longer than 72 chars → trim, move detail to body
- Starts with capital letter after colon → lowercase it
- Past tense ("added", "fixed") → imperative ("add", "fix")

## Edge Cases

**Empty diff:** Don't write a message. Tell the user there's nothing to commit.

**Only deleted files:** `chore(scope): remove <what was removed and why>`

**Only renamed/moved files:** `refactor(scope): move <thing> to <destination>`

**Merge conflicts resolved:** Describe what was resolved, not that a merge happened.

**Generated code changes** (lockfiles, compiled output): `chore(deps): update lockfile` or similar. Keep it brief — nobody reads these.
