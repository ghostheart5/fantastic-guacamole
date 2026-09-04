import {
  deletionIdentifiers,
  getDeletionStatus,
  processDeletionRequest,
} from "./account_deletion_state_machine.ts";

const config = {
  supabaseUrl: "https://example.supabase.co",
  publishableKey: "publishable-test-key",
  serviceRoleKey: "service-role-test-key",
};

Deno.test("deletion identifiers are stable and opaque", async () => {
  const first = await deletionIdentifiers("user-1", "Bearer secret-token");
  const second = await deletionIdentifiers("user-1", "Bearer secret-token");
  if (
    first.requestId !== second.requestId ||
    first.receipt !== second.receipt ||
    first.receiptHash !== second.receiptHash
  ) {
    throw new Error("deletion identifiers must be stable");
  }
  if (
    first.requestId.includes("user-1") ||
    first.receipt.includes("secret-token") ||
    first.receiptHash.includes("secret-token")
  ) {
    throw new Error("deletion identifiers must not expose source values");
  }
});

Deno.test("reads status only when both request and receipt hash match", async () => {
  const status = await getDeletionStatus(
    "a".repeat(64),
    "b".repeat(64),
    config,
    (input) => {
      const url = new URL(String(input));
      if (
        url.searchParams.get("request_id") !== `eq.${"a".repeat(64)}` ||
        url.searchParams.get("receipt_hash") !== `eq.${"b".repeat(64)}`
      ) {
        throw new Error("status query did not bind both capabilities");
      }
      return Promise.resolve(Response.json([{ state: "storage_deleted" }]));
    },
  );
  if (status?.state !== "storage_deleted" || status.completed) {
    throw new Error(`unexpected status: ${JSON.stringify(status)}`);
  }
});

Deno.test("completes revocation, storage, auth, and durable status", async () => {
  const patches: Array<Record<string, unknown>> = [];
  const fetcher: typeof fetch = (input, init) => {
    const url = String(input);
    if (url.endsWith("/rpc/claim_account_deletion_request")) {
      return Promise.resolve(
        Response.json({
          claimed: true,
          state: "requested",
          userId: "user-1",
          sessionsRevoked: false,
          storageDeleted: false,
        }),
      );
    }
    if (url.endsWith("/rpc/revoke_account_deletion_sessions")) {
      return Promise.resolve(Response.json(true));
    }
    if (url.includes("/account_deletion_requests?")) {
      patches.push(JSON.parse(String(init?.body)) as Record<string, unknown>);
      return Promise.resolve(Response.json([{ request_id: "request" }]));
    }
    if (url.includes("/auth/v1/admin/users/user-1")) {
      return Promise.resolve(new Response(null, { status: 204 }));
    }
    throw new Error(`unexpected request: ${url}`);
  };

  const result = await processDeletionRequest({
    requestId: "a".repeat(64),
    receiptHash: "b".repeat(64),
    authenticatedUserId: "user-1",
    config,
    fetcher,
    storageCleanup: () => Promise.resolve(true),
  });

  if (!result.completed || result.state !== "completed") {
    throw new Error(`unexpected result: ${JSON.stringify(result)}`);
  }
  const completion = patches.at(-1);
  if (completion?.state !== "completed" || completion?.lease_id !== null) {
    throw new Error("completed deletion must persist a released tombstone");
  }
});

Deno.test("releases its lease when storage cleanup fails", async () => {
  const patches: Array<Record<string, unknown>> = [];
  const fetcher: typeof fetch = (input, init) => {
    const url = String(input);
    if (url.endsWith("/rpc/claim_account_deletion_request")) {
      return Promise.resolve(
        Response.json({
          claimed: true,
          state: "sessions_revoked",
          userId: "user-1",
          sessionsRevoked: true,
          storageDeleted: false,
        }),
      );
    }
    if (url.includes("/account_deletion_requests?")) {
      patches.push(JSON.parse(String(init?.body)) as Record<string, unknown>);
      return Promise.resolve(Response.json([{ request_id: "request" }]));
    }
    throw new Error(`unexpected request: ${url}`);
  };

  const result = await processDeletionRequest({
    requestId: "a".repeat(64),
    authenticatedUserId: "user-1",
    receiptHash: "b".repeat(64),
    config,
    fetcher,
    storageCleanup: () => Promise.resolve(false),
  });

  if (!result.retry || result.state !== "sessions_revoked") {
    throw new Error(`unexpected result: ${JSON.stringify(result)}`);
  }
  const release = patches.at(-1);
  if (
    release?.lease_id !== null ||
    release?.last_error_code !== "storage_cleanup_failed"
  ) {
    throw new Error("failed cleanup must release the lease with an error code");
  }
});
