import {
  DEFAULT_RECENT_SIGN_IN_SECONDS,
  hasRecentSignIn,
} from "./recent_sign_in_policy.ts";

const now = new Date("2026-08-27T14:00:00.000Z");

Deno.test("accepts a recent sign-in inside the deletion window", () => {
  const signedInAt = now.getTime() / 1000 -
    (DEFAULT_RECENT_SIGN_IN_SECONDS - 1);
  if (!hasRecentSignIn(signedInAt, { now })) {
    throw new Error("recent sign-in should be accepted");
  }
});

Deno.test("rejects missing, invalid, future, and stale sign-ins", () => {
  const stale = now.getTime() / 1000 - (DEFAULT_RECENT_SIGN_IN_SECONDS + 1);
  const future = now.getTime() / 1000 + 1;
  for (const value of [null, NaN, Infinity, 0, -1, 1.5, stale, future]) {
    if (hasRecentSignIn(value, { now })) {
      throw new Error(`sign-in should be rejected: ${value}`);
    }
  }
});

Deno.test("accepts exactly the configured recent authentication boundary", () => {
  if (
    !hasRecentSignIn(now.getTime() / 1000 - DEFAULT_RECENT_SIGN_IN_SECONDS, {
      now,
    })
  ) {
    throw new Error("the inclusive boundary should be accepted");
  }
});

Deno.test("rejects invalid windows and invalid clocks", () => {
  const signedInAt = now.getTime() / 1000;
  for (const recentSignInSeconds of [NaN, Infinity, 0, -1]) {
    if (hasRecentSignIn(signedInAt, { now, recentSignInSeconds })) {
      throw new Error("invalid window must fail closed");
    }
  }
  if (hasRecentSignIn(signedInAt, { now: new Date("invalid") })) {
    throw new Error("invalid clock must fail closed");
  }
});
