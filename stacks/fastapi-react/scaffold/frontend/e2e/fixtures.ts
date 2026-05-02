/**
 * Shared Playwright fixtures for the fastapi-react (Postgres) E2E suite.
 *
 * Exports an extended `test` (and `expect`) that:
 *   1. Enforces TEST_DATABASE_URL isolation guards at worker start (fail-fast
 *      before any test runs — prevents accidental destruction of dev data).
 *   2. Applies bi-directional trace redaction: strips Authorization / Cookie
 *      from requests AND Set-Cookie from responses so Playwright traces
 *      uploaded as CI artifacts do not leak credentials.
 *
 * See:
 *   - `../../../.env.test.example` for the TEST_DATABASE_URL naming requirement
 *   - `../playwright.config.ts` for backend DATABASE_URL env propagation
 *   - `../../agents/tester.md` "Stack-Specific E2E Conventions" for the authoring guide
 */

import { test as base, expect } from "@playwright/test";

/**
 * Parse the database name out of a SQLAlchemy-style DSN.
 *
 * DSN shape: `postgresql+asyncpg://user:pass@host:port/dbname?opts=...`
 * Returns the `dbname` portion (between the last `/` and an optional `?`).
 * Returns an empty string if the DSN cannot be parsed.
 */
function extractDatabaseName(dsn: string): string {
  const match = dsn.match(/\/([^/?]+)(?:\?|$)/);
  return match?.[1] ?? "";
}

function assertTestDatabaseIsolation(): void {
  const testUrl = process.env.TEST_DATABASE_URL;
  const devUrl = process.env.DATABASE_URL;

  if (!testUrl || testUrl.trim() === "") {
    throw new Error(
      "TEST_DATABASE_URL env var required. Copy frontend/.env.test.example " +
        "to frontend/.env.test and set a DSN pointing to an ISOLATED test database.",
    );
  }

  if (devUrl && testUrl === devUrl) {
    throw new Error(
      "TEST_DATABASE_URL cannot equal DATABASE_URL (dev DSN collision). " +
        "E2E tests would run destructive migrations against your dev database.",
    );
  }

  const dbName = extractDatabaseName(testUrl).toLowerCase();
  if (!dbName.includes("test_") && !dbName.includes("_test")) {
    throw new Error(
      `TEST_DATABASE_URL database name must contain 'test_' or '_test'. ` +
        `Got database name: "${dbName}". Example: myapp_test or test_myapp.`,
    );
  }
}

// Fail-fast: run guard at module import time. Any test worker that loads
// fixtures.ts will throw before the first test if the adopter's env is wrong.
assertTestDatabaseIsolation();

export const test = base.extend({
  page: async ({ page }, use) => {
    // Bi-directional trace redaction.
    //
    // Request-side: delete Authorization and Cookie before the request is
    // captured by Playwright's trace recorder.
    //
    // Response-side: delete Set-Cookie before the response is recorded. We
    // use route.fetch() to make the upstream call with the redacted request,
    // then route.fulfill() to return a response with Set-Cookie stripped —
    // both halves of the round-trip land in the trace with credentials removed.
    await page.route("**/*", async (route) => {
      const requestHeaders = { ...route.request().headers() };
      delete requestHeaders["authorization"];
      delete requestHeaders["cookie"];

      try {
        const response = await route.fetch({ headers: requestHeaders });
        const responseHeaders = { ...response.headers() };
        delete responseHeaders["set-cookie"];

        await route.fulfill({
          response,
          headers: responseHeaders,
        });
      } catch (error) {
        // Upstream unreachable (e.g., webServer timeout). Continue with
        // original request so Playwright's own failure surfaces instead of
        // a fixture-level exception.
        await route.continue({ headers: requestHeaders });
      }
    });

    await use(page);
  },
});

export { expect };
