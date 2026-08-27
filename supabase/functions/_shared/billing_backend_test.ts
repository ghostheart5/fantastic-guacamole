import { clientIp, sha256Hex } from "./billing_backend.ts";

Deno.test("billing rate limits use the first trusted forwarding hop", () => {
  const request = new Request("https://example.invalid", {
    headers: { "x-forwarded-for": "203.0.113.8, 10.0.0.4" },
  });
  if (clientIp(request) !== "203.0.113.8") {
    throw new Error("forwarded client address was not normalized");
  }
});

Deno.test("billing identifiers are irreversibly hashed", async () => {
  const value = await sha256Hex("user:account-1");
  if (!/^[0-9a-f]{64}$/.test(value) || value.includes("account-1")) {
    throw new Error("billing subject hash is malformed");
  }
});
