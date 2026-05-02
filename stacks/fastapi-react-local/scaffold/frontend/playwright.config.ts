/**
 * Playwright configuration for the fastapi-react-local (SQLite) scaffold.
 *
 * Generates a per-run ephemeral SQLite file at `/tmp/e2e-<uuid>.db` and
 * passes its path to the backend subprocess as DATABASE_URL. No adopter
 * env-var configuration is required — the fixture is self-contained.
 *
 * Contract references:
 *   - `frontend/e2e/fixtures.ts` — trace redaction (no DB guard needed here)
 *   - Declaration: `stacks/fastapi-react-local/STACK.md` contract block (e2e_command)
 */

import { randomUUID } from "node:crypto";
import { defineConfig } from "@playwright/test";

const backendPort = process.env.BACKEND_TEST_PORT ?? "8001";
const frontendPort = process.env.FRONTEND_TEST_PORT ?? "5173";

// Generated once per Playwright CLI invocation (module load time). All
// workers within this run share the same ephemeral database file. A fresh
// run picks a new UUID so state never leaks across runs.
const ephemeralDbPath = `/tmp/e2e-${randomUUID()}.db`;
const ephemeralDatabaseUrl = `sqlite+aiosqlite:///${ephemeralDbPath}`;

export default defineConfig({
  testDir: "./e2e",
  testIgnore: /\.template\.ts$/,
  timeout: 60_000,
  retries: 2,
  workers: 1,
  reporter: [["list"]],
  use: {
    baseURL: `http://127.0.0.1:${frontendPort}`,
    trace: "on-first-retry",
  },
  // Best-effort teardown: delete the ephemeral DB after the run. If this
  // file is missing or unwritable we log and move on — OS /tmp rotation
  // handles the long-tail case.
  globalTeardown: "./e2e/global-teardown.ts",
  webServer: [
    {
      command: `bash -c "alembic upgrade head && uvicorn app.main:app --host 127.0.0.1 --port ${backendPort}"`,
      cwd: "../backend",
      url: `http://127.0.0.1:${backendPort}/health`,
      timeout: 120_000,
      reuseExistingServer: !process.env.CI,
      stdout: "pipe",
      stderr: "pipe",
      env: {
        DATABASE_URL: ephemeralDatabaseUrl,
        E2E_SQLITE_DB_PATH: ephemeralDbPath,
      },
    },
    {
      command: `npm run dev -- --host 127.0.0.1 --port ${frontendPort}`,
      url: `http://127.0.0.1:${frontendPort}`,
      timeout: 60_000,
      reuseExistingServer: !process.env.CI,
      stdout: "pipe",
      stderr: "pipe",
    },
  ],
});

// Export for the globalTeardown module to read (process env won't carry
// through after Playwright tears down webServer subprocesses).
export { ephemeralDbPath };
