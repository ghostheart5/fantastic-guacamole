import {
  BASE,
  check,
  deleteOwnedUser,
  hash,
  ProbeError,
  PROVIDER,
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
const good = {
  AXIOMARA_DISPOSABLE_DB_GATE: "true",
  LOCAL_SUPABASE_URL: BASE,
  LOCAL_SUPABASE_ANON_KEY: "synthetic-anon",
  LOCAL_SUPABASE_SERVICE_KEY: "synthetic-service",
};
function rejects(fn: () => unknown, expected: string) {
  try {
    fn();
  } catch (e) {
    check(
      e instanceof ProbeError && e.code === expected,
      "unexpected_test_error",
    );
    return;
  }
  throw new Error("Expected rejection " + expected);
}
Deno.test("exact local configuration is accepted without any network", () => {
  check(validateConfig(good).base === BASE, "config");
});
for (const value of [undefined, "", "false", "TRUE"]) {
  Deno.test("disposal flag rejects " + String(value), () =>
    rejects(
      () => validateConfig({ ...good, AXIOMARA_DISPOSABLE_DB_GATE: value }),
      "disposal_flag_required",
    ));
}
for (
  const value of [
    "https://project.supabase.co",
    "http://localhost:54321",
    "http://127.0.0.1:54321/",
    "http://127.0.0.1:54322",
    "http://127.0.0.1:54321?x=1",
    "http://user@127.0.0.1:54321",
  ]
) {
  Deno.test(
    "nonexact backend rejects " + value,
    () =>
      rejects(
        () => validateConfig({ ...good, LOCAL_SUPABASE_URL: value }),
        "exact_loopback_required",
      ),
  );
}
for (const key of ["LOCAL_SUPABASE_ANON_KEY", "LOCAL_SUPABASE_SERVICE_KEY"]) {
  Deno.test(
    "missing " + key + " rejects",
    () =>
      rejects(
        () => validateConfig({ ...good, [key]: "" }),
        "local_keys_required",
      ),
  );
}
const att = {
  schemaVersion: 1,
  sourceSha: SOURCE,
  sourceTree: TREE,
  apiUrl: BASE,
  disposable: true,
  exclusive: true,
  noHostedProxy: true,
  freshMigrationReplay: true,
  localProjectId: "reply-probe-local",
  createdAt: "2026-10-03T12:00:00Z",
};
const now = Date.parse("2026-10-03T12:01:00Z");
Deno.test("fresh exact disposable attestation accepted", () =>
  validateAttestation(att, now));
for (const field of ["sourceSha", "sourceTree"]) {
  Deno.test("wrong " + field + " rejects", () =>
    rejects(
      () => validateAttestation({ ...att, [field]: "changed" }, now),
      "attestation_source",
    ));
}
for (
  const field of [
    "disposable",
    "exclusive",
    "noHostedProxy",
    "freshMigrationReplay",
  ]
) {
  Deno.test("missing attestation " + field + " rejects", () =>
    rejects(
      () => validateAttestation({ ...att, [field]: false }, now),
      "attestation_scope",
    ));
}
for (
  const createdAt of ["invalid", "2026-10-03T10:00:00Z", "2026-10-03T13:00:00Z"]
) {
  Deno.test("invalid/stale/future attestation " + createdAt, () =>
    rejects(
      () => validateAttestation({ ...att, createdAt }, now),
      "attestation_freshness",
    ));
}
Deno.test("only named local GET/POST RPC routes accepted", () => {
  check(route(BASE + "/auth/v1/user") === "local", "auth");
  check(
    route(BASE + "/rest/v1/rpc/settle_ai_usage_v2", "POST") === "local",
    "rpc",
  );
  check(route(PROVIDER, "POST") === "synthetic", "synthetic");
});
for (
  const value of [
    "https://project.supabase.co/auth/v1/user",
    "https://api.anthropic.com/v1/other",
    "http://127.0.0.1:54322/rest/v1/ai_usage_requests",
    "http://localhost:54321/auth/v1/user",
  ]
) {
  Deno.test(
    "external transport route rejected " + value,
    () => rejects(() => route(value), "external_target_blocked"),
  );
}
for (
  const [path, method] of [
    ["/rest/v1/rpc/reconcile_google_play_rtdn_queue", "POST"],
    ["/auth/v1/admin/users", "DELETE"],
    ["/rest/v1/ai_usage_requests", "DELETE"],
    ["/rest/v1/ai_usage_requests", "PATCH"],
    ["/storage/v1/object/bucket", "POST"],
    ["/rest/v1/rpc/settle_ai_usage_v2?redirect=https://example.com", "POST"],
  ]
) {
  Deno.test(
    "unapproved path/method rejected " + method + " " + path,
    () => rejects(() => route(BASE + path, method), "local_route_blocked"),
  );
}
Deno.test("URL embedded credentials and fragments rejected", () => {
  rejects(
    () => route("http://user:secret@127.0.0.1:54321/auth/v1/user"),
    "url_credentials_or_fragment",
  );
  rejects(
    () => route(BASE + "/auth/v1/user#fragment"),
    "url_credentials_or_fragment",
  );
});
const users = new Set(["a", "b"]);
const requests = new Set(["req-a", "req-b"]);
Deno.test("purge exact owned rows accepted", () =>
  validateOwnedRows(
    [{ user_id: "a", request_key: "req-a" }, {
      user_id: "b",
      request_key: "req-b",
    }],
    users,
    requests,
  ));
Deno.test("purge rejects foreign owner", () =>
  rejects(() =>
    validateOwnedRows(
      [{ user_id: "other", request_key: "req-a" }],
      users,
      requests,
    ), "purge_foreign_row"));
Deno.test("purge rejects foreign request", () =>
  rejects(() =>
    validateOwnedRows(
      [{ user_id: "a", request_key: "other" }],
      users,
      requests,
    ), "purge_foreign_row"));
Deno.test("purge rejects non-array or excess rows", () => {
  rejects(() => validateOwnedRows({}, users, requests), "purge_inventory_size");
  rejects(
    () => validateOwnedRows([{}, {}, {}], users, requests),
    "purge_inventory_size",
  );
});
const before = { balance: 20, lifetime_spent: 0 };
const after = { balance: 17, lifetime_spent: 3 };
const ledger = [{ type: "spend", amount: -3, source: "ai_proxy" }];
Deno.test("actual one-debit accounting shape accepted", () =>
  validateAccounting(before, after, ledger, 3));
Deno.test("second wallet debit rejected", () =>
  rejects(
    () =>
      validateAccounting(before, { balance: 14, lifetime_spent: 6 }, ledger, 3),
    "wallet_second_debit_or_wrong_balance",
  ));
Deno.test("incorrect lifetime spend rejected", () =>
  rejects(
    () =>
      validateAccounting(before, { ...after, lifetime_spent: 6 }, ledger, 3),
    "lifetime_spend_mismatch",
  ));
for (
  const tx of [[], [...ledger, ...ledger], [{ ...ledger[0], amount: -6 }], [{
    ...ledger[0],
    source: "other",
  }]]
) {
  Deno.test(
    "missing/duplicate/wrong ledger rejected " + JSON.stringify(tx),
    () =>
      rejects(
        () => validateAccounting(before, after, tx, 3),
        "spend_ledger_not_exactly_one",
      ),
  );
}
Deno.test("unexpected error content is redacted", () => {
  check(
    safeFailure(new Error("secret-token private-response")) ===
      "unexpected_error_redacted",
    "redaction",
  );
  check(
    safeFailure(new ProbeError("safe_category")) === "safe_category",
    "controlled_category",
  );
});
Deno.test("source binding accepts exact bytes and checkout CRLF only", async () => {
  const expected = await hash(new TextEncoder().encode("source\n"));
  await verifyBoundBytes(new TextEncoder().encode("source\n"), expected);
  await verifyBoundBytes(new TextEncoder().encode("source\r\n"), expected);
});
Deno.test("source binding rejects altered content and truncation", async () => {
  const expected = await hash(new TextEncoder().encode("source\n"));
  for (const value of ["changed\n", "source", "source\nextra"]) {
    let rejected = false;
    try {
      await verifyBoundBytes(new TextEncoder().encode(value), expected);
    } catch (e) {
      check(
        e instanceof ProbeError && e.code === "source_file_changed",
        "wrong_source_error",
      );
      rejected = true;
    }
    check(rejected, "modified_source_accepted");
  }
});

Deno.test("cleanup marks deletion only after confirming GET404", async () => {
  const user: Record<string, unknown> = {
    id: "synthetic-owned-id",
    deleted: false,
  };
  const calls: string[] = [];
  await deleteOwnedUser(user, async (path, method = "GET") => {
    calls.push(method + " " + path);
    check(user.deleted === false, "deleted_set_before_verification");
    return { ok: method === "DELETE", status: method === "DELETE" ? 200 : 404 };
  });
  check(
    user.deleteAcknowledged === true && user.deleted === true &&
      calls.length === 2,
    "verified_delete_not_recorded",
  );
});
Deno.test("cleanup failed GET remains retryable even after DELETE acknowledged", async () => {
  const user: Record<string, unknown> = {
    id: "synthetic-owned-id",
    deleted: false,
  };
  const responses = [{ ok: true, status: 200 }, { ok: false, status: 500 }, {
    ok: false,
    status: 404,
  }, { ok: false, status: 404 }];
  const calls: string[] = [];
  const request = async (_path: string, method = "GET") => {
    calls.push(method);
    check(responses.length > 0, "unexpected_cleanup_call");
    return responses.shift()!;
  };
  let failure: unknown;
  try {
    await deleteOwnedUser(user, request);
  } catch (e) {
    failure = e;
  }
  check(
    failure instanceof ProbeError &&
      failure.code === "owned_auth_delete_not_verified",
    "missing_cleanup_failure",
  );
  check(
    user.deleteAcknowledged === true && user.deleted === false,
    "unverified_delete_misreported",
  );
  await deleteOwnedUser(user, request);
  check(
    Reflect.get(user, "deleted") === true &&
      calls.join(",") === "DELETE,GET,DELETE,GET",
    "cleanup_retry_skipped",
  );
});
Deno.test("cleanup successful DELETE but existing account is not verified deleted", async () => {
  const user: Record<string, unknown> = {
    id: "synthetic-owned-id",
    deleted: false,
  };
  let failure: unknown;
  try {
    await deleteOwnedUser(user, async () => ({ ok: true, status: 200 }));
  } catch (e) {
    failure = e;
  }
  check(
    failure instanceof ProbeError &&
      failure.code === "owned_auth_delete_not_verified" &&
      user.deleted === false,
    "present_account_marked_deleted",
  );
});
Deno.test("cleanup failed DELETE does not acknowledge deletion or read GET", async () => {
  const user: Record<string, unknown> = {
    id: "synthetic-owned-id",
    deleted: false,
  };
  let calls = 0;
  let failure: unknown;
  try {
    await deleteOwnedUser(user, async () => {
      calls++;
      return { ok: false, status: 500 };
    });
  } catch (e) {
    failure = e;
  }
  check(
    failure instanceof ProbeError &&
      failure.code === "owned_auth_delete_failed" &&
      user.deleteAcknowledged !== true && user.deleted === false && calls === 1,
    "failed_delete_claimed",
  );
});
Deno.test("already verified deletion can skip repeated transport", async () => {
  const user: Record<string, unknown> = {
    id: "synthetic-owned-id",
    deleted: true,
  };
  await deleteOwnedUser(user, async () => {
    throw new Error("must not call");
  });
});
Deno.test("scrub flag requires actual verified principal readback", () => {
  check(
    verifiedScrubbedTombstones(
      [{ principal: "a", contentScrubVerified: true }],
      [],
      false,
    ),
    "verified_scrub_not_recorded",
  );
});
for (
  const [label, users, errors, unknown] of [
    ["no principal", [], [], false],
    ["missing readback", [{ principal: "a" }], [], false],
    [
      "failed readback",
      [{ principal: "a", contentScrubVerified: false }],
      [],
      false,
    ],
    [
      "one unverified principal",
      [{ principal: "a", contentScrubVerified: true }, { principal: "b" }],
      [],
      false,
    ],
    ["cleanup error", [{ principal: "a", contentScrubVerified: true }], [
      "cleanup_failed",
    ], false],
    [
      "unknown partial creation",
      [{ principal: "a", contentScrubVerified: true }],
      [],
      true,
    ],
  ] as Array<[string, Array<Record<string, unknown>>, string[], boolean]>
) {
  Deno.test(
    "scrub flag rejects " + label,
    () =>
      check(
        !verifiedScrubbedTombstones(users, errors, unknown),
        "incomplete_cleanup_claimed",
      ),
  );
}
