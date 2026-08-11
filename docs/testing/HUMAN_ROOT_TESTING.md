# ChronoSpark Human Root Testing

Version: `1.0.0`
Status: `DEFINED — NO HUMAN CASE EXECUTED`
Owner: Release Engineering and independent human testers

## Purpose and boundary

Human Root Testing is black-box validation of an exact signed release candidate
through every current top-level application root. It does not mean Android,
iOS, emulator, or operating-system root privileges.

The current product roots are Nexus, Creator, Smart Planner, SI Console,
Timeline, Trajectory, Progression, Profile, and Settings. Authentication,
onboarding, notifications, subscriptions, account deletion, and lifecycle
recovery are supporting release-critical paths. Session/Focus, Journal, Logs,
standalone Insights, and Smart Coach are not test surfaces. Smart Planner and
SI Console must remain separate existing surfaces; a case may observe isolation
but must never connect, merge, or modify chat behavior.

This system supplies the governed human layer described in
`ADVANCED_TEST_PLAN.md`. It produces evidence; it never substitutes templates,
automation output, or historical results for a human result.

## Operating model

1. Create one candidate passport from
   [passport-template.md](human-root/passport-template.md) before installation.
   The passport is invalid if the commit SHA or binary hash changes.
2. Select an approved non-production environment, persona, device-matrix row,
   and dataset. Never use an employee's personal account or production test
   data as a substitute.
3. Record every executed case from
   [CASE_REGISTRY.md](human-root/cases/CASE_REGISTRY.md), including skips,
   blocks, defects, and evidence. A blank result is not a pass.
4. Run the mandatory core journey and the assigned persona, root, interruption,
   accessibility, privacy, and release cases against the same candidate.
5. Require a fresh-eyes verifier for the core journey, monetization, account
   deletion, and every release-veto defect retest.
6. Complete [release-signoff-template.md](human-root/release-signoff-template.md)
   only after all required cases have evidence and all vetoes are clear.

No case is executed by Phase 9. Every template begins in `NOT RUN` state.

## System index

| Artifact | Purpose |
|---|---|
| [Case registry](human-root/cases/CASE_REGISTRY.md) | Versioned IDs, required personas, owners, and acceptance criteria |
| [Core journey](human-root/cases/CORE_JOURNEY.md) | Mandatory fresh-install to persistence journey |
| [Top-level root cases](human-root/cases/TOP_LEVEL_ROOTS.md) | Required black-box coverage for all nine roots |
| [Interruption and recovery](human-root/cases/INTERRUPTION_AND_RECOVERY.md) | Lifecycle, network, storage, clock, permission, and retry coverage |
| [Personas](human-root/personas/PERSONAS.md) | Ten human personas and required journeys |
| [Datasets](human-root/personas/DATASETS.md) | Isolated seed definitions and corruption/migration boundaries |
| [Device matrix](human-root/DEVICE_MATRIX.md) | Candidate devices, screen sizes, OS, and accessibility combinations |
| [Environment requirements](human-root/ENVIRONMENT_REQUIREMENTS.md) | Candidate/environment qualification and account isolation |
| [Evidence requirements](human-root/EVIDENCE_REQUIREMENTS.md) | Evidence naming, retention, redaction, and evidence chain |
| [Severity and vetoes](human-root/SEVERITY_AND_VETOES.md) | Defect severity, automatic vetoes, and release decisions |
| [Retest and verification](human-root/RETEST_AND_INDEPENDENT_VERIFICATION.md) | Defect retest, regression, independence, and signature rules |
| [Candidate passport](human-root/passport-template.md) | Exact candidate identity and execution record |
| [Defect record](human-root/defect-template.md) | Reproducible, redacted human defect report |

## Required evidence and result semantics

A passing case must have a completed result row, named evidence references, the
candidate passport ID, the tester identity, and a timestamp. Required evidence
for a critical journey is a start screenshot, end screenshot, screen recording,
device log capture, and defect links if any. Evidence must be redacted: never
upload passwords, access/refresh tokens, purchase tokens, API keys, raw private
notes, or personally identifying content unrelated to the test.

Allowed result values are `PASS`, `FAIL`, `BLOCKED`, `NOT RUN`, and `NOT
APPLICABLE`. `BLOCKED` and `NOT RUN` are release-blocking for a required case.
`NOT APPLICABLE` requires a written reason approved by Release Engineering; it
cannot waive a release-veto category.

## Mandatory release rules

- The candidate must use the exact commit and binary hash recorded in its
  passport. Rebuild, re-sign, flavor change, backend switch, or schema change
  requires a new passport and rerun of affected cases.
- The mandatory core journey passes on two Android API levels and one physical
  low/mid-tier Android device. Any platform submitted for release also requires
  its platform-specific candidate matrix row.
- Primary tester and independent verifier are different people for the core
  journey, subscriptions/credits, account deletion, and any failed-case retest.
- A P0, P1, or automatic-veto condition blocks release until the verified retest
  and regression rules are satisfied. Waivers cannot override an automatic veto.
- Human results complement automated, device, Maestro, backend, and release
  gates; they do not override a blocked automated gate.

## Accessibility and visual obligations

Every root must be exercised with the accessibility row of the device matrix:
screen reader, maximum supported text scaling, high contrast where supported,
reduced motion, keyboard or switch access where available. Verify semantic
names/roles/states, logical focus order, no focus trap, actionable targets,
loading/error announcements, non-color-only meaning, visible primary actions,
and destructive-action confirmation. An inaccessible primary action, focus
trap, clipped critical action, or missing destructive confirmation is an
automatic release veto.

Visual comparison is observational for Human Root Testing. Approved automated
baselines remain under `test/goldens/`; human screenshots and failure evidence
belong to the candidate evidence bundle and are never promoted to a baseline
without a separately reviewed visual-regression change.

## Completion

Release Engineering records the final `GO`, `NO-GO`, or `BLOCKED` decision in
the signed candidate passport and release sign-off. Until then, the candidate is
not human-root-approved.
