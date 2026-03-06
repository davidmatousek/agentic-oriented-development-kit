# Tester — Python FastAPI + React Supplement

## Stack Context

Backend: pytest + pytest-asyncio (auto mode) as the test runner. httpx `AsyncClient` with `ASGITransport(app=app)` for API integration tests. `create_async_engine` with `NullPool` for test database engines. SQLAlchemy async sessions with transaction rollback per test. Frontend: Vitest as the test runner. React Testing Library (`@testing-library/react`) for component tests. `@testing-library/jest-dom` for DOM matchers. `@testing-library/user-event` for realistic interaction simulation. `renderHook` from `@testing-library/react` for custom hook tests. TypeScript strict mode throughout.

## Conventions

- ALWAYS configure pytest-asyncio in `pyproject.toml`: `asyncio_mode = "auto"` and `asyncio_default_fixture_loop_scope = "function"`
- ALWAYS use the three-tier fixture pattern in `tests/conftest.py`: engine (NullPool) -> session (transaction rollback) -> client (AsyncClient with ASGITransport)
- ALWAYS create test engines with `create_async_engine("...", poolclass=NullPool)` — connection pooling breaks function-scoped fixture isolation
- ALWAYS swap the database dependency with `app.dependency_overrides[get_db]` in test fixtures
- ALWAYS call `app.dependency_overrides.clear()` in fixture teardown after every test
- ALWAYS use function-scoped fixtures for database engine, session, and client — maximum isolation between tests
- ALWAYS use transaction rollback per test — begin a transaction before the test, rollback after, so no test data persists
- ALWAYS test both success and error paths for every API endpoint — assert correct status codes, response bodies, and error shapes
- ALWAYS place backend fixtures in `tests/conftest.py`, endpoint tests in `tests/api/`, service tests in `tests/services/`
- ALWAYS use `userEvent` (not `fireEvent`) for simulating frontend user interactions — it fires realistic event sequences
- ALWAYS query DOM elements by accessible roles first: `getByRole`, `getByLabelText`, `getByText` — in that preference order
- ALWAYS wrap components that use TanStack Query hooks in a `QueryClientProvider` with `retry: false` for deterministic test results
- ALWAYS use `renderHook` from `@testing-library/react` to test custom hooks in isolation
- ALWAYS test frontend behavior and user-visible outcomes — what the user sees and does, not how the component is wired internally
- ALWAYS co-locate frontend test files: `Component.test.tsx` next to `Component.tsx`, `useHook.test.ts` next to `useHook.ts`

## Anti-Patterns

- NEVER use class-level or module-level fixture scope for database fixtures — creates coupling and shared state between tests
- NEVER leave `app.dependency_overrides` set between tests — leaking overrides causes cascading test failures
- NEVER connect to a shared database across tests — use function-scoped create/drop or transaction rollback
- NEVER use `session.query()` in tests — use SQLAlchemy 2.0 `select()` syntax exclusively
- NEVER test frontend implementation details: component state values, exact DOM structure, hook return internals
- NEVER mock entire modules when only one export is needed — use `vi.importActual` to preserve real implementations
- NEVER use `fireEvent` when `userEvent` is available — `fireEvent` dispatches raw DOM events that skip realistic browser behavior
- NEVER use `getByTestId` as first-choice query — exhaust accessible queries (`getByRole`, `getByLabelText`, `getByText`) first
- NEVER use snapshot tests as primary strategy — test behavior and visible output instead
- NEVER use synchronous SQLAlchemy patterns (`Session`, `create_engine`) in test fixtures — use `AsyncSession` and `create_async_engine` exclusively
- NEVER hardcode database URLs in test files — load from environment or test configuration

## Guardrails

- Backend coverage: enforce minimum 80% line coverage on `app/services/` and `app/api/` directories
- Frontend coverage: test critical user interactions and data flows. No mandatory coverage thresholds on UI components
- `create_async_engine("...", poolclass=NullPool)` is mandatory in ALL test engine fixtures — no exceptions
- Function-scoped fixtures are mandatory for engine, session, and client — NEVER widen scope for convenience
- Backend test naming: `test_*.py` files with `async def test_*` functions
- Frontend test naming: `*.test.tsx` (components), `*.test.ts` (hooks and utilities)
- Describe blocks in frontend: `describe('ComponentName')` with `it('should {behavior}')` format
- Backend test organization: `tests/conftest.py` (shared fixtures), `tests/api/` (endpoint tests), `tests/services/` (unit tests)
- Frontend test utilities and custom render wrappers live in `tests/` with a setup file that imports `@testing-library/jest-dom`
