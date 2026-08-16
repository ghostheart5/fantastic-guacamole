const configUrl = new URL("../config.toml", import.meta.url);

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function hasVerifyJwt(
  config: string,
  functionName: string,
  expected: boolean,
): boolean {
  const escapedName = functionName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const expression = new RegExp(
    String
      .raw`\[functions\.${escapedName}\]\s*(?:#.*\s*)*verify_jwt\s*=\s*${expected}`,
    "m",
  );
  return expression.test(config);
}

async function functionSource(functionName: string): Promise<string> {
  return await Deno.readTextFile(
    new URL(`./${functionName}/index.ts`, import.meta.url),
  );
}

Deno.test("signed-in Edge Functions require Supabase platform JWT verification", async () => {
  const config = await Deno.readTextFile(configUrl);
  for (
    const functionName of [
      "ai-proxy",
      "monetization-verify",
      "account-delete",
      "strategic-intelligence",
      "verify-receipt",
      "delete-account",
      "webhook-ingest",
    ]
  ) {
    assert(
      hasVerifyJwt(config, functionName, true),
      `${functionName} must set verify_jwt = true`,
    );
  }

  assert(
    (await functionSource("ai-proxy")).includes("authenticatedUserId"),
    "ai-proxy must retain handler-level user verification",
  );
  assert(
    (await functionSource("monetization-verify")).includes(
      "authenticatedUserId",
    ),
    "monetization-verify must retain handler-level user verification",
  );
  assert(
    (await functionSource("account-delete")).includes(
      "authenticatedDeletionUser",
    ),
    "account-delete must retain handler-level user verification",
  );
  assert(
    (await functionSource("strategic-intelligence")).includes(
      "authenticatedUserId",
    ),
    "strategic-intelligence must retain handler-level user verification",
  );
  assert(
    (await functionSource("verify-receipt")).includes("authenticatedUserId"),
    "verify-receipt must retain handler-level user verification",
  );
  assert(
    (await functionSource("delete-account")).includes("auth.getUser(token)"),
    "delete-account must validate the bearer token before destructive work",
  );
  assert(
    (await functionSource("webhook-ingest")).includes(
      "intentionally DB-free",
    ),
    "webhook-ingest must retain its no-database-write contract",
  );
});

Deno.test("non-JWT Edge Functions have an explicit safe caller contract", async () => {
  const config = await Deno.readTextFile(configUrl);

  assert(
    hasVerifyJwt(config, "account-delete-reconcile", false),
    "account-delete-reconcile must use its dedicated internal secret contract",
  );
  assert(
    (await functionSource("account-delete-reconcile")).includes(
      "ACCOUNT_DELETE_RECONCILE_SECRET",
    ),
    "account-delete-reconcile must validate its dedicated internal secret",
  );

  assert(
    hasVerifyJwt(config, "google-play-rtdn", false),
    "google-play-rtdn must accept Google OIDC rather than a Supabase user JWT",
  );
  assert(
    (await functionSource("google-play-rtdn")).includes(
      "validateGoogleOidcPush",
    ),
    "google-play-rtdn must validate the Google OIDC push identity",
  );

  assert(
    hasVerifyJwt(config, "account-delete-status", false),
    "account-delete-status must use its opaque status-verification contract",
  );
  const statusSource = await functionSource("account-delete-status");
  assert(
    statusSource.includes("readBoundedJson") &&
      statusSource.includes("readDeletionStatus"),
    "account-delete-status must bound input and validate the deletion request",
  );
});
