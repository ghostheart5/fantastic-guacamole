import { hasOnlyKeys } from "./edge_http.ts";

export interface VerifyRequest {
  productId: string;
  purchaseToken: string;
  purchaseType: "subscription" | "inapp";
}

export function readVerifyRequest(value: unknown): VerifyRequest | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  if (
    !hasOnlyKeys(
      record,
      new Set(["productId", "purchaseToken", "purchaseType"]),
    ) ||
    typeof record.productId !== "string" ||
    typeof record.purchaseToken !== "string" ||
    (record.purchaseType !== "subscription" && record.purchaseType !== "inapp")
  ) return null;
  return {
    productId: record.productId.trim(),
    purchaseToken: record.purchaseToken.trim(),
    purchaseType: record.purchaseType,
  };
}

