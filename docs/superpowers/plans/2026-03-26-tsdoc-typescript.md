# TSDoc TypeScript Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a TSDoc documentation skill that teaches agents how to document TypeScript code using TSDoc conventions, with adaptive style detection and clear what-to-document rules.

**Architecture:** Two-file skill following the existing `skills/<name>/SKILL.md + references/` pattern. Main skill covers rules, decision logic, and one example per context. Reference file provides a TSDoc tag lookup table.

**Tech Stack:** Markdown skill files (no code dependencies)

---

## File Structure

```
skills/tsdoc-typescript/
  SKILL.md                        # Main skill — rules, decision logic, examples
  references/
    tsdoc-tags.md                 # Tag reference table with usage scenarios
```

---

### Task 1: Create the TSDoc Tags Reference

**Files:**
- Create: `skills/tsdoc-typescript/references/tsdoc-tags.md`

This goes first because the main skill references it.

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p skills/tsdoc-typescript/references
```

- [ ] **Step 2: Write `tsdoc-tags.md`**

Create `skills/tsdoc-typescript/references/tsdoc-tags.md` with the following content:

````markdown
# TSDoc Tags Reference

Complete reference for TSDoc tags used in TypeScript documentation.

## Core Tags

| Tag | Usage | When to Use |
|-----|-------|-------------|
| `@param name - desc` | Document a function/method parameter | Every parameter on public functions |
| `@returns desc` | Document return value | Every public function with non-void return |
| `@typeParam T - desc` | Document a generic type parameter | Every generic type parameter on public declarations |
| `@example` | Provide usage example (code block follows) | Public functions with non-obvious usage, components |
| `@remarks` | Extended explanation beyond the summary | When the one-line summary isn't enough context |
| `@defaultValue value` | Document default value for a property | Optional properties with defaults |
| `@deprecated reason` | Mark as deprecated with migration path | Any declaration being phased out |

## Linking Tags (Inline)

| Tag | Usage | When to Use |
|-----|-------|-------------|
| `{@link SymbolName}` | Link to another declaration | Referencing related types, functions, or classes |
| `{@link SymbolName \| display text}` | Link with custom display text | When the symbol name isn't clear enough in context |

## Visibility & Scope Tags

| Tag | Usage | When to Use |
|-----|-------|-------------|
| `@public` | Mark as part of public API | When visibility isn't obvious from `export` |
| `@internal` | Mark as internal (not for consumers) | Exported symbols that are internal implementation |
| `@privateRemarks` | Notes for maintainers only (stripped from public docs) | Implementation rationale that consumers don't need |
| `@packageDocumentation` | Mark a file-level comment as module documentation | Top of file for module-level docs |

## Error & Exception Tags

| Tag | Usage | When to Use |
|-----|-------|-------------|
| `@throws desc` | Document thrown errors | Functions that throw — describe when and what |

## TSDoc vs JSDoc Differences

| Feature | JSDoc | TSDoc |
|---------|-------|-------|
| Type annotations | `@param {string} name` | `@param name` (types come from TypeScript) |
| Linking | `{@link Foo}` | `{@link Foo}` (same syntax, stricter parsing) |
| Remarks section | No equivalent | `@remarks` separates summary from details |
| Private notes | No equivalent | `@privateRemarks` for maintainer-only notes |
| Module docs | `@module` | `@packageDocumentation` |
| Default values | No standard | `@defaultValue` |
| Overload docs | No standard | Document each overload signature separately |

## Tag Ordering Convention

When multiple tags appear on a single declaration, use this order:

1. Summary line (first paragraph, no tag)
2. `@remarks` (extended description)
3. `@typeParam` (generic parameters, in declaration order)
4. `@param` (parameters, in declaration order)
5. `@returns`
6. `@throws`
7. `@example`
8. `@defaultValue`
9. `@deprecated`
10. `@privateRemarks` (last — maintainer notes)

## Common Scenarios

### Documenting an overloaded function

Document each overload signature separately. The implementation signature (the one with the wide union type) does not get its own TSDoc — only the public-facing overload signatures do.

```typescript
/**
 * Parses a date from a string using ISO 8601 format.
 *
 * @param input - An ISO 8601 date string
 * @returns The parsed Date object
 * @throws If the string is not valid ISO 8601
 */
export function parseDate(input: string): Date;
/**
 * Parses a date from a Unix timestamp in milliseconds.
 *
 * @param input - Unix timestamp in milliseconds
 * @returns The parsed Date object
 */
export function parseDate(input: number): Date;
export function parseDate(input: string | number): Date {
  return typeof input === "string" ? new Date(input) : new Date(input);
}
```

### Documenting a generic utility

```typescript
/**
 * Groups array elements by a key extracted from each element.
 *
 * @typeParam T - The type of elements in the array
 * @typeParam K - The type of the grouping key
 * @param items - The array to group
 * @param keyFn - Function that extracts the grouping key from an element
 * @returns A Map from keys to arrays of elements with that key
 *
 * @example
 * ```typescript
 * const users = [{ name: "Alice", role: "admin" }, { name: "Bob", role: "user" }];
 * const byRole = groupBy(users, (u) => u.role);
 * // Map { "admin" => [{ name: "Alice", ... }], "user" => [{ name: "Bob", ... }] }
 * ```
 */
export function groupBy<T, K>(items: T[], keyFn: (item: T) => K): Map<K, T[]> {
  // ...
}
```

### Documenting a re-exported type with added context

```typescript
/**
 * Configuration for the retry behavior of API requests.
 *
 * @remarks
 * This extends the base retry config from the HTTP client with
 * application-specific defaults. See {@link HttpRetryConfig} for
 * the underlying options.
 */
export interface ApiRetryConfig extends HttpRetryConfig {
  /** Maximum number of retry attempts before failing. */
  maxAttempts: number;

  /**
   * Base delay between retries in milliseconds.
   *
   * @defaultValue 1000
   */
  baseDelayMs?: number;
}
```
````

- [ ] **Step 3: Verify the file**

```bash
cat skills/tsdoc-typescript/references/tsdoc-tags.md | head -5
```

Expected: the file title and start of the table.

- [ ] **Step 4: Commit**

```bash
jj describe -m "Add TSDoc tags reference for tsdoc-typescript skill"
jj new
```

---

### Task 2: Create the Main SKILL.md

**Files:**
- Create: `skills/tsdoc-typescript/SKILL.md`

- [ ] **Step 1: Write `SKILL.md`**

Create `skills/tsdoc-typescript/SKILL.md` with the following content:

````markdown
---
name: tsdoc-typescript
description: "Use when writing or modifying TypeScript (.ts/.tsx) files, or when asked to document existing TypeScript code. Covers TSDoc conventions for functions, methods, interfaces, type aliases, classes, enums, constants, React components, and module-level documentation. Do NOT trigger for .js/.jsx files or non-TypeScript contexts."
---

# TSDoc for TypeScript

Operational guide for documenting TypeScript code using TSDoc conventions. Apply when writing new `.ts`/`.tsx` code or when asked to document existing TypeScript.

**Before acting**, read the reference if you need the full tag list or syntax details:

- **`references/tsdoc-tags.md`** — All TSDoc tags, ordering convention, usage scenarios, and TSDoc vs JSDoc differences.

## Core Rules

1. **No inline comments inside bodies.** Never add comments inside function bodies, class method bodies, or any executable block. All documentation goes on declarations via TSDoc blocks.

2. **Adapt to existing style.** Before documenting, scan the codebase for existing TSDoc/JSDoc patterns. Match the tag usage, description style, and level of detail already in use. Only apply the defaults in this skill when no prior conventions exist.

## What to Document

### Always — full TSDoc block:
- All exported/public declarations: functions, methods, classes, interfaces, type aliases, enums, constants, React components. No exceptions, even if obvious.
- Module-level file headers when a file's purpose isn't obvious from its name and exports.

### Lighter — one-liner TSDoc at most:
- Internal/private declarations that are not self-evident.
- Skip entirely for trivial private code where name + types tell the full story.

### Never:
- Re-exports and barrel files.
- Inside function/class/method bodies.

### Depth:
- **Public** = summary, `@param`, `@returns`, `@typeParam`, `@example` where useful, `@remarks` for extended context.
- **Private/internal** = one-line `/** description */` at most.

## Detection

When the skill activates, scan for existing documentation patterns before writing anything:

```bash
# Check for existing TSDoc/JSDoc in the project
grep -r "\/\*\*" --include="*.ts" --include="*.tsx" -l . | head -10
```

If results exist, read 2-3 documented files to learn the existing style. Match it. If no results, apply the defaults below.

## Examples by Context

### Function / Method

```typescript
/**
 * Retries an async operation with exponential backoff.
 *
 * @typeParam T - The return type of the operation
 * @param operation - The async function to retry
 * @param maxAttempts - Maximum number of attempts before throwing
 * @returns The result of the first successful attempt
 * @throws The last error encountered after all attempts are exhausted
 *
 * @example
 * ```typescript
 * const data = await retry(() => fetchUserProfile(userId), 3);
 * ```
 */
export async function retry<T>(
  operation: () => Promise<T>,
  maxAttempts: number,
): Promise<T> {
  // ...
}
```

### Interface / Type Alias

```typescript
/**
 * Options for configuring the notification delivery pipeline.
 *
 * @remarks
 * Channels are attempted in order. If a channel fails, the next one is tried.
 * At least one channel must be provided.
 */
export interface NotificationOptions {
  /** The user-facing message content. */
  message: string;

  /** Ordered list of delivery channels to attempt. */
  channels: NotificationChannel[];

  /**
   * Whether to persist the notification for later retrieval.
   *
   * @defaultValue true
   */
  persist?: boolean;
}
```

### Class

```typescript
/**
 * Manages WebSocket connections with automatic reconnection.
 *
 * @remarks
 * Reconnection uses exponential backoff starting at 1 second,
 * capped at 30 seconds. Subscribe to {@link ConnectionManager.onStateChange}
 * to track connection lifecycle.
 */
export class ConnectionManager {
  /** Current connection state. */
  public state: ConnectionState;

  /**
   * Creates a new connection manager.
   *
   * @param url - The WebSocket server URL
   * @param options - Connection configuration
   */
  constructor(url: string, options: ConnectionOptions) {
    // ...
  }

  /**
   * Sends a message through the active connection.
   *
   * @param payload - The message to send
   * @throws If there is no active connection
   */
  public send(payload: Message): void {
    // ...
  }
}
```

### Enum

```typescript
/**
 * HTTP status codes returned by the API gateway.
 *
 * @remarks
 * Only includes codes the gateway actively uses.
 * Standard HTTP semantics apply.
 */
export enum GatewayStatus {
  /** Request processed successfully. */
  Ok = 200,

  /** Request payload failed validation. */
  BadRequest = 400,

  /** Bearer token is missing or expired. */
  Unauthorized = 401,

  /** Rate limit exceeded — retry after the `Retry-After` header. */
  TooManyRequests = 429,
}
```

### Constant

```typescript
/**
 * Maximum number of items a single bulk import request accepts.
 *
 * @remarks
 * Set to match the upstream provider's batch limit.
 * Exceeding this returns a 413 from the gateway.
 */
export const MAX_BULK_IMPORT_SIZE = 500;
```

### React Component

```typescript
/**
 * Renders a paginated data table with sortable columns.
 *
 * @param props - {@link DataTableProps}
 * @returns The rendered table element
 *
 * @example
 * ```tsx
 * <DataTable
 *   columns={[{ key: "name", label: "Name", sortable: true }]}
 *   rows={users}
 *   pageSize={25}
 * />
 * ```
 */
export function DataTable<T extends Record<string, unknown>>(
  props: DataTableProps<T>,
): React.ReactElement {
  // ...
}

/** Configuration for a single table column. */
export interface DataTableColumn<T> {
  /** Property key on the row object to display. */
  key: keyof T & string;

  /** Column header label. */
  label: string;

  /**
   * Whether the column supports click-to-sort.
   *
   * @defaultValue false
   */
  sortable?: boolean;
}

/** Props for the {@link DataTable} component. */
export interface DataTableProps<T extends Record<string, unknown>> {
  /** Column definitions. */
  columns: DataTableColumn<T>[];

  /** Data rows to display. */
  rows: T[];

  /**
   * Number of rows per page.
   *
   * @defaultValue 20
   */
  pageSize?: number;
}
```

### Module / File Header

```typescript
/**
 * @packageDocumentation
 *
 * Rate limiting middleware for the Express API layer.
 *
 * Provides a sliding-window rate limiter backed by Redis.
 * Attach to routes via {@link createRateLimiter}.
 *
 * @remarks
 * Requires a Redis connection configured in the app context.
 * Falls back to in-memory counting if Redis is unavailable,
 * but this does not work across multiple server instances.
 */
```
````

- [ ] **Step 2: Verify the file renders correctly**

```bash
cat skills/tsdoc-typescript/SKILL.md | head -10
```

Expected: YAML frontmatter with `name` and `description` fields, then the skill title.

- [ ] **Step 3: Commit**

```bash
jj describe -m "Add main SKILL.md for tsdoc-typescript skill"
jj new
```

---

### Task 3: Update CLAUDE.md and README.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`

- [ ] **Step 1: Update README.md skills table**

Add a new row to the "Available Skills" table in `README.md`:

```markdown
| [tsdoc-typescript](skills/tsdoc-typescript/SKILL.md) | TSDoc documentation conventions for TypeScript — what to document, tag usage, examples by context |
```

- [ ] **Step 2: Verify README looks correct**

```bash
cat README.md
```

Expected: two rows in the skills table — `jj-lazyjj` and `tsdoc-typescript`.

- [ ] **Step 3: Commit**

```bash
jj describe -m "Add tsdoc-typescript to README skills table"
jj new
```
