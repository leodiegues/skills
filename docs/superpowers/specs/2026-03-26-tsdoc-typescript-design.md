# TSDoc TypeScript Skill — Design Spec

## Skill Identity

- **Name:** `tsdoc-typescript`
- **Description:** Use when writing or modifying TypeScript (.ts/.tsx) files, or when asked to document existing TypeScript code. Covers TSDoc conventions for functions, methods, interfaces, type aliases, classes, enums, constants, React components, and module-level documentation. Do NOT trigger for .js/.jsx files or non-TypeScript contexts.

## Trigger Behavior

- **Proactive:** Agent applies TSDoc as it writes new TypeScript code
- **Reactive:** Agent follows the skill when asked to document existing code
- **Adaptive:** Agent scans for existing TSDoc patterns first, falls back to skill defaults when no prior conventions exist

## Core Rules

1. **No inline comments inside bodies.** Never add comments inside function bodies, class method bodies, scripts, or any executable block. All documentation goes on declarations via TSDoc.

2. **Adapt to existing style.** Before documenting, scan the codebase for existing TSDoc patterns (tag usage, description style, level of detail). Match what's there. Only apply skill defaults when no prior conventions exist.

## What to Document

### Always document (full TSDoc block):
- All exported/public declarations — functions, methods, classes, interfaces, type aliases, enums, constants, React components. No exceptions, even if obvious.
- Module-level file headers when a file's purpose isn't obvious from its name/exports

### Lighter treatment for non-public:
- Internal/private declarations get a one-liner TSDoc if not self-evident
- Skip entirely only for truly trivial private code where name + types tell the full story

### Never document:
- Re-exports and barrel files
- Inside function/class/method bodies (hard rule)

### Depth rule:
- **Public** = full TSDoc (description, params, returns, examples where useful)
- **Private/internal** = one-liner TSDoc at most

## File Structure

```
skills/tsdoc-typescript/
  SKILL.md                      # Core rules, decision logic, examples per context
  references/
    tsdoc-tags.md               # Tag reference table with usage scenarios
```

### SKILL.md contains:
- Trigger/detection rules
- Core rules (no inline comments, adapt to existing style)
- What-to-document decision logic
- One concise example per context (function, interface, class, enum, constant, React component, module header)
- Instruction to read `references/tsdoc-tags.md` when the full tag reference is needed

### references/tsdoc-tags.md contains:
- Tag reference table (`@param`, `@returns`, `@remarks`, `@example`, `@typeParam`, `@deprecated`, `@defaultValue`, `@privateRemarks`, `{@link}`, etc.)
- When to use each tag with a short scenario
- TSDoc-specific syntax notes (differences from JSDoc where relevant)

## Examples Coverage

One concise, realistic example per context (~15 lines max each):

| Context | Tags/Features Demonstrated |
|---------|---------------------------|
| Function/method | `@param`, `@returns`, `@typeParam`, `@example` |
| Interface/type alias | Description, `@remarks`, per-property docs |
| Class | Class description, constructor params, public methods, public properties |
| Enum | Enum description, individual member docs for meaningful values |
| Constant | Business meaning description, `@remarks` for context |
| React component | Component description, props interface, `@example` with JSX |
| Module/file header | `@packageDocumentation` or top-of-file comment explaining module role |

## Out of Scope

- `.js`/`.jsx` files (TypeScript only)
- JSDoc (this skill uses TSDoc)
- Inline comments inside function/class bodies
- Auto-generated documentation tooling configuration
