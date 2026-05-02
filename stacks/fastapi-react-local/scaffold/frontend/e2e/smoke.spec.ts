import { test, expect } from "./fixtures";

test("smoke: frontend loads and backend /health is reachable", async ({
  page,
  request,
}) => {
  await page.goto("/");

  // App.tsx renders a "Welcome" heading in the scaffold; this asserts the
  // React tree bootstrapped and a visible element rendered.
  await expect(page.getByText(/welcome/i)).toBeVisible();

  const backendPort = process.env.BACKEND_TEST_PORT ?? "8001";
  const response = await request.get(
    `http://127.0.0.1:${backendPort}/health`,
  );
  expect(response.status()).toBe(200);

  const body = await response.json();
  expect(body).toEqual({ status: "ok" });
});
