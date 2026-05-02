/**
 * Shared Playwright fixtures for the fastapi-react-local (SQLite) E2E suite.
 *
 * Exports an extended `test` (and `expect`) that:
 *   1. Applies bi-directional trace redaction: strips Authorization / Cookie
 *      from requests AND Set-Cookie from responses so CI trace artifacts do
 *      not leak credentials.
 *
 * Unlike the Postgres sibling in fastapi-react, this pack does NOT enforce
 * a TEST_DATABASE_URL guard. Database isolation is handled by ephemerality:
 * `playwright.config.ts` generates a unique `/tmp/e2e-<uuid>.db` path per
 * test run and passes it to the backend as DATABASE_URL. There is no adopter
 * env-var to misconfigure.
 *
 * See:
 *   - `../playwright.config.ts` for backend DATABASE_URL generation
 *   - `../../agents/tester.md` "Stack-Specific E2E Conventions" for the authoring guide
 */

import { test as base, expect } from "@playwright/test";

export const test = base.extend({
  page: async ({ page }, use) => {
    // Bi-directional trace redaction — identical pattern to the Postgres pack.
    // Keep these in sync: the redaction hook is shared behavior and both packs'
    // agents/tester.md documents the same guarantee.
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
        await route.continue({ headers: requestHeaders });
      }
    });

    await use(page);
  },
});

export { expect };
