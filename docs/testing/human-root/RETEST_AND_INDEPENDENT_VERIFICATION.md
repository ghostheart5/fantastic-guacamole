# Human Root retest and independent verification

Version: `1.0.0`

## Retest rules

1. A failed case stays `FAIL` until a new candidate build or approved
   configuration is identified in a new or amended passport.
2. The retest repeats the original case with the same persona, dataset,
   environment, device class, and fault condition unless the defect requires a
   documented change.
3. The tester links the original defect, original evidence, fix commit, new
   binary hash, retest evidence, and an automated regression reference where
   feasible. A screenshot alone is insufficient for a state, payment, deletion,
   security, or interruption defect.
4. A case cannot be converted from `FAIL` to `PASS` by editing history, replacing
   evidence, or relying on a later unrelated run.
5. If the fix changes candidate identity, all affected root cases are reassessed;
   the mandatory core journey is rerun when data, auth, lifecycle, navigation,
   Creator, Timeline, Nexus, Trajectory, Progression, Profile, or Settings could
   be affected.

## Independent verification

The verifier must not be the primary tester and must have access to the exact
candidate/passport. They independently repeat the core journey, payment/restore,
account deletion, and automatic-veto retests where safe. For other cases they may
verify a fresh replay or review evidence only when the registry explicitly allows
it.

The verifier confirms:

- candidate SHA and binary hash match the passport;
- environment/persona/dataset/device are permitted and correctly recorded;
- the terminal state matches the claimed result;
- evidence is complete, legible, and redacted;
- linked defects have an appropriate severity and no veto remains;
- Smart Planner and SI Console remain isolated with no unintended shared state.

Both signatures are required for a `GO`. Missing independent verification is
`BLOCKED`, never an implied approval.
