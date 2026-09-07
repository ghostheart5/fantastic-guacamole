import {
  getGoogleAccessToken,
  googleServiceAccountCredentialFingerprint,
} from "./google_auth.ts";

Deno.test("runtime Google OAuth request uses the JWT bearer grant and a valid signed assertion", async () => {
  const keys = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const encoded = btoa(String.fromCharCode(
    ...new Uint8Array(
      await crypto.subtle.exportKey("pkcs8", keys.privateKey),
    ),
  ));
  const account = {
    client_email: "synthetic@example.invalid",
    private_key:
      `-----BEGIN PRIVATE KEY-----\n${encoded}\n-----END PRIVATE KEY-----\n`,
  };
  const originalFetch = globalThis.fetch;
  let exchanges = 0;
  globalThis.fetch = async (input, init) => {
    const req = new Request(input, init);
    if (
      req.url !== "https://oauth2.googleapis.com/token" || req.method !== "POST"
    ) {
      throw new Error("Unexpected OAuth destination or method");
    }
    const form = new URLSearchParams(await req.text());
    if (
      form.get("grant_type") !== "urn:ietf:params:oauth:grant-type:jwt-bearer"
    ) {
      return Response.json({ error: "unsupported_grant_type" }, {
        status: 400,
      });
    }
    const [header, claims, signature] = (form.get("assertion") ?? "").split(
      ".",
    );
    const decode = (value: string) =>
      Uint8Array.from(
        atob(value.replaceAll("-", "+").replaceAll("_", "/")),
        (c) => c.charCodeAt(0),
      );
    const payload = JSON.parse(new TextDecoder().decode(decode(claims)));
    const now = Math.floor(Date.now() / 1000);
    if (
      payload.iss !== account.client_email ||
      payload.scope !== "https://www.googleapis.com/auth/androidpublisher" ||
      payload.aud !== req.url || Math.abs(payload.iat - now) > 5 ||
      payload.exp - payload.iat !== 3600 ||
      !await crypto.subtle.verify(
        "RSASSA-PKCS1-v1_5",
        keys.publicKey,
        decode(signature),
        new TextEncoder().encode(`${header}.${claims}`),
      )
    ) {
      throw new Error("Invalid signed Google assertion");
    }
    exchanges++;
    return Response.json({ access_token: "synthetic-access-token" });
  };
  try {
    if (
      await getGoogleAccessToken(account) !== "synthetic-access-token" ||
      exchanges !== 1
    ) {
      throw new Error("OAuth exchange did not complete");
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

Deno.test("credential fingerprint ignores JSON metadata and PEM whitespace", async () => {
  const account = {
    client_email: "synthetic@example.invalid",
    private_key:
      "-----BEGIN PRIVATE KEY-----\nU1lOVEhFVElD\n-----END PRIVATE KEY-----\n",
  };
  const fingerprint = await googleServiceAccountCredentialFingerprint(account);
  const reformattedKey = account.private_key.replaceAll("\n", "\r\n");
  const reformatted = await googleServiceAccountCredentialFingerprint({
    ...account,
    private_key: reformattedKey,
  });
  if (!fingerprint || fingerprint !== reformatted) {
    throw new Error("Equivalent credentials did not match");
  }
  for (
    const changed of [
      { ...account, client_email: "other@example.invalid" },
      { ...account, private_key: "DIFFERENT" },
    ]
  ) {
    if (
      await googleServiceAccountCredentialFingerprint(changed) === fingerprint
    ) {
      throw new Error("Credential change was not detected");
    }
  }
});

Deno.test("missing Google credential cannot report a usable fingerprint", async () => {
  for (
    const account of [null, {}, { client_email: "synthetic@example.invalid" }]
  ) {
    if (await googleServiceAccountCredentialFingerprint(account) !== null) {
      throw new Error("Missing credential was accepted");
    }
  }
});
