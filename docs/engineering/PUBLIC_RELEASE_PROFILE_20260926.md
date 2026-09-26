# Public release profile preparation

Status: **not ready for public build or rollout**. This change prepares an explicit public Android configuration and validation path. It does not approve the missing reviews, enable any contained capability, deploy a backend, or publish an app. The existing private CI candidate builder remains private.

## Source and effective behavior

The public profile requests the production cloud backend, sync/restore, paid AI and billing, frozen general assistant availability, and ordinary consent/account controls. It rejects internal billing tests, public admission QA, private cohorts, mock login/mode, free access, paywall bypass and mutable remote feature flags. Analytics, crash reporting, inferred identity, and the separately contained planner-explanation experiment remain excluded.

Native public billing has a separate manifest overlay. Selecting it requires a release cloud build and explicitly closed private QA flags. This is separate from the existing internalBilling overlay. Source containment is still false for cloud, public AI and paid capabilities. A new privacy/legal approval constant is false and joins the existing safety and provider gates; no define can turn those approvals on.

The production configuration validator rejects public intent until all source gates are approved and all flags/endpoints/policy match. The runtime readiness gate also reports missing source approvals. The guarded PowerShell builder checks source approvals before it resolves or reads signing files, then requires external evidence before copying signing material. Existing contained build behavior is preserved when `-PublicRelease` is absent.

## Evidence needed before building

An operator must inspect actual independent privacy/legal and mental-health-safety reviews, current provider handling, deployed backend parity, cloud isolation/restore/deletion, and billing recovery evidence. Record the source SHA and SHA-256 of the exact canonical effective defines plus each evidence document's bytes. The schema is illustrated by `tool/public_release_evidence.template.json`; it is deliberately pending and unusable as approval.

Each record has status `approved`, scope `source-and-configuration`, the reviewer/operator identity, timezone-qualified review/expiry dates, and a relative file path plus SHA-256. Backend and provider observations must be no older than seven days at build time. This seven-day limit is an internal freshness control, not a provider or legal rule. Future, expired, missing, altered, duplicate-key, cross-source and cross-configuration evidence is rejected. Reviewer documents stay outside the checkout and the output artifact; only their hashes and dates enter the build receipt.

Hash/shape validation proves binding and integrity, **not** the author's qualifications or the truth of a professional opinion. An operator must inspect the signed documents. Updating the non-overridable source gates requires the separately reviewed checkpoint supported by those documents. Preliminary reviewer feedback does not meet this gate. Final AAB acceptance follows the pre-build review and must identify the built artifact hash.

After the required reviews and source checkpoint, use the existing external signing paths with:

```powershell
./scripts/build_android_aab_prod_guarded.ps1 -PublicRelease `
  -PublicEvidencePath '<external-reviewed-packet>/evidence.json' `
  -SigningPropertiesPath '<existing-external-signing-properties>' `
  -SigningKeystorePath '<existing-external-upload-keystore>'
```

The command is preparation guidance, not authorization to activate production. Existing service settings are read through the guarded builder; AI report/planner endpoint paths are derived exactly from that configured project. The receipt binds the committed source/version, effective defines, review evidence and resulting AAB hash. Independently verify the AAB signing identity, compiled manifest/permissions, target SDK, native page alignment and all final-device flows before submission.

## Current evidence and limits

The baseline main `fb169bcedf200dab3fd1f6f3df76fe4f01f3eca6` passed main CI/database/security and hosted Android 15 QA smoke run 36209871386 (five flows, zero failures/skips or fatal markers). This is debug QA evidence, separate from Play-signed billing. Installed private 3089 still predates the latest client recovery repair. No new public artifact has been built.

Regression coverage exercises public/private separation, every required flag, stale/tampered review evidence, exact source/configuration binding, missing approvals, safe evidence paths and the real guarded builder's refusal before signing-file reads. A compiled-public-intent test confirms the same build define cannot activate the current unapproved runtime capabilities. Public native permission and final signed-runtime acceptance remain unverified until a real approved public candidate exists.

## Release sequence after preparation

1. Obtain and review the signed source/configuration assessments; close findings and freeze the public source and backend profile.
2. Build the next unused signed version with the recovery repair; verify build receipt, signature and native packaging.
3. Execute final EN/ES critical flows, API 35/36, accessibility, account isolation, sync/restore/deletion, AI quote/consent/reporting and no-charge Play billing/refund tests in the authorized test environment. Never relabel synthetic or debug evidence as public paid-service acceptance.
4. Reconcile Play declarations, app-access instructions and locale listings/media against those exact flows. Managed publishing was observed off on September 26 UTC; treat any review submission as potentially publishing once approved unless a separately authorized publishing hold is verified.
5. Obtain final artifact dispositions and the owner's explicit submission/activation approval. Execute the approved staged plan with read-only monitoring and operator coverage. Stop new sales first on billing incidents while preserving already owed fulfillment/refunds and support evidence.

Public sales, scheduled refunds and rollout remain off. Reviewers are arranged by the owner; no review invitation or signed disposition is created by this change.
