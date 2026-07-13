# ChronoSpark Release Roadmap

> Last updated: 2026-07-13  
> All dates are targets, not commitments. Scope is locked per cycle; new items enter the next cycle.

---

## v1.0 — Closed Testing Baseline (current)

**Goal:** Ship a stable, testable build to invited testers on the Google Play closed testing track.

**Scope:**
- Core task lifecycle (create, edit, complete, skip, delete)
- Focus session start / pause / complete / cancel flow
- Smart Coach conversational AI (with fallback)
- SI Console decision support (trial-gated)
- Temporal Ops: timeline, milestones, streaks (Premium trial)
- Offline-first local storage with optional Supabase cloud sync
- Subscription paywall (test-mode only in this build; real billing not active)
- Privacy policy, terms, support, and delete-account pages live on GitHub Pages

**Blockers remaining (see `docs/RELEASE_TRACKER.md §10`):**
- Upload keystore + Play Console secrets
- Firebase options verified against release project
- Play Console metadata complete

---

## v1.1 — Reliability + Blocker Fixes (~2 weeks post-testing start)

**Goal:** Address every P0/P1 bug found by testers and close known gaps before wider distribution.

**Candidate items:**
- [ ] Fix any crash-rate regressions identified in Crashlytics
- [ ] Restore purchases: add loading state and error feedback (currently missing)
- [ ] Notification permission prompt copy aligned with privacy policy
- [ ] Deep-link invalid path: add snackbar user feedback
- [ ] Tutorial analytics events: `tutorial_started`, `tutorial_completed`, `tutorial_skipped`
- [ ] Permission prompt widget test coverage
- [ ] Error-boundary integration smoke test
- [ ] Fix all P1 tester-reported issues from the evidence log

**Technical debt:**
- [ ] Consolidate overlapping audit docs (merge stale items into `RELEASE_TRACKER.md`)
- [ ] Remove unused feature flags from Remote Config definitions

---

## v1.2 — UX Polish + Quality-of-Life (~4 weeks post-testing start)

**Goal:** Make the app feel polished and premium before any public release.

**Candidate items (full list in `docs/UX_POLISH_CHECKLIST.md`):**
- [ ] Onboarding → home transition: replace abrupt navigation with a smooth fade
- [ ] Empty states for tasks, goals, habits, logs (consistent illustrated placeholders)
- [ ] Loading states: shimmer skeletons on data-fetch screens
- [ ] Error message audit: all snackbar/dialog copy reviewed for clarity and tone
- [ ] Misaligned padding audit across all major screens
- [ ] Color/label consistency pass (typography scale and spacing tokens)
- [ ] Accessibility: add missing `semanticsLabel` on icon-only buttons
- [ ] First-run tutorial: contextual hints for Smart Coach and SI Console
- [ ] Account creation flow: confirmation email copy and post-creation route
- [ ] Permission prompts: add "why we need this" rationale where missing

---

## v1.3 — New Features (telemetry-driven) (~8 weeks post-testing start)

**Goal:** Add features with demonstrated demand from tester usage data.

**Candidates (require ≥20% of testers to request or engagement data to justify):**
- [ ] Calendar integration (Google Calendar / Apple Calendar)
- [ ] Shared goals / collaborative tasks
- [ ] AI-generated weekly review
- [ ] Advanced SI Console analytics (compare weeks, trend visualisation)
- [ ] Widgets (Android home screen widget for next task)
- [ ] iOS app

**Gate:** None of these are committed. Candidates are promoted after v1.2 ships if telemetry confirms demand.

---

## Technical Debt Lane

One 20% slice of every sprint cycle is reserved for technical debt:

| Item | Target cycle |
|------|-------------|
| Consolidate overlapping audit docs | v1.1 |
| Remove unused packages from `pubspec.yaml` | v1.1 |
| Migrate remaining `TODO` comments to tracked issues | v1.2 |
| Increase unit test coverage on SI engine edge cases | v1.2 |
| Evaluate and upgrade pinned action SHA versions in workflows | v1.3 |
| Document all Remote Config keys and their defaults | v1.3 |

---

## Long-Term Vision (post-v1.3)

- Web app (already partially deployed, needs full feature parity)
- Desktop (Windows, macOS, Linux builds exist but are not promoted)
- Cross-platform subscription via a unified backend
- Public API for third-party integrations
