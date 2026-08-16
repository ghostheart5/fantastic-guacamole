import {
  validateGoogleOidcClaims,
  validateGoogleOidcPush,
} from "./google_auth.ts";

function expect(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

Deno.test("Google push validation rejects missing and oversized bearer tokens locally", async () => {
  const originalFetch = globalThis.fetch;
  let fetchCalls = 0;
  globalThis.fetch = (() => {
    fetchCalls++;
    throw new Error("fetch must not be called");
  }) as typeof fetch;
  try {
    const missing = await validateGoogleOidcPush(
      new Request("https://local.invalid"),
      "audience",
      "server@example.test",
    );
    const oversized = await validateGoogleOidcPush(
      new Request("https://local.invalid", {
        headers: { authorization: `Bearer ${"x".repeat(8193)}` },
      }),
      "audience",
      "server@example.test",
    );
    expect(!missing && !oversized, "invalid tokens must be rejected");
    expect(fetchCalls === 0, "invalid tokens must not reach tokeninfo");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("Google push validation checks audience, email, issuer, verification, and expiry", () => {
  const now = Math.floor(Date.now() / 1000);
  const baseClaims = {
    aud: "approved-audience",
    email: "approved-server@example.test",
    email_verified: true,
    iss: "https://accounts.google.com",
    iat: String(now - 30),
    exp: String(now + 300),
  };
  for (
    const [override, expected] of [
      [{}, true],
      [{ aud: "other" }, false],
      [{ email: "other@example.test" }, false],
      [{ email_verified: false }, false],
      [{ iss: "https://issuer.invalid" }, false],
      [{ exp: "1" }, false],
      [{ iat: String(now + 301) }, false],
    ] as const
  ) {
    const accepted = validateGoogleOidcClaims(
      { ...baseClaims, ...override },
      "approved-audience",
      "approved-server@example.test",
      now,
    );
    expect(accepted === expected, "OIDC claim decision did not fail closed");
  }
});

Deno.test("Google push validation treats tokeninfo failure as unauthorized", async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response("unavailable", { status: 503 }),
    )) as typeof fetch;
  try {
    const accepted = await validateGoogleOidcPush(
      new Request("https://local.invalid", {
        headers: { authorization: "Bearer local-test-token" },
      }),
      "approved-audience",
      "approved-server@example.test",
    );
    expect(!accepted, "tokeninfo failure must be unauthorized");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
