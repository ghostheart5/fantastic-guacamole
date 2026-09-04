# Phase 6: artifact-only candidate workflow (prepared, not executed)

The manual `Android Candidate Build Only` workflow builds app source
`9e1ba13376d0747fa6393f428d66f71f353985a5`, after reading successful exact-source
CI run `33924430045`. It does not rerun that app suite. The workflow/tooling
commit is recorded separately from the frozen app source and must be reviewed
before execution. No app source, version, signing identity or containment flag
is changed by preparing this workflow.

## What it does

- Requires a manual dispatch on exactly
  `fix/app-only-readiness-priority2-20260902` in the original repository.
- Uses only read-only contents/actions token permissions. It retains the
  `production` environment gate; it does not modify or bypass that gate.
- Uses existing signing secrets and requires the upload SHA-1 pin already in
  `android-release.yml`. The AAB's SHA-256 signer fingerprint is recorded
  separately; Play's app-signing identity must not be confused with the upload key.
- Verifies production configuration format with the existing source validator.
  Firebase secret configuration must match the frozen tracked configuration;
  drift fails instead of silently changing the candidate.
- Builds with prod enforcement, mocks/tester access off, and source-enforced
  AI/billing/cloud/telemetry containment unchanged.
- Verifies every JAR payload entry's signature, certificate expiry and pinned
  signer; rejects unsigned, tampered or multiply-signed payloads.
- Runs checksum-pinned bundletool 1.18.3 validation and checks actual manifest
  package/version, non-debuggable status and API floor.
- Checks the bundle's 16 KB ZIP-alignment request and all ARM64/x86-64 native
  LOAD segments. This is not 16 KB device/runtime proof.
- Saves only the AAB, digest, manifest, bundle configuration, R8 mapping and
  privacy-safe provenance as a seven-day Actions artifact, after verification.
  Artifact access follows repository/Actions permissions; this is not a
  private distribution service. Signing files and define secrets are never
  included in the artifact allowlist and are cleaned on failure too.

No release tag, GitHub Release, Play upload, website deployment, production
database operation, external-AI call, replacement key, or whole-suite rerun
exists in this workflow.

## Exact access change to review before execution

Repository: `ghostheart5/fantastic-guacamole`.
Environment: `production`.
Add one deployment branch policy, type **branch**, exact name:

```text
fix/app-only-readiness-priority2-20260902
```

Keep the existing `main` branch, `v*` tag and
`release/chronospark-production-candidate-20260821` branch rules unchanged.
Do not switch to all branches, add a wildcard, disable restrictions, or copy
production secrets into a less-protected environment. Adding this rule permits
environment-secret access from eligible workflows on that branch, not solely
this new workflow; that broader effect requires explicit approval.

The rule has **not** been added. No workflow has been dispatched.

User approved committing/pushing the tooling, narrowly registering it on main,
adding this exact rule, and one build-only run. Readback before execution found
that main enforces pull-request review and strict required checks even for
administrators: `Analyze & Test`, `database`, and `enforce-maintainer-only`.
Registration is therefore blocked under the current no-full-suite-rerun
constraint. Do not bypass protections, manufacture check results, or silently
merge the app branch. Keep environment access unchanged until registration is
resolved. The tooling-only commit uses `[skip ci]` on the existing feature
branch to avoid repeating app CI; it is not a green registration/merge result.

## Separate registration and run prerequisites

This new manual workflow must first exist on the default branch to be
dispatchable. A narrowly scoped workflow/tooling merge requires separate
approval; do not merge the full pending app branch as a shortcut. The reviewed
tooling must also be committed/pushed on the exact allowed dispatch branch.
Only then, after the access rule is approved, dispatch this named workflow once.
See [GitHub manual-workflow requirements](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).

## Evidence limits and remaining holds

Local verifier tests are only tests of rejection/validation logic, not proof
that a real signed AAB exists. A future successful build still does not close
Phase 5, production-backend reconciliation, independent Play certificate and
version-code checks, native-symbol completeness, real-device/16 KB runtime
testing, human UAT, or release approval. Current source does not request a
complete native-symbol archive; the manifest explicitly keeps that item open.

The committed Phase 5 hold remains INCOMPLETE / DEFERRED.

## Local preparation checks (2026-09-04)

- PASS: actionlint for the new workflow.
- PASS: repository workflow guard, 12 workflows.
- PASS: nine focused verifier tests (including unsigned-payload rejection by
  the actual Java verifier; no signing key was generated).
- PASS: tracked diff whitespace check.
- WARNING: the security path guard reported success, but Windows long-path
  warnings limited discovery of unrelated untracked historical artifacts.
  None of those artifacts is part of this change or an upload allowlist.
- NOT RUN: real signed build, positive signer verification, bundletool against
  a new AAB, or GitHub workflow execution. Passing local guard tests does not
  substitute for these artifact checks.

References: [bundletool release](https://github.com/google/bundletool/releases/tag/1.18.3),
[Android page-size verification](https://developer.android.com/guide/practices/page-sizes).
