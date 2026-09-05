# ChronoSpark Known Limitations

## Current evidence and remaining limits - 2026-09-04

Use the [current signed-candidate/device checkpoint](docs/engineering/SAFE_QUICK_PHASE_5_6_STATUS_20260904.md)
and [live backend checkpoint](docs/engineering/SAFE_QUICK_PHASE_7_STATUS_20260904.md)
for current status. Source `61c7331dda9e82201a0561dbcd79aa0b37118446` passed
exact-source CI (2,352 Flutter tests, 15 configuration tests, static checks,
goldens, integration, and coverage); signed build `33940078212`, physical smoke,
and one task save/restart/complete/restart journey passed. These do not establish
full device, service-runtime, human, safety, or production readiness.

The current source supports `en` and `es`; Spanish is not an absent/disabled
locale. Qualified Spanish usability, legal, and distress-language review remains
open. Bundled policy is adults 18+; Play declarations must match it. Domain work
is excluded from the current closeout scope and remains separately deferred.

The older app-only baseline and priority statements below preserve their original
evidence boundaries. References to uncommitted work, missing exact-source CI,
missing signing, or no device smoke must not override the newer checkpoints.
Containment is still not completion: AI, billing, sync/restore and telemetry
require their own gates before any separately approved enablement.

## Historical app-only baseline and priority limitations

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
- A single deterministic Person Context behavior policy and the bounded
  Nexus/Planner recommendation path now have focused Windows host proof, but
  the changes remain uncommitted and lack exact-commit CI, device, and human
  evidence.
- SI Console, Trajectory, and Creator now consume the shared policy for
  query-relevant evidence, bounded constraints, warnings, traceability, and
  correction/withdrawal invalidation. Priority 4 has focused Windows host proof
  only; the changes remain uncommitted and lack exact-commit CI, physical-device,
  deployed-service, and human-usefulness evidence.
- Priority 5 bounded preference learning now has focused Windows-host evidence
  for account scoping, decay, low-confidence gating, exact Smart Planner use,
  correction/undo, pause, export, retention, and delete-all. It remains an
  uncommitted host result without exact-commit CI, physical-device restart,
  localization, privacy-review, or human-usefulness evidence.
- Priority 6 first-use context now has focused Windows-host proof for a
  post-value, account-scoped optional offer, consent-before-save, lawful
  current-priority tie-break behavior, decline-without-write, visible Nexus
  discovery, Settings governance, semantics, and 200% small-viewport
  reachability. The binder exit remains open until representative participants
  complete the full timed path in under two minutes with zero facilitator
  rescue, and until Linux/exact-commit, device, and translation evidence exist.
- Priority 7's four binder-named files, planned-source reachability, static
  checks, full host suite, and target-mode 85/80/70 coverage gates now pass on
  the final Windows candidate. Exact-commit CI and device/runtime evidence are
  still separate unverified gates.
- Learned support preferences are purpose-limited surface/situation signals,
  not verified facts, identity attributes, synthetic emotional intelligence,
  or whole-person understanding.
- Exact-build physical-device, TalkBack, keyboard, rotation, offline,
  performance, and human-UAT evidence remains incomplete.
- Crisis and non-crisis distress handling still requires qualified review.
- Spanish source support exists; a fully validated Spanish launch claim still
  requires human language, legal, and distress-journey review.

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
- Spanish source support exists; a fully validated Spanish launch claim still
  requires human language, legal, and distress-journey review.
- Host accessibility checks pass, but real-device screen-reader, visual, performance, exact-artifact, and human UAT evidence is incomplete.
- Production Firebase, Supabase, provider, billing, monitoring, backup, and retention settings remain external verification gates.
- Google Play listing, signing, submission, rollout, and publication were excluded
  from the app-only audit contract. Later signed-artifact evidence is linked
  above; no checklist or audit result authorizes submission or rollout.

Strong Nexus, Creator, SI V2, Trajectory, governed-memory, account-boundary, RLS, deletion-state-machine, and deterministic-learning foundations must be preserved while these limitations are repaired.
