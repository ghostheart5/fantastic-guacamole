# Performance + Stability Audit

Date: 2026-07-24
Owner:
Release Target:
Build/Commit:

## Checklist
- [ ] Startup time measured before and after hydration.
- [ ] Large snapshot load does not freeze UI.
- [ ] SI recompute has bounded time and safe fallback.
- [ ] Log list uses lazy rendering, not full heavy rebuilds.
- [ ] Animated backgrounds paused/reduced when offscreen.
- [ ] Images/assets have fallbacks and are compressed.
- [ ] No memory growth after repeated navigation loops.
- [ ] No rebuild storms from providers watching overly broad state.
- [ ] No synchronous file/network work on UI thread.
- [ ] Release mode tested, not just debug mode.
- [ ] Crash reporting planned before public release.
- [ ] App handles offline mode gracefully.

## Performance budgets to define before release

| Area | Target to define before release |
|---|---|
| Cold start | Decide acceptable startup time on low-end Android. |
| Hydration | Decide maximum snapshot size and load behavior. |
| SI recompute | Decide max recompute cost and fallback response. |
| Navigation | No noticeable hang when changing tabs. |
| Scrolling | Long tasks/logs remain smooth. |
| Animations | Subtle, interruptible, reduced-motion friendly. |

## Automated audit coverage
Executable test script:
- test/audit/run_performance_stability_audit.ps1

Automated checks include:
- Startup/hydration evidence artifacts present.
- Lazy list rendering signals in critical screens.
- Sync I/O usage scan for UI-thread risks.
- Broad provider watch heuristic scan.
- Offline-mode codepath signals.
- Crash reporting readiness signals.
- Release artifact/log presence signals.
- Animation guardrails and offscreen-reduction signals.

## Manual evidence still required
- [ ] Stopwatch or profiling evidence for cold start and hydration on low-end Android.
- [ ] Repeated navigation loop memory capture (before/after).
- [ ] SI recompute stress run with fallback behavior evidence.
- [ ] Release mode behavior confirmation on at least one physical Android device.

## Findings log
- Date/Time:
- Finding:
- Severity:
- Evidence:
- Owner:
- Fix PR/Commit:
- Retest result:
