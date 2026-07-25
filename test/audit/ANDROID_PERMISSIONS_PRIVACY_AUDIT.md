# Android Permissions + Privacy Audit

Date: 2026-07-24
Owner:
Release Target:
Build/Commit:

Principle: request the minimum. If a feature can work without a permission, do not declare it. If a permission is declared, the app must provide obvious user value and the Play listing must match actual behavior.

## Current Android manifest snapshot
Source: android/app/src/main/AndroidManifest.xml

Declared permissions currently found:
- android.permission.INTERNET
- com.android.vending.BILLING
- android.permission.POST_NOTIFICATIONS
- android.permission.RECORD_AUDIO
- android.permission.WAKE_LOCK
- android.permission.RECEIVE_BOOT_COMPLETED

Explicit ad identifier removals currently found:
- com.google.android.gms.permission.AD_ID removed
- android.permission.ACCESS_ADSERVICES_AD_ID removed
- android.permission.ACCESS_ADSERVICES_ATTRIBUTION removed

## Permission-by-permission V1 decision table

| Permission / capability | Use only if... | V1 recommendation | Current status | Action |
|---|---|---|---|---|
| INTERNET | Supabase, Firebase, billing, analytics, remote services, web links | Needed for backend/auth/analytics/billing | Declared | Keep |
| POST_NOTIFICATIONS | Reminders/alerts on Android 13+ | Request only when user enables reminders | Declared | Keep with just-in-time prompt |
| SCHEDULE_EXACT_ALARM | Exact alarms are truly required | Avoid unless strict timing is essential | Not declared | Keep out for V1 unless proven required |
| RECEIVE_BOOT_COMPLETED | Restore notifications after reboot | Use only if reminder system is active | Declared | Keep if reboot restore is used |
| USE_BIOMETRIC | App lock/secure vault | Optional future feature | Not declared | Keep out for V1 |
| READ/WRITE CALENDAR | Device calendar sync | Cut unless implemented | Not declared | Keep out for V1 |
| CAMERA | Scan/avatar capture/OCR | Likely cut for V1 | Not declared | Keep out for V1 |
| READ_MEDIA_IMAGES / photo picker | Image attachments/profile media | Prefer system photo picker | Not declared in manifest | Verify plugin/runtime behavior |
| LOCATION | Location reminders/planning | Avoid unless essential | Not declared | Keep out for V1 |
| RECORD_AUDIO | Voice input/voice notes | Keep only if voice feature is implemented and user-visible | Declared | Verify feature readiness and in-app explanation |
| CONTACTS | Invite/social graph | Avoid for V1 | Not declared | Keep out for V1 |
| Broad storage access | File-manager style access | Avoid, use app-scoped storage | Not declared | Keep out for V1 |

## SDK + data safety inventory
Source baseline: pubspec.yaml

Primary SDKs/plugins detected for privacy review:
- supabase_flutter
- firebase_core
- firebase_auth
- firebase_analytics
- firebase_crashlytics
- firebase_messaging
- firebase_remote_config
- cloud_firestore
- firebase_storage
- in_app_purchase
- in_app_purchase_android
- flutter_local_notifications
- permission_handler
- app_links
- flutter_secure_storage
- shared_preferences
- hive / hive_flutter
- image_picker
- device_info_plus
- package_info_plus
- connectivity_plus
- internet_connection_checker_plus

## Privacy/Data Safety checklist
- [ ] List every SDK in release and map each to data collected.
- [ ] For each SDK, document purpose, sharing, retention, and optional/required status.
- [ ] Privacy policy URL exists and matches real behavior.
- [ ] Play Data Safety form matches app + SDK behavior.
- [ ] No API keys/secrets are committed in repository.
- [ ] Logs do not expose sensitive user data or tokens.
- [ ] Users can understand local-only versus cloud-synced behavior.
- [ ] If accounts exist, account deletion path is documented.
- [ ] If subscriptions exist, billing/refund/support flow is documented.
- [ ] Permission rationale appears in-app before system prompt.

## Required evidence before release
- [ ] Screenshot/video: notification permission requested only after user enables reminders.
- [ ] Screenshot/video: app remains functional when notification permission is denied.
- [ ] Screenshot/video: any audio permission request is user-triggered and explained.
- [ ] Review note: why RECEIVE_BOOT_COMPLETED is needed and tested.
- [ ] Review note: why WAKE_LOCK is needed and tested.
- [ ] Link to privacy policy and account deletion flow in production environment.

## Suggested audit commands
Run from project root:

- flutter pub deps
- flutter analyze
- flutter test
- Select-String -Path android/app/src/main/AndroidManifest.xml -Pattern uses-permission
- Select-String -Path lib/**/*.dart -Pattern request|Permission|permission_handler|flutter_local_notifications
- Select-String -Path lib/**/*.dart -Pattern Crashlytics|Analytics|Supabase|Firebase

## Findings log
- Date/Time:
- Finding:
- Severity:
- Evidence:
- Owner:
- Fix PR/Commit:
- Retest result:
