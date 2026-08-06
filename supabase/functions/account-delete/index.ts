import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// Environment — injected by the Supabase runtime.
// Set SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY
// as Supabase project secrets:
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=eyJ...
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ?? "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean),
);

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin) ? { "Access-Control-Allow-Origin": origin } : {}),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}

// Verify the caller's Bearer JWT against Supabase Auth and return their user ID.
// Returns null if the token is missing, malformed, or invalid.
// The userId returned here is the authoritative identity used for all deletion
// operations — the userId field in the request body is never used to determine
// who is deleted, preventing arbitrary user deletion from the client.
async function authenticatedUserId(req: Request): Promise<string | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ") || !SUPABASE_URL || !SUPABASE_ANON_KEY) return null;
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authorization, apikey: SUPABASE_ANON_KEY },
  });
  if (!response.ok) return null;
  const user = await response.json();
  return typeof user?.id === "string" ? user.id : null;
}

// Delete all storage objects under the user's prefix in the chronospark-sync bucket.
// auth.users deletion cascades to database rows but NOT to storage objects, so
// storage must be cleaned up explicitly before the user record is removed.
async function deleteUserStorageObjects(userId: string): Promise<void> {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return;

  const serviceHeaders = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
  };

  // List all objects in the user's prefix. Limit is 1000 which covers
  // any realistic upload volume per user.
  const listRes = await fetch(`${SUPABASE_URL}/storage/v1/object/list/chronospark-sync`, {
    method: "POST",
    headers: serviceHeaders,
    body: JSON.stringify({ prefix: `${userId}/`, limit: 1000, offset: 0 }),
  });

  if (!listRes.ok) {
    // Non-fatal: log the failure but continue — the auth deletion still
    // removes the database rows. Orphaned storage objects can be cleaned
    // up by a scheduled maintenance job.
    console.error("Failed to list storage objects for deletion");
    return;
  }

  const objects: Array<{ name: string }> = await listRes.json();
  if (!Array.isArray(objects) || objects.length === 0) return;

  const prefixes = objects.map((obj) => `${userId}/${obj.name}`);

  const deleteRes = await fetch(
    `${SUPABASE_URL}/storage/v1/object/chronospark-sync`,
    {
      method: "DELETE",
      headers: serviceHeaders,
      body: JSON.stringify({ prefixes }),
    },
  );

  if (!deleteRes.ok) {
    console.error("Failed to delete storage objects");
  }
}

// Delete the auth.users record for userId using the service role key.
// The delete cascades to profiles, user_daily_metrics, and purchase_bindings
// via ON DELETE CASCADE foreign keys defined in the schema migrations.
async function deleteAuthUser(userId: string): Promise<{ ok: boolean; status: number }> {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return { ok: false, status: 500 };
  }
  const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${userId}`, {
    method: "DELETE",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
  });
  return { ok: res.ok, status: res.status };
}

interface DeleteRequest {
  userId?: string;  // client-provided for informational verification only
  email?: string;   // client-provided for informational verification only
}

interface DeleteResponse {
  success?: boolean;
  error?: string;
}

serve(async (req) => {
  const headers = cors(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405, headers });
    }

    // Authentication is required. The authenticated user's ID is the sole
    // determinant of whose data is deleted — client body fields are ignored
    // for the deletion target.
    const userId = await authenticatedUserId(req);
    if (!userId) {
      return new Response(
        JSON.stringify({ error: "unauthorized" } satisfies DeleteResponse),
        { status: 401, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    if (!SUPABASE_SERVICE_ROLE_KEY) {
      console.error("SUPABASE_SERVICE_ROLE_KEY is not configured");
      return new Response(
        JSON.stringify({ error: "service not configured" } satisfies DeleteResponse),
        { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    // Step 1: Remove storage objects. Must happen before auth user deletion
    // because storage RLS checks the auth user's JWT; after deletion the
    // service role path still works, but we clean up in dependency order.
    await deleteUserStorageObjects(userId);

    // Step 2: Delete the auth.users record. This cascades to all tables
    // that reference auth.users(id) with ON DELETE CASCADE:
    //   - public.profiles
    //   - public.user_daily_metrics
    //   - public.purchase_bindings
    const result = await deleteAuthUser(userId);

    if (!result.ok) {
      // 404 means the user was already deleted — treat as success so a
      // retry does not leave the client stuck.
      if (result.status === 404) {
        return new Response(
          JSON.stringify({ success: true } satisfies DeleteResponse),
          { headers: { ...headers, "Content-Type": "application/json" } },
        );
      }
      return new Response(
        JSON.stringify({ error: "deletion failed" } satisfies DeleteResponse),
        { status: 502, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ success: true } satisfies DeleteResponse),
      { headers: { ...headers, "Content-Type": "application/json" } },
    );
  } catch {
    console.error("Account deletion request failed");
    return new Response(
      JSON.stringify({ error: "request failed" } satisfies DeleteResponse),
      { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
    );
  }
});
