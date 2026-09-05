# Safe-quick repair plan: Phase 7 live backend and Firebase

Status: **INCOMPLETE - verified operational repair, remaining gates open**.
Recorded 2026-09-04 America/Chicago (live repair readback 2026-09-05 03:39:29 UTC).
This is Phase 7 of the agreed 13-phase safe-quick plan, not binder Priority 7.

## Scope and preservation

- Checkout: `ChronoSpark-app-only-priority2`; branch
  `fix/app-only-readiness-priority2-20260902`; HEAD
  `7274e369f589faafe4e0f276cf7ef7cd2610e4b7`.
- Frozen signed app source: `61c7331dda9e82201a0561dbcd79aa0b37118446`.
- Production Supabase: `qpwhuckyirnqtmvhpede`.
- Firebase: `chronospark-app`, project number `956622397052`, signed-in owner
  account `domnichols39@gmail.com`.
- Production Android: `com.ghostheart5.chronospark`; Firebase app ID
  `1:956622397052:android:3ecf5fcda0f2e1ef9133f9`.
- No app rebuild, full-suite rerun, commit/push, migration, Edge deployment,
  data deletion, credential change, or phone-session change during this repair.
  AI, billing, cloud sync/restore, analytics and Crashlytics containment unchanged.

## Repair completed and independently read back

Two active cron jobs ran identical subscription-expiration SQL every 15 minutes.
The older job was reversibly deactivated using `cron.alter_job`, guarded by
exact job IDs/names, identical command/schedule/database/username and an active
replacement. No jobs or run history were deleted; the expiration function was
not manually executed.

| Job | Before | After |
| --- | --- | --- |
| 1: `chronospark-expire-subscriptions` | Active | Inactive |
| 5: `chronospark-expire-stale-subscriptions` | Active | Active |

Both commands remain `select public.expire_stale_monetization_subscriptions();`,
schedule `*/15 * * * *`, database/user `postgres`. Command comparison fingerprint
(MD5, not a security signature): `629f0db7dd19a50b578e6f1e3ffeb7d0`.
An independent read-only query after transaction commit confirmed this state.
The next naturally scheduled execution has not been observed in this record.

Rollback, only if separately requested after rechecking identities: reactivate
job 1 using `cron.alter_job(job_id := 1, active := true)`. This would intentionally
restore the duplicate behavior. This was a live operational repair, not a new
tracked migration; a fresh replay of historical migrations may recreate both
active jobs. Prepare and validate a separately approved migration before relying
on fresh-environment parity for this repair.

Reference: [Supabase Cron quickstart](https://supabase.com/docs/guides/cron/quickstart).

## Live verification obtained during Phase 7

- All 44 migration version/name entries match the frozen candidate inventory.
  This is not full schema or migration-content checksum equivalence.
- All seven deployed Edge Functions are active. All 27 retrieved function-file
  instances, including bundled shared source, match the frozen candidate after
  line-ending/trailing-whitespace normalization. This is not runtime proof.
- Required custom secret names are present: `ANDROID_PACKAGE_NAME`,
  `GOOGLE_SERVICE_ACCOUNT_JSON`, `ACCOUNT_DELETE_RECONCILE_SECRET`,
  `RTDN_AUDIENCE`, `RTDN_SERVICE_ACCOUNT_EMAIL`, `ANTHROPIC_API_KEY`.
  Values were not revealed, replaced, or proven valid by name presence.
- All 55 public ordinary tables have RLS; no anonymous SELECT grants on those
  tables. Three exposed views use security-invoker semantics. Fourteen
  no-policy advisor notes concern tables with no anon/authenticated DML grants.
  Seven authenticated SECURITY DEFINER routines were inspected for caller
  checks and empty search paths; they were not blindly revoked.
- `chronospark-sync` is private, JSON-only, maximum 5 MiB. Storage policies
  restrict paths to the authenticated user's two backup objects and prevent
  writes during account deletion.
- Existing cron histories showed successful executions over the preceding
  24 hours. The duplicate was the confirmed operational defect above.
- Scheduled Backend Reconciliation run `33941433823` succeeded with the current
  contract and `scanned=0, completed=0`. Deletion/recheck queues were empty.
  This does not prove end-to-end deletion or billing reconciliation.
- Seven daily database backups were visible, latest 2026-09-04 10:09:43 UTC.
  Console explicitly excludes Storage object contents. No restore was run.
- Supabase leaked-password protection is enabled. Refresh-token replay
  detection is enabled, reuse interval 10 seconds, access-token lifetime
  3600 seconds. Single-session enforcement is off; session and inactivity
  timeouts are zero (no forced expiry). These settings were not changed.
- Auth rate limits: refresh 150/5 min/IP; verification 30/5 min/IP;
  signup/signin 30/5 min/IP. CAPTCHA and IP forwarding are off. CAPTCHA cannot
  safely be enabled without compatible client integration.
- Firebase production app identity matches candidate configuration and its
  upload certificate is registered. This is not Play App Signing authority.
- FCM HTTP v1 is enabled and legacy messaging disabled. No push was sent.
- Remote Config has a published template; no fetch data was visible. Candidate
  runtime flags are disabled, so remote fetch/kill-switch runtime is unproven.
- App Check shows Get started and the candidate lacks `firebase_app_check`.
  Enforcing it without client integration/valid-token evidence is not safe.

## Remaining gates - do not advance as complete

1. Firebase alert configuration: **REPAIRED / persisted readback PASS** after
   explicit user approval. Verified the production package/app ID in General
   settings, renamed only its Firebase nickname from `chronospark (android)`
   to `ChronoSpark — Production Android`, then selected that distinct entry
   in Crashlytics alert settings. Enabled E-mail for new fatal, non-fatal and
   ANR issues for `domnichols39@gmail.com`. Each category offered only E-mail;
   no In-console option was available for these three categories. Reloaded
   the page, reselected production, and independently read back all three as
   E-mail. Existing trending E-mail and regression E-mail/In-console settings
   were preserved. The old Android test entry retained its nickname and its
   three None selected preferences. No SDK collection, installed app name,
   package, certificates or app data changed. Actual incident ingestion and
   email delivery remain untested; configuration success does not prove them.
2. Firebase API-key restrictions and applicable App Check integration/readiness
   remain unverified. Do not restrict a potentially shared key or enforce App
   Check until consumers and valid signed-client behavior are established.
3. Old auth redirects require an ownership/usage decision: `chronospark.ai`,
   `www.chronospark.ai`, localhost ports 3000/8000. Current custom-scheme and
   `chronospark.app/app/auth/callback` redirects also remain configured. No
   redirect was removed on an assumption about ownership.
4. An isolated, timed restore drill, Storage-object backup/restore coverage,
   and recovery-time/data-loss evidence remain open. Do not overwrite live
   production or provision a paid destination without specific approval.
5. Real push delivery, applicable incident ingestion/alert delivery, and other
   signed-client backend journeys remain unproven. Preserve telemetry/provider
   containment; do not generate real user data or enable collection to obtain
   a cosmetic pass.

Phase 5 website/legal/support remains separately deferred. Play signing/store
and full physical UAT remain separate gates. No production-ready claim is made.
