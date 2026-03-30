# Testing Patterns by Scenario

Organized by what you're testing, not what tools you're using. Each pattern shows the recommended approach, fixtures, and assertions for a specific scenario.

## Table of Contents

1. [FastAPI / Starlette endpoints](#fastapi--starlette-endpoints)
2. [Service layer with external HTTP calls](#service-layer-with-external-http-calls)
3. [Database operations (SQLAlchemy)](#database-operations-sqlalchemy)
4. [Async service orchestration](#async-service-orchestration)
5. [Pydantic model validation](#pydantic-model-validation)
6. [CLI applications (Click / Typer)](#cli-applications)
7. [Time-dependent logic](#time-dependent-logic)
8. [Background tasks and workers](#background-tasks-and-workers)
9. [File processing](#file-processing)
10. [Authentication and authorization](#authentication-and-authorization)
11. [Error handling and retries](#error-handling-and-retries)
12. [Event-driven / message patterns](#event-driven--message-patterns)

---

## FastAPI / Starlette endpoints

### Unit testing routes (mocked dependencies)

```python
from httpx import ASGITransport, AsyncClient

@pytest.fixture
def app_with_mocks(mocker):
    """Override FastAPI dependencies for unit tests."""
    mock_repo = mocker.AsyncMock(spec=UserRepository)
    mock_repo.find_by_id.return_value = User(id=1, name="Alice")

    app.dependency_overrides[get_user_repo] = lambda: mock_repo
    yield app
    app.dependency_overrides.clear()

@pytest.fixture
async def client(app_with_mocks):
    transport = ASGITransport(app=app_with_mocks)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c

async def test_get_user(client):
    resp = await client.get("/users/1")
    assert resp.status_code == 200
    assert resp.json()["name"] == "Alice"

async def test_user_not_found(client, mocker):
    # Override for this specific test
    repo = app.dependency_overrides[get_user_repo]()
    repo.find_by_id.return_value = None

    resp = await client.get("/users/999")
    assert resp.status_code == 404
```

### Integration testing with real DB

```python
@pytest.fixture(scope="session")
def postgres():
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg

@pytest.fixture(scope="session")
async def db_engine(postgres, anyio_backend):
    engine = create_async_engine(postgres.get_connection_url().replace(
        "psycopg2", "asyncpg"
    ))
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()

@pytest.fixture
async def db_session(db_engine):
    async with AsyncSession(db_engine) as session:
        async with session.begin():
            yield session
            await session.rollback()

@pytest.fixture
async def integration_client(db_session):
    def override_session():
        return db_session

    app.dependency_overrides[get_db_session] = override_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()

async def test_create_and_retrieve_user(integration_client):
    create_resp = await integration_client.post("/users", json={"name": "Bob"})
    assert create_resp.status_code == 201
    user_id = create_resp.json()["id"]

    get_resp = await integration_client.get(f"/users/{user_id}")
    assert get_resp.status_code == 200
    assert get_resp.json()["name"] == "Bob"
```

---

## Service layer with external HTTP calls

### Mocking with respx

```python
class TestPaymentService:
    """Tests for PaymentService — Stripe API integration."""

    @pytest.fixture
    def service(self):
        return PaymentService(api_key="sk_test_xxx")

    @pytest.mark.respx(base_url="https://api.stripe.com/v1")
    async def test_create_charge_success(self, service, respx_mock):
        respx_mock.post("/charges").respond(200, json={
            "id": "ch_123", "status": "succeeded", "amount": 2000
        })

        result = await service.charge(amount_cents=2000, token="tok_visa")

        assert result.charge_id == "ch_123"
        assert result.status == "succeeded"

        # Verify the request body
        request = respx_mock.calls.last.request
        assert "amount=2000" in str(request.content)

    @pytest.mark.respx(base_url="https://api.stripe.com/v1")
    async def test_handles_card_declined(self, service, respx_mock):
        respx_mock.post("/charges").respond(402, json={
            "error": {"type": "card_error", "code": "card_declined"}
        })

        with pytest.raises(CardDeclinedError):
            await service.charge(amount_cents=2000, token="tok_declined")

    @pytest.mark.respx(base_url="https://api.stripe.com/v1")
    async def test_retries_on_timeout(self, service, respx_mock):
        route = respx_mock.post("/charges")
        route.side_effect = [
            httpx.ReadTimeout("timeout"),
            httpx.Response(200, json={"id": "ch_123", "status": "succeeded"}),
        ]

        result = await service.charge(amount_cents=2000, token="tok_visa")
        assert result.charge_id == "ch_123"
        assert route.call_count == 2
```

### Testing retry logic

```python
async def test_gives_up_after_max_retries(service, respx_mock):
    respx_mock.post("/charges").mock(side_effect=httpx.ConnectError)

    with pytest.raises(ServiceUnavailableError, match="after 3 retries"):
        await service.charge(amount_cents=1000, token="tok_visa")

    assert respx_mock.calls.call_count == 3
```

---

## Database operations (SQLAlchemy)

### Testing repositories with real DB

```python
class TestUserRepository:
    @pytest.fixture
    def repo(self, db_session):
        return UserRepository(db_session)

    async def test_create_user(self, repo):
        user = await repo.create(name="Alice", email="alice@test.com")

        assert user.id is not None
        assert user.name == "Alice"

        # Verify persistence
        found = await repo.find_by_id(user.id)
        assert found is not None
        assert found.email == "alice@test.com"

    async def test_find_by_email_case_insensitive(self, repo):
        await repo.create(name="Alice", email="Alice@Test.com")

        found = await repo.find_by_email("alice@test.com")
        assert found is not None
        assert found.name == "Alice"

    async def test_unique_email_constraint(self, repo):
        await repo.create(name="Alice", email="alice@test.com")

        with pytest.raises(IntegrityError):
            await repo.create(name="Bob", email="alice@test.com")
```

### Testing with transactions (isolation between tests)

```python
@pytest.fixture
async def db_session(db_engine):
    """Each test runs inside a transaction that gets rolled back."""
    conn = await db_engine.connect()
    trans = await conn.begin()
    session = AsyncSession(bind=conn)

    yield session

    await session.close()
    await trans.rollback()
    await conn.close()
```

---

## Async service orchestration

### Testing concurrent operations

```python
class TestDataPipeline:
    async def test_parallel_fetch_aggregation(self, mocker):
        """Pipeline fetches from 3 sources concurrently and aggregates."""
        mocker.patch.object(SourceA, "fetch", return_value=[1, 2, 3])
        mocker.patch.object(SourceB, "fetch", return_value=[4, 5])
        mocker.patch.object(SourceC, "fetch", return_value=[6])

        result = await Pipeline().aggregate()

        assert sorted(result) == [1, 2, 3, 4, 5, 6]

    async def test_partial_failure_returns_available_data(self, mocker):
        """If one source fails, pipeline returns data from the others."""
        mocker.patch.object(SourceA, "fetch", return_value=[1, 2])
        mocker.patch.object(SourceB, "fetch",
                          side_effect=ConnectionError("timeout"))
        mocker.patch.object(SourceC, "fetch", return_value=[3])

        result = await Pipeline(fail_strategy="partial").aggregate()

        assert sorted(result) == [1, 2, 3]
```

### Testing cancellation

```python
async def test_cancels_remaining_on_first_result():
    """Race pattern: first successful response wins, others cancel."""
    slow = asyncio.Event()

    async def slow_source():
        await slow.wait()  # never completes
        return "slow"

    async def fast_source():
        return "fast"

    result = await race_fetch([slow_source, fast_source])
    assert result == "fast"
```

---

## Pydantic model validation

### Testing with polyfactory

```python
@register_fixture
class OrderCreateFactory(ModelFactory[OrderCreate]):
    __allow_none_optionals__ = 0

class TestOrderValidation:
    def test_valid_order(self, order_create_factory):
        order = order_create_factory.build()
        assert OrderCreate.model_validate(order.model_dump())

    def test_negative_quantity_rejected(self, order_create_factory):
        with pytest.raises(ValidationError, match="quantity"):
            order_create_factory.build(quantity=-1)

    def test_all_type_branches(self, order_create_factory):
        """Cover every Optional/Union variant."""
        for order in order_create_factory.coverage():
            data = order.model_dump()
            assert OrderCreate.model_validate(data)
```

### Property-based model testing

```python
@given(st.from_type(OrderCreate))
def test_model_roundtrip(order):
    """Any valid OrderCreate survives dump → validate cycle."""
    data = order.model_dump(mode="json")
    restored = OrderCreate.model_validate(data)
    assert restored == order
```

---

## CLI applications

### Testing Click/Typer CLIs

```python
from click.testing import CliRunner
from typer.testing import CliRunner as TyperRunner

@pytest.fixture
def runner():
    return CliRunner(mix_stderr=False)

class TestMyCLI:
    def test_help_shows_usage(self, runner):
        result = runner.invoke(app, ["--help"])
        assert result.exit_code == 0
        assert "Usage:" in result.output

    def test_process_file(self, runner, tmp_path):
        input_file = tmp_path / "input.csv"
        input_file.write_text("a,b\n1,2\n3,4")
        output_file = tmp_path / "output.json"

        result = runner.invoke(app, ["process", str(input_file),
                                     "--output", str(output_file)])

        assert result.exit_code == 0
        assert output_file.exists()
        data = json.loads(output_file.read_text())
        assert len(data) == 2

    def test_invalid_file_shows_error(self, runner):
        result = runner.invoke(app, ["process", "/nonexistent.csv"])
        assert result.exit_code != 0
        assert "Error" in result.output or "Error" in result.stderr
```

---

## Time-dependent logic

### Token expiry, scheduling, TTL

```python
class TestTokenExpiry:
    @pytest.fixture
    def frozen(self):
        with time_machine.travel("2025-01-01 12:00:00+00:00", tick=False) as t:
            yield t

    def test_token_valid_within_ttl(self, frozen):
        token = create_token(ttl_seconds=3600)
        frozen.shift(datetime.timedelta(minutes=59))
        assert token.is_valid()

    def test_token_expired_after_ttl(self, frozen):
        token = create_token(ttl_seconds=3600)
        frozen.shift(datetime.timedelta(hours=1, seconds=1))
        assert not token.is_valid()

    def test_cron_schedule_next_run(self, frozen):
        schedule = CronSchedule("0 9 * * MON")  # every Monday 9am
        next_run = schedule.next_after(datetime.datetime.now(datetime.UTC))
        assert next_run.weekday() == 0  # Monday
        assert next_run.hour == 9
```

### Rate limiting

```python
def test_rate_limiter(frozen):
    limiter = RateLimiter(max_calls=3, window_seconds=60)

    for _ in range(3):
        assert limiter.allow()

    assert not limiter.allow()   # exceeded

    frozen.shift(datetime.timedelta(seconds=61))
    assert limiter.allow()       # window reset
```

---

## Background tasks and workers

### Testing async workers

```python
class TestEmailWorker:
    async def test_processes_queued_email(self, mocker):
        mock_send = mocker.patch("myapp.email.smtp_send", new_callable=mocker.AsyncMock)
        queue = asyncio.Queue()
        await queue.put(Email(to="bob@test.com", subject="Hi"))

        worker = EmailWorker(queue)
        await worker.process_one()

        mock_send.assert_awaited_once()
        assert queue.empty()

    async def test_dead_letter_on_permanent_failure(self, mocker):
        mocker.patch("myapp.email.smtp_send",
                    side_effect=InvalidRecipientError("bounce"))
        dead_letter = mocker.AsyncMock()

        queue = asyncio.Queue()
        await queue.put(Email(to="invalid", subject="Hi"))

        worker = EmailWorker(queue, dead_letter_queue=dead_letter)
        await worker.process_one()

        dead_letter.put.assert_awaited_once()
```

---

## File processing

### Using tmp_path for isolation

```python
class TestCSVProcessor:
    @pytest.fixture
    def sample_csv(self, tmp_path):
        f = tmp_path / "data.csv"
        f.write_text("name,age\nAlice,30\nBob,25\n")
        return f

    def test_parses_csv(self, sample_csv):
        rows = CSVProcessor.parse(sample_csv)
        assert len(rows) == 2
        assert rows[0]["name"] == "Alice"

    def test_handles_empty_file(self, tmp_path):
        empty = tmp_path / "empty.csv"
        empty.write_text("")
        assert CSVProcessor.parse(empty) == []

    def test_writes_output(self, tmp_path, sample_csv):
        output = tmp_path / "output.json"
        CSVProcessor.convert(sample_csv, output)

        assert output.exists()
        data = json.loads(output.read_text())
        assert len(data) == 2
```

---

## Authentication and authorization

### Testing auth middleware

```python
class TestAuthMiddleware:
    @pytest.fixture
    def valid_token(self, frozen):
        """Frozen time ensures token never expires during test."""
        return create_jwt(user_id=1, role="admin", ttl=3600)

    async def test_valid_token_passes(self, client, valid_token):
        resp = await client.get("/protected",
                               headers={"Authorization": f"Bearer {valid_token}"})
        assert resp.status_code == 200

    async def test_missing_token_returns_401(self, client):
        resp = await client.get("/protected")
        assert resp.status_code == 401

    async def test_expired_token_returns_401(self, client, frozen):
        token = create_jwt(user_id=1, role="user", ttl=60)
        frozen.shift(datetime.timedelta(seconds=61))

        resp = await client.get("/protected",
                               headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 401

    async def test_insufficient_role_returns_403(self, client):
        token = create_jwt(user_id=1, role="viewer")
        resp = await client.delete("/admin/users/1",
                                  headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 403
```

---

## Error handling and retries

### Testing retry decorators

```python
class TestRetryMechanism:
    async def test_retries_transient_errors(self, mocker):
        call_count = 0
        async def flaky_fn():
            nonlocal call_count
            call_count += 1
            if call_count < 3:
                raise ConnectionError("transient")
            return "success"

        result = await retry(flaky_fn, max_attempts=3, backoff=0)
        assert result == "success"
        assert call_count == 3

    async def test_raises_after_max_retries(self):
        async def always_fails():
            raise ConnectionError("permanent")

        with pytest.raises(ConnectionError):
            await retry(always_fails, max_attempts=3, backoff=0)

    async def test_no_retry_on_non_retryable_error(self, mocker):
        call_count = 0
        async def bad_input():
            nonlocal call_count
            call_count += 1
            raise ValueError("bad input")  # not retryable

        with pytest.raises(ValueError):
            await retry(bad_input, max_attempts=3, backoff=0,
                       retryable=(ConnectionError,))
        assert call_count == 1
```

---

## Event-driven / message patterns

### Testing event handlers

```python
class TestOrderEventHandler:
    @pytest.fixture
    def handler(self, mocker):
        return OrderEventHandler(
            email_service=mocker.AsyncMock(spec=EmailService),
            inventory_service=mocker.AsyncMock(spec=InventoryService),
        )

    async def test_order_created_sends_confirmation(self, handler):
        event = OrderCreatedEvent(order_id="ord-123", user_email="alice@test.com")

        await handler.handle(event)

        handler.email_service.send_confirmation.assert_awaited_once_with(
            to="alice@test.com", order_id="ord-123"
        )

    async def test_order_created_reserves_inventory(self, handler):
        event = OrderCreatedEvent(
            order_id="ord-123",
            user_email="alice@test.com",
            items=[{"sku": "WIDGET-1", "qty": 2}],
        )

        await handler.handle(event)

        handler.inventory_service.reserve.assert_awaited_once_with(
            items=[{"sku": "WIDGET-1", "qty": 2}]
        )

    async def test_email_failure_does_not_block_inventory(self, handler):
        handler.email_service.send_confirmation.side_effect = SMTPError("down")
        event = OrderCreatedEvent(order_id="ord-123", user_email="alice@test.com",
                                 items=[{"sku": "W-1", "qty": 1}])

        await handler.handle(event)  # should not raise

        # Inventory still reserved despite email failure
        handler.inventory_service.reserve.assert_awaited_once()
```

### Testing pub/sub with in-memory broker

```python
@pytest.fixture
def broker():
    """In-memory event broker for testing pub/sub without infrastructure."""
    return InMemoryBroker()

async def test_subscriber_receives_published_event(broker):
    received = []
    await broker.subscribe("order.created", lambda e: received.append(e))

    await broker.publish("order.created", {"order_id": "123"})
    await asyncio.sleep(0)  # yield to event loop

    assert len(received) == 1
    assert received[0]["order_id"] == "123"
```
