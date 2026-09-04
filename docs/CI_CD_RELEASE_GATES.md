# ChronoSpark CI/CD Release Gates

This document is the source-of-truth for the repository-side release gates. It
does not replace device, signed-artifact, or Play Console verification.

## Required gates

Every pull request to `main`, every change to `main`, and every release tag must
run the canonical reusable source gate. The gate is split into independently
rerunnable static-policy, Flutter-test, Linux-integration, and Windows-golden
jobs. A final fail-closed job retains the required GitHub check name
`Analyze & Test` and succeeds only when every category succeeds.

The dedicated `database` workflow is the single authority for Edge Function,
migration replay, local database, RLS, and schema-lint validation. Feature
branches run it through the pull-request event only, avoiding duplicate push
and pull-request checks for the same commit. It first exercises the Edge gate's
zero-test, skip, and timeout failure fixtures, then retains exact-commit and
Edge JUnit evidence even when a later database stage fails.

Required checks include:

1. Dart formatting and `flutter analyze --fatal-infos`.
2. The tracked-lockfile check after dependency resolution.
3. Filename and content secret scans. A client publishable Supabase key may be
   present where required; service-role keys, private keys, bearer/JWT tokens,
   and provider credentials may not be committed.
4. Version consistency between `pubspec.yaml`, `android/gradle.properties`,
   and a release tag (`vMAJOR.MINOR.PATCH`).
5. All Supabase Edge Function entrypoints are discovered automatically and
   type-checked. Every `*_test.ts` function test is executed by the same gate.
6. Flutter unit/widget/release-contract tests and every app-root
   `integration_test` file. Flutter invocations have a hard timeout and retain
   JSON reports plus manifests that reject zero tests, incomplete runs,
   failures, and unexpected skips. The QA compile-time configuration receives
   a separate defined-profile run. Linux app-root runs have both a per-file
   10-minute limit and a 30-minute total suite budget so artifact upload has
   headroom inside its job timeout.
7. Architecture, Maestro YAML contract, coverage-ratchet, and fail-closed
   PowerShell parsing across every maintained root and `scripts/` gate.
8. A non-zero golden assertion guard followed by Linux and Windows comparison
   runs,
   so eight logical comparisons select reviewed, exact platform masters rather
   than merely storing images. Linux generation and comparison stay pinned to
   `ubuntu-24.04`; Windows uses `windows-2022`. The manual update workflow runs
   both hosts from the immutable dispatch SHA, records and verifies the exact
   checked-out commit, rejects dependency-lock drift, and returns separate
   review artifacts without committing changes.

CI evidence is retained in category-specific workflow artifacts containing
exact-commit identity, structured test manifests, coverage, integration
results, golden results, and the dependency report. Missing evidence is an
error. A failure is release-blocking; a warning must not silently turn
production readiness off.

CI is host evidence. It does not establish physical-device rendering,
TalkBack, keyboard behavior, performance, signed-artifact behavior, or human
usefulness. Release reports must list those evidence classes separately.

## Production configuration

Android and Pages workflows fail closed when required GhostHeart5 production
configuration is missing. They pass explicit `CHRONOSPARK_APP_FLAVOR=prod` and
`CHRONOSPARK_ENFORCE_PROD_READINESS=true`; they never publish a build with a
development fallback.

## Release artifact evidence

The Android workflow validates the tag before signing, verifies that the AAB is
non-empty and signed, and publishes a SHA-256 checksum beside the AAB. The
release workflow still requires a maintainer to inspect the generated artifact
on a real supported device and complete Play Console declarations.

## Automated emulator gate

`.github/workflows/maestro-runtime.yml` automatically runs the non-destructive
QA smoke journeys for `main` and is reused as a blocking release-tag gate. It
uses a pinned GitHub-hosted Android emulator, a checksum-verified Maestro CLI,
and `scripts/run_maestro_android_evidence.ps1` to build and install the exact
checkout. The retained manifest binds the Git commit, APK SHA-256, installed
package, emulator/API, JUnit counts, Logcat scan, and final status.

This QA emulator evidence does not prove the signed AAB, real Play Billing,
physical-device rendering, startup/frame performance, notifications, or Play
Console acceptance. Those remain separate release-phase gates and must not be
inferred from static validation or QA smoke.

## Dependency and supply-chain review

`scripts/dependency_audit.ps1` records the committed lockfile hash and resolved
dependency graph, and requests an outdated-package report when Flutter is
available. License approval and advisory triage remain explicit release-owner
decisions; the generated report must be attached to the release evidence. The
direct-capability ownership register is maintained in
[`DEPENDENCY_CAPABILITY_REGISTER.md`](DEPENDENCY_CAPABILITY_REGISTER.md).

## Rollback and release notes

For each tag, retain the CI evidence artifact, AAB checksum, migration list, and
release notes. Rollback means stopping promotion of the tag and selecting the
last known-good artifact; database migrations require a separately reviewed
forward-compatible repair because binary rollback cannot undo schema changes.
