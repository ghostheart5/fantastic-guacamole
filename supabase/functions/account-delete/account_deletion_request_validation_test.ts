import { readDeletionInput } from "../_shared/account_deletion_state_machine.ts";

function expect(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

const requestId = "a".repeat(64);
const receipt = "R".repeat(32);

Deno.test("accepts a bounded deletion request and trims optional identity hints", () => {
  const value = readDeletionInput({
    action: "delete",
    requestId,
    receipt,
    userId: " 00000000-0000-4000-8000-000000000801 ",
    email: " user-a@example.test ",
  });
  expect(value?.action === "delete", "expected delete action");
  expect(value?.requestId === requestId, "expected request ID");
  expect(value?.receipt === receipt, "expected receipt");
  expect(
    value?.userId === "00000000-0000-4000-8000-000000000801",
    "expected trimmed user hint",
  );
  expect(value?.email === "user-a@example.test", "expected trimmed email");
});

Deno.test("accepts status lookup without turning it into deletion", () => {
  const value = readDeletionInput({ action: "status", requestId, receipt });
  expect(value?.action === "status", "status must remain read-only");
});

Deno.test("rejects malformed, missing, oversized, and non-object payloads", () => {
  const invalid = [
    null,
    [],
    "delete",
    {},
    { requestId: "not-hex", receipt },
    { requestId, receipt: "short" },
    { requestId, receipt: "x".repeat(257) },
    { requestId: requestId.toUpperCase(), receipt },
  ];
  for (const value of invalid) {
    expect(
      readDeletionInput(value) === null,
      "malformed input must fail closed",
    );
  }
});
