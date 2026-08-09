# Next Backend Validation Phase

**Plan only. Do not execute SQL, migrations, deployments, privileged tests, receipt tests, or Storage tests from this document.**

## 1. `grant_monetization_credits` Authorization Denial

Prepare an authenticated-caller denial test plan first. It should confirm the staging-effective signature, expected non-privileged denial, and no side effects. Do not require a service-role key or generate an admin test; the first question is whether a normal authenticated caller is correctly denied.

## 2. Approved Wallet Setup and Cleanup

Obtain a human-approved, isolated wallet setup and cleanup contract before testing valid debit and insufficient balance. This phase needs known balance columns/defaults and deterministic transaction assertions; without those, a debit test could leave misleading staging state.

## 3. Receipt Mismatch / `apply_verified_purchase`

Validate only after the deployed staging Edge Function route, safe Google test receipt path, product mapping, and function-body authorization/replay behavior are reviewed. This is next after wallet mechanics because receipt handling has external-provider and replay-risk implications.

## 4. Storage Policy-Contract Validation

Perform this only if Storage is used in staging. First establish the bucket, object-path convention, effective `storage.objects` policy contract, and cleanup expectations. Do not upload any object until that contract is approved.

## 5. Final Release Backend Checklist

Reconcile all evidence: ready backend checks, Core-Sync/Profile/Monetization results, the remaining privileged and payment-path validation, and Storage applicability. Production remains blocked unless every applicable category has explicit passing evidence and release approval.