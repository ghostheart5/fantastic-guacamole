import { verifyManifest } from "./verify_manifest.ts";

Deno.test("hosted-state manifest is internally consistent", async () => {
  const failures = await verifyManifest();
  if (failures.length > 0) {
    throw new Error(failures.join("\n"));
  }
});
