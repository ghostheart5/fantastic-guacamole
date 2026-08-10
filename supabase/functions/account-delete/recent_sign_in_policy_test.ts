import { hasRecentSignIn } from "./recent_sign_in_policy.ts";

const now = Date.parse("2026-08-09T18:00:00.000Z");

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, received ${actual}`);
  }
}

Deno.test("accepts provider sign-in just inside the configured window", () => {
  assertEquals(
    hasRecentSignIn("2026-08-09T17:50:00.001Z", {
      now,
      recentSignInSeconds: 600,
    }),
    true,
  );
});

Deno.test("rejects provider sign-in at the configured boundary", () => {
  assertEquals(
    hasRecentSignIn("2026-08-09T17:50:00.000Z", {
      now,
      recentSignInSeconds: 600,
    }),
    false,
  );
});

Deno.test("rejects missing, invalid, stale, and implausibly future dates", () => {
  assertEquals(hasRecentSignIn(null, { now }), false);
  assertEquals(hasRecentSignIn("invalid", { now }), false);
  assertEquals(hasRecentSignIn("2026-08-09T17:00:00.000Z", { now }), false);
  assertEquals(
    hasRecentSignIn("2026-08-09T18:02:00.001Z", {
      now,
      allowedClockSkewSeconds: 120,
    }),
    false,
  );
});
