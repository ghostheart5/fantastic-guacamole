# ChronoSpark — UI / Visual / Layout / Theme Production-Readiness Audit

**Scope:** UI, visual polish, layout/responsiveness, theming, accessibility, visual states, navigation shell, forms. **Audit only — no code was modified, nothing deleted, no renames performed.**
**Excluded by design:** auth/Supabase/Firebase/DB/RLS/monetization/SI/Smart Planner/domain logic (see §14). Domain/SI/Smart Planner naming work already audited separately is **not** repeated here.
**Canon respected:** Session and Insight are treated as **dead/output-only**, not active features. No old naming reintroduced.
**Tooling:** `flutter analyze --no-pub` → **"No issues found" (0 diagnostics)**. All findings below are visual/runtime, not static-analysis detectable.

---

## 1. Executive Summary

**Overall UI production-readiness rating: 🔴 NO-GO (fixable) — currently CONDITIONAL at best.**

The app has an ambitious, distinctive "neon/holographic" identity and its bones are sound (clean navigation shell, modern `withValues` color API, bundled Inter font, `flutter analyze` clean). But the presentation layer **bypasses its own theme almost entirely**, has **several confirmed overflow/keyboard blockers**, **near-absent accessibility**, and **broken light mode** — enough to fail a careful visual review and to look inconsistent across device sizes.

### Top 5 visual risks
1. **Light mode is visually broken.** ~1,125 hardcoded `Colors.*` + 245 `Color(0x…)` literals vs only **4** `Theme.of(context)` reads across all of `lib/features`; no `darkTheme:`/`themeMode:` wiring. Selecting light theme leaves dark hardcoded colors → unreadable.
2. **Confirmed layout blockers:** Timeline event-title `Row` overflow on long titles; Onboarding personalization slide keyboard covers the name field / primary button.
3. **Accessibility failure surface:** 6 `Semantics` uses in 3 files, `0` text-scale handling, pervasive sub-48dp touch targets, and 7–11px fonts with `FittedBox` that fights OS text scaling.
4. **Design-system fragmentation:** 2 competing color palettes, 3 spacing/radius systems, 4 button components, 4 card/panel components — visual inconsistency screen-to-screen.
5. **Weak/absent visual states** on core surfaces (Tasks, Profile, Timeline, Nexus error) — async failures render as empty data with no skeleton/error/retry.

### Google Play visual-review readiness
**Not yet.** Layout overflows on small phones, broken light mode, and dev/diagnostic surfaces visible to users (reported by the prior production-readiness pass) are the kind of issues a reviewer or a screenshot set will surface. After Phase 1 + Phase 2 (§12), it should reach CONDITIONAL PASS.

---

## 2. Files / Screens Audited

Grouped by feature area (UI files only; 38 screen/page files + shared widget/theme layers).

**Shell / navigation / root**
- `lib/app/app_root.dart`, `lib/app/navigation_shell.dart`
- `lib/app/router/app_router.dart`, `route_paths.dart`, `info_pages.dart`, `web_page_view.dart`

**Canon feature screens**
- Nexus (home): `features/nexus/ui/nexus_screen.dart`, `nexus_screen.widgets.dart`
- Smart Planner: `features/home/ui/smart_planner_screen.dart` (+ `home/widgets/ai_decision_card.dart`)
- Creator: `features/creator/ui/creator_screen.dart` (+ `widgets/dynamic_form.dart`, `input_field.dart`, `quick_input_bar.dart`, `type_selector.dart`)
- SI Console: `features/si_console/ui/si_console_screen.dart`
- Timeline: `features/timeline/ui/timeline_screen.dart`
- Trajectory Engine (Tasks tab): `features/tasks/ui/task_screen.dart` (+ `widgets/task_card.dart`)
- Progression: `features/progression/ui/progression_screen.dart` (+ `widgets/level_card.dart`, `weekly_summary_card.dart`, streak)

**Supporting screens (visual-only pass)**
- Plan: `features/plan/ui/plan_screen.dart` (+ `widgets/timeline_view.dart`, `time_block_widget.dart`, `time_slot.dart`, `day_selector.dart`, `plan_header.dart`)
- Profile: `features/profile/ui/profile_screen.dart` (+ `widgets/profile_header.dart`)
- Settings: `features/settings/ui/settings_screen.dart`, `settings_screen.sections.dart`
- Milestones/Goals/Memories/Personal Alignment/Flowmap: respective `ui/*_screen.dart`
- Logs: `features/logs/ui/logs_screen.dart` (+ widgets)
- Onboarding: `features/onboarding/ui/onboarding_screen.dart`
- Tutorial: `lib/tutorial/tutorial_overlay.dart`, `widgets/micro_tutorial_card.dart`, `show_me_again_button.dart`
- Auth (visual-only): `features/auth/ui/login_screen.dart`, `auth/screens/auth_gate.dart`
- Paywall (visual-only): `features/paywall/ui/paywall_page.dart`, `feature_gate.dart`, `ui/system/premium_feature_gate.dart`
- Notifications: `features/notifications/ui/notification_screen.dart`
- Permissions: `features/permissions/*`
- Admin (internal): `features/admin/ui/product_advisor_screen.dart`

**Shared widgets**
- `lib/ui/widgets/`: `app_button`, `app_card`, `app_text`, `app_layout`, `app_screen`, `section_header`, `holo_button`, `smart_pressable`, `loading_overlay`, `offline_banner`, `success_banner`, `error_view`, `error_boundary_widget`, `typing_text`
- `lib/ui/system/`: `glass_panel`, `crisis_dialog`, `level_up_overlay`, `focus_start_overlay`, `premium_feature_gate`
- `lib/ui/layout/animated_system_background.dart`

**Theme system**
- `lib/theme/`: `theme.dart`, `app_theme.dart`, `colors.dart`, `typography.dart`, `spacing.dart`, `radii.dart`, `shadows.dart`, `theme_extensions.dart`, `widgets/{neon_button,neon_card,neon_panel,neon_divider,neon_input}.dart`
- `lib/ui/constants/`: `app_colors.dart`, `app_sizes.dart`, `app_assets.dart`

**Modals/sheets/overlays inventoried:** Navigation-Map sheet (`navigation_shell.dart:404`), Memory/Milestone/Goal/Flowmap/Soul-Map editor sheets, Permission rationale sheet, Smart Planner voice sheet, QA diagnostics sheet, delete-account/password AlertDialogs, crisis dialog, level-up/focus-start/tutorial overlays, SnackBars (widespread).

---

## 3. Critical Blockers

| # | File | Screen/Widget | Problem | Why it matters | Suggested fix (report-only) | Risk |
|---|---|---|---|---|---|---|
| B1 | `features/timeline/ui/timeline_screen.dart:430` | Timeline event tile | Title `Text` in a `Row(spaceBetween)` with a trailing time `Text` is **not** wrapped in `Expanded/Flexible`; titles are user-entered | RenderFlex overflow (yellow/black stripes) on long titles / small phones / large text | Wrap title in `Expanded` + `maxLines:1`, `overflow: ellipsis` | High |
| B2 | `features/onboarding/ui/onboarding_screen.dart:197-346,714` | Onboarding personalization slide | Bottom action bar is `Positioned(bottom:0)` + `SafeArea` with **no `viewInsets` awareness**; name `TextField` sits above it | Keyboard covers the input and the INITIALIZE button on 320–390-tall screens → user can't finish onboarding | Add `MediaQuery.viewInsetsOf(context).bottom` padding to the bottom bar, or move it inside the scroll view | High |
| B3 | Theme-wide (`app_root.dart:137`; ~1,125 `Colors.*`, 245 `Color(0x…)` in features) | All screens in light mode | Feature widgets hardcode dark colors; only 4 `Theme.of` reads; `theme:` swapped, no `darkTheme/themeMode` | If a user selects Light theme, most screens render dark text on light scaffold / invisible content → unusable | Route feature colors through `colorScheme`; wire `darkTheme`+`themeMode`. Large effort — see §12 Phase 3 | High |
| B4 | `features/plan/widgets/time_slot.dart:14-17` | Plan → TimeSlot | Start-time `Text` has **no `color`**, inherits ambient default | On the dark scaffold the time label can render near-black/invisible | Apply an explicit themed color | Medium-High |
| B5 | `features/si_console/ui/si_console_screen.dart:553,607-611` | SI Console composer | `resizeToAvoidBottomInset:false` + a **fixed** `composerReservedHeight` (120/220) estimate | A tall/wrapped composer can hide the last messages behind the input bar | Measure composer height (LayoutBuilder/keys) instead of a constant | Medium-High |

> Note: The "dev/diagnostic UI visible in production" and "fabricated data shown as analytics" items are real release blockers but were raised in the prior production-readiness pass and involve non-visual gating logic — listed here as **cross-reference only**, not re-audited.

---

## 4. High-Priority Issues (fix before release)

- **H1 — Systemic sub-48dp touch targets.** Back buttons are 34–36px (`profile_header.dart:132`, `settings_screen.dart:74`, `paywall_page.dart:253`, `notification_screen.dart:68`, timeline/goals/memories/soul-map headers); "COMPLETE" is a 10px `Text` (`time_block_widget.dart:125`); priority bars are 6px tall (`dynamic_form.dart:306`); value/emotion chips ~26-28px. Below Material's 48×48 minimum.
- **H2 — Icon-only controls lack `Semantics`/`Tooltip`.** Notification bell, voice/mic/speak/summary chips, chevrons, star toggle, delete-node all use bare `GestureDetector`/`SmartPressable`. Only `HoloButton` and a couple of `IconButton`s are labelled.
- **H3 — Text-scaling fragility.** Dozens of fixed 7–11px fonts + `FittedBox` scale-down; `0` uses of `MediaQuery.textScaler`. Large-font accessibility users get clipped/misaligned layouts.
- **H4 — Weak visual-state coverage on core surfaces.** Tasks, Profile, Timeline, Personal Alignment, Progression read synchronous providers or `.asData?.value` and render failures as empty (`timeline_screen.dart:41`, `nexus_screen.widgets.dart:725`, `profile_screen.dart:25`). No skeleton/error/retry.
- **H5 — Duplicate/competing components** (visual inconsistency): 4 buttons (`app_button` r-hardcoded, `neon_button`, `holo_button`, `smart_pressable` used in 20 files) and 4 card/panel looks with 4 radii (`app_card` r14, `neon_card` r24, `neon_panel` r32, `glass_panel` r20). Screens don't look like one product.
- **H6 — "SMART PLANNER" appears in visible UI** (naming mismatch, report-only per scope): screen header `smart_planner_screen.dart:456`, onboarding tag `onboarding_screen.dart:45`, tutorial title `tutorial_content.dart:56` — while the same screens elsewhere say "Smart Planner". User sees two names for one feature.
- **H7 — Contrast.** Pervasive `Colors.white24/38/54` text at 9–11px on translucent dark cards — below WCAG AA for small text.
- **H8 — Status-bar icon style unmanaged.** `0` uses of `SystemUiOverlayStyle`/`AnnotatedRegion`; on light backgrounds or certain OEMs the status-bar icons can be unreadable.

---

## 5. Medium-Priority Issues

- **M1 — Spacing/radius tokens ignored.** 3 systems (`theme/spacing`+`radii`, `AppSizes`, `app_layout._spacing`); 325 raw `EdgeInsets` literals, 536 `SizedBox` magic numbers → inconsistent rhythm.
- **M2 — Plan double horizontal padding** (`plan_screen.dart:281` + `timeline_view.dart:35`) pushes content off the card border.
- **M3 — Creator has no focus-scroll**; multi-line fields mid-page rely on manual scroll (`creator_screen.dart:25`).
- **M4 — Flowmap uses a stock `AppBar`** while every sibling uses a custom neon header → jarring inconsistency.
- **M5 — Nexus info density.** Rings + labels + bridge card + 4 pills + 7-card mesh + 6 actions; card hierarchy is flat (everything a similar dark glass card).
- **M6 — Bespoke banners** in `app_root.dart` reimplement styling instead of reusing `offline_banner`/`success_banner`/`error_view`.
- **M7 — No tablet/foldable navigation.** `0` `NavigationRail`, `0` `Drawer`; bottom nav only; `LayoutBuilder` in just 5 files, `OrientationBuilder` in 0. On tablets most screens stretch a narrow list edge-to-edge.
- **M8 — Typography weight mismatch.** Theme requests `FontWeight.w800` (`typography.dart`) but only Inter Regular/Medium/Bold(700) are bundled → headlines render synthetic/fallback bold, not true 800.
- **M9 — `_ComparisonCard`/paywall lacks a max-width cap** on the overall list (stretches wide on tablets), though it does have a 420px card breakpoint (good).
- **M10 — Dead "Dismiss" button** renders disabled because callers pass no `onDismiss` (`permission_denied_recovery.dart:63`) — visual-only defect.

---

## 6. Low-Priority Improvements

- L1 — Consolidate `hSpace/vSpace/allPad` helpers usage; adopt a single spacing token everywhere.
- L2 — `_StaticPage` body (`web_page_view.dart:99`) has no scroll wrapper; long copy could overflow.
- L3 — Reduce always-on animation controllers on the home surface (ring pulse + pulse dot + animated background) for calmer, lower-power idle.
- L4 — Standardize section headers on `SectionHeader` instead of 24 bespoke `ShaderMask` gradient titles.
- L5 — Snackbars are used heavily for errors; consider inline error regions on forms for persistence.
- L6 — `premium_feature_gate.dart` (clean, `maxWidth:480`) is a good pattern to propagate to other centered content.

---

## 7. Device Matrix — expected risk areas

| Target | Primary risks |
|---|---|
| **320×568 (small Android)** | B1 Timeline title overflow; B2 onboarding keyboard; tight Nexus header (<340 ultra-compact only); fixed `width:104` profile cards + `width:280` planner bubbles crowd; 7-card mesh cramped; small fonts become unreadable. |
| **360×640 (compact)** | B2 keyboard overlap; SI Console composer reserved-height mismatch; DaySelector 7 fixed cells tight; sub-48dp targets hard to hit. |
| **390×844 (standard)** | Mostly OK layout-wise; a11y + light-mode + naming issues remain; info density on Nexus. |
| **428×926 (large phone)** | Wasted horizontal space (fixed-width cards/bubbles don't grow); flat hierarchy more apparent. |
| **Large text scale (1.3–2.0×)** | H3 widespread: clipped labels, `FittedBox` shrink fights scaling, overflow risk on any fixed-height Row/chip; B1 worsens. |
| **Landscape** | Not locked, no landscape-specific handling except Login/Onboarding; keyboard + `Positioned` bottom bars (onboarding/SI) most exposed; short viewport clips fixed-height sections. |
| **Notch / cutout / safe area** | `SafeArea` present in ~22 feature files (good coverage) but no `SystemUiOverlayStyle` (H8); verify Nexus header + bottom nav insets on cutout devices. |
| **Keyboard open** | Strong on Login, Smart Planner, and all bottom-sheet editors (`viewInsets` used). Weak on **Onboarding (B2)**, **SI Console (B5)**, and **Creator (no focus-scroll, M3)**. |

---

## 8. Theme Findings

- **Two competing palettes** — `theme/colors.dart` (`primaryNeon=0xFF00E5FF`) vs `ui/constants/app_colors.dart` (`AppColors.primary=0xFF6C8CFF`, `accent=0xFF9B8AFB`); two different "background" values (`0xFF050510` vs `0xFF0F172A`). Partial reconciliation left `shadows.dart:20,24,57` on the **old** violet, so violet glows no longer match violet fills.
- **Theme largely bypassed** — `AppColors.*` referenced 584×; `Colors.*` ~1,125× (non-transparent); `Color(0x…)` 245×; raw `TextStyle(` 425× in features vs **4** `Theme.of(context)` reads. `colorScheme`, `textTheme`, `cardTheme`, `inputDecorationTheme`, `snackBarTheme`, `dialogTheme` are all defined in `app_theme.dart` but rarely consumed.
- **Dark/light wiring** — `app_root.dart:137` swaps a single `theme:` slot (`appTheme`/`appLightTheme`) with no `darkTheme:`/`themeMode:`, so OS-driven `'system'` mode can't resolve in `MaterialApp`. `appLightTheme` exists but is defeated by hardcoded colors (**broken light mode, B3**).
- **Typography** — `neonTextTheme` hardcodes neon cyan/violet/magenta on headline/label; light theme only re-applies body/display colors, so headings stay neon in light mode. `w800` requested but not bundled (M8).
- **Component theme gaps** — banners reimplemented inline (M6); date picker forces `ThemeData.dark()` (`dynamic_form.dart:351`) ignoring app theme; `glass_panel.dart` ignores theme entirely and bakes an `AssetImage` per instance.
- **Positive** — modern `withValues` API used exclusively (`withOpacity` = 0 uses); `useMaterial3: true`; consistent single loading/offline/success/error components exist.

---

## 9. Widget / Component Findings

- **Buttons (4 systems):** `app_button` (1 file, hardcoded `EdgeInsets.all(16)`, dual `label`/`text` API), `neon_button` (2), `holo_button` (3, force-uppercases), `smart_pressable` (**20 files — de-facto standard**). No shared button contract.
- **Cards/panels (4 systems, 4 radii):** `app_card` (r14), `neon_card` (r24), `neon_panel` (r32), `glass_panel` (r20, raster image baked in). Cards look different screen-to-screen.
- **Duplicate patterns:** `dynamic_form._buildTextField` duplicates `InputField`; multiple bespoke header rows instead of `SectionHeader`; bespoke banner stack in `app_root`.
- **Report-separately (do NOT assume dead):** `input_field.dart`, `quick_input_bar.dart`, `ai_decision_card.dart`, `task_card.dart`, `logic/log_formatter.dart` appear unreferenced by their screens — flagged as **potentially unused UI, needs confirmation**, not deletion.
- **Premium-feel gaps:** flat visual hierarchy on Nexus (M5); heavy sci-fi telemetry copy; tiny low-contrast labels weaken the intended high-trust/premium feel; glow/`ShaderMask`/gradient overdraw on list-heavy screens (visual heaviness).

---

## 10. Accessibility Findings

- **Touch targets:** systemic <48dp (H1) — back buttons 34–36px, complete/priority/chip controls far smaller.
- **Semantics:** only 6 `Semantics` in 3 files; icon-only buttons unlabeled (H2); charts (`CustomPaint` XP line/ring, Insights bars, Progression) invisible to screen readers.
- **Text scale:** `0` `textScaler` handling; fixed 7–11px fonts + `FittedBox` (H3).
- **Contrast:** `white24/38/54` small text on dark/translucent surfaces (H7).
- **Forms:** Login email/password are **hint-only, no labels/`Semantics`** (`login_screen.dart:829-896`); Settings toggle labels not linked to their `Switch` (tap-label doesn't toggle); metadata/ID fields expose raw syntax.
- **Color-only status:** selection state on chips/toggles conveyed by color alone (emotion selector, category chips) with no semantic "selected".
- **Motion:** multiple always-on animations (ring pulse, starfield, glows); no reduced-motion accommodation.
- **Positive:** Permissions module uses proper `FilledButton`/`OutlinedButton`; rationale + denied-recovery flow is solid; `SelectableText` on legal/info URLs.

---

## 11. Visual State Coverage (per major feature)

| Feature | Loading | Empty | Error | Success | Notes |
|---|---|---|---|---|---|
| Nexus | ⚠ text-only | ✅ | ❌ (only "DEGRADED" label) | ✅ | async dropped via `.asData?.value` |
| Smart Planner | ✅ ("THINKING") | ❌ | ⚠ masked by default copy | ✅ | good timeout/crisis handling |
| Creator | ✅ | ⚠ | ✅ (retry copy) | ✅ | no focus-scroll |
| SI Console | ✅ (overlay) | ✅ greeting | ✅ (ErrorView+retry) | ✅ | no timeout on dispatch |
| Timeline | ❌ | ✅ | ❌ | ✅ | async coerced to empty |
| Trajectory Engine (Tasks) | ❌ | ⚠ | ❌ | ⚠ | placeholder-style screen |
| Progression | ⚠ | ⚠ (fabricates trend) | ⚠ | ✅ | advisor card handles `when` |
| Plan | ✅ | ✅ ("NO PLAN YET") | ✅ (Re-sync) | ✅ | strongest coverage |
| Milestones/Flowmap | ✅ | ✅ | ✅ | ✅ | `.when` used |
| Paywall | ✅ | ⚠ (empty plans silent) | ✅ (restore) | ✅ | no purchase-in-progress state |
| Login/Auth | ✅ | — | ✅ (mapped+timeout) | ✅ | best-in-app |
| Logs | ✅ | ✅ | ✅ | ✅ | good |
| Profile/Goals/Memories/Personal Alignment | ❌ | ✅ (some) | ❌ | ✅ | sync providers mask failures |

Legend: ✅ complete · ⚠ partial/weak · ❌ missing. **Offline** and **skeleton** states are essentially absent app-wide (only `OfflineBanner` exists as a global affordance).

---

## 12. Recommended Fix Order (safe, UI-only)

**Phase 1 — Release blockers (visual/layout only):** B1 (Timeline `Expanded`), B2 (onboarding keyboard inset), B4 (TimeSlot color), B5 (SI composer height). Small, isolated, low-risk.

**Phase 2 — High-priority visual consistency:** H1 touch targets, H2 semantics/tooltips on icon buttons, H4 add loading/error/skeleton to Tasks/Profile/Timeline/Nexus, H5 pick one button + one card component, H6 fix visible "SMART PLANNER" copy.

**Phase 3 — Theme/token cleanup (larger):** B3 route colors through `colorScheme`; wire `darkTheme`+`themeMode`; merge the two palettes and three spacing/radius systems; fix `shadows.dart` violet; resolve `w800` (M8).

**Phase 4 — Accessibility polish:** H3 text-scaler clamping + raise tiny fonts, H7 contrast, H8 `SystemUiOverlayStyle`, form labels, semantic selection state, chart semantics.

**Phase 5 — Optional premium polish:** Nexus density/hierarchy, standardize headers/banners, tablet `NavigationRail`, reduce overdraw/always-on motion.

---

## 13. Follow-up Test Plan (visual validation, later)

**Emulator/device sizes:** launch on 320×568, 360×640, 390×844, 428×926; each in portrait + landscape; each at text scale 1.0 / 1.5 / 2.0; one cutout device; verify no overflow stripes, no clipped labels, no keyboard-blocked inputs.

**Manual walkthrough:** onboarding → login → Nexus → Smart Planner (open keyboard, type) → Creator (submit) → SI Console (long input) → Timeline (long-title task) → Plan → Progression → Settings → Paywall; toggle Light theme and re-walk to confirm readability; enable TalkBack and traverse Nexus + Login.

**Widget tests:** golden/overflow tests for Timeline tile (long title), Onboarding personalization slide with keyboard inset, Plan `TimeSlot` color, SI Console composer at max height; touch-target size assertions on shared buttons.

**Golden tests:** capture Nexus, Smart Planner, Plan, Paywall in dark + light at 360/390/428 (will immediately expose broken light mode).

**Maestro flows (later):** onboarding completion with keyboard, create-task flow, subscribe/restore flow, theme-switch flow — assert no visual regressions.

---

## 14. Do-Not-Touch List (confirmed avoided)

This audit did **not** read-for-modification or alter any of:
- ✅ Auth logic
- ✅ Supabase
- ✅ Firebase
- ✅ Database
- ✅ RLS
- ✅ Monetization/purchase logic
- ✅ SI / domain logic
- ✅ Smart Planner business logic
- ✅ Migrations
- ✅ Edge Functions
- ✅ Environment setup

No files were created except this report. No code, routes, providers, repositories, use cases, entities, or services were modified. Items requiring non-UI logic changes (e.g., converting sync providers to `AsyncValue`, gating dev UI, purchase-in-progress state) are noted as **outside scope** and left for a separate pass.
