/// <reference lib="deno.ns" />
import { fetchWithDeadline, hasOnlyKeys, logEdgeEvent } from "./edge_http.ts";
import { sha256Hex } from "./google_auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_PUBLISHABLE_KEY = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SYNC_BUCKET = "chronospark-sync";
const STORAGE_PAGE_SIZE = 100;
const MAX_STORAGE_DELETES_PER_STAGE = 250;
const MAX_STORAGE_LIST_CALLS_PER_STAGE = 5;
const MAX_PENDING_PREFIXES = 2_000;

export interface DeletionRequestInput {
  action: "delete" | "status";
  requestId: string;
  receipt: string;
  userId?: string;
  email?: string;
}

export interface AuthenticatedDeletionUser {
  id: string;
  email: string | null;
  lastSignInAt: string | null;
}

type StorageListItem = { id?: string | null; name?: string };

function serviceHeaders(): Record<string, string> {
  return {
    apikey: SUPABASE_SECRET_KEY,
    Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
    "Content-Type": "application/json",
  };
}

export function accountDeletionConfigured(): boolean {
  return Boolean(
    SUPABASE_URL && SUPABASE_SECRET_KEY && SUPABASE_PUBLISHABLE_KEY,
  );
}

export function readDeletionInput(value: unknown): DeletionRequestInput | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const body = value as Record<string, unknown>;
  const action = body.action === "status"
    ? "status"
    : body.action === "delete"
    ? "delete"
    : null;
  if (!action) return null;
  const allowed = action === "delete"
    ? new Set(["action", "requestId", "receipt", "userId", "email"])
    : new Set(["action", "requestId", "receipt"]);
  if (!hasOnlyKeys(body, allowed)) return null;
  const requestId = typeof body.requestId === "string"
    ? body.requestId.trim()
    : "";
  const receipt = typeof body.receipt === "string" ? body.receipt.trim() : "";
  const userId = typeof body.userId === "string"
    ? body.userId.trim()
    : undefined;
  const email = typeof body.email === "string" ? body.email.trim() : undefined;
  if (
    !/^[0-9a-f]{64}$/.test(requestId) ||
    !/^[A-Za-z0-9_-]{32,256}$/.test(receipt) ||
    (action === "delete" && (!userId || userId.length > 128)) ||
    (email !== undefined && (email.length > 320 || !email.includes("@")))
  ) return null;
  return { action, requestId, receipt, userId, email };
}

export function canAdvanceDeletion(options: {
  action: "delete" | "status";
  authenticated: boolean;
  allowInternal: boolean;
}): boolean {
  return options.allowInternal ||
    (options.action === "delete" && options.authenticated);
}

export async function authenticatedDeletionUser(
  authorization: string,
): Promise<AuthenticatedDeletionUser | null> {
  if (!authorization.startsWith("Bearer ")) return null;
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/auth/v1/user`,
    {
      headers: {
        Authorization: authorization,
        apikey: SUPABASE_PUBLISHABLE_KEY,
      },
    },
    { timeoutMs: 5_000, dependency: "supabase_auth_user" },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  const user = await response.json();
  if (typeof user?.id !== "string") return null;
  return {
    id: user.id,
    email: typeof user?.email === "string" ? user.email : null,
    lastSignInAt: typeof user?.last_sign_in_at === "string"
      ? user.last_sign_in_at
      : null,
  };
}

async function serviceRpc(
  name: string,
  body: Record<string, unknown>,
  timeoutMs = 5_000,
): Promise<Record<string, unknown> | null> {
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: serviceHeaders(),
      body: JSON.stringify(body),
    },
    { timeoutMs, dependency: `supabase_rpc_${name}` },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  const value = await response.json();
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

async function serviceBooleanRpc(
  name: string,
  body: Record<string, unknown>,
  timeoutMs = 5_000,
): Promise<boolean> {
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: serviceHeaders(),
      body: JSON.stringify(body),
    },
    { timeoutMs, dependency: `supabase_rpc_${name}` },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return false;
  }
  return await response.json() === true;
}

async function transitionRequest(options: {
  requestId: string;
  leaseId: string;
  expectedState: string;
  nextState: string;
  storagePendingPrefixes?: string[];
  errorCode?: string;
}): Promise<boolean> {
  return await serviceBooleanRpc("transition_account_deletion_request", {
    p_request_id: options.requestId,
    p_lease_id: options.leaseId,
    p_expected_state: options.expectedState,
    p_next_state: options.nextState,
    p_storage_pending_prefixes: options.storagePendingPrefixes ?? null,
    p_last_error_code: options.errorCode ?? null,
  });
}

function safePendingPrefixes(value: unknown, userId: string): string[] {
  const root = userId.replace(/^\/+|\/+$/g, "");
  const raw = Array.isArray(value) ? value : [];
  const unique = new Set<string>();
  for (const item of raw) {
    if (typeof item !== "string") continue;
    const prefix = item.replace(/^\/+|\/+$/g, "");
    if (prefix === root || prefix.startsWith(`${root}/`)) unique.add(prefix);
    if (unique.size >= MAX_PENDING_PREFIXES) break;
  }
  return unique.size > 0 ? [...unique] : [root];
}

async function processStorageBatch(
  userId: string,
  pendingValue: unknown,
): Promise<{ complete: boolean; pendingPrefixes: string[]; deleted: number }> {
  const stack = safePendingPrefixes(pendingValue, userId);
  let deleted = 0;
  let listCalls = 0;
  while (
    stack.length > 0 &&
    deleted < MAX_STORAGE_DELETES_PER_STAGE &&
    listCalls < MAX_STORAGE_LIST_CALLS_PER_STAGE
  ) {
    const prefix = stack.pop()!;
    const response = await fetchWithDeadline(
      `${SUPABASE_URL}/storage/v1/object/list/${SYNC_BUCKET}`,
      {
        method: "POST",
        headers: serviceHeaders(),
        body: JSON.stringify({
          prefix,
          limit: STORAGE_PAGE_SIZE,
          offset: 0,
          sortBy: { column: "name", order: "asc" },
        }),
      },
      { timeoutMs: 5_000, dependency: "supabase_storage_list" },
    );
    listCalls += 1;
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error("storage_list_failed");
    }
    const entries = await response.json() as StorageListItem[];
    if (!Array.isArray(entries)) throw new Error("storage_list_invalid");

    const files: string[] = [];
    const folders: string[] = [];
    for (const entry of entries) {
      if (typeof entry.name !== "string" || !entry.name) continue;
      const path = `${prefix}/${entry.name}`.replace(/^\/+/, "");
      if (entry.id) files.push(path);
      else folders.push(path);
    }

    if (entries.length === STORAGE_PAGE_SIZE) stack.push(prefix);
    for (const folder of folders) {
      if (stack.length >= MAX_PENDING_PREFIXES) {
        throw new Error("storage_prefix_limit_exceeded");
      }
      stack.push(folder);
    }

    const remainingCapacity = MAX_STORAGE_DELETES_PER_STAGE - deleted;
    const filesToDelete = files.slice(0, remainingCapacity);
    if (filesToDelete.length < files.length) stack.push(prefix);
    if (filesToDelete.length > 0) {
      const deleteResponse = await fetchWithDeadline(
        `${SUPABASE_URL}/storage/v1/object/${SYNC_BUCKET}`,
        {
          method: "DELETE",
          headers: serviceHeaders(),
          body: JSON.stringify({ prefixes: filesToDelete }),
        },
        { timeoutMs: 8_000, dependency: "supabase_storage_delete" },
      );
      if (!deleteResponse.ok) {
        await deleteResponse.body?.cancel();
        throw new Error("storage_delete_failed");
      }
      await deleteResponse.body?.cancel();
      deleted += filesToDelete.length;
    }
  }
  return { complete: stack.length === 0, pendingPrefixes: stack, deleted };
}

async function deleteAuthUser(userId: string): Promise<boolean> {
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
    { method: "DELETE", headers: serviceHeaders() },
    { timeoutMs: 8_000, dependency: "supabase_auth_admin_delete" },
  );
  const accepted = response.ok || response.status === 404;
  await response.body?.cancel();
  return accepted;
}

export async function readDeletionStatus(
  input: DeletionRequestInput,
): Promise<Record<string, unknown> | null> {
  if (input.action !== "status") return null;
  return await serviceRpc("read_account_deletion_status", {
    p_request_id: input.requestId,
    p_receipt_hash: await sha256Hex(input.receipt),
  });
}

export async function processDeletionRequest(options: {
  input: DeletionRequestInput;
  authenticatedUserId?: string;
  allowInternal?: boolean;
}): Promise<Record<string, unknown>> {
  if (
    !canAdvanceDeletion({
      action: options.input.action,
      authenticated: Boolean(options.authenticatedUserId),
      allowInternal: options.allowInternal === true,
    })
  ) {
    return { accepted: false, completed: false, state: "unauthorized" };
  }
  const receiptHash = options.allowInternal
    ? ""
    : await sha256Hex(options.input.receipt);
  const leaseId = crypto.randomUUID();
  const claim = await serviceRpc("claim_account_deletion_request", {
    p_request_id: options.input.requestId,
    p_receipt_hash: receiptHash,
    p_user_id: options.authenticatedUserId ?? null,
    p_lease_id: leaseId,
    p_allow_internal: options.allowInternal === true,
  });
  if (!claim || (claim.claimed !== true && claim.completed !== true)) {
    return {
      accepted: claim?.retry === true,
      completed: false,
      state: claim?.state ?? "unavailable",
      retry: claim?.retry === true,
      reason: claim?.reason,
    };
  }
  if (claim.completed === true) {
    return { accepted: true, completed: true, state: "completed" };
  }
  const userId = claim.userId?.toString() ?? "";
  const state = claim.state?.toString() ?? "";
  if (
    !userId ||
    !["requested", "sessions_revoked", "storage_deleted"].includes(state)
  ) {
    return { accepted: false, completed: false, state: "invalid" };
  }

  if (state === "requested") {
    const revoked = await serviceBooleanRpc(
      "revoke_account_deletion_sessions",
      { p_request_id: options.input.requestId, p_lease_id: leaseId },
    );
    const transitioned = await transitionRequest({
      requestId: options.input.requestId,
      leaseId,
      expectedState: "requested",
      nextState: revoked ? "sessions_revoked" : "requested",
      errorCode: revoked ? undefined : "session_revocation_failed",
    });
    if (!transitioned) throw new Error("deletion_lease_lost");
    return {
      accepted: true,
      completed: false,
      state: revoked ? "sessions_revoked" : "requested",
      retry: true,
    };
  }

  if (state === "sessions_revoked") {
    try {
      const batch = await processStorageBatch(
        userId,
        claim.storagePendingPrefixes,
      );
      const transitioned = await transitionRequest({
        requestId: options.input.requestId,
        leaseId,
        expectedState: "sessions_revoked",
        nextState: batch.complete ? "storage_deleted" : "sessions_revoked",
        storagePendingPrefixes: batch.pendingPrefixes,
      });
      if (!transitioned) throw new Error("deletion_lease_lost");
      logEdgeEvent("info", "account_deletion_storage_batch", {
        requestId: options.input.requestId,
        deleted: batch.deleted,
        remainingPrefixes: batch.pendingPrefixes.length,
      });
      return {
        accepted: true,
        completed: false,
        state: batch.complete ? "storage_deleted" : "sessions_revoked",
        retry: true,
      };
    } catch (error) {
      const code = error instanceof Error
        ? error.message.slice(0, 100)
        : "storage_cleanup_failed";
      await transitionRequest({
        requestId: options.input.requestId,
        leaseId,
        expectedState: "sessions_revoked",
        nextState: "sessions_revoked",
        storagePendingPrefixes: safePendingPrefixes(
          claim.storagePendingPrefixes,
          userId,
        ),
        errorCode: code,
      });
      throw error;
    }
  }

  const deleted = await deleteAuthUser(userId);
  const transitioned = await transitionRequest({
    requestId: options.input.requestId,
    leaseId,
    expectedState: "storage_deleted",
    nextState: deleted ? "completed" : "storage_deleted",
    errorCode: deleted ? undefined : "auth_deletion_failed",
  });
  if (!transitioned) throw new Error("deletion_lease_lost");
  return {
    accepted: true,
    completed: deleted,
    state: deleted ? "completed" : "storage_deleted",
    retry: !deleted,
  };
}

export async function listReconcileCandidates(
  limit = 5,
): Promise<DeletionRequestInput[]> {
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/list_account_deletion_reconcile_candidates`,
    {
      method: "POST",
      headers: serviceHeaders(),
      body: JSON.stringify({ p_limit: Math.min(Math.max(limit, 1), 20) }),
    },
    { timeoutMs: 5_000, dependency: "account_deletion_candidates" },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return [];
  }
  const rows = await response.json();
  if (!Array.isArray(rows)) return [];
  return rows.flatMap((row: unknown) => {
    if (!row || typeof row !== "object" || Array.isArray(row)) return [];
    const requestId = (row as Record<string, unknown>).request_id;
    return typeof requestId === "string" && /^[0-9a-f]{64}$/.test(requestId)
      ? [{
        action: "delete" as const,
        requestId,
        receipt: "internal-reconciliation-token",
      }]
      : [];
  });
}

