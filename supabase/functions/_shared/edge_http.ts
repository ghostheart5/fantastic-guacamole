/// <reference lib="deno.ns" />

export class EdgeHttpError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    message = code,
  ) {
    super(message);
    this.name = "EdgeHttpError";
  }
}

export interface DeadlineOptions {
  timeoutMs: number;
  dependency: string;
  signal?: AbortSignal;
}

export async function fetchWithDeadline(
  input: RequestInfo | URL,
  init: RequestInit = {},
  options: DeadlineOptions,
): Promise<Response> {
  if (!Number.isFinite(options.timeoutMs) || options.timeoutMs < 1) {
    throw new EdgeHttpError("invalid_deadline", 500);
  }
  const controller = new AbortController();
  const abortFromCaller = () => controller.abort(options.signal?.reason);
  options.signal?.addEventListener("abort", abortFromCaller, { once: true });
  const timer = setTimeout(
    () =>
      controller.abort(new DOMException("deadline exceeded", "TimeoutError")),
    options.timeoutMs,
  );
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) {
      throw new EdgeHttpError(
        "dependency_timeout",
        504,
        `${options.dependency} deadline exceeded`,
      );
    }
    throw error;
  } finally {
    clearTimeout(timer);
    options.signal?.removeEventListener("abort", abortFromCaller);
  }
}

export interface JsonReadOptions {
  maxBytes: number;
  allowedContentTypes?: readonly string[];
}

export async function readBoundedJson(
  req: Request,
  options: JsonReadOptions,
): Promise<unknown> {
  const allowed = options.allowedContentTypes ?? ["application/json"];
  const contentType = (req.headers.get("content-type") ?? "")
    .split(";", 1)[0]
    .trim()
    .toLowerCase();
  if (!allowed.includes(contentType)) {
    throw new EdgeHttpError("unsupported_media_type", 415);
  }
  const encoding = (req.headers.get("content-encoding") ?? "identity")
    .trim()
    .toLowerCase();
  if (encoding && encoding !== "identity") {
    throw new EdgeHttpError("unsupported_content_encoding", 415);
  }
  const declaredLength = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > options.maxBytes) {
    throw new EdgeHttpError("request_body_too_large", 413);
  }
  if (!req.body) throw new EdgeHttpError("empty_request_body", 400);

  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value) continue;
      total += value.byteLength;
      if (total > options.maxBytes) {
        await reader.cancel("request body too large");
        throw new EdgeHttpError("request_body_too_large", 413);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new EdgeHttpError("invalid_json", 400);
  }
}

export async function readBoundedResponseJson(
  response: Response,
  options: JsonReadOptions,
): Promise<unknown> {
  const allowed = options.allowedContentTypes ?? ["application/json"];
  const contentType = (response.headers.get("content-type") ?? "")
    .split(";", 1)[0]
    .trim()
    .toLowerCase();
  if (!allowed.includes(contentType)) {
    await response.body?.cancel();
    throw new EdgeHttpError("dependency_invalid_content_type", 502);
  }
  const declaredLength = Number(response.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > options.maxBytes) {
    await response.body?.cancel();
    throw new EdgeHttpError("dependency_response_too_large", 502);
  }
  if (!response.body) {
    throw new EdgeHttpError("dependency_empty_response", 502);
  }
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value) continue;
      total += value.byteLength;
      if (total > options.maxBytes) {
        await reader.cancel("dependency response too large");
        throw new EdgeHttpError("dependency_response_too_large", 502);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new EdgeHttpError("dependency_invalid_json", 502);
  }
}

export function hasOnlyKeys(
  value: Record<string, unknown>,
  allowed: ReadonlySet<string>,
): boolean {
  return Object.keys(value).every((key) => allowed.has(key));
}

export function safeCorrelationId(value: unknown): string {
  return typeof value === "string" && /^[A-Za-z0-9._:-]{8,128}$/.test(value)
    ? value
    : crypto.randomUUID();
}

export function logEdgeEvent(
  level: "info" | "warn" | "error",
  event: string,
  fields: Record<string, string | number | boolean | null | undefined> = {},
): void {
  const safeFields = Object.fromEntries(
    Object.entries(fields).filter(([, value]) => value !== undefined),
  );
  const line = JSON.stringify({
    event,
    at: new Date().toISOString(),
    ...safeFields,
  });
  if (level === "error") console.error(line);
  else if (level === "warn") console.warn(line);
  else console.log(line);
}

