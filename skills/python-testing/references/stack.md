# Testing Stack Reference

Quick-reference for every library in the recommended Python testing stack. Look up syntax here; see `patterns.md` for when and how to combine them.

## Table of Contents

1. [pytest core](#pytest-core)
2. [anyio (async testing)](#anyio-async-testing)
3. [pytest-mock](#pytest-mock)
4. [respx (httpx mocking)](#respx-httpx-mocking)
5. [time-machine](#time-machine)
6. [testcontainers](#testcontainers)
7. [pytest-cov + coverage](#pytest-cov--coverage)
8. [pytest-xdist](#pytest-xdist)
9. [dirty-equals](#dirty-equals)
10. [inline-snapshot](#inline-snapshot)
11. [hypothesis](#hypothesis)
12. [polyfactory](#polyfactory)
13. [pytest-sugar](#pytest-sugar)

---

## pytest core

**Version**: ≥9.0 | **Config**: `pyproject.toml` under `[tool.pytest.ini_options]`

### Key fixtures (built-in)

```python
def test_with_builtins(tmp_path, monkeypatch, capsys, request):
    tmp_path          # pathlib.Path to a unique temp directory (function-scoped)
    monkeypatch       # setattr, setenv, delattr, delenv, syspath_prepend, chdir
    capsys            # capture stdout/stderr: out, err = capsys.readouterr()
    request           # test metadata: request.node.name, request.param, etc.
```

### Parametrize

```python
@pytest.mark.parametrize("input_val,expected", [
    ("hello", 5),
    ("", 0),
    ("  spaces  ", 10),
], ids=["normal", "empty", "with-spaces"])
def test_string_length(input_val, expected):
    assert len(input_val) == expected
```

### Exception testing

```python
def test_raises_value_error():
    with pytest.raises(ValueError, match=r"must be positive"):
        process_amount(-1)

def test_raises_and_inspect():
    with pytest.raises(ValidationError) as exc_info:
        validate(bad_data)
    assert exc_info.value.error_count() == 2
```

### Markers

```python
@pytest.mark.skip(reason="not implemented yet")
@pytest.mark.skipif(sys.platform == "win32", reason="unix only")
@pytest.mark.xfail(reason="known bug #123", strict=True)  # strict: fail if it passes
@pytest.mark.parametrize(...)
@pytest.mark.slow       # custom marker, must register in pyproject.toml
@pytest.mark.anyio       # for async tests
```

---

## anyio (async testing)

**Version**: anyio ≥4.13.0 | **Plugin**: built-in, auto-activates | **NOT pytest-asyncio**

The pytest plugin ships inside `anyio` itself. The `pytest-anyio` package on PyPI is a 0.0.0 placeholder — don't install it separately.

### Configuration

```toml
[tool.pytest.ini_options]
anyio_mode = "auto"   # all async test functions auto-detected
```

### Backend pinning (almost always needed)

```python
# conftest.py — pin to asyncio unless you actually test Trio
@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"
```

Without this, anyio parametrizes every async test across ALL installed backends (asyncio + trio if trio is installed), which doubles your test count.

### Async fixtures

```python
# Regular @pytest.fixture works for async — no special decorator needed
@pytest.fixture
async def client():
    async with httpx.AsyncClient(base_url="http://test") as c:
        yield c

# Session-scoped async fixtures need a matching session-scoped anyio_backend
@pytest.fixture(scope="session")
async def database(anyio_backend):  # anyio_backend dependency required
    db = await Database.connect("sqlite+aiosqlite:///test.db")
    yield db
    await db.disconnect()
```

### Writing async tests

```python
# In auto mode, no marker needed — just make the function async
async def test_fetch_user(client):
    response = await client.get("/users/1")
    assert response.status_code == 200

# Explicit marker (needed if anyio_mode != "auto")
@pytest.mark.anyio
async def test_with_marker():
    await some_async_operation()
```

### Task groups in tests

```python
async def test_concurrent_operations():
    async with anyio.create_task_group() as tg:
        results = []
        async def worker(n):
            results.append(await compute(n))
        for i in range(5):
            tg.start_soon(worker, i)
    assert len(results) == 5
```

### Critical gotchas

- Never combine `anyio_mode = "auto"` with `asyncio_mode = "auto"` — plugin conflict
- Add `addopts = ["-p", "no:asyncio"]` if pytest-asyncio is installed alongside anyio
- Sync test functions receiving async fixtures get raw coroutine objects, not awaited results
- `scope="session"` async fixtures must depend on `anyio_backend` at the same scope

---

## pytest-mock

**Version**: ≥3.14 | **Fixture**: `mocker` (auto-injected, auto-cleanup)

### Core API

```python
def test_with_mocks(mocker: MockerFixture):
    # Patch a function/method — ALWAYS use autospec=True
    mock_send = mocker.patch("myapp.email.send_email", autospec=True)
    mock_send.return_value = {"status": "sent"}

    # Patch an object's method
    mocker.patch.object(UserRepo, "find_by_email", return_value=None)

    # Spy — calls the real function but records calls
    spy = mocker.spy(UserService, "validate_email")
    result = UserService.validate_email("a@b.com")
    spy.assert_called_once_with("a@b.com")
    assert spy.spy_return is True          # real return value
    assert spy.spy_return_list == [True]   # all returns

    # Stub — a callable that accepts anything, returns None
    callback = mocker.stub(name="on_complete")

    # Stop a specific mock mid-test
    mocker.stop(mock_send)
```

### Patch targets

```python
# RULE: patch where the object is USED, not where it's DEFINED
# If myapp/services.py does: from myapp.email import send_email
mocker.patch("myapp.services.send_email")    # correct
mocker.patch("myapp.email.send_email")       # wrong — bypasses the import

# For methods on instances, patch the class
mocker.patch.object(MyClient, "fetch", return_value=data)
```

### Async mocks

```python
async def test_async_mock(mocker):
    mock_fetch = mocker.patch("myapp.client.fetch_data", new_callable=mocker.AsyncMock)
    mock_fetch.return_value = {"data": [1, 2, 3]}

    result = await MyService().get_data()
    mock_fetch.assert_awaited_once()
```

### Side effects

```python
# Raise an exception
mocker.patch("myapp.db.connect", side_effect=ConnectionError("timeout"))

# Return different values on successive calls
mocker.patch("myapp.api.poll", side_effect=[None, None, {"ready": True}])

# Custom logic
def fake_send(to, body):
    if "spam" in body:
        raise ValueError("blocked")
    return {"id": "msg-123"}
mocker.patch("myapp.email.send", side_effect=fake_send)
```

---

## respx (httpx mocking)

**Version**: ≥0.22.0 | **For**: httpx-based HTTP clients (sync and async)

### Basic usage

```python
@pytest.mark.respx(base_url="https://api.example.com")
async def test_api_call(respx_mock):
    # Route definition
    respx_mock.get("/users/1").respond(200, json={"id": 1, "name": "Alice"})

    # Your code makes the real httpx call — respx intercepts it
    async with httpx.AsyncClient(base_url="https://api.example.com") as client:
        resp = await client.get("/users/1")

    assert resp.json()["name"] == "Alice"
    assert respx_mock.calls.call_count == 1
```

### Pattern matching

```python
respx_mock.get("/users/", params={"page": 1}).respond(200, json=[...])
respx_mock.post("/users/", json={"name": "Bob"}).respond(201)
respx_mock.route(method="GET", path__regex=r"/users/\d+").respond(200, json={})
respx_mock.route(host="api.stripe.com").respond(200, json={"ok": True})
```

### Side effects and errors

```python
# Simulate network error
respx_mock.get("/health").mock(side_effect=httpx.ConnectError)

# Dynamic response
def dynamic_response(request):
    user_id = request.url.path.split("/")[-1]
    return httpx.Response(200, json={"id": int(user_id)})
respx_mock.get(path__regex=r"/users/\d+").mock(side_effect=dynamic_response)
```

### Assert all routes were called

```python
async def test_all_routes_hit(respx_mock):
    respx_mock.get("/a").respond(200)
    respx_mock.get("/b").respond(200)
    # ... test code ...
    assert respx_mock.calls.call_count == 2
```

### Critical notes

- Create httpx.Client instances INSIDE the mock scope
- For httpx ≥0.28, check respx changelog for transport API changes
- Use `assert_all_called=True` on the marker to fail if any route was never hit
- respx only works with httpx — for `requests` library, use `responses` or `pytest-mock`

---

## time-machine

**Version**: ≥2.13 | **Preferred over freezegun** (100-200× faster, catches C-level time calls)

### As decorator

```python
@time_machine.travel("2025-01-15 10:00:00", tick=False)
def test_morning_greeting():
    assert get_greeting() == "Good morning"

@time_machine.travel("2025-01-15 10:00:00", tick=False)
async def test_async_with_time():
    # Works with async tests too
    result = await schedule_task()
    assert result.scheduled_at.hour == 10
```

### As fixture with traveler

```python
@pytest.fixture
def frozen_time():
    with time_machine.travel("2025-06-15 09:00:00+00:00", tick=False) as traveler:
        yield traveler

def test_token_expiry(frozen_time):
    token = create_token(ttl_seconds=3600)
    assert not token.is_expired()

    frozen_time.shift(datetime.timedelta(hours=1, seconds=1))
    assert token.is_expired()
```

### Key parameters

- `tick=False` — time stays frozen (default for tests)
- `tick=True` — time advances from the starting point, but `time.sleep()` is instant
- `traveler.shift(timedelta)` — move forward/backward relative to current position
- `traveler.move_to(datetime)` — jump to an absolute time

---

## testcontainers

**Version**: ≥4.14 | **Package**: `testcontainers[postgres,redis,...]`

### PostgreSQL

```python
from testcontainers.postgres import PostgresContainer

@pytest.fixture(scope="session")
def postgres():
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg

@pytest.fixture(scope="session")
def db_url(postgres):
    return postgres.get_connection_url()

@pytest.fixture(scope="session")
def engine(db_url):
    engine = create_engine(db_url)
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()

@pytest.fixture
def db_session(engine):
    with Session(engine) as session:
        yield session
        session.rollback()
```

### Redis

```python
from testcontainers.redis import RedisContainer

@pytest.fixture(scope="session")
def redis_container():
    with RedisContainer("redis:7-alpine") as redis:
        yield redis

@pytest.fixture
def redis_client(redis_container):
    client = redis.Redis(
        host=redis_container.get_container_host_ip(),
        port=redis_container.get_exposed_port(6379),
    )
    yield client
    client.flushall()
```

### Generic container

```python
from testcontainers.core.container import DockerContainer
from testcontainers.core.waiting_utils import wait_for_logs

@pytest.fixture(scope="session")
def custom_service():
    container = (DockerContainer("my-service:latest")
        .with_exposed_ports(8080)
        .with_env("APP_ENV", "test"))
    container.start()
    wait_for_logs(container, "Ready to accept connections", timeout=30)
    yield container
    container.stop()
```

### Important notes

- Use `-alpine` images in CI for faster pulls
- `get_connection_url()` returns a SQLAlchemy URL with `psycopg2` driver by default
- With pytest-xdist, each worker gets its own containers — this is correct and desired
- Always use `get_exposed_port()` for port mapping — the host port is random

---

## pytest-cov + coverage

**Version**: pytest-cov ≥7.0, coverage ≥7.10

### Run commands

```bash
pytest --cov --cov-branch --cov-report=term-missing   # quick check
pytest --cov --cov-report=html:htmlcov                  # detailed HTML report
pytest --cov --cov-fail-under=80                        # fail CI if <80%
```

### Configuration → see SKILL.md pyproject.toml section

### Pragmas for excluding code

```python
if TYPE_CHECKING:           # auto-excluded via exclude_also
    from expensive import Module

def abstract_method(self):  # auto-excluded
    raise NotImplementedError

def platform_specific():    # manual exclusion
    if sys.platform == "win32":  # pragma: no cover
        return win32_impl()
```

---

## pytest-xdist

**Version**: ≥3.8 | **Run**: `pytest -n auto --dist worksteal`

### Session fixture sharing across workers

```python
from filelock import FileLock

@pytest.fixture(scope="session")
def db_schema(tmp_path_factory, worker_id):
    if worker_id == "master":
        return _run_migrations()

    root_tmp = tmp_path_factory.getbasetemp().parent
    lock = root_tmp / "db_schema.lock"
    marker = root_tmp / "db_schema.done"

    with FileLock(str(lock)):
        if marker.is_file():
            return  # another worker already migrated
        _run_migrations()
        marker.write_text("done")
```

### Group slow tests together

```python
@pytest.mark.xdist_group(name="database")
class TestDatabaseMigrations:
    def test_forward_migration(self): ...
    def test_backward_migration(self): ...
```

---

## dirty-equals

**Version**: ≥0.11 | **No config needed** — works with plain `assert`

### Common matchers

```python
from dirty_equals import (
    IsPositiveInt, IsNegativeInt, IsFloat, IsNumber,
    IsStr, IsBytes, IsUUID, IsUUID4,
    IsNow, IsDate, IsDatetime,
    IsList, IsDict, IsPartialDict,
    IsJson, IsUrl, IsIP, IsHash,
    IsInstance, AnyThing, IsTrue, IsFalse,
)

assert response == {
    "id": IsPositiveInt,
    "uuid": IsUUID4,
    "name": IsStr(regex=r"^[A-Z][a-z]+$"),
    "score": IsFloat(gt=0, lt=100),
    "created_at": IsNow(delta=3),       # within 3 seconds of now
    "tags": IsList(length=3),
    "metadata": IsPartialDict(type="user"),  # only checks specified keys
}
```

### Composition

```python
assert value == IsStr | IsInt           # union
assert value == IsInt & IsPositiveInt   # intersection
assert value == ~IsNone                 # negation
```

---

## inline-snapshot

**Version**: ≥0.32 | **Config**: none needed, integrates with pytest

### Basic usage

```python
from inline_snapshot import snapshot

def test_user_serialization():
    user = create_user(name="alice")
    assert user.to_dict() == snapshot()  # empty → run with --inline-snapshot=create
```

After running `pytest --inline-snapshot=create`, the source file is rewritten:

```python
def test_user_serialization():
    user = create_user(name="alice")
    assert user.to_dict() == snapshot({"name": "alice", "role": "user"})
```

### With dirty-equals for dynamic fields

```python
from dirty_equals import IsPositiveInt, IsNow

def test_api_response():
    resp = client.post("/users", json={"name": "alice"}).json()
    assert resp == snapshot({
        "id": IsPositiveInt,           # preserved across snapshot updates
        "name": "alice",
        "created_at": IsNow(delta=3),
    })
```

### Commands

```bash
pytest --inline-snapshot=create    # fill empty snapshot() calls
pytest --inline-snapshot=fix       # update failing snapshots
pytest --inline-snapshot=update    # update all snapshots (even passing ones)
pytest --inline-snapshot=trim      # remove unused snapshots
```

**Never run `fix` or `update` in CI.** Tests should fail on snapshot mismatch.
Not compatible with pytest-xdist (source rewriting isn't parallel-safe).

---

## hypothesis

**Version**: ≥6.100 | **Plugin**: built-in, auto-activates

### Profiles

```python
# conftest.py
from hypothesis import settings, HealthCheck
import os

settings.register_profile("ci", max_examples=500, deadline=None,
    suppress_health_check=[HealthCheck.too_slow])
settings.register_profile("dev", max_examples=10)
settings.load_profile(os.getenv("HYPOTHESIS_PROFILE", "dev"))
```

### Core patterns

```python
from hypothesis import given, example, assume, settings
from hypothesis import strategies as st

@given(st.text(min_size=1))
def test_strip_is_idempotent(s):
    assert s.strip().strip() == s.strip()

# Composite strategy
@st.composite
def valid_email(draw):
    local = draw(st.from_regex(r"[a-z]{1,20}", fullmatch=True))
    domain = draw(st.sampled_from(["example.com", "test.org"]))
    return f"{local}@{domain}"

@given(valid_email())
def test_email_parsing(email):
    parsed = parse_email(email)
    assert "@" in parsed.full_address

# Explicit regression case
@example(n=0)
@example(n=-1)
@given(st.integers())
def test_absolute_value(n):
    assert abs(n) >= 0

# Pydantic model strategy (auto-plugin)
@given(st.from_type(UserCreate))
def test_user_model_roundtrip(user_input):
    data = user_input.model_dump()
    assert UserCreate.model_validate(data) == user_input
```

### Settings decorator (must be ABOVE @given)

```python
@settings(max_examples=200, deadline=datetime.timedelta(seconds=1))
@given(st.lists(st.integers(), min_size=1))
def test_sorting(xs):
    sorted_xs = sorted(xs)
    assert sorted_xs[0] == min(xs)
```

---

## polyfactory

**Version**: ≥3.0 | **For**: Pydantic models, dataclasses, TypedDict, attrs

### Basic factory

```python
from polyfactory.factories.pydantic_factory import ModelFactory
from polyfactory.pytest_plugin import register_fixture

class User(BaseModel):
    id: UUID
    name: str
    email: EmailStr
    role: Literal["admin", "user"]

@register_fixture
class UserFactory(ModelFactory[User]):
    __allow_none_optionals__ = 0     # never generate None for Optional fields

# Fixture name is snake_case of class: user_factory
def test_create_user(user_factory):
    user = user_factory.build()            # single instance
    users = user_factory.batch(size=10)    # multiple instances
    admin = user_factory.build(role="admin")  # with overrides
```

### Nested models

```python
class Order(BaseModel):
    id: UUID
    user: User
    items: list[OrderItem]

@register_fixture
class OrderFactory(ModelFactory[Order]):
    pass

def test_order(order_factory):
    order = order_factory.build()
    assert len(order.items) > 0       # auto-generates nested models
    assert isinstance(order.user, User)
```

### Coverage mode

```python
def test_all_branches(user_factory):
    # Generates instances covering all Optional/Union branches
    for user in user_factory.coverage():
        assert validate_user(user)  # tests every type variant
```

---

## pytest-sugar

**Version**: ≥1.0 | **Config**: none — auto-activates on install

Provides a progress bar and instant failure display. Disable with `-p no:sugar` when you need raw output. Mutually exclusive with pytest-pretty — don't install both.

---

## Dependency group

```toml
[dependency-groups]
test = [
    "pytest>=9.0",
    "anyio[trio]>=4.13",
    "pytest-cov>=7.0",
    "pytest-xdist[psutil]>=3.8",
    "pytest-mock>=3.14",
    "time-machine>=2.13",
    "dirty-equals>=0.11",
    "hypothesis>=6.100",
    "polyfactory>=3.0",
    "respx>=0.22",
    "testcontainers[postgres,redis]>=4.14",
    "inline-snapshot>=0.32",
    "pytest-sugar>=1.0",
    "filelock>=3.12",
]
```

Trim to what your project actually needs. Not every project needs testcontainers or hypothesis.
