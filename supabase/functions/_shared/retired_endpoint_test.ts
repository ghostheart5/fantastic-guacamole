import {
  RETIRED_ENDPOINT_BODY,
  retiredEndpointResponse,
} from "./retired_endpoint.ts";

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, received ${actual}`);
  }
}

Deno.test("retired endpoints fail closed without reflecting caller data", async () => {
  const response = retiredEndpointResponse();
  const body = await response.json();

  assertEquals(response.status, 410);
  assertEquals(response.headers.get("cache-control"), "no-store");
  assertEquals(response.headers.get("access-control-allow-origin"), null);
  assertEquals(body.error, RETIRED_ENDPOINT_BODY.error);
  assertEquals(body.message, RETIRED_ENDPOINT_BODY.message);
});
