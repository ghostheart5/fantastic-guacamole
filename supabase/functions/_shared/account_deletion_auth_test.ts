import { authenticatedDeletionUser } from "./account_deletion_state_machine.ts";
import { hasRecentSignIn } from "../account-delete/recent_sign_in_policy.ts";

const config = {
  supabaseUrl: "https://example.supabase.co",
  publishableKey: "publishable-test-key",
  serviceRoleKey: "service-role-test-key",
};
const now = new Date("2026-09-04T12:00:00.000Z");
const nowSeconds = now.getTime() / 1000;
const userId = "11111111-1111-4111-8111-111111111111";
const oldSessionId = "22222222-2222-4222-8222-222222222222";
const freshSessionId = "33333333-3333-4333-8333-333333333333";

// These are deliberately non-production token fixtures. The injected Auth
// responses exercise the application's trust boundary, not Supabase's actual
// cryptographic verification or a deployed two-device journey.
function authorizationFor(overrides: Record<string, unknown> = {}): string {
  const claims = {
    sub: userId,
    role: "authenticated",
    is_anonymous: false,
    session_id: freshSessionId,
    iat: nowSeconds,
    exp: nowSeconds + 3600,
    amr: [{ method: "password", timestamp: nowSeconds - 10 }],
    ...overrides,
  };
  const payload = btoa(JSON.stringify(claims)).replace(/=/g, "")
    .replace(/\+/g, "-").replace(/\//g, "_");
  return `Bearer eyJhbGciOiJIUzI1NiJ9.${payload}.c2lnbmF0dXJl`;
}

function acceptedByAuth(
  authorization: string,
  overrides: Record<string, unknown> = {},
): typeof fetch {
  return (input, init) => {
    if (String(input) !== `${config.supabaseUrl}/auth/v1/user`) {
      throw new Error("authentication must use the configured Auth server");
    }
    const headers = new Headers(init?.headers);
    if (
      headers.get("Authorization") !== authorization ||
      headers.get("apikey") !== config.publishableKey
    ) {
      throw new Error(
        "Auth must validate the exact presented token, not an admin credential",
      );
    }
    return Promise.resolve(Response.json({
      id: userId,
      email: "test@example.invalid",
      last_sign_in_at: now.toISOString(),
      ...overrides,
    }));
  };
}

Deno.test("two sessions: a fresh account login cannot authorize an older presented session", async () => {
  const oldBearer = authorizationFor({
    session_id: oldSessionId,
    amr: [{ method: "password", timestamp: nowSeconds - 3600 }],
  });
  const freshBearer = authorizationFor();
  const oldUser = await authenticatedDeletionUser(
    oldBearer,
    config,
    acceptedByAuth(oldBearer),
  );
  const freshUser = await authenticatedDeletionUser(
    freshBearer,
    config,
    acceptedByAuth(freshBearer),
  );
  if (!oldUser || !freshUser || oldUser.id !== freshUser.id) {
    throw new Error("both still-valid sessions should identify the same user");
  }
  if (hasRecentSignIn(oldUser.sessionSignInAtSeconds, { now })) {
    throw new Error(
      "another session's login must not authorize account deletion",
    );
  }
  if (!hasRecentSignIn(freshUser.sessionSignInAtSeconds, { now })) {
    throw new Error(
      "the actually reauthenticated session should remain supported",
    );
  }
});

Deno.test("refreshing an old session does not count as recent authentication", async () => {
  const bearer = authorizationFor({
    iat: nowSeconds,
    amr: [
      { method: "password", timestamp: nowSeconds - 3600 },
      { method: "token_refresh", timestamp: nowSeconds },
    ],
  });
  const user = await authenticatedDeletionUser(
    bearer,
    config,
    acceptedByAuth(bearer),
  );
  if (!user || hasRecentSignIn(user.sessionSignInAtSeconds, { now })) {
    throw new Error(
      "refresh iat and token_refresh cannot renew the deletion window",
    );
  }
});

Deno.test("untrusted fresh claims are rejected when Auth rejects the token", async () => {
  const bearer = authorizationFor();
  for (const status of [401, 403, 500]) {
    const user = await authenticatedDeletionUser(
      bearer,
      config,
      () =>
        Promise.resolve(
          Response.json({ id: userId, last_sign_in_at: now.toISOString() }, {
            status,
          }),
        ),
    );
    if (user !== null) {
      throw new Error("rejected/forged bearer must never yield trusted claims");
    }
  }
});

Deno.test("revoked session response rejects a still-unexpired fresh token", async () => {
  const bearer = authorizationFor();
  const user = await authenticatedDeletionUser(
    bearer,
    config,
    () =>
      Promise.resolve(
        Response.json({ code: "session_not_found" }, { status: 403 }),
      ),
  );
  if (user !== null) {
    throw new Error("revoked session must not authorize deletion");
  }
});

Deno.test("malformed bearer cannot reach Auth or authorize deletion", async () => {
  for (
    const bearer of [
      "",
      "Bearer ",
      "Bearer opaque",
      "Bearer a.b.",
      "Basic abc",
      "Bearer a.b.c extra",
    ]
  ) {
    const user = await authenticatedDeletionUser(bearer, config, () => {
      throw new Error(
        "malformed bearer should be rejected before the network call",
      );
    });
    if (user !== null) throw new Error("malformed bearer must fail closed");
  }
});

Deno.test("malformed payload is rejected even if an unexpected Auth response succeeds", async () => {
  for (const payload of ["a", "W10", "bnVsbA", "e30"]) {
    const bearer = `Bearer a.${payload}.b`;
    if (
      await authenticatedDeletionUser(
        bearer,
        config,
        acceptedByAuth(bearer),
      ) !== null
    ) {
      throw new Error("malformed payload must fail closed");
    }
  }
});

Deno.test("subject mismatch, anonymous, privileged and sessionless tokens are rejected", async () => {
  for (
    const claims of [
      { sub: "44444444-4444-4444-8444-444444444444" },
      { role: "service_role" },
      { is_anonymous: true },
      { session_id: null },
      { session_id: "" },
      { session_id: "00000000-0000-0000-0000-000000000000" },
      { session_id: "invalid" },
    ]
  ) {
    const bearer = authorizationFor(claims);
    if (
      await authenticatedDeletionUser(
        bearer,
        config,
        acceptedByAuth(bearer),
      ) !== null
    ) {
      throw new Error(
        "token must match a non-anonymous authenticated user's session",
      );
    }
  }
});

Deno.test("user metadata cannot supply missing session authentication evidence", async () => {
  const bearer = authorizationFor({
    amr: undefined,
    user_metadata: { amr: [{ method: "password", timestamp: nowSeconds }] },
  });
  const user = await authenticatedDeletionUser(
    bearer,
    config,
    acceptedByAuth(bearer, {
      user_metadata: { last_sign_in_at: now.toISOString() },
    }),
  );
  if (!user || user.sessionSignInAtSeconds !== null) {
    throw new Error(
      "missing AMR must deny new deletion while allowing authenticated status lookup",
    );
  }
});

Deno.test("invalid, unknown, refresh-only and anonymous AMR entries fail closed", async () => {
  for (
    const amr of [
      null,
      {},
      [],
      [null],
      ["password"],
      [{ method: "password", timestamp: String(nowSeconds) }],
      [{ method: "password", timestamp: -1 }],
      [{ method: "password", timestamp: nowSeconds - 0.5 }],
      [{ method: "password", timestamp: nowSeconds + 1 }],
      [{ method: "unknown", timestamp: nowSeconds }],
      [{ method: "token_refresh", timestamp: nowSeconds }],
      [{ method: "anonymous", timestamp: nowSeconds }],
      [{ method: "email_change", timestamp: nowSeconds }],
    ]
  ) {
    const bearer = authorizationFor({ amr });
    const user = await authenticatedDeletionUser(
      bearer,
      config,
      acceptedByAuth(bearer),
    );
    if (!user || user.sessionSignInAtSeconds !== null) {
      throw new Error(
        "invalid AMR must not provide recent authentication evidence",
      );
    }
  }
});

Deno.test("supported password/OAuth/OTP methods and later MFA retain recent-auth behavior", async () => {
  for (
    const method of [
      "password",
      "oauth",
      "otp",
      "totp",
      "sso/saml",
      "magiclink",
      "recovery",
      "invite",
      "email/signup",
    ]
  ) {
    const bearer = authorizationFor({
      amr: [
        { method: "password", timestamp: nowSeconds - 3600 },
        { method, timestamp: nowSeconds - 10 },
      ],
    });
    const user = await authenticatedDeletionUser(
      bearer,
      config,
      acceptedByAuth(bearer),
    );
    if (!user || !hasRecentSignIn(user.sessionSignInAtSeconds, { now })) {
      throw new Error(
        `supported authentication method should be accepted: ${method}`,
      );
    }
  }
});
