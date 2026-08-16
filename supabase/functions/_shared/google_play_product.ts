import { fetchWithDeadline } from "./edge_http.ts";

export type GooglePlayProductKind =
  | "subscription"
  | "nonconsumable"
  | "consumable";

export interface GooglePlayProductConfig {
  purchaseType: "subscription" | "inapp";
  kind: GooglePlayProductKind;
}

export const GOOGLE_PLAY_PRODUCTS: Readonly<
  Record<string, GooglePlayProductConfig>
> = Object.freeze({
  chronospark_premium_monthly: {
    purchaseType: "subscription",
    kind: "subscription",
  },
  chronospark_premium_annual: {
    purchaseType: "subscription",
    kind: "subscription",
  },
  chronospark_lifetime: { purchaseType: "inapp", kind: "nonconsumable" },
  chronospark_credits_100: { purchaseType: "inapp", kind: "consumable" },
  chronospark_credits_500: { purchaseType: "inapp", kind: "consumable" },
  chronospark_credits_1200: { purchaseType: "inapp", kind: "consumable" },
  chronospark_credits_3000: { purchaseType: "inapp", kind: "consumable" },
});

export function googlePlayProductConfig(
  productId: string,
): GooglePlayProductConfig | null {
  return GOOGLE_PLAY_PRODUCTS[productId] ?? null;
}

export async function completeGooglePlayDelivery(options: {
  accessToken: string;
  packageName: string;
  productId: string;
  purchaseToken: string;
  kind: GooglePlayProductKind;
  alreadyAcknowledged?: boolean;
  alreadyConsumed?: boolean;
}): Promise<boolean> {
  if (options.kind === "consumable" && options.alreadyConsumed) return true;
  if (options.kind !== "consumable" && options.alreadyAcknowledged) return true;
  const base =
    "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";
  const packageName = encodeURIComponent(options.packageName);
  const productId = encodeURIComponent(options.productId);
  const purchaseToken = encodeURIComponent(options.purchaseToken);
  const url = options.kind === "subscription"
    ? `${base}/${packageName}/purchases/subscriptions/${productId}/tokens/${purchaseToken}:acknowledge`
    : options.kind === "consumable"
    ? `${base}/${packageName}/purchases/products/${productId}/tokens/${purchaseToken}:consume`
    : `${base}/${packageName}/purchases/products/${productId}/tokens/${purchaseToken}:acknowledge`;
  const response = await fetchWithDeadline(
    url,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${options.accessToken}`,
        "Content-Type": "application/json",
      },
      body: "{}",
    },
    { timeoutMs: 8_000, dependency: "google_play_delivery_completion" },
  );
  if (response.ok || response.status === 409) {
    await response.body?.cancel();
    return true;
  }
  await response.body?.cancel();
  return false;
}

