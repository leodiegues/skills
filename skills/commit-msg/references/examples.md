# Commit Message Examples

Real-world examples showing how to derive messages from diffs. Study the pattern: diff → scope detection → type selection → message.

---

## Example 1: New API endpoint

**Diff summary:**
```
A services/auth/src/routes/verify-email.ts
M services/auth/src/routes/index.ts
M services/auth/src/types.ts
```

**Scope detection:** All files under `services/auth/` → scope is `auth`

**Type:** New file, new route → `feat`

**Good:**
```
feat(auth): add email verification endpoint

Accepts a token from the verification link and marks
the user's email as verified. Returns 400 if the token
is expired or already used.
```

**Bad:**
```
add email verification
```
*Missing type, scope, and doesn't explain behavior.*

---

## Example 2: Bug fix in a shared package

**Diff summary:**
```
M packages/utils/src/date-format.ts
M packages/utils/src/date-format.test.ts
```

**Scope detection:** `packages/utils/` → scope is `utils`

**Type:** Existing behavior corrected + test updated → `fix`

**Good:**
```
fix(utils): handle timezone offset in date formatting

formatDate() was using UTC hours but local date, causing
dates to shift by one day for users west of UTC after 5pm.
```

**Bad:**
```
fix: fix date bug
```
*Tautological. Which date bug? What was wrong?*

---

## Example 3: Refactoring without behavior change

**Diff summary:**
```
M apps/web/src/hooks/useAuth.ts
M apps/web/src/hooks/useUser.ts
D apps/web/src/hooks/useAuthUser.ts
```

**Scope detection:** `apps/web/` → scope is `web`

**Type:** Restructured, deleted redundant file, no behavior change → `refactor`

**Good:**
```
refactor(web): split useAuthUser into useAuth and useUser

Separating auth state from user profile data reduces
unnecessary re-renders when only one changes.
```

**Bad:**
```
refactor(web): refactor hooks
```
*Tautology. Says nothing about what or why.*

---

## Example 4: CI pipeline change

**Diff summary:**
```
M .github/workflows/ci.yml
M nx.json
```

**Scope detection:** Root-level CI files → scope is `ci` (or omit)

**Type:** CI config → `ci`

**Good:**
```
ci: cache nx computation results between runs

Adds nx-cache restore/save steps. Should reduce CI time
for unchanged projects from ~8min to ~2min.
```

**Bad:**
```
update ci
```
*No type, no explanation of what changed or why.*

---

## Example 5: Dependency update

**Diff summary:**
```
M package.json
M pnpm-lock.yaml
```

**Scope detection:** Root lockfile → scope is `deps`

**Type:** Dependency maintenance → `chore`

**Good:**
```
chore(deps): bump vitest from 1.6.0 to 2.0.1
```

**Bad:**
```
update dependencies
```
*Which dependencies? What versions?*

---

## Example 6: Cross-cutting change across multiple packages

**Diff summary:**
```
M packages/ui/src/Button.tsx
M packages/ui/src/Input.tsx
M packages/forms/src/LoginForm.tsx
M apps/web/src/pages/Login.tsx
```

**Scope detection:** Primary change is in `ui` (component API changed), others are consumers updating to match.

**Type:** Component API changed → could be `feat` (new prop) or `refactor` (restructure). Check the diff.

**Good** (if new prop added):
```
feat(ui): add loading state to Button and Input components

Consumers updated to pass isLoading prop where applicable.
```

**Good** (if just restructuring):
```
refactor(ui): extract shared disabled styles from Button and Input

LoginForm and Login page updated to use the new API.
```

---

## Example 7: Documentation only

**Diff summary:**
```
M libs/sdk/src/client.ts    (only TSDoc comments changed)
A libs/sdk/docs/auth-flow.md
```

**Scope detection:** `libs/sdk/` → scope is `sdk`

**Type:** Only docs/comments → `docs`

**Good:**
```
docs(sdk): document auth flow and add TSDoc to client methods
```

---

## Example 8: Single-file config tweak

**Diff summary:**
```
M tsconfig.base.json
```

**Scope detection:** Root config → omit scope or use `repo`

**Type:** Build config → `build`

**Good:**
```
build: enable strict null checks in base tsconfig
```

*Short, no body needed — the diff tells the full story.*

---

## Example 9: Test-only change

**Diff summary:**
```
A services/billing/src/__tests__/invoice.test.ts
M services/billing/src/__tests__/helpers.ts
```

**Scope detection:** `services/billing/` → scope is `billing`

**Type:** Only test files → `test`

**Good:**
```
test(billing): add unit tests for invoice generation

Covers prorated billing, tax calculation, and currency
rounding edge cases.
```

---

## Example 10: Performance improvement

**Diff summary:**
```
M apps/api/src/middleware/cache.ts
M apps/api/src/routes/products.ts
```

**Scope detection:** `apps/api/` → scope is `api`

**Type:** Performance optimization → `perf`

**Good:**
```
perf(api): add response caching to product list endpoint

Cache product listings for 60s. Reduces DB queries by
~80% during peak traffic based on load test results.
```
