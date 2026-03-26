---
name: typescript-tsdoc
description: "Use when writing or modifying TypeScript (.ts/.tsx) files, or when asked to document existing TypeScript code. Covers TSDoc conventions for functions, methods, interfaces, type aliases, classes, enums, constants, React components, and module-level documentation. Do NOT trigger for .js/.jsx files or non-TypeScript contexts."
---

# TSDoc for TypeScript

Operational guide for documenting TypeScript code using TSDoc conventions. Apply when writing new `.ts`/`.tsx` code or when asked to document existing TypeScript.

**RULE: Never add comments inside function bodies, method bodies, or any executable block. All documentation goes on declarations via TSDoc blocks.**

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

When the skill activates, scan for existing documentation patterns before writing anything. Search for `/**` blocks in `.ts` and `.tsx` files to find existing TSDoc/JSDoc usage.

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
 * @throws If all retry attempts are exhausted
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
 * @typeParam T - The type of each row object
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
