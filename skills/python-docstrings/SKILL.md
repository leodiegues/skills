---
allowed-tools: Read, Edit, MultiEdit, Glob, Grep
argument-hint: <python-file-or-directory>
description: "Add or improve docstrings in Python files using Google convention. Use this skill whenever the user asks to add, fix, update, or improve docstrings in Python code — whether for a single file, a module, or an entire package. Also trigger when the user mentions 'document this code', 'add documentation', 'missing docstrings', 'undocumented functions', or wants to prepare code for Sphinx/MkDocs/pdoc. Trigger for any Python docstring-related task including converting between docstring styles (NumPy, Sphinx/reST, epydoc → Google). Do NOT trigger for non-Python documentation, README files, or general prose writing."
---

# Add Docstrings

Add comprehensive, well-crafted docstrings to Python files using Google style convention.

## Before You Start

1. **Read the target file(s)** to understand the code structure, existing documentation, and conventions already in use.
2. **Detect the repository language** — follow the language detection rules below.
3. **Read `references/conventions.md`** for detailed formatting rules and framework-specific patterns before writing any docstrings.

## Language Detection

Docstrings must match the natural language used in the repository. Detect it by scanning (in priority order):

1. **Existing docstrings** in the target file or nearby files — if most are in Portuguese, write in Portuguese.
2. **Code comments** (`#` inline comments) — these reveal the team's working language.
3. **Commit messages** — a strong signal of team convention.
4. **README or CONTRIBUTING docs** at the repo root.
5. **Default to English** if no signal is found.

Once detected, use that language consistently for all docstrings in the session. Identifiers, parameter names, type names, and technical terms (e.g., "endpoint", "middleware", "callback") stay in English regardless — only the prose descriptions are translated.

**Example (Portuguese):**
```python
def calcular_imposto(valor, aliquota):
    """Calcula o imposto com base no valor e na alíquota.

    Args:
        valor: Valor base para o cálculo.
        aliquota: Percentual da alíquota aplicada.

    Returns:
        Valor do imposto calculado.
    """
```

## Core Rules

### Google Style Convention

Use Google style for all docstrings. The format uses plain-text section headers (`Args:`, `Returns:`, etc.) with indented descriptions — no Sphinx `:param:` or NumPy-style underlines.

Refer to `references/conventions.md` for the full formatting specification, including all section types and edge cases.

### What Gets a Docstring

- **Every public module, class, function, and method.** This is the baseline.
- **Non-trivial `__init__` methods** — document if the constructor does meaningful work or has non-obvious parameters. Skip for simple attribute assignments that mirror the class docstring.
- **Private functions/methods (`_name`)** — add a docstring if the logic is non-obvious. A one-liner helper that does what its name says can be left alone.
- **Dunder methods** — skip `__repr__`, `__str__`, `__eq__` unless they have surprising behavior.
- **Module level** — add a module docstring at the top of the file if one is missing. Keep it to one or two sentences describing the module's purpose.

### What NOT to Document

- Don't restate the function signature in prose. `Args` descriptions should add meaning beyond what the type hint already says.
- Don't document parameters whose purpose is completely obvious from name + type (e.g., `self`, `cls`).
- Don't add boilerplate docstrings that say nothing useful — `"""Does the thing."""` on `do_thing()` adds noise, not documentation.

### Preserve Existing Work

- If a docstring already exists and is accurate, leave it alone (or improve wording without changing meaning).
- If an existing docstring uses a different convention (Sphinx, NumPy), convert it to Google style while preserving the content.
- Never delete documentation that contains useful information.

## Framework-Specific Patterns

The skill handles several Python framework patterns differently. Read `references/conventions.md` for the full details on each. A quick summary:

### Dataclasses, Pydantic Models, TypedDicts, NamedTuples

Use **inline attribute docstrings** (a string literal on the line after the attribute). This is the only way to document individual fields that tools like Sphinx and pdoc can pick up:

```python
@dataclass
class Config:
    """Application configuration."""

    host: str
    """Hostname for the server."""

    port: int = 8080
    """Port number. Defaults to 8080."""
```

### FastAPI Endpoints

FastAPI generates its own OpenAPI docs from type hints, so the documentation strategy is different from regular functions. See `references/conventions.md` § FastAPI for the full pattern, but the key points are:

- Use the `summary` parameter in the route decorator for the brief description.
- Use `responses` dict to document status codes (import `status` from `fastapi`).
- The function docstring becomes the OpenAPI "description" — write it in Markdown with `####` headers.
- Do NOT use `Args`/`Returns` sections — FastAPI ignores them and generates parameter docs from type hints.
- Document error responses with a `ProblemDetail` model (or whatever error schema the project uses — look for it before assuming a name).

### Abstract Base Classes

Document the interface contract in the abstract method's docstring. Concrete implementations can reference the base class doc or add implementation-specific details.

### Decorators and Wrappers

Document the decorator's effect on the wrapped function, not the wrapper's internals. Use a `Note:` section if the decorator modifies the function's signature or return type.

## Workflow

When given a file or directory path:

1. If a directory, use `Glob` to find all `.py` files. Process them one at a time.
2. Read each file fully before making any edits.
3. Detect the language (see above) on the first file; apply consistently.
4. Identify all items that need docstrings (or need their docstrings improved/converted).
5. Use `Edit` or `MultiEdit` to add docstrings. Batch related changes in a single `MultiEdit` when possible to minimize tool calls.
6. Preserve all existing code — only add or modify docstring content.

For large files (50+ documentable items), work in logical sections: module docstring first, then classes top-to-bottom, then standalone functions.
