# Internal 3018 prepaid allowance and Settings repair

Prepared after the live failures recorded in the 3017 acceptance report. Public launch containment remains closed. This candidate is for the existing internal track and two authorized accounts only.

The proposed database migration adds a separate prepaid grant cause and unique purchase-token index while retaining the global unique-order guard. The reconciliation branch requires active, non-renewing Google authority, the exact monthly prepaid test base plan, and Google's verified test-purchase marker. It fills the 300-credit allowance once without requiring predecessor lineage. It does not rewrite any existing wallet or grant. Edge handlers now pass those fields from the Google response. Ordinary production grant rules are unchanged.

RTDN cancellation handling accepts Google's already-expired terminal snapshot and standalone canceled pending purchases. Linked predecessor authority remains separate; contradictory active/pending states still fail. The core fix was deployed as RTDN v16 and recovered the observed failed notification. Subsequent prepaid metadata changes and the database migration have not yet been deployed at this checkpoint.

Settings status copy now follows actual internal credit availability. Toggle rows merge their label and switch semantics, and a label tap changes the control once. The regression checks both label and switch taps and the accessible name.

Local checks: 99 Edge Function tests, six catalog checks, 24 Settings/credit-panel tests, targeted Dart analysis, and migration replay policy pass. The new 12-case database regression and full hosted candidate checks remain pending. The original toggle test needed a visible scroll position and correctly scoped semantics cleanup; the repaired test passes without weakened assertions.

No monkey or level-20 tests are part of this work. No all-pass or production-readiness claim is made.
