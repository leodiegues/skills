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
