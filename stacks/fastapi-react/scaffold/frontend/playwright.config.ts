/**
 * Playwright configuration for the fastapi-react (Postgres) scaffold.
 *
 * Runs a backend uvicorn subprocess and a frontend Vite subprocess via
 * Playwright's built-in webServer. The backend receives TEST_DATABASE_URL
 * as DATABASE_URL so alembic migrations + request handlers hit the test
 * database, never the adopter's dev DB.
 *
 * Contract references:
 *   - `frontend/e2e/fixtures.ts` — enforces TEST_DATABASE_URL guards + trace redaction
 *   - `frontend/.env.test.example` — documents the TEST_DATABASE_URL naming rule
 *   - Declaration: `stacks/fastapi-react/STACK.md` contract block (e2e_command)
 */

import { defineConfig } from "@playwright/test";

const backendPort = process.env.BACKEND_TEST_PORT ?? "8001";
const frontendPort = process.env.FRONTEND_TEST_PORT ?? "5173";

export default defineConfig({
  testDir: "./e2e",
  // Exclude _templates/ — adopter templates ship as .template.ts and should
  // not execute as tests until an adopter renames them to .spec.ts.
  testIgnore: /\.template\.ts$/,
  timeout: 60_000,
  retries: 2,
  workers: 1,
  reporter: [["list"]],
  use: {
    baseURL: `http://127.0.0.1:${frontendPort}`,
    trace: "on-first-retry",
  },
  webServer: [
    {
      // Backend: run alembic migrations against TEST_DATABASE_URL, then boot
      // uvicorn bound to 127.0.0.1 (not localhost — avoids IPv6 drift on CI).
      // DATABASE_URL is propagated via env: below so the subprocess picks up
      // the test DSN rather than any dev .env.
      command: `bash -c "alembic upgrade head && uvicorn app.main:app --host 127.0.0.1 --port ${backendPort}"`,
      cwd: "../backend",
      url: `http://127.0.0.1:${backendPort}/health`,
      timeout: 120_000,
      reuseExistingServer: !process.env.CI,
      stdout: "pipe",
      stderr: "pipe",
      env: {
        DATABASE_URL: process.env.TEST_DATABASE_URL ?? "",
        // SECRET_KEY is required by app/config.py (no default). Default to a
        // test-only value so fresh scaffolds boot without a backend/.env.
        // Adopters can override by exporting TEST_SECRET_KEY in their shell.
        SECRET_KEY:
          process.env.TEST_SECRET_KEY ?? "test-secret-key-e2e-only",
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
