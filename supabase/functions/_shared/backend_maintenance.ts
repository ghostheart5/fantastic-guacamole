/// <reference lib="deno.ns" />
import { fetchWithDeadline } from "./edge_http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY") ??
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface MaintenanceResult {
  staleReservationsRefunded: number;
  expiredResponsePayloadsPurged: number;
  staleSubscriptionsExpired: number;
}

async function invokeIntegerRpc(
  name: string,
  body: Record<string, unknown>,
): Promise<number> {
  if (!SUPABASE_URL || !SUPABASE_SECRET_KEY) {
    throw new Error("backend_maintenance_not_configured");
  }
  const response = await fetchWithDeadline(
    `${SUPABASE_URL}/rest/v1/rpc/${name}`,
    {
      method: "POST",
      headers: {
        apikey: SUPABASE_SECRET_KEY,
        Authorization: `Bearer ${SUPABASE_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
    { timeoutMs: 5_000, dependency: `maintenance_${name}` },
  );
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(`maintenance_${name}_${response.status}`);
  }
  const value = await response.json();
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    throw new Error(`maintenance_${name}_invalid_result`);
  }
  return value;
}

export async function runBackendMaintenance(): Promise<MaintenanceResult> {
  const staleReservationsRefunded = await invokeIntegerRpc(
    "refund_stale_ai_usage_reservations",
    { p_older_than: "10 minutes" },
  );
  const expiredResponsePayloadsPurged = await invokeIntegerRpc(
    "purge_expired_ai_response_payloads",
    {},
  );
  const staleSubscriptionsExpired = await invokeIntegerRpc(
    "expire_stale_monetization_subscriptions",
    {},
  );
  return {
    staleReservationsRefunded,
    expiredResponsePayloadsPurged,
    staleSubscriptionsExpired,
  };
}

