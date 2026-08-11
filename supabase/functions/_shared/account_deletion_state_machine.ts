/// <reference lib="deno.ns" />
import { sha256Hex } from "./google_auth.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const SUPABASE_PUBLISHABLE_KEY = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SYNC_BUCKET = "chronospark-sync";
const PAGE_SIZE = 1000;

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
  const action = body.action === "status" ? "status" : "delete";
  const requestId = typeof body.requestId === "string"
    ? body.requestId.trim()
    : "";
  const receipt = typeof body.receipt === "string" ? body.receipt.trim() : "";
  if (
    !/^[0-9a-f]{64}$/.test(requestId) ||
    !/^[A-Za-z0-9_-]{32,256}$/.test(receipt)
  ) {
    return null;
  }
  return {
    action,
    requestId,
    receipt,
    userId: typeof body.userId === "string" ? body.userId.trim() : undefined,
    email: typeof body.email === "string" ? body.email.trim() : undefined,
  };
}

export async function authenticatedDeletionUser(
  authorization: string,
): Promise<AuthenticatedDeletionUser | null> {
  if (!authorization.startsWith("Bearer ")) return null;
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: SUPABASE_PUBLISHABLE_KEY },
  });
  if (!response.ok) return null;
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
): Promise<Record<string, unknown> | null> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify(body),
  });
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
): Promise<boolean> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: serviceHeaders(),
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    await response.body?.cancel();
    return false;
  }
  return await response.json() === true;
}

async function patchRequest(
  requestId: string,
  leaseId: string,
  values: Record<string, unknown>,
): Promise<boolean> {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/account_deletion_requests?request_id=eq.${requestId}&lease_id=eq.${leaseId}`,
    {
      method: "PATCH",
      headers: { ...serviceHeaders(), Prefer: "return=minimal" },
      body: JSON.stringify({ ...values, updated_at: new Date().toISOString() }),
    },
  );
  return response.ok;
}

async function listStorageFiles(prefix: string): Promise<string[] | null> {
  const files: string[] = [];
  let offset = 0;
  while (true) {
    const response = await fetch(
      `${SUPABASE_URL}/storage/v1/object/list/${SYNC_BUCKET}`,
      {
        method: "POST",
        headers: serviceHeaders(),
        body: JSON.stringify({
          prefix,
          limit: PAGE_SIZE,
          offset,
          sortBy: { column: "name", order: "asc" },
        }),
      },
    );
    if (!response.ok) return null;
    const entries = await response.json() as StorageListItem[];
    if (!Array.isArray(entries)) return null;
    for (const entry of entries) {
      if (typeof entry.name !== "string" || !entry.name) continue;
      const path = `${prefix}/${entry.name}`.replace(/^\/+/, "");
      if (entry.id) {
        files.push(path);
      } else {
        const nested = await listStorageFiles(path);
        if (nested === null) return null;
        files.push(...nested);
      }
    }
    if (entries.length < PAGE_SIZE) return files;
    offset += entries.length;
  }
}

async function deleteStorageObjects(userId: string): Promise<boolean> {
  const files = await listStorageFiles(userId);
  if (files === null) return false;
  for (let index = 0; index < files.length; index += PAGE_SIZE) {
    const response = await fetch(
      `${SUPABASE_URL}/storage/v1/object/${SYNC_BUCKET}`,
      {
        method: "DELETE",
        headers: serviceHeaders(),
        body: JSON.stringify({
          prefixes: files.slice(index, index + PAGE_SIZE),
        }),
      },
    );
    if (!response.ok) return false;
  }
  return true;
}

async function deleteAuthUser(userId: string): Promise<boolean> {
  const response = await fetch(
    `${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
    { method: "DELETE", headers: serviceHeaders() },
  );
  return response.ok || response.status === 404;
}

export async function processDeletionRequest(options: {
  input: DeletionRequestInput;
  authenticatedUserId?: string;
  allowInternal?: boolean;
}): Promise<Record<string, unknown>> {
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
    };
  }
  if (claim.completed === true) {
    return { accepted: true, completed: true, state: "completed" };
  }
  const userId = claim.userId?.toString() ?? "";
  if (!userId) return { accepted: false, completed: false, state: "invalid" };

  if (claim.sessionsRevoked !== true) {
    const revoked = await serviceBooleanRpc(
      "revoke_account_deletion_sessions",
      {
        p_request_id: options.input.requestId,
        p_lease_id: leaseId,
      },
    );
    if (revoked !== true) {
      await patchRequest(options.input.requestId, leaseId, {
        lease_id: null,
        lease_until: null,
        last_error_code: "session_revocation_failed",
      });
      return {
        accepted: true,
        completed: false,
        state: "requested",
        retry: true,
      };
    }
    if (
      !await patchRequest(options.input.requestId, leaseId, {
        state: "sessions_revoked",
        sessions_revoked_at: new Date().toISOString(),
        last_error_code: null,
      })
    ) throw new Error("deletion_state_update_failed");
  }

  if (claim.storageDeleted !== true) {
    if (!await deleteStorageObjects(userId)) {
      await patchRequest(options.input.requestId, leaseId, {
        lease_id: null,
        lease_until: null,
        last_error_code: "storage_cleanup_failed",
      });
      return {
        accepted: true,
        completed: false,
        state: "sessions_revoked",
        retry: true,
      };
    }
    if (
      !await patchRequest(options.input.requestId, leaseId, {
        state: "storage_deleted",
        storage_deleted_at: new Date().toISOString(),
        last_error_code: null,
      })
    ) throw new Error("deletion_state_update_failed");
  }

  if (!await deleteAuthUser(userId)) {
    await patchRequest(options.input.requestId, leaseId, {
      lease_id: null,
      lease_until: null,
      last_error_code: "auth_deletion_failed",
    });
    return {
      accepted: true,
      completed: false,
      state: "storage_deleted",
      retry: true,
    };
  }

  if (
    !await patchRequest(options.input.requestId, leaseId, {
      state: "completed",
      auth_deleted_at: new Date().toISOString(),
      completed_at: new Date().toISOString(),
      lease_id: null,
      lease_until: null,
      last_error_code: null,
    })
  ) throw new Error("deletion_completion_update_failed");

  return { accepted: true, completed: true, state: "completed" };
}

export async function listReconcileCandidates(
  limit = 20,
): Promise<DeletionRequestInput[]> {
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/account_deletion_requests?state=neq.completed&order=updated_at.asc&limit=${limit}&select=request_id`,
    { headers: serviceHeaders() },
  );
  if (!response.ok) return [];
  const rows = await response.json();
  if (!Array.isArray(rows)) return [];
  return rows.flatMap((row: unknown) => {
    if (!row || typeof row !== "object" || Array.isArray(row)) return [];
    const requestId = (row as Record<string, unknown>).request_id;
    return typeof requestId === "string"
      ? [{
        action: "status" as const,
        requestId,
        receipt: "internal-reconciliation-token",
      }]
      : [];
  });
}
