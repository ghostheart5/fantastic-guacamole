# ChronoSpark — Phase 1 Critical UI Blocker Fix Report

**Pass type:** Phase 1 only — critical UI/runtime visual blockers.
**Not a redesign, theme rewrite, cleanup, naming, or test pass.** Phases 2–5 not started.

---

## 1. Summary

**Final status: ✅ PASS (Phase 1 complete)**

| Metric | Result |
|---|---|
| Blockers addressed | **2 fixed with code** (B1, B4) |
| Blockers found **not reproducible** | **2** (B2, B5) — verified, corrected, reported |
| Blockers deferred / outside scope | 0 |
| Hardening changes applied | 1 (B2, one-line ergonomic) |
| `flutter analyze` after **every** fix | ✅ **"No issues found"** (0 diagnostics), 3 consecutive runs |
| Files changed | 3 (`+28 / −9` lines, UI-only) |
| Files deleted | 0 |
| Features renamed | 0 |

**Headline correction:** two of the four Phase 1 blockers (B2, B5) did **not** reproduce when I inspected the actual code paths rather than trusting the prior audit's summary. Both were overstated in `UI_VISUAL_LAYOUT_THEME_AUDIT.md`. I did **not** manufacture changes to justify them — I verified, reported, and left working code alone. Details in §2.

**Test execution note:** `flutter test` could not run in this environment — it crashes before executing any test with `_TypeError: Null check operator used on a null value` in `package:test_core/src/executable.dart:31` (`_globalConfigPath`), triggered by a missing `%PROGRAMFILES(X86)%` variable in this Git Bash shell. This is a **pre-existing local tooling/environment issue, unrelated to these changes** (it fails identically regardless of the diff). `flutter analyze` was used as the gate instead; manual verification steps are listed in §5.

---

## 2. Fix Log

### B1 — Timeline event-title Row overflow ✅ FIXED (real blocker)

| Field | Detail |
|---|---|
| **File** | `lib/features/timeline/ui/timeline_screen.dart:427-453` |
| **Screen/widget** | Timeline → `_TimelineEventTile` |
| **Exact visual problem** | The title `Text` sat directly in a `Row(mainAxisAlignment: spaceBetween)` alongside a trailing time `Text`, with **no `Expanded`/`Flexible` and no `maxLines`/`overflow`**. Event titles are user-entered (built from task/goal titles), so a long title produced a genuine `RenderFlex` overflow (yellow/black stripes) — worst on 320–360dp widths and at large text scale. |
| **Fix applied** | Wrapped the title `Text` in `Expanded`; added `maxLines: 1` + `overflow: TextOverflow.ellipsis`; inserted `const SizedBox(width: 8)` so the ellipsis doesn't collide with the time label. |
| **Why UI-only** | Pure widget-tree/layout change inside a presentational tile. No change to the event model, `_eventMoment`, sorting, filtering, grouping, persistence, or any provider. |
| **Consistency note** | Matches the file's own existing convention — the sibling `event.detail` Text already used `maxLines` + `ellipsis`. |
| **Risk** | **Very low.** With `Expanded` as the first child, `spaceBetween` still renders the time flush right, so layout intent is preserved. |
| **Verification** | `flutter analyze` → 0 issues. Visual confirmation pending manual run (§5). |

---

### B2 — Onboarding personalization keyboard coverage ⚠️ NOT REPRODUCIBLE (audit finding corrected)

| Field | Detail |
|---|---|
| **File inspected** | `lib/features/onboarding/ui/onboarding_screen.dart:173, 197-346, 660-968`; `android/app/src/main/AndroidManifest.xml:37` |
| **Original claim** | "Bottom action bar is `Positioned(bottom:0)` + `SafeArea` with no `viewInsets` awareness → keyboard covers the name field and INITIALIZE button." |
| **What I actually found** | The claim **does not hold**. Two mechanisms already handle this: (1) the `Scaffold` at line 173 uses the **default `resizeToAvoidBottomInset: true`**, so the body — and therefore the whole `Stack` — is shrunk by the keyboard inset, placing `Positioned(bottom: 0)` **above** the keyboard; (2) `AndroidManifest.xml:37` sets `android:windowSoftInputMode="adjustResize"`, which is required for that to work on Android and **is** set. Additionally, Flutter auto-scrolls the focused `TextField` into view inside the `SingleChildScrollView`, and the slide's reserved bottom padding (160–188dp) comfortably exceeds the bottom bar's height (~85dp), so the field settles clear of the bar. |
| **Conclusion** | The name field and INITIALIZE button are **not** covered by the keyboard. The prior audit reached its conclusion from the `Positioned` + no-`viewInsets` pattern without accounting for the `Scaffold` default. **No restructuring was warranted**, and rewriting a working keyboard layout would have added risk for no benefit. |
| **Change actually applied** | One line only: `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` on the personalization slide's `SingleChildScrollView`. This is a standard mobile ergonomic (drag to dismiss keyboard) and **matches the existing pattern already used in `login_screen.dart`**. Scoped to the personalization slide only — the identical `_SlideView` scroll view was deliberately left untouched, since it has no input. |
| **Why UI-only** | A scroll-view presentation property. No onboarding state, flow, persistence, route, auth, or copy changes. |
| **Risk** | **Negligible.** |
| **Verification** | `flutter analyze` → 0 issues. |

---

### B4 — Plan TimeSlot start-time text color ✅ FIXED (real blocker)

| Field | Detail |
|---|---|
| **File** | `lib/features/plan/widgets/time_slot.dart:14-22` |
| **Screen/widget** | Plan → `TimeSlot` (start-time label) |
| **Exact visual problem** | The `start` `Text` had **no `color`** and inherited the ambient `DefaultTextStyle`, while its sibling `end` `Text` had an explicit `Colors.white38`. Depending on the surrounding surface/`DefaultTextStyle`, the start time could render near-invisible — and it would definitely break under any future light-theme work. |
| **Fix applied** | Applied an explicit **themed** colour: `Theme.of(context).colorScheme.onSurface`. Removed `const` from the `TextStyle` (now context-derived). |
| **Why this token** | Per the brief, no hardcoded white/black. `onSurface` is `Colors.white` in `appTheme` (identical rendering today — zero visual regression) and `Color(0xFF0F1A33)` in `appLightTheme`, so it is automatically correct for Phase 3 light-mode work. |
| **Why UI-only** | `TimeSlot` is a pure presentational widget taking two pre-formatted `String`s. No scheduling, planning, or Smart Planner business logic touched. The sibling `end` text was intentionally left as-is to stay within blocker scope. |
| **Risk** | **Very low** — visually identical in the current dark theme. |
| **Verification** | `flutter analyze` → 0 issues. |

---

### B5 — SI Console composer reserved height ⚠️ NOT REPRODUCIBLE (audit finding corrected)

| Field | Detail |
|---|---|
| **File inspected** | `lib/features/si_console/ui/si_console_screen.dart:547-647, 1094-1129` |
| **Original claim** | "Fixed `composerReservedHeight` (120/220) can hide the last messages behind the composer." |
| **What I actually found** | The claim is **inverted**. The composer is wrapped in `ConstrainedBox(maxHeight: composerMaxHeight)` (line 628-629), and `_InputBar` is a `Container → SingleChildScrollView → Column(mainAxisSize: min)` (line 1099-1113) — it **scrolls internally rather than growing**. So the composer's actual height is **always ≤ `composerMaxHeight`**. Since `composerReservedHeight == composerMaxHeight` and the list pads by `composerReservedHeight + composerBottomInset` (line 607-612), the reservation is a guaranteed **upper bound** on composer height. **Messages can never be hidden behind the composer.** |
| **Keyboard handling** | Also verified correct: `resizeToAvoidBottomInset: false` is deliberate here and compensated manually — `composerBottomInset` uses `viewInsets.bottom` when the keyboard is open and `padding.bottom` otherwise (line 550-552), applied to both the composer and the list padding. This is a sound manual implementation. |
| **Actual (minor) artifact** | The inverse of the claim: when the composer renders **shorter** than its max, the message list carries up to ~100dp of harmless dead space below the last message. Cosmetic only — logged as a **Phase 2+ polish item**, not a blocker. |
| **Change applied** | **None.** Restructuring the `Stack` into a `Column`/`Expanded` layout would change SI Console's floating-composer visual behaviour, which the brief explicitly requires preserving — and would be a behavioural change made to fix a non-existent bug. |
| **Risk of not changing** | **None** — current behaviour is correct. |

---

## 3. Diffs Summary

Three files changed, `+28 / −9`. No files added, deleted, moved, or renamed.

| File | Changed behaviour |
|---|---|
| `lib/features/timeline/ui/timeline_screen.dart` | Timeline event titles now flex and truncate with an ellipsis instead of overflowing the row. Time label still right-aligned, now with an 8dp gap. |
| `lib/features/onboarding/ui/onboarding_screen.dart` | Personalization slide only: dragging the scroll view now dismisses the keyboard. No layout, state, flow, or copy change. |
| `lib/features/plan/widgets/time_slot.dart` | Start-time label now uses the themed `colorScheme.onSurface` instead of an inherited/undefined colour. Visually identical in the current dark theme. |

No changes to: routes, providers, repositories, use cases, entities, services, models, generated files, or shared widgets.

---

## 4. Out-of-Scope Items — Confirmed Untouched

I confirm **no changes** were made to any of:

- ✅ Auth logic / auth services
- ✅ Supabase
- ✅ Firebase
- ✅ Database
- ✅ RLS
- ✅ Monetization / purchase logic
- ✅ SI logic (no SI decision logic, providers, use cases, repositories, models, or backend calls)
- ✅ Smart Planner business logic
- ✅ Migrations
- ✅ Edge Functions
- ✅ Domain entities, use cases, repositories, providers
- ✅ Route definitions
- ✅ Feature names (the visible "SMART COACH" copy was **not** changed — report-only, per instruction 10)

One incidental artifact: the failed `flutter test` invocation generated a crash log at repo root (`flutter_02.log`). Per the "do not delete files" rule I left it in place — remove it manually if unwanted.

---

## 5. Remaining Work (Phase 2+ — NOT started)

**Phase 2 — high-priority visual consistency**
- Sub-48dp touch targets (back buttons 34–36px; "COMPLETE" 10px text; priority bars 6px; value/emotion chips ~26–28px)
- `Semantics`/`Tooltip` on icon-only controls (only 6 `Semantics` uses in 3 files today)
- Visual state coverage: loading/skeleton/error/retry for Tasks, Profile, Timeline, Nexus error path
- Button/card system consolidation (4 button + 4 card/panel components, 4 radii)
- Visible **"SMART COACH"** copy — report-only so far: `smart_coach_screen.dart:456`, `onboarding_screen.dart:45`, `tutorial_content.dart:56`
- SI Console composer dead-space polish (from B5 finding above)

**Phase 3 — theme/token unification & light-mode wiring**
- ~1,125 hardcoded `Colors.*` + 245 `Color(0x…)` + 425 raw `TextStyle(` vs 4 `Theme.of` reads in `lib/features`
- Merge the two palettes (`theme/colors.dart` vs `ui/constants/app_colors.dart`) and three spacing/radius systems
- Wire `darkTheme:` + `themeMode:`; fix `shadows.dart` stale violet; resolve `w800` weight (only Regular/Medium/Bold bundled)

**Phase 4 — accessibility polish**
- Text-scale handling (0 `textScaler` uses today), contrast on `white24/38/54` small text, `SystemUiOverlayStyle`, form labels, semantic selection state, chart semantics

**Phase 5 — optional premium polish**
- Nexus density/hierarchy, standardized headers/banners, tablet `NavigationRail`, reduced overdraw/always-on motion

**Also outstanding (non-UI, separate pass):** dev/diagnostic UI gating, fabricated data in Logs/Insights/Progression, paywall purchase-in-progress state — all flagged **outside this scope**.

---

## 6. Next Recommended Prompt

> **Verify Phase 1 visually, then begin Phase 2 (touch targets + semantics only).**
>
> **Part A — verify Phase 1 (no code changes):** Run the app on 320×568, 360×640, and 390×844. Confirm: (1) a Timeline event with a very long title truncates with an ellipsis and shows no overflow stripes; (2) the Plan start-time label is clearly readable; (3) the onboarding personalization field and INITIALIZE button remain usable with the keyboard open, and dragging dismisses the keyboard. Also repeat at text scale 1.5× and 2.0×. Report findings only.
>
> **Part B — Phase 2, first slice only:** Fix sub-48dp touch targets and add `Semantics`/`Tooltip` to icon-only controls, starting with the shared widgets and the Nexus/Timeline/Plan/Profile headers. UI-only; no theme/token work, no state-coverage work, no naming changes, no deletions. Show me each diff before moving to the next file and run `flutter analyze` after each.
>
> Separately, please advise whether to fix the `flutter test` environment issue (missing `%PROGRAMFILES(X86)%`) so widget/golden tests can gate future phases.
