# ChronoSpark Release Tracker

> **Scope lock date:** 2026-07-13  
> **Target:** Google Play Closed Testing → v1.0 public launch

Status legend: ✅ Done · ⏳ In progress · ❌ Blocked · 📋 Planned

---

## 1. CI/CD Pipelines

| Item | Status | Notes |
|------|--------|-------|
| Flutter CI (`dart.yml`) runs on push/PR to main | ✅ | `flutter analyze` + `flutter test --coverage` |
| CodeQL Swift analysis | ✅ | `.github/workflows/codeql.yml`, uses xcodebuild |
| GitHub Pages web deploy (`main.yml`) | ✅ | Deploys on push to main |
| Android release AAB (`android-release.yml`) | ✅ | Triggered on `v*.*.*` tags |
| Linux tester release (`linux-release.yml`) | ✅ | Manual `workflow_dispatch` |
| PR template + required CI checks enforced | 📋 | See `.github/pull_request_template.md` |
| Branch protection rules (require passing CI) | ❌ | Must be enabled in repo Settings → Branches |
| Test summary artifact upload in `dart.yml` | ⏳ | Added JUnit upload step |
| QA tester AAB CI path (signed, secrets set) | ❌ | Needs `ANDROID_KEYSTORE_BASE64` etc. in secrets |

---

## 2. Automated Testing — Critical Flows

| Critical Flow | Unit | Widget | Integration | Gap |
|--------------|------|--------|-------------|-----|
| Account creation / login | ✅ | ✅ | ✅ `auth_flow_integration_test.dart` | None |
| Onboarding / first-run tutorial | ✅ | ✅ | ✅ `app_startup_test.dart` | Tutorial analytics |
| Task lifecycle (create/edit/complete) | ✅ | ✅ | ✅ `task_lifecycle_test.dart` | None |
| Paywall / entitlement gate | ✅ | ✅ | ✅ `paywall_gate_test.dart` | Restore-purchases loading state |
| Sync / offline recovery | ✅ | ✅ | ✅ `offline_sync_roundtrip_integration_test.dart` | None |
| Error boundary / crash recovery | ✅ | ✅ | – | No integration smoke |
| SI Console flow | ✅ | ✅ | ✅ `si_console_flow_test.dart` | None |
| Permission prompts (notification) | ✅ | – | – | Widget test missing |

**Remaining test gaps (prioritised):**
1. `permission_prompt_widget_test.dart` – notification permission grant/deny/revoke widget coverage
2. `error_boundary_integration_test.dart` – smoke: inject crash, verify recovery screen shown
3. Tutorial analytics events (verify `tutorial_started`, `tutorial_completed`, `tutorial_skipped`)

---

## 3. Store Assets

| Asset | Status | Notes |
|-------|--------|-------|
| App name | ✅ | ChronoSpark |
| Short description (80 chars) | ❌ | Draft in this doc (see §3.1) |
| Full description (4 000 chars) | ❌ | Draft in this doc (see §3.1) |
| App icon (512 × 512 PNG) | ✅ | `assets/icons/app_icon.png` — verify Play-ready |
| Feature graphic (1024 × 500 PNG) | ✅ | `feature.png` at repo root — verify dimensions |
| Phone screenshots (2–8) | ✅ | `assets/screenshots/` — 13 images present |
| Tablet screenshots | 📋 | Optional unless tablet UI is claimed |
| Tester notes (closed testing) | ❌ | Draft in §3.2 |
| Release notes | ❌ | Draft in §3.3 |

### 3.1 Listing Copy Drafts

**Short description (≤80 chars)**
> AI productivity planner: tasks, focus sessions, smart coaching, and insights.

**Full description**
```
ChronoSpark is your AI-powered second brain for deep work and intentional living.

FEATURES
• Smart Task Engine — prioritise and schedule work with adaptive ranking.
• Focus Sessions — time-block your day with guided start/complete flows.
• Smart Coach — conversational AI coaching for plans, habits, and decisions.
• SI Console — advanced decision-support that understands your goals and history.
• Temporal Ops — timeline, milestones, and streak tracking (Premium).
• Offline-first — all core data lives on device; optional cloud sync available.

SUBSCRIPTION
ChronoSpark Base is free. Premium and Ultimate unlock advanced AI features.
Subscription pricing is shown before purchase. You can restore past purchases any time.

TESTING NOTE
This build is a closed test. Some features may not represent the final experience.
```

### 3.2 Tester Notes (Closed Testing Track)

```
This is a closed testing build of ChronoSpark. Some authentication and premium 
restrictions are bypassed in QA mode. Live billing and account deletion are not 
finalised. Please report bugs to: ghostheart131517@gmail.com
```

### 3.3 Release Notes (v1.0 closed test)

```
ChronoSpark v1.0 closed testing release.
- Initial end-to-end task and focus session flow.
- Smart Coach AI coaching.
- SI Console for adaptive decision support.
- Offline-first data with optional Supabase cloud sync.
- Subscription paywall (test mode only in this build).
```

---

## 4. Policy / Compliance

| Item | Status | URL |
|------|--------|-----|
| Privacy policy | ✅ | `https://ghostheart5.github.io/fantastic-guacamole/privacy/` |
| Terms of service | ✅ | `https://ghostheart5.github.io/fantastic-guacamole/terms/` |
| Support / contact page | ✅ | `https://ghostheart5.github.io/fantastic-guacamole/support/` |
| Delete account page | ✅ | `https://ghostheart5.github.io/fantastic-guacamole/delete-account/` |
| Support email visible on support page | ✅ | `ghostheart131517@gmail.com` |
| Play Console support email set | ❌ | Manual — Play Console → Store listing → Contact details |
| Play Console privacy policy URL set | ❌ | Manual — Play Console → Store listing |
| Data Safety section complete | ❌ | Manual — Play Console → Data Safety |
| Microphone use disclosure | ❌ | Required if voice features shipped |
| COPPA / children's audience declaration | ❌ | Declare "not directed at children" |

---

## 5. UX Polish Before Wider Testing

See [`docs/UX_POLISH_CHECKLIST.md`](UX_POLISH_CHECKLIST.md) for the full item list.

**Top-5 items from current audit:**
1. Paywall restore button has no loading state — add spinner
2. Deep-link invalid path shows no user feedback — add snackbar
3. Notification permission prompt wording not policy-aligned — audit copy
4. Missing `semanticsLabel` on icon-only action buttons — accessibility gap
5. Transition from onboarding → home is abrupt on first launch — add fade

---

## 6. Google Closed-Testing Questionnaire

See [`docs/GOOGLE_PLAY_QUESTIONNAIRE.md`](GOOGLE_PLAY_QUESTIONNAIRE.md) for pre-drafted answers.

**Evidence log (update as testing progresses):**

| Date | Item | Evidence |
|------|------|---------|
| TBD | Tester recruitment | Describe how testers were invited |
| TBD | Tester count | Total unique tester installs from Play Console |
| TBD | Key feedback themes | Summary from in-app / email reports |
| TBD | Issues fixed | Link to GitHub issues / changelog |

---

## 7. Analytics Dashboards

See [`docs/ANALYTICS_TAXONOMY.md`](ANALYTICS_TAXONOMY.md) for the locked event list.

**Dashboard readiness:**

| Dashboard | Status | Tool |
|-----------|--------|------|
| Task completion funnel | 📋 | Firebase Analytics |
| Error rate + crash-free sessions | 📋 | Firebase Crashlytics |
| Session length | 📋 | Firebase Analytics |
| Feature usage (coach/si/focus) | 📋 | Firebase Analytics |
| Paywall → purchase funnel | 📋 | Firebase Analytics |
| Retention curves (D1/D7/D30) | 📋 | Firebase Analytics |

---

## 8. Backend Hardening

See [`docs/BACKEND_HARDENING_RUNBOOK.md`](BACKEND_HARDENING_RUNBOOK.md) for full checklist.

| Item | Status |
|------|--------|
| Firestore security rules reviewed | ❌ |
| Cloud Functions cold-start tested | ❌ |
| Supabase RLS audit complete | ❌ |
| Schema changes frozen for test window | ❌ |
| Storage bucket policies verified | ❌ |
| Rollback runbook written | ✅ (in runbook doc) |

---

## 9. Release Roadmap

See [`docs/ROADMAP.md`](ROADMAP.md) for the full versioned plan.

| Version | Focus | Target |
|---------|-------|--------|
| v1.0 | Closed testing baseline | Now |
| v1.1 | Blocker fixes + reliability | 2 weeks post-testing start |
| v1.2 | UX polish + QoL | 4 weeks post-testing start |
| v1.3 | New features (telemetry-driven) | 8 weeks post-testing start |

---

## 10. Remaining Blockers Before Upload

> These must all be ✅ before uploading to the Play internal testing track.

1. ❌ Real upload keystore + `android/key.properties` not yet created  
2. ❌ Secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD` not set in repo  
3. ❌ Firebase options (`lib/firebase_options.dart`) not verified against release project  
4. ❌ Play Console: support email, privacy policy URL, and Data Safety not completed  
5. ❌ Branch protection rules not enforced  
6. ❌ Billing verification endpoint not deployed  
7. ❌ Account deletion backend endpoint not deployed  
