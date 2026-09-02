# ChronoSpark Known Limitations

[`APP_ONLY_READINESS_MATRIX.md`](APP_ONLY_READINESS_MATRIX.md) separates the
professor-report baseline at
`6118ba6df289ca89472ba804307a85be00a0c0f2` from provisional Gate 1 working-tree
evidence. After commit, the Gate 1 candidate is the commit carrying that matrix;
its CI status must be read from checks attached to that exact SHA. This summary
must not be used without those evidence boundaries.

Professor baseline verdict:

- Developer/internal use: `PASS` with the limitations below.
- Supervised app-only pilot: `BLOCKED` until Priorities 1-3 and minimum
  exact-build physical-device smoke proof pass.
- Public advanced-planner claim: `BLOCKED` pending behavior, device,
  accessibility, performance, and UAT evidence.
- Public whole-person or equivalent understanding claim: `NO-GO`.

## App-only blockers

- At evaluated source `6118ba6`, golden PNGs exist but both named test files
  perform zero `matchesGoldenFile` comparisons. Gate 1 now defines five logical
  exact comparisons with separate reviewed Windows and Linux masters. Initial
  exact-commit CI run `33677111731` exposed the renderer split by failing only
  those five comparisons; a corrective commit is not promoted unless its own
  attached CI check passes.
- There is no single deterministic Person Context behavior policy governing
  ranking, constraints, surface output, override, and explanation.
- Relevant Person Context does not yet produce the required bounded,
  reversible recommendation delta across Nexus, Smart Planner, SI Console,
  Trajectory, and Creator.
- Learning is reachable but remains task-affinity focused and only partly
  visible and reversible across surfaces.
- Learning access fails closed at the account-session boundary, but the current
  learning-state storage key is shared rather than namespaced per account.
- Exact-build physical-device, TalkBack, keyboard, rotation, offline,
  performance, and human-UAT evidence remains incomplete.
- Crisis and non-crisis distress handling still requires qualified review.
- Spanish coverage is not complete enough for a launch claim.

## Excluded external systems

Supabase, Firebase, Google identity/Play, cloud sync, subscriptions, billing,
Analytics, Crashlytics, external-AI transport, website hosting, DNS, App Links
public readback, and every deployed-service configuration are not graded by the
app-only contract. `NOT GRADED` does not mean passed or verified.

Launch containment remains active: cloud sync/restore, subscriptions, paid credit plans, external AI, credit spending, Analytics, Crashlytics, and inferred identity are disabled. This reduces pilot risk but does not establish production readiness.

- ChronoSpark is not yet a coherent whole-person AI/SI companion.
- External generative AI is not a reachable or approved product surface.
- Cloud restore and multi-device sync are not safe to expose.
- Paid subscription and credit benefits are not ready to market or enable. Phase 8 hardens source authority, detached-account recovery after free-only bootstrap use, out-of-app re-subscription lineage, account-hold recovery, hold-time repurchase, and lapsed-period allowance grants, but no disposable PostgreSQL, deployed-backend, Play sandbox, RTDN, signed-device, or human billing evidence exists for this checkpoint.
- Provider recheck rows retain only purchase-token hashes. A production worker cannot query Google Play from the hash alone and needs an approved token-reacquisition design before subscriptions can be enabled.
- Governed Planner preferences remain user-controlled and purpose-limited; their usefulness does not establish whole-person understanding.
- Account deletion outcomes are typed on the client, but deployed deletion recovery and verified billing-principal reattachment remain external gates.
- Crisis and non-crisis distress handling require qualified review.
- Whole-person domains and the canonical decision authority are improved locally but do not establish synthetic emotional intelligence or whole-person understanding.
- Spanish coverage is not complete enough for a launch claim.
- Host accessibility checks pass, but real-device screen-reader, visual, performance, exact-artifact, and human UAT evidence is incomplete.
- Production Firebase, Supabase, provider, billing, monitoring, backup, and retention settings remain external verification gates.
- Google Play listing, signing, submission, rollout, and publication are excluded and must not be performed in this project.

Strong Nexus, Creator, SI V2, Trajectory, governed-memory, account-boundary, RLS, deletion-state-machine, and deterministic-learning foundations must be preserved while these limitations are repaired.
