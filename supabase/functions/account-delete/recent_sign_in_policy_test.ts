import {
  DEFAULT_RECENT_SIGN_IN_SECONDS,
  hasRecentSignIn,
} from "./recent_sign_in_policy.ts";

const now = new Date("2026-08-27T14:00:00.000Z");

Deno.test("accepts a recent sign-in inside the deletion window", () => {
  const signedInAt = new Date(
    now.getTime() - (DEFAULT_RECENT_SIGN_IN_SECONDS - 1) * 1000,
  ).toISOString();
  if (!hasRecentSignIn(signedInAt, { now })) {
    throw new Error("recent sign-in should be accepted");
  }
});

Deno.test("rejects missing, invalid, future, and stale sign-ins", () => {
  const stale = new Date(
    now.getTime() - (DEFAULT_RECENT_SIGN_IN_SECONDS + 1) * 1000,
  ).toISOString();
  const future = new Date(now.getTime() + 1000).toISOString();
  for (const value of [null, "invalid", stale, future]) {
    if (hasRecentSignIn(value, { now })) {
      throw new Error(`sign-in should be rejected: ${value}`);
    }
  }
});
