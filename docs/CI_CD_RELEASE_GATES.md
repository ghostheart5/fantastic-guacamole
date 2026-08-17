# ChronoSpark CI/CD Release Gates

This document is the source-of-truth for the repository-side release gates. It
does not replace device, signed-artifact, or Play Console verification.

## Required gates

Every change to `main` and every release tag must run:

1. Dart formatting and `flutter analyze --fatal-infos`.
2. The tracked-lockfile check after dependency resolution.
3. Filename and content secret scans. A client publishable Supabase key may be
   present where required; service-role keys, private keys, bearer/JWT tokens,
   and provider credentials may not be committed.
4. Version consistency between `pubspec.yaml`, `android/gradle.properties`,
   and a release tag (`vMAJOR.MINOR.PATCH`).
5. All Supabase Edge Function entrypoints are discovered automatically and
   type-checked. Every `*_test.ts` function test is executed by the same gate.
6. Flutter unit/widget/release-contract tests and the app-root
   `integration_test` suite.
7. Architecture, Maestro YAML contract, and coverage-ratchet checks.

CI evidence is retained as a workflow artifact containing coverage and the
dependency report. A failure is release-blocking; a warning must not silently
turn production readiness off.

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

## Deferred runtime gates

Maestro execution is defined in `.github/workflows/maestro-runtime.yml` and
requires an authorized self-hosted Android/Maestro runner with a prepared
candidate. Signed Android installation, startup/frame profiling, notification
behavior, and Play Console upload are also separate runtime gates. They must be
run only when an authorized device/release phase is opened; static YAML
validation in CI is not evidence that a device flow passed.

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
