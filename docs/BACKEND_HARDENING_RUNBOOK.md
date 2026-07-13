# ChronoSpark Backend Hardening Runbook

> Run this checklist before and during each closed testing window.  
> Owner: backend/infra owner  
> Last reviewed: 2026-07-13

---

## Firebase Hardening

### Firestore Security Rules

- [ ] Open Firebase Console → Firestore → Rules
- [ ] Verify every collection has an explicit `allow read/write` rule; no collection uses `allow read, write: if true`
- [ ] Verify user documents are scoped to `request.auth.uid == userId`
- [ ] Verify no rule grants unauthenticated write access to any user-data collection
- [ ] Run the Rules Simulator against: unauthenticated read, unauthenticated write, cross-user read, cross-user write — all must be denied
- [ ] Export current rules to `supabase/firestore.rules.bak` before any rule change

### Cloud Functions Cold Starts

- [ ] Open Firebase Console → Functions → each function
- [ ] Confirm memory allocation is ≥256 MB for AI proxy and receipt verification functions
- [ ] Deploy a warm-up cron (Cloud Scheduler) for any function with a P99 cold-start > 3 s
- [ ] Verify timeout settings (default 60 s is usually sufficient; AI proxy may need 120 s)
- [ ] Test each function with a cold invocation: curl the endpoint and record response time
- [ ] Check error rate in Functions dashboard — alert threshold: >1% error rate

### Auth Flow Stability

- [ ] Firebase Auth → Sign-in methods: confirm Email/Password and OAuth providers are enabled
- [ ] Test sign-up, sign-in, password reset, and token refresh on a clean device
- [ ] Verify Supabase OAuth redirect URLs match Firebase Auth configured callbacks
- [ ] Confirm session persistence (app backgrounded → foregrounded → still authenticated)
- [ ] Confirm `CHRONOSPARK_OAUTH_REDIRECT_URL` is set to the correct production value in release builds

### Analytics Events

- [ ] Open Firebase Analytics → DebugView (connect a test device with `--dart-define=FIREBASE_DEBUG_MODE=true`)
- [ ] Walk through each flow in `docs/ANALYTICS_TAXONOMY.md` and verify the corresponding event appears in DebugView
- [ ] Confirm no PII appears in event parameters (no email, name, or user content as values)
- [ ] Verify `app_open`, `session_start`, and `session_end` all fire correctly

### Crashlytics

- [ ] Trigger a test crash (`FirebaseCrashlytics.instance.crash()` from a debug build)
- [ ] Confirm crash appears in Firebase Console → Crashlytics within 5 minutes
- [ ] Set up email alerts for crash-free session rate dropping below 99%
- [ ] Review any existing open crashes before distributing to new testers

---

## Supabase Hardening

### Schema Freeze

- [ ] Announce schema freeze on all production tables before distributing the test build
- [ ] Tag the current migration state: `git tag schema-freeze-v1.0 HEAD`
- [ ] Document any allowed schema changes (additive only: new nullable columns, new indexes)
- [ ] Prohibited during freeze: column renames, type changes, table renames, RLS policy removals

### RLS Policy Audit

- [ ] Open Supabase Dashboard → Table Editor → each table
- [ ] Verify RLS is **enabled** on every table that holds user data
- [ ] Verify every policy uses `auth.uid()` to scope rows to the authenticated user
- [ ] Verify anonymous users cannot read or write user-owned data
- [ ] Run the Supabase policy test queries: unauthenticated read (expect 0 rows), cross-user read (expect 0 rows)
- [ ] Export RLS policies to `supabase/rls_audit_snapshot.sql` before the testing window opens

### Migration Rehearsal

- [ ] Apply all pending migrations to a staging project first
- [ ] Run `flutter test` against the staging project to verify no data contract break
- [ ] Only apply to production after staging verification passes
- [ ] Keep migration rollback SQL in `supabase/migrations/rollback/`

### Storage Bucket Policies

- [ ] Open Supabase Storage → each bucket
- [ ] Verify buckets intended to be private are not set to public
- [ ] Verify the upload policy restricts file size and MIME type
- [ ] Verify delete policy prevents cross-user deletion
- [ ] Test upload, read, and delete with an authenticated test user

---

## Rollback Runbook

### When to trigger a rollback

Trigger a rollback if any of the following occur during testing:
- Crash-free session rate drops below 95% in a 24-hour window
- Auth error rate exceeds 5%
- Sync failure rate exceeds 10%
- RLS bypass or data leak is confirmed or suspected

### Firebase rollback steps

1. Revert Firestore rules: open Rules editor → paste previous version → Publish
2. Revert Cloud Functions: `firebase deploy --only functions:<function-name> --version <previous-version>`
3. Disable a broken auth provider: Firebase Auth → Provider → Disable
4. Record rollback in the evidence log in `docs/RELEASE_TRACKER.md`

### Supabase rollback steps

1. Run the rollback SQL from `supabase/migrations/rollback/` in the Supabase SQL editor
2. If a column was added: `ALTER TABLE <table> DROP COLUMN <column>;`
3. If an RLS policy was broken: restore from `supabase/rls_audit_snapshot.sql`
4. Notify all active testers of the service interruption via email

### App build rollback steps

1. Re-upload the previous `.aab` to the Play Console testing track
2. Increment the version code to force an update
3. Post an updated tester note explaining the rollback

---

## Contact Escalation

| Severity | Response Target | Contact |
|----------|----------------|---------|
| P0 — data leak or auth bypass | 1 hour | ghostheart131517@gmail.com |
| P1 — crash rate > 5% | 4 hours | ghostheart131517@gmail.com |
| P2 — feature completely broken | 24 hours | ghostheart131517@gmail.com |
| P3 — degraded behaviour | 72 hours | ghostheart131517@gmail.com |
