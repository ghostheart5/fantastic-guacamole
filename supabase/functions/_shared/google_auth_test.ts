import { googleServiceAccountCredentialFingerprint } from "./google_auth.ts";

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
