import {
  BASE,
  check,
  deleteOwnedUser,
  hash,
  ProbeError,
  replayComparison,
  route,
  safeFailure,
  SOURCE,
  TREE,
  validateAccounting,
  validateAttestation,
  validateConfig,
  validateOwnedRows,
  verifiedScrubbedTombstones,
  verifyBoundBytes,
} from "./guards.ts";

// This support probe is not part of the release commit. Sources are pinned before import.
const BINDINGS_SHA256 =
  "b79bf7f1ae3b0e2267b644c68dfa7b81d2148422270a3fb3c4888f4a5649b870";
type Obj = Record<string, any>;
type Handler = (req: Request) => Promise<Response>;
const envNames = [
  "AXIOMARA_DISPOSABLE_DB_GATE",
  "LOCAL_SUPABASE_URL",
  "LOCAL_SUPABASE_ANON_KEY",
  "LOCAL_SUPABASE_SERVICE_KEY",
];
function args(argv: string[]) {
  if (argv.length === 1 && argv[0] === "--help") return null;
  check(
    argv.length === 7 && argv[0] === "--execute" &&
      argv[1] === "--source-root" &&
      argv[3] === "--attestation" && argv[5] === "--output",
    "usage_required",
  );
  return { root: argv[2], attestation: argv[4], output: argv[6] };
}
function fileUrl(path: string): URL {
  const normalized = path.replaceAll("\\", "/");
  return new URL(
    "file://" + (normalized.startsWith("/") ? "" : "/") +
      normalized.split("/").map((p, i) =>
        i === 0 && /^[A-Za-z]:$/.test(p) ? p : encodeURIComponent(p)
      ).join("/"),
  );
}
async function verifySources(root: string) {
  const data = await Deno.readFile(
    new URL("./source-bindings.json", import.meta.url),
  );
  check(await hash(data) === BINDINGS_SHA256, "source_manifest_changed");
  const manifest = JSON.parse(new TextDecoder().decode(data));
  check(
    manifest.sourceSha === SOURCE && manifest.sourceTree === TREE,
    "source_identity_mismatch",
  );
  const rootReal = (await Deno.realPath(root)).replaceAll("\\", "/").replace(
    /\/$/,
    "",
  );
  for (const entry of manifest.files) {
    check(
      typeof entry.path === "string" &&
        /^supabase\/(functions|migrations)\/[A-Za-z0-9_./-]+$/.test(
          entry.path,
        ) &&
        !entry.path.split("/").includes(".."),
      "source_path_invalid",
    );
    const path = (await Deno.realPath(rootReal + "/" + entry.path)).replaceAll(
      "\\",
      "/",
    );
    check(path.startsWith(rootReal + "/"), "source_path_escape");
    const bytes = await Deno.readFile(path);
    // Match exact Git blob after only CRLF checkout normalization.
    await verifyBoundBytes(bytes, entry.gitBlobSha256);
  }
  return {
    manifest,
    handlerUrl:
      fileUrl(rootReal + "/supabase/functions/ai-proxy/index.ts").href,
  };
}
async function run() {
  if (
    Deno.args.length === 3 && Deno.args[0] === "--verify-source" &&
    Deno.args[1] === "--source-root"
  ) {
    const verified = await verifySources(Deno.args[2]);
    console.log(
      JSON.stringify({
        status: "PASS",
        mode: "source-binding-only",
        boundFiles: verified.manifest.files.length,
        sourceSha: SOURCE,
        sourceTree: TREE,
        sourceManifestSha256: BINDINGS_SHA256,
      }),
    );
    return;
  }
  const options = args(Deno.args);
  if (!options) {
    console.log(
      "deno run [restricted permissions; see README] reply_recovery_probe.ts --execute --source-root PATH --attestation LOCAL_JSON --output NEW_DIRECTORY",
    );
    return;
  }
  const config = validateConfig(
    Object.fromEntries(envNames.map((name) => [name, Deno.env.get(name)])),
  );
  check(
    (await Deno.permissions.query({
      name: "net",
      host: "api.anthropic.com:443",
    })).state === "denied",
    "external_network_permission_must_be_denied",
  );
  check(
    (await Deno.permissions.query({ name: "net", host: "127.0.0.1:54321" }))
      .state === "granted",
    "local_network_permission_required",
  );
  const attestationBytes = await Deno.readFile(options.attestation);
  validateAttestation(JSON.parse(new TextDecoder().decode(attestationBytes)));
  const source = await verifySources(options.root);
  // Exclusive creation; never continue in/overwrite an earlier output directory.
  await Deno.mkdir(options.output);
  const output = (name: string, value: unknown) =>
    Deno.writeTextFile(
      options.output + "/" + name,
      JSON.stringify(value, null, 2) + "\n",
      { createNew: true },
    );
  const startedAt = new Date().toISOString();
  await output("started.json", {
    sourceSha: SOURCE,
    sourceTree: TREE,
    startedAt,
    attestationSha256: await hash(attestationBytes),
    sourceManifestSha256: BINDINGS_SHA256,
    disposableIdentity:
      "operator attestation plus exact loopback, permission restriction and empty-data guards",
    runCompleted: false,
  });
  const checks: Obj[] = [];
  const counters = {
    localRequests: 0,
    syntheticProviderAttempts: 0,
    externalProviderNetworkCalls: 0,
    blockedTargets: 0,
    ttlSettlements: 0,
    legacySettlements: 0,
    discardedCommittedResponses: 0,
    suppressedHandlerLogs: 0,
  };
  let replayDiagnostics: ReturnType<typeof replayComparison>[] = [];
  const users: Obj[] = [];
  const ownedRequests = new Set<string>();
  const originalFetch = globalThis.fetch;
  const originalServe = Deno.serve;
  const originalEnvGet = Deno.env.get;
  const originalLogs = {
    log: console.log,
    warn: console.warn,
    error: console.error,
    info: console.info,
    debug: console.debug,
  };
  let syntheticAllowed = false;
  let discardSettlement = false;
  let handler: Handler | undefined;
  let mainFailure: string | null = null;
  const cleanupErrors: string[] = [];
  let possiblyUntrackedCreatedUser = false;
  const record = (name: string, details: Obj = {}) =>
    checks.push({ name, status: "PASS", ...details });
  const ownedIds = () => new Set<string>(users.map((u) => u.id));
  function ownMutation(req: Request, body: Obj | null) {
    const url = new URL(req.url);
    if (req.method === "DELETE") {
      check(
        ownedIds().has(url.pathname.split("/").at(-1)!),
        "delete_unowned_user",
      );
    }
    if (req.method === "PATCH") {
      check(
        ownedIds().has((url.searchParams.get("user_id") ?? "").slice(3)) &&
          ownedRequests.has(
            (url.searchParams.get("request_key") ?? "").slice(3),
          ),
        "patch_unowned_usage",
      );
    }
    if (
      url.pathname.startsWith("/rest/v1/rpc/") && body && "p_user_id" in body
    ) {
      check(ownedIds().has(body.p_user_id), "rpc_unowned_user");
    }
    if (url.pathname.endsWith("/ensure_monetization_wallet_for_principal")) {
      check(
        users.some((u) => u.principal === body?.p_billing_principal_id),
        "rpc_unowned_principal",
      );
    }
  }
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    let kind: "local" | "synthetic";
    try {
      kind = route(input, init?.method);
    } catch (e) {
      counters.blockedTargets++;
      throw e;
    }
    const req = new Request(input, init);
    if (kind === "synthetic") {
      counters.syntheticProviderAttempts++;
      check(syntheticAllowed, "unexpected_provider_attempt_on_replay");
      check(
        req.headers.get("x-api-key") === "synthetic-provider-key-not-real",
        "unexpected_provider_key",
      );
      return Response.json({
        id: "synthetic-provider-reply",
        model: "claude-sonnet-4-6",
        stop_reason: "end_turn",
        content: [{ type: "text", text: "Review the visible plan." }],
        usage: { input_tokens: 10, output_tokens: 5 },
      });
    }
    const body = req.method === "POST" || req.method === "PATCH"
      ? await req.clone().json().catch(() => null)
      : null;
    ownMutation(req, body);
    const path = new URL(req.url).pathname;
    if (path.endsWith("/settle_ai_usage_v2")) {
      counters.ttlSettlements++;
      check(
        body?.p_response_ttl === "15 minutes",
        "ttl_overload_not_requested",
      );
    }
    if (path.endsWith("/settle_ai_usage")) counters.legacySettlements++;
    counters.localRequests++;
    let response: Response;
    try {
      response = await originalFetch(
        new Request(req, {
          redirect: "error",
          signal: AbortSignal.any([req.signal, AbortSignal.timeout(12_000)]),
        }),
      );
    } catch {
      throw new ProbeError("local_transport_failed");
    }
    check(
      !response.redirected && new URL(response.url).origin === BASE,
      "local_redirect_blocked",
    );
    if (
      discardSettlement && path.endsWith("/settle_ai_usage_v2") && response.ok
    ) {
      discardSettlement = false;
      await response.arrayBuffer();
      counters.discardedCommittedResponses++;
      throw new DOMException(
        "Synthetic response loss after local commit",
        "TimeoutError",
      );
    }
    return response;
  };
  async function request(
    path: string,
    method = "GET",
    body?: unknown,
    token = config.service,
    admin = true,
  ) {
    const response = await fetch(BASE + path, {
      method,
      headers: {
        apikey: admin ? config.service : config.anon,
        Authorization: "Bearer " + token,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    let data: any = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      throw new ProbeError("local_response_not_json");
    }
    return { ok: response.ok, status: response.status, data };
  }
  async function rpc(name: string, body: Obj) {
    const result = await request("/rest/v1/rpc/" + name, "POST", body);
    check(result.ok, "rpc_failed_" + name);
    return result.data;
  }
  async function rows(
    table: string,
    filters: Obj = {},
    token = config.service,
    admin = true,
  ): Promise<Obj[]> {
    const params = new URLSearchParams({
      select: "*",
      limit: "100",
      ...filters,
    });
    const result = await request(
      "/rest/v1/" + table + "?" + params,
      "GET",
      undefined,
      token,
      admin,
    );
    check(
      result.ok && Array.isArray(result.data) && result.data.length < 100,
      "table_read_failed_or_truncated_" + table,
    );
    return result.data;
  }
  async function single(table: string, filters: Obj) {
    const found = await rows(table, filters);
    check(found.length === 1, "expected_one_" + table);
    return found[0];
  }
  async function wallet(user: Obj) {
    return await single("monetization_wallets", {
      billing_principal_id: "eq." + user.principal,
    });
  }
  async function accounting(user: Obj) {
    const current = await wallet(user);
    const tx = await rows("monetization_credit_transactions", {
      billing_principal_id: "eq." + user.principal,
      type: "eq.spend",
      "metadata->>request_key": "eq." + user.requestId,
    });
    validateAccounting(user.before, current, tx, user.credits);
    return {
      balanceBefore: user.before.balance,
      balanceAfter: current.balance,
      debit: user.credits,
      spendRows: tx.length,
    };
  }
  async function usage(user: Obj) {
    return await single("ai_usage_requests", {
      billing_principal_id: "eq." + user.principal,
      request_key: "eq." + user.requestId,
    });
  }
  async function patch(user: Obj, fields: Obj) {
    const q = new URLSearchParams({
      user_id: "eq." + user.id,
      request_key: "eq." + user.requestId,
    });
    const result = await request(
      "/rest/v1/ai_usage_requests?" + q,
      "PATCH",
      fields,
    );
    check(
      result.ok && Array.isArray(result.data) && result.data.length === 1,
      "owned_usage_patch_failed",
    );
  }
  async function invoke(user: Obj, extra: Obj = {}) {
    check(handler, "handler_not_captured");
    const response = await handler(
      new Request(BASE + "/functions/v1/ai-proxy", {
        method: "POST",
        headers: {
          Authorization: "Bearer " + user.access,
          "Content-Type": "application/json",
          "x-forwarded-for": "127.0.0.1",
        },
        body: JSON.stringify({
          prompt: "Help me review this visible plan.",
          personality: "planner",
          context: {},
          maxTokens: 64,
          allowExternalAi: true,
          requestId: user.requestId,
          quote: user.quote,
          ...extra,
        }),
      }),
    );
    return { status: response.status, data: await response.json() };
  }
  async function deleteUser(user: Obj) {
    await deleteOwnedUser(user, request);
  }
  try {
    const initial = await request("/auth/v1/admin/users?page=1&per_page=1");
    check(
      initial.ok && Array.isArray(initial.data?.users) &&
        initial.data.users.length === 0,
      "auth_not_empty",
    );
    for (
      const table of [
        "ai_usage_requests",
        "billing_principals",
        "monetization_wallets",
        "monetization_credit_transactions",
      ]
    ) {
      check(
        (await rows(table, { limit: "1" })).length === 0,
        "fresh_database_required_" + table,
      );
    }
    record("fresh_disposable_data_preflight");
    let serveCalls = 0;
    Reflect.set(Deno, "serve", (captured: Handler) => {
      serveCalls++;
      handler = captured;
    });
    Reflect.set(Deno.env, "get", (name: string) => {
      if (name === "SUPABASE_URL") return BASE;
      if (name === "SUPABASE_PUBLISHABLE_KEY" || name === "SUPABASE_ANON_KEY") {
        return config.anon;
      }
      if (
        name === "SUPABASE_SECRET_KEY" || name === "SUPABASE_SERVICE_ROLE_KEY"
      ) return config.service;
      if (name === "ANTHROPIC_API_KEY") {
        return "synthetic-provider-key-not-real";
      }
      if (
        [
          "CHRONOSPARK_PUBLIC_AI_ENABLED",
          "CHRONOSPARK_PUBLIC_AI_PROVIDER_RETENTION_VERIFIED",
          "CHRONOSPARK_PUBLIC_AI_SAFETY_REVIEW_APPROVED",
        ].includes(name)
      ) return "true";
      return undefined;
    });
    for (const key of Object.keys(originalLogs)) {
      Reflect.set(console, key, () => counters.suppressedHandlerLogs++);
    }
    try {
      await import(source.handlerUrl);
    } finally {
      Reflect.set(Deno, "serve", originalServe);
      Reflect.set(Deno.env, "get", originalEnvGet);
    }
    check(
      serveCalls === 1 && typeof handler === "function",
      "handler_capture_failed",
    );
    record("exact_source_handler_captured", {
      boundFiles: source.manifest.files.length,
    });

    for (const label of ["a", "b"]) {
      const email = "reply-probe-" + label + "-" + crypto.randomUUID() +
        "@example.invalid";
      const password = "Synthetic-" + crypto.randomUUID() + "!";
      possiblyUntrackedCreatedUser = true;
      const created = await request("/auth/v1/admin/users", "POST", {
        email,
        password,
        email_confirm: true,
      });
      check(
        created.ok && typeof created.data?.id === "string",
        "synthetic_auth_create_failed",
      );
      const user: Obj = { id: created.data.id, deleted: false };
      users.push(user);
      possiblyUntrackedCreatedUser = false;
      const login = await request(
        "/auth/v1/token?grant_type=password",
        "POST",
        { email, password },
        config.anon,
        false,
      );
      check(
        login.ok && typeof login.data?.access_token === "string",
        "synthetic_auth_login_failed",
      );
      user.access = login.data.access_token;
      user.principal = await rpc("ensure_billing_principal", {
        p_user_id: user.id,
      });
      check(typeof user.principal === "string", "principal_shape");
      await rpc("ensure_monetization_wallet_for_principal", {
        p_billing_principal_id: user.principal,
      });
      user.before = await wallet(user);
      user.requestId = "reply-probe-" + label + "-" + crypto.randomUUID();
      ownedRequests.add(user.requestId);
      const quote = await invoke(user, { quoteOnly: true });
      check(
        quote.status === 200 && Number.isInteger(quote.data?.quote?.credits),
        "quote_failed",
      );
      user.quote = quote.data.quote;
      user.credits = user.quote.credits;
      check(
        user.credits <= Number(user.before.balance),
        "fixture_allowance_insufficient",
      );
      syntheticAllowed = true;
      discardSettlement = label === "a";
      const countBefore = counters.syntheticProviderAttempts;
      let answer;
      try {
        answer = await invoke(user);
      } finally {
        syntheticAllowed = false;
      }
      check(
        answer.status === 200 &&
          answer.data.message === "Review the visible plan." &&
          answer.data.requestId === user.requestId,
        "fresh_handler_response_failed",
      );
      check(
        counters.syntheticProviderAttempts === countBefore + 1,
        "fresh_provider_attempt_count",
      );
      user.answer = answer.data;
      const row = await usage(user);
      check(
        row.state === "completed" &&
          row.response_payload?.message === user.answer.message &&
          row.response_payload?.requestId === user.requestId,
        "committed_payload_missing",
      );
      const remainingMs = Date.parse(row.response_expires_at) - Date.now();
      check(
        remainingMs > 14 * 60_000 && remainingMs <= 15 * 60_000 + 5_000,
        "committed_ttl_invalid",
      );
      const q = { billing_principal_id: "eq." + user.principal };
      const principal = await single("billing_principals", q);
      check(
        principal.current_user_id === user.id && principal.retired_at === null,
        "principal_owner_invalid",
      );
      record(
        label === "a"
          ? "lost_settlement_response_reconciled"
          : "ordinary_ttl_settlement",
        {
          ...await accounting(user),
          committedPayloadAndExpiry: true,
          faultTestedAtomicRollback: false,
          syntheticProviderAttempts: 1,
        },
      );
    }
    const [a, b] = users;
    check(
      counters.discardedCommittedResponses === 1 &&
        counters.legacySettlements === 0,
      "settlement_route_or_fault_not_exercised",
    );
    const baselineAttempts = counters.syntheticProviderAttempts;
    const retries = await Promise.all([invoke(a), invoke(a)]);
    replayDiagnostics = retries.map((r) =>
      replayComparison(r.status, r.data, a.answer)
    );
    check(
      replayDiagnostics.every((r) =>
        r.httpStatus === 200 && r.structuralJsonEqual
      ),
      "concurrent_replay_failed",
    );
    record("concurrent_completed_retries", {
      ...await accounting(a),
      cachedReplies: 2,
    });
    const foreign = await rows(
      "ai_usage_requests",
      { request_key: "eq." + a.requestId },
      b.access,
      false,
    );
    check(foreign.length === 0, "cross_account_rls_leak");
    const wrongAccount = await invoke(b, {
      requestId: a.requestId,
      quote: a.quote,
    });
    const wrongRequest = await invoke(a, {
      requestId: "reply-probe-wrong-request",
    });
    check(
      [wrongAccount, wrongRequest].every((r) =>
        r.status === 409 && r.data.error === "credit_quote_required" &&
        !("message" in r.data)
      ),
      "quote_account_or_request_binding_failed",
    );
    record("cross_account_rls_and_quote_scope", {
      rlsForeignRows: 0,
      quoteRejections: 2,
    });
    const originalRow = await usage(a);
    await patch(a, {
      response_payload: { ...a.answer, requestId: "reply-probe-wrong-payload" },
    });
    const malformed = await invoke(a);
    check(
      malformed.status === 409 &&
        malformed.data.error === "request_completed" &&
        !("message" in malformed.data),
      "malformed_payload_replayed",
    );
    await patch(a, { response_payload: a.answer, response_expires_at: null });
    const unbounded = await invoke(a);
    check(
      unbounded.status === 409 &&
        unbounded.data.error === "request_completed" &&
        !("message" in unbounded.data),
      "null_expiry_replayed",
    );
    await patch(a, { response_expires_at: originalRow.response_expires_at });
    record("malformed_payload_and_null_expiry_refused", await accounting(a));
    await patch(a, { response_expires_at: "2020-01-01T00:00:00Z" });
    const expired = await invoke(a);
    check(
      expired.status === 409 && expired.data.error === "request_completed" &&
        !("message" in expired.data),
      "expired_reply_replayed",
    );
    // Recheck ALL usage rows immediately before the global purge; no other fixtures may coexist.
    validateOwnedRows(
      await rows("ai_usage_requests"),
      ownedIds(),
      ownedRequests,
    );
    const beforePurge = await usage(a);
    check(
      Object.keys(beforePurge.response_payload).length > 0,
      "cron_raced_purge_probe_inconclusive",
    );
    const purged = await rpc("purge_expired_ai_response_payloads", {});
    const afterPurge = await usage(a);
    check(
      purged === 1 && Object.keys(afterPurge.response_payload).length === 0 &&
        afterPurge.response_expires_at === null,
      "expiry_purge_not_proven",
    );
    check(
      afterPurge.provider_request_id === beforePurge.provider_request_id,
      "purge_provider_metadata_semantics_changed",
    );
    record("expiry_refusal_and_real_purge", {
      ...await accounting(a),
      rowsPurged: purged,
      providerIdPreservedUntilOwnerDetachment: true,
    });
    await deleteUser(b);
    const detachedPrincipal = await single("billing_principals", {
      billing_principal_id: "eq." + b.principal,
    });
    const detachedUsage = await usage(b);
    check(
      detachedPrincipal.current_user_id === null &&
        Object.keys(detachedUsage.response_payload).length === 0 &&
        detachedUsage.provider_request_id === null,
      "owner_detachment_did_not_scrub_content",
    );
    const deletedRetry = await invoke(b);
    check(
      deletedRetry.status === 401 && !("message" in deletedRetry.data),
      "deleted_auth_still_accepted_by_handler",
    );
    record("owner_deletion_scrubs_reply_and_handler_rejects", {
      accountingTombstoneRetained: true,
    });
    check(
      counters.syntheticProviderAttempts === baselineAttempts &&
        counters.externalProviderNetworkCalls === 0 &&
        counters.blockedTargets === 0,
      "replay_provider_or_external_traffic",
    );
    record("all_completed_negative_retries_no_provider_attempts", {
      additionalSyntheticAttempts: 0,
      externalNetworkCalls: 0,
    });
  } catch (e) {
    mainFailure = safeFailure(e);
  } finally {
    Reflect.set(Deno, "serve", originalServe);
    Reflect.set(Deno.env, "get", originalEnvGet);
    for (const user of users) {
      try {
        await deleteUser(user);
        if (user.principal) {
          const principal = await single("billing_principals", {
            billing_principal_id: "eq." + user.principal,
          });
          check(
            principal.current_user_id === null,
            "cleanup_principal_still_owned",
          );
          const leftovers = await rows("ai_usage_requests", {
            billing_principal_id: "eq." + user.principal,
          });
          check(
            leftovers.every((r) =>
              Object.keys(r.response_payload ?? {}).length === 0 &&
              r.provider_request_id === null
            ),
            "cleanup_content_not_scrubbed",
          );
          user.contentScrubVerified = true;
        }
      } catch (e) {
        cleanupErrors.push(safeFailure(e));
      }
    }
    globalThis.fetch = originalFetch;
    for (const [key, value] of Object.entries(originalLogs)) {
      Reflect.set(console, key, value);
    }
  }
  const passed = mainFailure === null && cleanupErrors.length === 0 &&
    !possiblyUntrackedCreatedUser;
  const codeBytes = await Deno.readFile(
    new URL("./reply_recovery_probe.ts", import.meta.url),
  );
  const guardBytes = await Deno.readFile(
    new URL("./guards.ts", import.meta.url),
  );
  await output("result.json", {
    schemaVersion: 1,
    status: passed ? "PASS" : "FAIL",
    sourceSha: SOURCE,
    sourceTree: TREE,
    startedAt,
    finishedAt: new Date().toISOString(),
    deno: Deno.version,
    probeSha256: await hash(codeBytes),
    guardSha256: await hash(guardBytes),
    sourceManifestSha256: BINDINGS_SHA256,
    sourceFilesVerified: source.manifest.files.length,
    checks,
    counters,
    replayDiagnostics,
    failure: mainFailure,
    cleanup: {
      ownedUsersCreated: users.length,
      ownedUsersDeleted: users.filter((u) => u.deleted).length,
      errors: cleanupErrors,
      possiblyUntrackedCreatedUser,
      retainedScrubbedAccountingTombstones: verifiedScrubbedTombstones(
        users,
        cleanupErrors,
        possiblyUntrackedCreatedUser,
      ),
      ownedUsersDeletionAcknowledged: users.filter((u) =>
        u.deleteAcknowledged
      ).length,
    },
    limitations: [
      "Operator attests dedicated disposable identity; loopback is not by itself proof against a local proxy.",
      "Actual handler is captured in-process, not exercised through the Edge Runtime gateway.",
      "Provider responses are synthetic. No external provider availability or quality evidence.",
      "Payload/expiry joint commit is checked; transactional rollback is not fault-tested.",
      "Retired/mismatched-principal rejection remains covered by existing source unit tests; this probe tests real active join and deleted owner.",
      "No production parity, cron cadence, device acceptance, real purchase or release approval claim.",
    ],
  });
  console.log(
    JSON.stringify({
      status: passed ? "PASS" : "FAIL",
      checksPassed: checks.length,
      failure: mainFailure,
      cleanupErrors: cleanupErrors.length,
      externalNetworkCalls: 0,
    }),
  );
  if (!passed) Deno.exitCode = 1;
}
if (import.meta.main) {
  try {
    await run();
  } catch (e) {
    console.error(
      JSON.stringify({
        status: "REJECTED_OR_INCOMPLETE",
        failure: safeFailure(e),
      }),
    );
    Deno.exitCode = 1;
  }
}
