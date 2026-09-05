/// <reference lib="deno.ns" />
import { deleteUserStorageObjects } from "./storage_cleanup.ts";

export interface AccountDeletionConfig {
  supabaseUrl: string;
  publishableKey: string;
  serviceRoleKey: string;
}

export interface AuthenticatedDeletionUser {
  id: string;
  email: string | null;
  sessionSignInAtSeconds: number | null;
}

export interface DeletionResult {
  accepted: boolean;
  completed: boolean;
  retry: boolean;
  state: string;
}

export interface DeletionStatus {
  completed: boolean;
  state: string;
}

export interface ProcessDeletionOptions {
  requestId: string;
  receiptHash?: string;
  authenticatedUserId?: string;
  allowInternal?: boolean;
  config: AccountDeletionConfig;
  fetcher?: typeof fetch;
  storageCleanup?: typeof deleteUserStorageObjects;
}

interface DeletionClaim {
  claimed: boolean;
  completed: boolean;
  retry: boolean;
  state: string;
  userId?: string;
  sessionsRevoked: boolean;
  storageDeleted: boolean;
}

function jsonHeaders(serviceRoleKey: string): Record<string, string> {
  return {
    apikey: serviceRoleKey,
    Authorization: `Bearer ${serviceRoleKey}`,
    "Content-Type": "application/json",
  };
}

export function loadAccountDeletionConfig(): AccountDeletionConfig {
  return {
    supabaseUrl: (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, ""),
    publishableKey: Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    serviceRoleKey: Deno.env.get("SUPABASE_SECRET_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  };
}

export function accountDeletionConfigured(
  config: AccountDeletionConfig,
  requirePublishableKey = true,
): boolean {
  return Boolean(
    config.supabaseUrl && config.serviceRoleKey &&
      (!requirePublishableKey || config.publishableKey),
  );
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function deletionIdentifiers(
  userId: string,
  authorization: string,
): Promise<{ requestId: string; receipt: string; receiptHash: string }> {
  const receipt = await sha256Hex(
    `chronospark-account-deletion-receipt:${authorization}`,
  );
  return {
    requestId: await sha256Hex(`chronospark-account-deletion:${userId}`),
    receipt,
    receiptHash: await sha256Hex(receipt),
  };
}

export async function authenticatedDeletionUser(
  authorization: string,
  config: AccountDeletionConfig,
  fetcher: typeof fetch = fetch,
): Promise<AuthenticatedDeletionUser | null> {
  if (
    !/^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(
      authorization,
    )
  ) {
    return null;
  }
  // Validate this exact token with Auth before reading any of its claims. Auth's
  // /user endpoint verifies the signature/expiry and loads session_id from the
  // server, rejecting missing (signed-out/revoked) sessions. Local JWT decoding
  // or account-wide last_sign_in_at alone cannot establish either guarantee.
  const response = await fetcher(`${config.supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: authorization,
      apikey: config.publishableKey,
    },
  });
  if (!response.ok) return null;
  const user = await response.json();
  if (typeof user?.id !== "string") return null;
  const claims = readValidatedSessionClaims(authorization, user.id);
  if (!claims || user.is_anonymous === true) return null;
  return {
    id: user.id,
    email: typeof user.email === "string" ? user.email : null,
    sessionSignInAtSeconds: sessionSignInAtSeconds(claims),
  };
}

// Private deliberately: callers must not use claims until /auth/v1/user has
// accepted the same bearer. Never read user_metadata for authorization.
function readValidatedSessionClaims(
  authorization: string,
  verifiedUserId: string,
): Record<string, unknown> | null {
  try {
    const payload = authorization.slice("Bearer ".length).split(".")[1];
    const encoded = payload.replace(/-/g, "+").replace(/_/g, "/");
    const bytes = Uint8Array.from(
      atob(encoded),
      (value) => value.charCodeAt(0),
    );
    const claims = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(bytes),
    );
    if (!claims || typeof claims !== "object" || Array.isArray(claims)) {
      return null;
    }
    if (
      claims.sub !== verifiedUserId || claims.role !== "authenticated" ||
      claims.is_anonymous !== false ||
      typeof claims.session_id !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
        .test(claims.session_id)
    ) return null;
    return claims;
  } catch {
    return null;
  }
}

const SIGN_IN_METHODS = new Set([
  "password",
  "oauth",
  "otp",
  "totp",
  "sso/saml",
  "magiclink",
  "recovery",
  "invite",
  "email/signup",
]);

function sessionSignInAtSeconds(
  claims: Record<string, unknown>,
): number | null {
  if (!Array.isArray(claims.amr)) return null;
  const issuedAt = claims.iat;
  if (
    typeof issuedAt !== "number" || !Number.isSafeInteger(issuedAt) ||
    issuedAt <= 0
  ) {
    return null;
  }
  let latest: number | null = null;
  for (const reference of claims.amr) {
    if (
      !reference || typeof reference !== "object" || Array.isArray(reference)
    ) continue;
    const { method, timestamp } = reference;
    // Refreshing an old session is not reauthentication. Unknown methods fail
    // closed until explicitly supported; neither token iat nor metadata is a
    // fallback for a missing/invalid AMR timestamp.
    if (
      typeof method !== "string" || !SIGN_IN_METHODS.has(method) ||
      typeof timestamp !== "number" || !Number.isSafeInteger(timestamp) ||
      timestamp <= 0 || timestamp > issuedAt
    ) continue;
    latest = Math.max(latest ?? 0, timestamp);
  }
  return latest;
}

function readClaim(value: unknown): DeletionClaim | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const claim = value as Record<string, unknown>;
  return {
    claimed: claim.claimed === true,
    completed: claim.completed === true,
    retry: claim.retry === true,
    state: typeof claim.state === "string" ? claim.state : "unavailable",
    userId: typeof claim.userId === "string" ? claim.userId : undefined,
    sessionsRevoked: claim.sessionsRevoked === true,
    storageDeleted: claim.storageDeleted === true,
  };
}

async function serviceRpc(
  config: AccountDeletionConfig,
  fetcher: typeof fetch,
  name: string,
  body: Record<string, unknown>,
): Promise<unknown> {
  const response = await fetcher(
    `${config.supabaseUrl}/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: jsonHeaders(config.serviceRoleKey),
      body: JSON.stringify(body),
    },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  return await response.json();
}

async function patchRequest(
  options: ProcessDeletionOptions,
  fetcher: typeof fetch,
  leaseId: string,
  values: Record<string, unknown>,
): Promise<boolean> {
  const response = await fetcher(
    `${options.config.supabaseUrl}/rest/v1/account_deletion_requests` +
      `?request_id=eq.${encodeURIComponent(options.requestId)}` +
      `&lease_id=eq.${encodeURIComponent(leaseId)}`,
    {
      method: "PATCH",
      headers: {
        ...jsonHeaders(options.config.serviceRoleKey),
        Prefer: "return=representation",
      },
      body: JSON.stringify({ ...values, updated_at: new Date().toISOString() }),
    },
  );
  if (!response.ok) return false;
  const rows = await response.json();
  return Array.isArray(rows) && rows.length === 1;
}

async function releaseLease(
  options: ProcessDeletionOptions,
  fetcher: typeof fetch,
  leaseId: string,
  errorCode: string,
): Promise<void> {
  await patchRequest(options, fetcher, leaseId, {
    lease_id: null,
    lease_until: null,
    last_error_code: errorCode,
  });
}

async function deleteAuthUser(
  userId: string,
  config: AccountDeletionConfig,
  fetcher: typeof fetch,
): Promise<boolean> {
  const response = await fetcher(
    `${config.supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
    { method: "DELETE", headers: jsonHeaders(config.serviceRoleKey) },
  );
  return response.ok || response.status === 404;
}

export async function getDeletionStatus(
  requestId: string,
  receiptHash: string,
  config: AccountDeletionConfig,
  fetcher: typeof fetch = fetch,
): Promise<DeletionStatus | null> {
  const response = await fetcher(
    `${config.supabaseUrl}/rest/v1/account_deletion_requests` +
      `?request_id=eq.${encodeURIComponent(requestId)}` +
      `&receipt_hash=eq.${encodeURIComponent(receiptHash)}` +
      "&select=state&limit=1",
    { headers: jsonHeaders(config.serviceRoleKey) },
  );
  if (!response.ok) return null;
  const rows = await response.json();
  const state = Array.isArray(rows) && rows.length === 1 &&
      typeof rows[0]?.state === "string"
    ? rows[0].state
    : null;
  return state === null ? null : { completed: state === "completed", state };
}

export async function processDeletionRequest(
  options: ProcessDeletionOptions,
): Promise<DeletionResult> {
  const fetcher = options.fetcher ?? fetch;
  const storageCleanup = options.storageCleanup ?? deleteUserStorageObjects;
  const leaseId = crypto.randomUUID();
  const claim = readClaim(
    await serviceRpc(
      options.config,
      fetcher,
      "claim_account_deletion_request",
      {
        p_request_id: options.requestId,
        p_receipt_hash: options.receiptHash ?? "",
        p_user_id: options.authenticatedUserId ?? null,
        p_lease_id: leaseId,
        p_allow_internal: options.allowInternal === true,
      },
    ),
  );

  if (!claim) {
    return {
      accepted: false,
      completed: false,
      retry: true,
      state: "unavailable",
    };
  }
  if (claim.completed) {
    return {
      accepted: true,
      completed: true,
      retry: false,
      state: "completed",
    };
  }
  if (!claim.claimed) {
    return {
      accepted: claim.retry,
      completed: false,
      retry: claim.retry,
      state: claim.state,
    };
  }

  const userId = claim.userId ?? "";
  if (!userId) {
    await releaseLease(options, fetcher, leaseId, "missing_user_id");
    return {
      accepted: false,
      completed: false,
      retry: false,
      state: "invalid",
    };
  }

  if (!claim.sessionsRevoked) {
    const revoked = await serviceRpc(
      options.config,
      fetcher,
      "revoke_account_deletion_sessions",
      { p_request_id: options.requestId, p_lease_id: leaseId },
    );
    if (revoked !== true) {
      await releaseLease(
        options,
        fetcher,
        leaseId,
        "session_revocation_failed",
      );
      return {
        accepted: true,
        completed: false,
        retry: true,
        state: "requested",
      };
    }
    if (
      !await patchRequest(options, fetcher, leaseId, {
        state: "sessions_revoked",
        sessions_revoked_at: new Date().toISOString(),
        last_error_code: null,
      })
    ) {
      throw new Error("account_deletion_state_update_failed");
    }
  }

  if (!claim.storageDeleted) {
    const storageDeleted = await storageCleanup(userId, {
      supabaseUrl: options.config.supabaseUrl,
      serviceRoleKey: options.config.serviceRoleKey,
      fetcher,
    });
    if (!storageDeleted) {
      await releaseLease(options, fetcher, leaseId, "storage_cleanup_failed");
      return {
        accepted: true,
        completed: false,
        retry: true,
        state: "sessions_revoked",
      };
    }
    if (
      !await patchRequest(options, fetcher, leaseId, {
        state: "storage_deleted",
        storage_deleted_at: new Date().toISOString(),
        last_error_code: null,
      })
    ) {
      throw new Error("account_deletion_state_update_failed");
    }
  }

  if (!await deleteAuthUser(userId, options.config, fetcher)) {
    await releaseLease(options, fetcher, leaseId, "auth_deletion_failed");
    return {
      accepted: true,
      completed: false,
      retry: true,
      state: "storage_deleted",
    };
  }

  if (
    !await patchRequest(options, fetcher, leaseId, {
      state: "completed",
      auth_deleted_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
      lease_id: null,
      lease_until: null,
      last_error_code: null,
    })
  ) {
    throw new Error("account_deletion_completion_update_failed");
  }
  return { accepted: true, completed: true, retry: false, state: "completed" };
}

export async function listReconcileCandidates(
  config: AccountDeletionConfig,
  limit = 20,
  fetcher: typeof fetch = fetch,
): Promise<string[] | null> {
  const boundedLimit = Math.max(1, Math.min(100, Math.trunc(limit)));
  const response = await fetcher(
    `${config.supabaseUrl}/rest/v1/account_deletion_requests` +
      `?state=neq.completed&order=updated_at.asc&limit=${boundedLimit}` +
      "&select=request_id",
    { headers: jsonHeaders(config.serviceRoleKey) },
  );
  if (!response.ok) return null;
  const rows = await response.json();
  if (!Array.isArray(rows)) return null;
  const requestIds = rows.map((row: unknown) =>
    row && typeof row === "object" && !Array.isArray(row)
      ? (row as Record<string, unknown>).request_id
      : null
  );
  return requestIds.every((value) =>
      typeof value === "string" && /^[0-9a-f]{64}$/.test(value)
    )
    ? requestIds as string[]
    : null;
}
