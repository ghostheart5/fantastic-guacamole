export const SOURCE = "401913600150334749118e6907b0be2c5f062839";
export const TREE = "f8e9fa7c6e4a332e1874e8a227046f7df9f327db";
export const BASE = "http://127.0.0.1:54321";
export const PROVIDER = "https://api.anthropic.com/v1/messages";
export class ProbeError extends Error {
  constructor(public code: string) {
    super(code);
  }
}
export function check(value: unknown, code: string): asserts value {
  if (!value) throw new ProbeError(code);
}
export async function hash(bytes: Uint8Array): Promise<string> {
  return [
    ...new Uint8Array(
      await crypto.subtle.digest("SHA-256", bytes as BufferSource),
    ),
  ]
    .map((v) => v.toString(16).padStart(2, "0")).join("");
}
export async function verifyBoundBytes(
  bytes: Uint8Array,
  expectedHash: string,
) {
  const normalized = new TextEncoder().encode(
    new TextDecoder("utf-8", { fatal: true }).decode(bytes).replaceAll(
      "\r\n",
      "\n",
    ),
  );
  check(await hash(normalized) === expectedHash, "source_file_changed");
}
export function validateConfig(values: Record<string, string | undefined>) {
  check(
    values.AXIOMARA_DISPOSABLE_DB_GATE === "true",
    "disposal_flag_required",
  );
  check(values.LOCAL_SUPABASE_URL === BASE, "exact_loopback_required");
  check(
    values.LOCAL_SUPABASE_ANON_KEY && values.LOCAL_SUPABASE_SERVICE_KEY,
    "local_keys_required",
  );
  return {
    base: BASE,
    anon: values.LOCAL_SUPABASE_ANON_KEY!,
    service: values.LOCAL_SUPABASE_SERVICE_KEY!,
  };
}
export function validateAttestation(
  v: Record<string, unknown>,
  now = Date.now(),
) {
  check(
    v.schemaVersion === 1 && v.sourceSha === SOURCE && v.sourceTree === TREE,
    "attestation_source",
  );
  check(
    v.apiUrl === BASE && v.disposable === true && v.exclusive === true &&
      v.noHostedProxy === true && v.freshMigrationReplay === true,
    "attestation_scope",
  );
  check(
    typeof v.localProjectId === "string" &&
      /^[a-z0-9_-]{4,100}$/i.test(v.localProjectId),
    "attestation_project",
  );
  check(
    typeof v.createdAt === "string" &&
      Number.isFinite(Date.parse(v.createdAt)) &&
      now - Date.parse(v.createdAt) >= 0 &&
      now - Date.parse(v.createdAt) < 3_600_000,
    "attestation_freshness",
  );
}
const getTables = new Set([
  "ai_usage_requests",
  "billing_principals",
  "monetization_wallets",
  "monetization_credit_transactions",
]);
const rpcs = new Set([
  "consume_backend_rate_limit",
  "ensure_billing_principal",
  "ensure_monetization_wallet_for_principal",
  "reserve_ai_usage",
  "settle_ai_usage_v2",
  "settle_ai_usage",
  "purge_expired_ai_response_payloads",
]);
export function route(
  input: string | URL | Request,
  method?: string,
): "local" | "synthetic" {
  const raw = input instanceof Request ? input.url : String(input);
  const url = new URL(raw);
  const m = (method ?? (input instanceof Request ? input.method : "GET"))
    .toUpperCase();
  check(
    !url.username && !url.password && !url.hash,
    "url_credentials_or_fragment",
  );
  if (raw === PROVIDER && m === "POST") return "synthetic";
  check(url.origin === BASE, "external_target_blocked");
  const p = url.pathname;
  const allowed = (p === "/auth/v1/user" && m === "GET" && !url.search) ||
    (p === "/auth/v1/admin/users" && (m === "GET" || m === "POST")) ||
    (/^\/auth\/v1\/admin\/users\/[0-9a-f-]{36}$/.test(p) &&
      (m === "DELETE" || m === "GET") && !url.search) ||
    (p === "/auth/v1/token" && m === "POST" &&
      url.search === "?grant_type=password") ||
    (p.startsWith("/rest/v1/") && m === "GET" && getTables.has(p.slice(9))) ||
    (p === "/rest/v1/ai_usage_requests" && m === "PATCH" &&
      /^eq\.[0-9a-f-]{36}$/.test(url.searchParams.get("user_id") ?? "") &&
      /^eq\.reply-probe-[a-z0-9-]+$/.test(
        url.searchParams.get("request_key") ?? "",
      )) ||
    (p.startsWith("/rest/v1/rpc/") && m === "POST" && !url.search &&
      rpcs.has(p.slice(13)));
  check(allowed, "local_route_blocked");
  return "local";
}
export function validateOwnedRows(
  rows: unknown,
  users: ReadonlySet<string>,
  requests: ReadonlySet<string>,
) {
  check(Array.isArray(rows) && rows.length <= 2, "purge_inventory_size");
  for (const row of rows) {
    check(
      row && users.has(row.user_id) && requests.has(row.request_key),
      "purge_foreign_row",
    );
  }
}
export function validateAccounting(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  transactions: Array<Record<string, unknown>>,
  credits: number,
) {
  check(Number.isInteger(credits) && credits > 0, "credits_invalid");
  check(
    Number(after.balance) === Number(before.balance) - credits,
    "wallet_second_debit_or_wrong_balance",
  );
  check(
    Number(after.lifetime_spent) === Number(before.lifetime_spent) + credits,
    "lifetime_spend_mismatch",
  );
  check(
    transactions.length === 1 && transactions[0].type === "spend" &&
      transactions[0].amount === -credits &&
      transactions[0].source === "ai_proxy",
    "spend_ledger_not_exactly_one",
  );
}
export function safeFailure(e: unknown): string {
  return e instanceof ProbeError ? e.code : "unexpected_error_redacted";
}

export async function deleteOwnedUser(
  user: Record<string, unknown>,
  request: (
    path: string,
    method?: string,
  ) => Promise<{ ok: boolean; status: number }>,
) {
  if (user.deleted === true) return;
  check(typeof user.id === "string", "owned_auth_id_missing");
  const result = await request("/auth/v1/admin/users/" + user.id, "DELETE");
  check(result.ok || result.status === 404, "owned_auth_delete_failed");
  user.deleteAcknowledged = true;
  const verify = await request("/auth/v1/admin/users/" + user.id);
  check(verify.status === 404, "owned_auth_delete_not_verified");
  user.deleted = true;
}
export function verifiedScrubbedTombstones(
  users: Array<Record<string, unknown>>,
  cleanupErrors: readonly string[],
  possiblyUntrackedCreatedUser: boolean,
): boolean {
  const withPrincipal = users.filter((u) => u.principal);
  return cleanupErrors.length === 0 && !possiblyUntrackedCreatedUser &&
    withPrincipal.length > 0 &&
    withPrincipal.every((u) => u.contentScrubVerified === true);
}
