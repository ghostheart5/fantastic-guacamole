import { unboundTerminalReconciliationWasHandled } from "../_shared/google_play_rtdn.ts";

for (const status of ["expired", "revoked"]) {
  for (const binding of [false, true, null]) {
    Deno.test(`terminal ${status} closes only with confirmed absent binding (${binding})`, async () => {
      const handled = await unboundTerminalReconciliationWasHandled(
        { applied: false, reason: "binding_not_found" },
        status,
        false,
        () => Promise.resolve(binding),
      );
      if (handled !== (binding === false)) {
        throw new Error("Unsafe terminal resolution");
      }
    });
  }
}

Deno.test("active, canceled, pending and unknown purchases remain retryable", async () => {
  for (
    const [status, active] of [
      ["active", true],
      ["grace", true],
      ["canceled", false],
      ["pending", false],
      ["on_hold", false],
      ["expired", true],
      ["unknown", false],
    ] as const
  ) {
    const handled = await unboundTerminalReconciliationWasHandled(
      { reason: "binding_not_found" },
      status,
      active,
      () => {
        throw new Error("Must not try to discard a nonterminal purchase");
      },
    );
    if (handled) throw new Error("Nonterminal purchase was discarded");
  }
});

Deno.test("database and authority failures are never acknowledged as terminal", async () => {
  for (
    const result of [null, {}, { reason: "purchase_not_found" }, {
      reason: "database_error",
    }]
  ) {
    if (
      await unboundTerminalReconciliationWasHandled(
        result,
        "expired",
        false,
        () => {
          throw new Error("Must retain unrelated failures");
        },
      )
    ) {
      throw new Error("Failure was discarded");
    }
  }
});
