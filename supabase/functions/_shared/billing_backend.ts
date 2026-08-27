/// <reference lib="deno.ns" />

export interface BillingBackendConfig {
  supabaseUrl: string;
  publishableKey: string;
  secretKey: string;
}

export type JsonObject = Record<string, unknown>;

export function clientIp(req: Request): string {
  const forwarded = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return forwarded || req.headers.get("cf-connecting-ip")?.trim() ||
    req.headers.get("x-real-ip")?.trim() || "unknown";
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

export async function authenticatedUserId(
  req: Request,
  config: BillingBackendConfig,
): Promise<string | null> {
  const authorization = req.headers.get("authorization") ?? "";
  if (
    !authorization.startsWith("Bearer ") || !config.supabaseUrl ||
    !config.publishableKey
  ) return null;
  const response = await fetch(`${config.supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: authorization,
      apikey: config.publishableKey,
    },
  });
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  const value = await response.json();
  return typeof value?.id === "string" ? value.id : null;
}

export async function serviceRpc(
  config: BillingBackendConfig,
  name: string,
  body: JsonObject,
): Promise<JsonObject | null> {
  if (!config.supabaseUrl || !config.secretKey) return null;
  const response = await fetch(
    `${config.supabaseUrl}/rest/v1/rpc/${encodeURIComponent(name)}`,
    {
      method: "POST",
      headers: {
        apikey: config.secretKey,
        Authorization: `Bearer ${config.secretKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );
  if (!response.ok) {
    await response.body?.cancel();
    return null;
  }
  const value = await response.json();
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as JsonObject
    : null;
}

async function consumeBucket(
  config: BillingBackendConfig,
  bucket: string,
  subjectHash: string,
  limit: number,
  windowSeconds: number,
): Promise<boolean> {
  const result = await serviceRpc(config, "consume_backend_rate_limit", {
    p_bucket: bucket,
    p_subject_hash: subjectHash,
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  return result?.allowed === true;
}

export async function consumeDurableRateLimits(
  req: Request,
  config: BillingBackendConfig,
  userId: string,
  options: {
    bucket: string;
    userLimit: number;
    ipLimit: number;
    windowSeconds?: number;
  },
): Promise<boolean> {
  const windowSeconds = options.windowSeconds ?? 60;
  const userHash = await sha256Hex(`user:${userId}`);
  const ipHash = await sha256Hex(`ip:${clientIp(req)}`);
  const userAllowed = await consumeBucket(
    config,
    `${options.bucket}:user`,
    userHash,
    options.userLimit,
    windowSeconds,
  );
  if (!userAllowed) return false;
  return await consumeBucket(
    config,
    `${options.bucket}:ip`,
    ipHash,
    options.ipLimit,
    windowSeconds,
  );
}
