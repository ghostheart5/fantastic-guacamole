import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_PUBLISHABLE_KEY = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ALLOWED_ORIGINS = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ??
      "https://chronospark.app,https://www.chronospark.app")
    .split(",")
    .map((value: string) => value.trim())
    .filter(Boolean),
);

function cors(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? "";
  return {
    ...(ALLOWED_ORIGINS.has(origin)
      ? { "Access-Control-Allow-Origin": origin }
      : {}),
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}

async function authenticatedUser(req: Request): Promise<{
  id: string;
  email: string | null;
} | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ") || !SUPABASE_URL ||
    !SUPABASE_PUBLISHABLE_KEY) {
    return null;
  }

  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      Authorization: authorization,
      apikey: SUPABASE_PUBLISHABLE_KEY,
    },
  });
  if (!response.ok) {
    return null;
  }
  const user = await response.json();
  if (typeof user?.id !== "string") {
    return null;
  }
  return {
    id: user.id,
    email: typeof user?.email === "string" ? user.email : null,
  };
}

async function readDeleteRequest(
  req: Request,
): Promise<{ userId: string; email: string | null } | null> {
  try {
    const parsed = await req.json();
    if (!parsed || typeof parsed !== "object") {
      return null;
    }
    const record = parsed as Record<string, unknown>;
    if (typeof record.userId !== "string") {
      return null;
    }
    return {
      userId: record.userId.trim(),
      email: typeof record.email === "string" ? record.email.trim() : null,
    };
  } catch {
    return null;
  }
}

async function deleteUser(userId: string): Promise<boolean> {
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) {
    return false;
  }
  const response = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${userId}`,
    {
      method: "DELETE",
      headers: {
        apikey: SUPABASE_SECRET_KEY,
        Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
      },
    });
  return response.ok;
}

serve(async (req: Request) => {
  const headers = cors(req);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers });
  }

  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405, headers });
    }

    if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY || !SUPABASE_SECRET_KEY) {
      return new Response(
        JSON.stringify({ error: "function not configured" }),
        { status: 500, headers: { ...headers, "Content-Type": "application/json" } },
      );
    }

    const authUser = await authenticatedUser(req);
    if (!authUser) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    const body = await readDeleteRequest(req);
    if (!body || body.userId.isEmpty) {
      return new Response(JSON.stringify({ error: "invalid request body" }), {
        status: 400,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    if (body.userId != authUser.id) {
      return new Response(JSON.stringify({ error: "user mismatch" }), {
        status: 403,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    if (body.email && authUser.email && body.email != authUser.email) {
      return new Response(JSON.stringify({ error: "email mismatch" }), {
        status: 403,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    const deleted = await deleteUser(authUser.id);
    if (!deleted) {
      return new Response(JSON.stringify({ error: "account deletion failed" }), {
        status: 502,
        headers: { ...headers, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ deleted: true }), {
      status: 200,
      headers: { ...headers, "Content-Type": "application/json" },
    });
  } catch {
    return new Response(JSON.stringify({ error: "request failed" }), {
      status: 500,
      headers: { ...headers, "Content-Type": "application/json" },
    });
  }
});