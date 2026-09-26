import {
  authenticatedDeletionUser,
  deletionIdentifiers,
  getDeletionStatus,
  processDeletionRequest,
} from "../../supabase/functions/_shared/account_deletion_state_machine.ts";

// Real Auth, PostgREST, Storage and deletion state machine; synthetic data only.
// Network permissions and this exact endpoint guard exclude hosted projects.
Deno.test("two-account cloud isolation and durable deletion reject lingering credentials", async () => {
  const base = Deno.env.get("LOCAL_SUPABASE_URL");
  const service = Deno.env.get("LOCAL_SUPABASE_SERVICE_KEY");
  const anon = Deno.env.get("LOCAL_SUPABASE_ANON_KEY");
  function check(value: unknown, message: string): asserts value {
    if (!value) throw new Error(message);
  }
  check(
    Deno.env.get("AXIOMARA_DISPOSABLE_DB_GATE") === "true" &&
      base === "http://127.0.0.1:54321" && service && anon,
    "Requires explicitly disposable loopback Supabase",
  );
  const config = {
    supabaseUrl: base,
    publishableKey: anon,
    serviceRoleKey: service,
  };
  async function request(
    path: string,
    token: string,
    method = "GET",
    body?: unknown,
    admin = false,
  ) {
    const response = await fetch(`${base}${path}`, {
      method,
      headers: {
        apikey: admin ? service! : anon!,
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    return {
      status: response.status,
      ok: response.ok,
      data: text ? JSON.parse(text) : null,
    };
  }
  const users: Array<{ id: string; access: string; refresh: string }> = [];
  try {
    for (const label of ["a", "b"]) {
      const email = `cloud-${label}-${crypto.randomUUID()}@example.invalid`;
      const password = `Synthetic-${crypto.randomUUID()}!`;
      const created = await request("/auth/v1/admin/users", service, "POST", {
        email,
        password,
        email_confirm: true,
      }, true);
      check(
        created.ok && created.data.id,
        "Could not create synthetic account",
      );
      users.push({ id: created.data.id, access: "", refresh: "" });
      const login = await request(
        "/auth/v1/token?grant_type=password",
        anon,
        "POST",
        { email, password },
      );
      check(login.ok && login.data.access_token, "Synthetic sign-in failed");
      users[users.length - 1].access = login.data.access_token;
      users[users.length - 1].refresh = login.data.refresh_token;
    }
    const [a, b] = users;
    const table = "/rest/v1/cloud_backup_snapshots";
    for (const user of users) {
      const inserted = await request(table, user.access, "POST", {
        user_id: user.id,
        revision: 1,
        payload: { synthetic: user.id },
      });
      check(inserted.ok, "Owner snapshot insert failed");
      const uploaded = await request(
        `/storage/v1/object/chronospark-sync/${user.id}/backup/tasks_backup.json`,
        user.access,
        "POST",
        { synthetic: user.id },
      );
      check(uploaded.ok, "Owner storage upload failed");
    }
    const foreign = await request(`${table}?user_id=eq.${a.id}`, b.access);
    check(
      foreign.ok && foreign.data.length === 0,
      "Another account could read owner snapshot",
    );
    const overwrite = await request(
      `${table}?user_id=eq.${a.id}&revision=eq.1`,
      b.access,
      "PATCH",
      { revision: 2, payload: { leaked: true } },
    );
    check(
      overwrite.ok && overwrite.data.length === 0,
      "Another account could update owner snapshot",
    );
    const foreignStorage = await request(
      `/storage/v1/object/authenticated/chronospark-sync/${a.id}/backup/tasks_backup.json`,
      b.access,
    );
    check(!foreignStorage.ok, "Another account could download owner storage");
    const foreignWrite = await request(
      `/storage/v1/object/chronospark-sync/${a.id}/backup/foreign.json`,
      b.access,
      "POST",
      { leaked: true },
    );
    check(!foreignWrite.ok, "Another account could write owner storage");

    const authenticated = await authenticatedDeletionUser(
      `Bearer ${a.access}`,
      config,
    );
    check(
      authenticated?.id === a.id && authenticated.sessionSignInAtSeconds,
      "Deletion requires a real recent Auth session",
    );
    const ids = await deletionIdentifiers(a.id, `Bearer ${a.access}`);
    const deleted = await processDeletionRequest({
      requestId: ids.requestId,
      receiptHash: ids.receiptHash,
      authenticatedUserId: a.id,
      config,
    });
    check(
      deleted.accepted && deleted.completed,
      "Real deletion state machine did not complete",
    );
    check(
      (await getDeletionStatus(ids.requestId, ids.receiptHash, config))
        ?.completed,
      "Deletion receipt did not report completion",
    );
    check(
      await getDeletionStatus(ids.requestId, "0".repeat(64), config) === null,
      "Wrong receipt exposed deletion state",
    );
    const repeat = await processDeletionRequest({
      requestId: ids.requestId,
      receiptHash: ids.receiptHash,
      authenticatedUserId: a.id,
      config,
    });
    check(repeat.completed, "Deletion retry was not idempotent");
    check(
      await authenticatedDeletionUser(`Bearer ${a.access}`, config) === null,
      "Deleted session still authenticates",
    );
    const refresh = await request(
      "/auth/v1/token?grant_type=refresh_token",
      anon,
      "POST",
      { refresh_token: a.refresh },
    );
    check(!refresh.ok, "Deleted account refresh token still works");
    const remaining = await request(
      `${table}?user_id=eq.${a.id}`,
      service,
      "GET",
      undefined,
      true,
    );
    check(
      remaining.ok && remaining.data.length === 0,
      "Account-linked snapshot survived deletion",
    );
    const profile = await request(
      `/rest/v1/profiles?id=eq.${a.id}`,
      service,
      "GET",
      undefined,
      true,
    );
    check(profile.ok && profile.data.length === 0, "Profile survived deletion");
    const storage = await request(
      "/storage/v1/object/list/chronospark-sync",
      service,
      "POST",
      { prefix: `${a.id}/backup` },
      true,
    );
    check(
      storage.ok && storage.data.length === 0,
      "Account storage survived deletion",
    );
    const resurrect = await request(table, a.access, "POST", {
      user_id: a.id,
      revision: 1,
      payload: { resurrected: true },
    });
    check(!resurrect.ok, "Lingering JWT recreated a deleted snapshot");
    const resurrectStorage = await request(
      `/storage/v1/object/chronospark-sync/${a.id}/backup/resurrected.json`,
      a.access,
      "POST",
      { resurrected: true },
    );
    check(!resurrectStorage.ok, "Lingering JWT recreated deleted storage");
    const survivor = await request(`${table}?user_id=eq.${b.id}`, b.access);
    check(
      survivor.ok && survivor.data.length === 1 &&
        survivor.data[0].payload.synthetic === b.id,
      "Deleting A damaged account B",
    );
  } finally {
    // All IDs below were created by this run, behind the loopback-only guard.
    for (const user of users) {
      const removedStorage = await request(
        "/storage/v1/object/chronospark-sync",
        service,
        "DELETE",
        {
          prefixes: [
            `${user.id}/backup/tasks_backup.json`,
            `${user.id}/backup/foreign.json`,
            `${user.id}/backup/resurrected.json`,
          ],
        },
        true,
      );
      check(removedStorage.ok, "Synthetic storage cleanup failed");
      const removed = await request(
        `/auth/v1/admin/users/${user.id}`,
        service,
        "DELETE",
        undefined,
        true,
      );
      check(
        removed.ok || removed.status === 404,
        "Synthetic account cleanup failed",
      );
    }
  }
});
