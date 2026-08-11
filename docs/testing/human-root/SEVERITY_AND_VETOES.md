# Human Root severity and release vetoes

Version: `1.0.0`

## Severity definitions

| Severity | Meaning | Release effect |
|---|---|---|
| P0 | Security, privacy, payment, deletion, data-integrity, crash-loop, or core-journey failure with no safe workaround | Automatic `NO-GO` |
| P1 | Major current-root behavior failure, inaccessible primary action, durable incorrect state, or broken recovery with no acceptable release workaround | Automatic `NO-GO` |
| P2 | Material non-core defect with a documented workaround and bounded impact | `BLOCKED` pending Release Engineering decision and risk acceptance |
| P3 | Minor cosmetic, copy, or low-risk behavior defect | Track; does not independently block release |

## Automatic release vetoes

Any observed or credibly reproduced instance is an automatic `NO-GO`:

1. Data loss or confirmed corruption of user-created task, goal, habit/routine,
   note, Timeline, Profile, Settings, Progression, or entitlement state.
2. Cross-user data visibility, modification, account switch leakage, or any
   authentication/authorization bypass.
3. Duplicate charge, duplicate payment verification, duplicate credit award or
   debit, or entitlement applied to the wrong account.
4. Irreversible incorrect state, including wrong completion/skip/reschedule,
   incorrect deletion, or wrong account deletion outcome.
5. Crash loop, inability to launch, or a broken mandatory core journey.
6. Inaccessible primary action, focus trap, clipped critical control, missing
   destructive confirmation, or inaccessible error/recovery path.
7. Account deletion failure, including incomplete deletion, deletion of the
   wrong account, or exposure of deleted account data.
8. Sensitive data exposure in UI, screen recording, logs, exports, diagnostics,
   or an unauthorized recipient.
9. Unauthorized connection, shared draft/state, navigation, persistence, or
   data flow between Smart Planner and SI Console or any chat surface.

## Decision rules

- `GO` requires no unresolved P0/P1, all mandatory cases PASS with complete
  evidence, independent verification, and no other release gate blocked.
- `BLOCKED` is used for incomplete evidence, unavailable environment/device,
  unresolved P2 risk, or an unexecuted required case. It is not a pass.
- `NO-GO` is used for any automatic veto or unresolved P0/P1.
- A waiver cannot change an automatic-veto decision. It may only document why a
  non-veto P2/P3 is accepted, with owner, expiry, and mitigation.
