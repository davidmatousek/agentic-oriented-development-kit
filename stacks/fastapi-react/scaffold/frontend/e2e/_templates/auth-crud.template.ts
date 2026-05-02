/**
 * ADOPTER TEMPLATE — Auth + CRUD E2E example.
 *
 * This file is EXCLUDED from `playwright test` runs (see testIgnore in
 * playwright.config.ts). It exists as a copy-ready reference.
 *
 * To use:
 *   1. Copy this file to a new .spec.ts:
 *      cp e2e/_templates/auth-crud.template.ts e2e/auth-crud.spec.ts
 *   2. Implement a /login page and /items CRUD pages in your scaffold.
 *   3. Replace the placeholder selectors and TODO markers below to match
 *      your actual implementation.
 *
 * The template uses accessibility-first queries (getByRole → getByLabel →
 * getByText). Prefer these over CSS selectors — they survive refactors and
 * double as accessibility checks. See `stacks/fastapi-react/agents/tester.md`
 * "Stack-Specific E2E Conventions" for the full authoring guide.
 */

import { test, expect } from "../fixtures";

test.describe("Auth + CRUD example (adopter template)", () => {
  test("user can log in", async ({ page }) => {
    await page.goto("/login");

    await page.getByLabel(/email/i).fill("test@example.com");
    await page.getByLabel(/password/i).fill("password");
    await page.getByRole("button", { name: /sign in|log in/i }).click();

    // TODO: assert the post-login landing URL matches your app's convention.
    await expect(page).toHaveURL(/dashboard|home|items/);
  });

  test("user can create, read, and delete an item", async ({ page }) => {
    // TODO: establish auth state before this test — either via storageState
    // (recommended: see Playwright's auth recipe) or by repeating the login
    // flow from the previous test.
    await page.goto("/items");

    // Create
    await page.getByRole("button", { name: /new|create/i }).click();
    await page.getByLabel(/name|title/i).fill("Example item");
    await page.getByRole("button", { name: /save|submit/i }).click();
    await expect(page.getByText("Example item")).toBeVisible();

    // Read — the created item is visible in the list.
    await expect(page.getByRole("listitem")).toContainText("Example item");

    // Delete
    await page.getByRole("button", { name: /delete|remove/i }).click();
    await expect(page.getByText("Example item")).not.toBeVisible();
  });
});
