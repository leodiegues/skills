# Forge Workflows: GitHub & GitLab

How to push changes and create PRs/MRs from jj with LazyJJ, for both GitHub and GitLab.

## Table of Contents

1. [Detecting the Forge](#detecting-the-forge)
2. [GitHub Workflows (LazyJJ Native)](#github-workflows)
3. [GitLab Workflows (Manual Patterns)](#gitlab-workflows)
4. [Common Patterns](#common-patterns)

---

## Detecting the Forge

```bash
# Check which forge the remote points to
jj git remote list
# or
git remote get-url origin
```

- Contains `github.com` → use GitHub workflow
- Contains `gitlab.com` or a GitLab instance → use GitLab workflow

---

## GitHub Workflows

LazyJJ has native GitHub integration via `gh` CLI.

### Prerequisites

```bash
brew install gh    # or your package manager
gh auth login
```

### Single PR

```bash
jj stack-start
# make changes
jj describe -m "Add user authentication"
jj create auth-feature        # bookmark at @-
jj new                        # start fresh change
jj stack-submit               # push

# Create PR via gh
gh pr create --base main --head auth-feature
```

### Stacked PRs

LazyJJ's killer feature for GitHub:

```bash
# Build the stack
jj stack-start
jj describe -m "step 1: database schema"
jj create db-schema
jj new
jj describe -m "step 2: user model"
jj create user-model
jj new
jj describe -m "step 3: user API"
jj create user-api

# Create all PRs at once (sets base branches correctly)
jj pr-stack-create            # or: jj sprs

# Update PR descriptions with stack summary
jj pr-stack-update            # or: jj uprs

# View the stack summary
jj pr-stack-summary           # or: jj prs

# View formatted stack with CI/review status
jj pr-stack-md                # or: jj prmd
```

### Updating After Changes

```bash
jj stack-sync                 # rebase onto latest trunk
# make additional changes to any commit in the stack
jj stack-submit               # re-push everything

# Update PR descriptions
jj pr-stack-update
```

### After a PR is Merged

```bash
jj stack-sync                 # rebases remaining stack onto new trunk
jj stack-submit               # push updated stack
```

### GitHub Utility Commands

```bash
jj pr-view                    # or: jj prv — view current PR
jj pr-open                    # or: jj pro — open in browser
jj github-repo                # or: jj repo — get owner/repo
jj gh pr list                 # run any gh command in repo context
jj gh issue create
```

### The ghbranch Revset

LazyJJ provides a revset to find the bookmark GitHub will use:

```bash
jj log -r ghbranch            # see which bookmark maps to current position
```

---

## GitLab Workflows

LazyJJ's PR commands are GitHub-specific. For GitLab, use manual bookmark + push patterns. The core jj workflow is identical — only the PR/MR creation step differs.

### Prerequisites

```bash
# Optional but helpful:
# Install glab CLI: https://gitlab.com/gitlab-org/cli
brew install glab    # or your package manager
glab auth login
```

### Single MR

```bash
jj stack-start
# make changes
jj describe -m "Add user authentication"
jj bookmark set auth-feature -r @-
jj new
jj git push --bookmark auth-feature --allow-new   # --allow-new for first push

# Create MR via glab (if installed)
glab mr create --source-branch auth-feature --target-branch main

# Or create MR via GitLab web UI — the branch is already pushed
```

### Updating an MR

```bash
# Make more changes or rebase
jj stack-sync
# Edit as needed
jj bookmark set auth-feature -r @-   # update bookmark position
jj git push --bookmark auth-feature   # force-push happens automatically
```

### Stacked MRs (Manual)

GitLab doesn't have native stacked MR support like GitHub, but you can approximate it:

```bash
# Build the stack
jj stack-start
jj describe -m "step 1: database schema"
jj bookmark set db-schema -r @
jj new
jj describe -m "step 2: user model"
jj bookmark set user-model -r @
jj new
jj describe -m "step 3: user API"
jj bookmark set user-api -r @
jj new

# Push all bookmarks
jj git push --bookmark db-schema --allow-new
jj git push --bookmark user-model --allow-new
jj git push --bookmark user-api --allow-new

# Create MRs manually, setting base branches:
# db-schema → main
# user-model → db-schema
# user-api → user-model

# With glab:
glab mr create --source-branch db-schema --target-branch main
glab mr create --source-branch user-model --target-branch db-schema
glab mr create --source-branch user-api --target-branch user-model
```

**Note:** When a lower MR is merged, you need to retarget the next MR's base branch to `main` in GitLab's UI or via `glab mr update`.

### GitLab Trunk-Based Development

For trunk-based dev with short-lived branches (typical in GitLab CI/CD):

```bash
# Start from trunk
jj stack-start

# Work on your change
jj describe -m "feat: add authentication endpoint"

# Create bookmark and push
jj bookmark set feat/auth -r @-
jj new
jj git push --bookmark feat/auth --allow-new

# Create MR
glab mr create --source-branch feat/auth --target-branch main --squash-before-merge

# After review, merge via GitLab (squash merge recommended)
# Then clean up locally:
jj stack-sync
jj stack-gc
```

---

## Common Patterns

### Bookmark Naming Conventions

- GitHub: `feature-name` (kebab-case, no prefix)
- GitLab: `feat/feature-name` or `fix/bug-name` (conventional commits style, often with slash prefix)

### Bookmark Gotcha: They Don't Auto-Follow

Unlike Git branches, jj bookmarks stay where you set them. After creating new changes:

```bash
# WRONG — bookmark still points at old change
jj describe -m "my change"
jj new
# bookmark is still on the change BEFORE the one you described

# RIGHT — explicitly update bookmark
jj describe -m "my change"
jj bookmark set my-feature -r @    # point at current (described) change
jj new                              # then move on
```

Or use LazyJJ helpers:
```bash
jj create my-feature    # creates bookmark at @- (parent = just-finished change)
jj tug                  # moves existing bookmark to @-
```

### Force Push is Normal

jj rewrites history freely (that's the point). Force-pushing is expected and safe for feature branches/bookmarks. Both GitHub and GitLab handle force-pushed branches correctly for PRs/MRs.

### Syncing After Upstream Merge

Same for both forges:

```bash
jj stack-sync    # fetch + rebase
jj stack-gc      # clean up empty changes (from merged commits)
```
