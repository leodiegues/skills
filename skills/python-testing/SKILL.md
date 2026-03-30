---
name: pytest-testing
description: "Comprehensive guide for writing Python tests with pytest and the modern testing ecosystem. Use this skill whenever the user asks to write, fix, refactor, or review Python tests — including unit tests, integration tests, async tests, API tests, or any test file using pytest. Also trigger when the user asks to add test coverage to existing code, set up a testing infrastructure for a Python project, write conftest.py files, create test fixtures, mock dependencies, or test async code. Trigger for questions about pytest configuration, test structure, marker strategies, or when the user says 'write tests for this', 'add tests', 'test this function', 'how should I test X', or mentions pytest, pytest-mock, pytest-cov, testcontainers, anyio testing, respx, hypothesis, dirty-equals, inline-snapshot, polyfactory, or time-machine in a testing context. Do NOT trigger for JavaScript/TypeScript testing (vitest, jest) or non-Python test frameworks."
---

# Python Testing with pytest

You are writing production-grade Python tests using pytest and the modern testing ecosystem. Your goal is to write tests that are **correct, readable, maintainable, and fast** — in that priority order.

Before writing any tests, read the reference files relevant to your task:

- **`references/stack.md`** — Full library reference with versions, configuration, and API patterns. Read this when you need specific syntax for any library in the stack.
- **`references/patterns.md`** — Mocking, async, integration, and assertion patterns organized by scenario. Read this when deciding *how* to test something.

## The Testing Mindset

Tests exist to catch regressions and document behavior. Every test should answer: "what breaks if someone changes this code?" If you can't answer that, the test is probably not worth writing.

**Test behavior, not implementation.** A test for `create_user()` should assert that a user exists with the right attributes after calling it — not that `session.add()` was called. Implementation-coupled tests break on every refactor and provide no safety net.

**One logical assertion per test.** A test can have multiple `assert` statements, but they should all verify a single behavior. `test_create_user_returns_user_with_correct_fields` is one behavior even if you assert `name`, `email`, and `id` separately.

**Tests are code. Treat them that way.** Apply DRY through fixtures and helpers, but don't over-abstract — a test should be readable top-to-bottom without jumping to 5 other files. When in doubt, duplicate a little rather than creating a fixture maze.

## Decision Process

When asked to write tests, follow this sequence:

### 1. Analyze the Code Under Test

Before writing anything, understand:
- **What does this code do?** Identify the core behavior, inputs, outputs, and side effects.
- **What are the boundaries?** External services, databases, filesystem, time, randomness — these are your mocking/isolation targets.
- **What can go wrong?** Error paths, edge cases, validation failures, race conditions.
- **Is it async?** If yes, you'll use anyio's pytest plugin (not pytest-asyncio).

### 2. Choose the Test Type

| Signal | Test type | Speed | Libraries |
|--------|-----------|-------|-----------|
| Pure function, no I/O | Unit test | ~ms | pytest, hypothesis |
| Class/service with injectable deps | Unit test + mocks | ~ms | pytest-mock, respx, time-machine |
| FastAPI/Starlette endpoint | Integration test | ~100ms | httpx + respx (mocked) or TestClient |
| Database queries, ORM models | Integration test | ~1s | testcontainers, real DB |
| Full request → DB → response | E2E test | ~2s | testcontainers + TestClient |

**Default to the lightest test type that covers the behavior.** Don't spin up a Postgres container to test input validation.

### 3. Decide What to Mock

The mocking decision tree:

1. **External HTTP APIs** → Always mock with `respx` (for httpx) or `pytest-mock` (for requests). Never call real APIs in tests.
2. **Time/dates** → Mock with `time-machine`. Never use `datetime.now()` assertions with tolerances when you can freeze time.
3. **Databases** → Prefer real databases via testcontainers for integration tests. Mock the repository/DAO layer for unit tests.
4. **File system** → Use `tmp_path` fixture. Never write to real paths.
5. **Environment variables** → Use `monkeypatch.setenv()`.
6. **Internal functions** → Almost never mock these. If you feel the need, the code probably needs refactoring to inject the dependency instead.

**The golden rule of mocking:** mock at the boundary of your system, not inside it. If `UserService.create()` calls `EmailClient.send()`, mock `EmailClient.send()` — don't mock `UserService._build_email_body()`.

### 4. Write the Test

Follow this structure consistently:

```python
class TestCreateUser:
    """Tests for UserService.create() — user creation happy path and validation."""

    async def test_creates_user_with_valid_input(self, db_session, user_factory):
        # Arrange
        input_data = user_factory.build(role="user")

        # Act
        user = await UserService(db_session).create(input_data)

        # Assert
        assert user.id is not None
        assert user.name == input_data.name
        assert user.role == "user"

    async def test_raises_on_duplicate_email(self, db_session, user_factory):
        existing = user_factory.build()
        await UserService(db_session).create(existing)

        with pytest.raises(DuplicateEmailError, match="already exists"):
            await UserService(db_session).create(existing)
```

## Naming and Organization

### Test file naming
- Mirror the source structure: `src/myapp/services/user.py` → `tests/unit/services/test_user.py`
- Integration tests go in `tests/integration/`, E2E in `tests/e2e/`
- Shared fixtures live in `conftest.py` at the appropriate directory level

### Test function naming
- `test_<action>_<scenario>` for happy paths: `test_creates_user_with_valid_input`
- `test_<action>_<error_condition>` for error paths: `test_raises_on_duplicate_email`
- `test_<action>_when_<condition>` for conditional behavior: `test_sends_email_when_verified`
- Never use `test_1`, `test_success`, `test_failure` — the name IS the documentation

### Test class grouping
- Group related tests in classes: `class TestCreateUser`, `class TestDeleteUser`
- Classes don't need `__init__` — pytest discovers methods automatically
- Use classes for logical grouping, not for shared state — use fixtures for that

## Fixture Patterns

### Scope selection
- **`function`** (default): Use for almost everything. Each test gets a clean instance.
- **`session`**: Only for expensive setup that's safe to share — containers, app config, compiled schemas.
- **`module`/`class`**: Rarely useful. If you need these, you probably want `session` or `function`.

### Factory fixtures over static fixtures
```python
# BAD — every test gets the same user, can't customize
@pytest.fixture
def user():
    return User(name="Alice", role="admin")

# GOOD — tests declare what they need
@pytest.fixture
def make_user():
    def _make(name="Alice", role="user", **overrides):
        return User(name=name, role=role, **overrides)
    return _make

def test_admin_access(make_user):
    admin = make_user(role="admin")
    assert admin.can_access("/admin")
```

Even better: use **polyfactory** for Pydantic models — zero boilerplate, respects field constraints, auto-generates valid data.

### Yield fixtures for cleanup
```python
@pytest.fixture
async def db_session(db_engine):
    async with db_engine.begin() as conn:
        session = AsyncSession(bind=conn)
        yield session
        await conn.rollback()  # always clean up, even if test fails
```

## conftest.py Organization

Place fixtures at the narrowest scope that needs them:

```
tests/
├── conftest.py                 # markers, anyio_backend, shared config
├── unit/
│   ├── conftest.py             # mocker helpers, factory fixtures
│   └── test_services.py
├── integration/
│   ├── conftest.py             # containers, DB sessions, TestClient
│   └── test_api.py
└── e2e/
    ├── conftest.py             # full app setup, seed data
    └── test_flows.py
```

The root `conftest.py` should contain:
- `anyio_backend` fixture (pinned to `"asyncio"` unless testing Trio)
- Marker registrations matching `pyproject.toml`
- Autouse fixtures for global test setup (logging config, env vars)

## pyproject.toml Configuration

Recommend this baseline, adapting to the project's actual packages and structure:

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["src"]                    # for src-layout projects
import_mode = "importlib"
anyio_mode = "auto"
xfail_strict = true
addopts = [
    "--strict-markers",
    "--strict-config",
    "-ra",
    "--cov",
    "--cov-branch",
    "--cov-report=term-missing:skip-covered",
    "--cov-fail-under=80",
]
markers = [
    "unit: fast isolated tests",
    "integration: tests requiring external services",
    "e2e: end-to-end tests",
    "slow: tests taking >5s",
]
filterwarnings = [
    "error",                             # treat warnings as errors
    "ignore::DeprecationWarning:anyio",  # third-party deprecations
]

[tool.coverage.run]
source_pkgs = ["myproject"]
branch = true
parallel = true

[tool.coverage.report]
fail_under = 80
show_missing = true
skip_covered = true
exclude_also = [
    "if TYPE_CHECKING:",
    "class .*\\bProtocol\\):",
    "@(abc\\.)?abstractmethod",
    "raise NotImplementedError",
    "if __name__ == .__main__.:",
]
```

## Common Pitfalls

**Don't assert on mock call counts unless the count IS the behavior.** `mock.assert_called_once()` is fine for "sends exactly one email". It's pointless for "calls the database" — assert on the result instead.

**Don't test framework code.** If FastAPI validates a Pydantic model, you don't need a test that sends invalid JSON and checks for 422. FastAPI already tests that. Test YOUR validation logic.

**Don't use `conftest.py` as a dumping ground.** If a fixture is used by exactly one test file, put it in that file. conftest is for shared fixtures.

**Don't ignore test warnings.** `filterwarnings = ["error"]` catches real bugs. Add specific ignores for third-party noise, never blanket-ignore.

**Don't use `@pytest.fixture(autouse=True)` unless you really mean it.** It applies to every test in scope, which is rarely what you want. Explicit fixture injection is almost always better.

**Never use `sleep()` in tests.** If you're waiting for an async operation, await it. If you're testing timing, use `time-machine`. If you're testing retries, mock the delay.

## Adapting to Project Context

Before writing tests, check the project for:
- **Existing test patterns** — match them. Consistency beats "better" patterns.
- **`pyproject.toml`** — check for existing pytest config, installed test deps.
- **`conftest.py` files** — understand available fixtures before creating new ones.
- **CI pipeline** — know if tests run in parallel (xdist), if containers are available (Docker-in-CI).
- **The async story** — is the project using asyncio? trio? Is anyio already a dependency?

When the project has no tests yet, set up the infrastructure first: `pyproject.toml` config, root `conftest.py`, directory structure, and a single example test that passes. Then build from there.
