# Staging Empty-State Verification

**Read-only verification checklist. Completion requires captured output from confirmed staging `RETIRED_STAGING_PROJECT`.**

Do not infer emptiness from blank migration history or missing expected functions.

- [ ] **Auth users count:** record a count only; confirm each account is disposable and non-valuable.
- [ ] **Storage buckets:** list every bucket and identify its owner/purpose.
- [ ] **Storage objects:** record per-bucket object counts; confirm no object is valuable.
- [ ] **Non-system schemas:** list every schema other than PostgreSQL system schemas.
- [ ] **Tables:** list every table and partition in each non-system schema.
- [ ] **Views:** list every view and materialized view in each non-system schema.
- [ ] **Functions:** list every function in each non-system schema.
- [ ] **Policies:** list every row-level-security policy and its table.
- [ ] **Triggers:** list every non-internal trigger and its table.
- [ ] **Extensions:** list enabled extensions and confirm migration compatibility.
- [ ] **Row counts:** for every discovered user/application table, capture an approved read-only row count and confirm whether the data is disposable.

## Completion Gate

Classify every discovered object as `SAFE_TO_REPLACE`, `MANUAL_OBJECT_FOUND`, or `NEEDS_COMPATIBILITY_REVIEW`. The empty-state claim is valid only when no valuable Auth users, Storage objects, rows, or conflicting manual objects remain and a human confirms staging is disposable.

Current status: **incomplete; migration application is NO-GO.**
