# Google Style Docstring Conventions

Detailed reference for formatting docstrings. The SKILL.md provides the workflow and high-level rules; this file covers the syntax specifics.

## Table of Contents

1. [Basic Structure](#basic-structure)
2. [Section Reference](#section-reference)
3. [Type Annotations in Docstrings](#type-annotations-in-docstrings)
4. [One-Liners vs Multi-Line](#one-liners-vs-multi-line)
5. [Classes](#classes)
6. [Attribute Docstrings](#attribute-docstrings)
7. [Generators and Async](#generators-and-async)
8. [Overloaded Functions](#overloaded-functions)
9. [FastAPI Endpoints](#fastapi-endpoints)
10. [Properties](#properties)
11. [Examples Section](#examples-section)

---

## Basic Structure

```python
def function(arg1, arg2, *, keyword_only=None):
    """Summary line — one sentence, imperative mood, fits on one line.

    Extended description if needed. Can be multiple paragraphs. Explain
    the *why*, not just the *what* — the signature already shows the what.

    Args:
        arg1: Description of arg1. Continue on the next line with a
            4-space hanging indent if it wraps.
        arg2: Description of arg2.
        keyword_only: Description. Mention the default behavior when
            None is passed if it's non-obvious.

    Returns:
        Description of the return value. If the function returns a
        complex structure, describe its shape.

    Raises:
        ValueError: When arg1 is negative.
        ConnectionError: If the remote service is unreachable.
    """
```

### Formatting Rules

- **Summary line**: imperative mood ("Calculate X", "Return Y", not "Calculates" or "This function calculates"). Ends with a period. Must be a single line — no wrapping.
- **Blank line** between summary and extended description, and between extended description and first section.
- **Section headers** end with a colon and have no blank line before the first entry.
- **Indentation**: section content is indented 4 spaces from the section header. Continuation lines within an entry are indented 4 more spaces (8 total from the section header).
- **Blank lines between sections**: yes, one blank line between sections.

---

## Section Reference

Use these sections in this order when applicable. Omit any section that doesn't apply.

| Section | When to use |
|---|---|
| `Args:` | Function/method has parameters (excluding `self`/`cls`) |
| `Returns:` | Function returns something other than `None` |
| `Yields:` | Function is a generator (use instead of `Returns`) |
| `Raises:` | Function explicitly raises exceptions |
| `Note:` or `Notes:` | Important caveats, side effects, or non-obvious behavior |
| `Example:` or `Examples:` | Usage examples (especially for public API) |
| `Attributes:` | Class-level attributes in the class docstring (alternative to inline attribute docstrings — prefer inline for dataclasses/Pydantic, `Attributes:` for regular classes) |
| `See Also:` | Cross-references to related functions or classes |
| `References:` | Academic papers, external docs, RFCs |
| `Todo:` | Known limitations to be addressed |

### Args Format

```
Args:
    name: Description.
    name: Description that wraps to the next line gets
        a 4-space hanging indent.
    *args: Variable positional arguments — describe what they represent.
    **kwargs: Variable keyword arguments. Mention important keys
        if the function inspects specific ones.
```

Do **not** include type annotations in `Args` entries when the function signature already has type hints. If the codebase lacks type hints, include types:

```
Args:
    name (str): Description — only when no type hints exist.
```

### Returns Format

```
Returns:
    Description of the return value.
```

For tuple returns:
```
Returns:
    A tuple of (matched_items, unmatched_items) where each element
    is a list of strings.
```

For dict returns, describe the shape:
```
Returns:
    A dict mapping user IDs to their profile data, where each value
    is a dict with keys "name", "email", and "role".
```

If the function can return `None` in some cases, mention when:
```
Returns:
    The parsed configuration, or None if the file doesn't exist.
```

### Raises Format

Only document exceptions the function **explicitly** raises, not every possible exception from called code:

```
Raises:
    ValueError: If the input is not a valid ISO 8601 date string.
    FileNotFoundError: If the template path doesn't exist.
```

---

## Type Annotations in Docstrings

**General rule**: if the code uses type hints, do NOT repeat types in the docstring. The docstring adds semantic meaning that the type hint can't convey.

```python
# Good — types are in the signature, docstring adds meaning
def connect(host: str, port: int, timeout: float = 30.0) -> Connection:
    """Establish a connection to the remote server.

    Args:
        host: Hostname or IP address.
        port: TCP port number.
        timeout: Seconds to wait before giving up.

    Returns:
        An open connection ready for queries.
    """
```

```python
# Bad — type info is duplicated
def connect(host: str, port: int, timeout: float = 30.0) -> Connection:
    """Establish a connection to the remote server.

    Args:
        host (str): The hostname or IP address of the server.
        port (int): The TCP port number to connect to.
        timeout (float): The timeout in seconds. Defaults to 30.0.

    Returns:
        Connection: An open connection to the server.
    """
```

**Exception**: if the codebase has no type hints, include types in the docstring using the `name (type):` format.

---

## One-Liners vs Multi-Line

Use a one-liner when the function is simple and needs no `Args`/`Returns` sections:

```python
def is_valid(self) -> bool:
    """Check whether the configuration passes all validation rules."""
```

Rules for one-liners:
- Opening `"""` and closing `"""` on the same line.
- Still a complete sentence ending with a period.
- No blank line after the one-liner before the code body.

Switch to multi-line whenever you need any section (`Args`, `Returns`, etc.) or the summary + description exceeds one line.

---

## Classes

### Regular Classes

```python
class HTTPClient:
    """HTTP client with connection pooling and retry logic.

    Manages a pool of persistent connections and automatically retries
    failed requests with exponential backoff.

    Attributes:
        base_url: The root URL all requests are relative to.
        timeout: Default timeout for requests in seconds.
        max_retries: Maximum retry attempts for failed requests.
    """

    def __init__(self, base_url: str, timeout: float = 30.0):
        """Initialize the HTTP client.

        Args:
            base_url: Root URL (e.g., "https://api.example.com").
            timeout: Default request timeout in seconds.
        """
        self.base_url = base_url
        self.timeout = timeout
        self.max_retries = 3
```

Use `Attributes:` in the class docstring for regular classes where attributes are set in `__init__`. Document `__init__` parameters in `__init__`'s own docstring.

### Dataclasses, Pydantic Models, TypedDicts, NamedTuples

Prefer **inline attribute docstrings** — a bare string literal on the line immediately after the attribute:

```python
@dataclass
class SearchResult:
    """A single search result with relevance scoring."""

    url: str
    """The canonical URL of the result."""

    title: str
    """Page title, already HTML-unescaped."""

    score: float
    """Relevance score between 0.0 and 1.0."""

    snippet: str | None = None
    """Extracted text snippet, if available."""
```

```python
class UserCreate(BaseModel):
    """Schema for creating a new user account."""

    email: EmailStr
    """Must be a valid, unique email address."""

    password: str = Field(..., min_length=8)
    """Minimum 8 characters. Stored as bcrypt hash."""

    display_name: str = Field(..., max_length=100)
    """Publicly visible name."""
```

```python
class Coordinates(TypedDict):
    """Geographic coordinate pair."""

    lat: float
    """Latitude in decimal degrees (-90 to 90)."""

    lng: float
    """Longitude in decimal degrees (-180 to 180)."""
```

Why inline over `Attributes:` in the class docstring? Tools like Sphinx (`autodoc`), pdoc, and mkdocstrings pick up inline attribute docstrings and render them next to each field. The `Attributes:` section in a class docstring works too, but for field-heavy models it creates duplication and drifts out of sync more easily.

---

## Generators and Async

### Generators

Use `Yields:` instead of `Returns:`:

```python
def read_chunks(path: Path, size: int = 8192):
    """Read a file in fixed-size chunks.

    Yields:
        Bytes chunks of at most `size` bytes.
    """
```

### Async Functions

Document identically to sync functions. The `async` keyword in the signature is sufficient — don't add "This is an async function" to the docstring unless there's something genuinely important about the async behavior (e.g., "Must be awaited before the event loop closes").

---

## Overloaded Functions

Document the primary overload. For `@typing.overload`, put the docstring on the implementation (non-decorated) function, covering all signatures:

```python
@overload
def parse(data: str) -> dict: ...
@overload
def parse(data: bytes) -> dict: ...

def parse(data):
    """Parse input data into a structured dict.

    Accepts either a JSON string or raw bytes (decoded as UTF-8).

    Args:
        data: JSON content as a string or bytes.

    Returns:
        Parsed dictionary.
    """
```

---

## FastAPI Endpoints

FastAPI auto-generates OpenAPI docs from type hints and the function docstring. The documentation approach differs from regular functions:

### Route Decorator Enhancements

1. Import `status` from `fastapi` and use status code constants.
2. Add `summary` — a short description (becomes the operation summary in OpenAPI).
3. Add `status_code` — the success status code.
4. Add `responses` — a dict mapping status codes to descriptions.
5. For error responses, reference the project's error schema model (look for a `ProblemDetail`, `ErrorResponse`, or similar class in the codebase before assuming a name).

### Docstring Content

The function docstring becomes the OpenAPI operation description. Write it in **Markdown**:

- Use `####` headers or higher (the summary creates an H3 in most OpenAPI UIs).
- Use bullet lists, bold, code spans — they render in Swagger/Redoc.
- Do NOT use `Args:` or `Returns:` — FastAPI generates parameter and response docs from the type hints and `response_model`.
- Focus on business logic, features, limitations, and usage notes.

### Full Example

```python
from fastapi import status

# Use whatever error schema the project defines — discover it first
from myapp.schemas.errors import ProblemDetail


@router.post(
    "/documents/search",
    summary="Search documents by semantic similarity",
    response_model=SearchResponse,
    status_code=status.HTTP_200_OK,
    responses={
        status.HTTP_200_OK: {"description": "Search results sorted by relevance"},
        status.HTTP_400_BAD_REQUEST: {
            "description": "Invalid query parameters",
            "model": ProblemDetail,
        },
        status.HTTP_422_UNPROCESSABLE_CONTENT: {
            "description": "Request body validation failed",
            "model": ProblemDetail,
        },
    },
)
async def search_documents(*, body: SearchRequest):
    """
    Perform semantic search across indexed documents.

    #### How It Works

    - **Embedding**: The query is embedded using the same model as the index.
    - **Similarity**: Results are ranked by cosine similarity.
    - **Filtering**: Optional metadata filters narrow the search scope.

    #### Limitations

    - Maximum query length is 512 tokens.
    - Returns at most 100 results per request.
    """
```

### Updating Existing Endpoints

When an endpoint already exists without documentation:

1. Search the codebase for the error response schema (e.g., `grep -r "class ProblemDetail" --include="*.py"` or `grep -r "class ErrorResponse" --include="*.py"`).
2. Add the import if found. If no standard error schema exists, skip the `"model"` key in responses.
3. Add `summary`, `status_code`, and `responses` to the decorator.
4. Add or improve the function docstring in Markdown format.

---

## Properties

Document properties like methods, but omit `Args` (they have none) and phrase `Returns` as what the property evaluates to:

```python
@property
def is_expired(self) -> bool:
    """Whether the token has passed its expiration time."""
```

For settable properties:
```python
@name.setter
def name(self, value: str) -> None:
    """Set the display name.

    Raises:
        ValueError: If the name is empty or exceeds 100 characters.
    """
```

---

## Examples Section

Use `Examples:` when the usage is non-obvious or the function is part of a public API:

```python
def retry(max_attempts: int = 3, backoff: float = 1.0):
    """Decorator that retries a function on exception.

    Args:
        max_attempts: Total attempts before giving up.
        backoff: Seconds to wait between attempts (doubles each retry).

    Examples:
        Basic usage with defaults:

            @retry()
            def fetch_data():
                ...

        Custom retry configuration:

            @retry(max_attempts=5, backoff=2.0)
            def fragile_operation():
                ...
    """
```

Rules for examples:
- Indent code blocks by 4 spaces within the section.
- Blank line before and after each code block.
- Use descriptive labels before each example if showing multiple.
- Examples must be syntactically valid Python.
- For `doctest`-style examples (with `>>>`), use them only if the project runs doctests.
