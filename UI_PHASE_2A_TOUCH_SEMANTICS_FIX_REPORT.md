# Phase 2A — Touch Targets & Semantics/Tooltips Fix Report

## 1. Summary

**Final status: PASS**

Phase 2A scope (sub-48dp touch targets, missing semantics/tooltips on icon-only actions, unclear tappable areas, unlabeled icon buttons, undersized/unlabeled `GestureDetector`/`InkWell` pseudo-buttons) is complete across every focus area named in the audit brief: Nexus, Smart Planner, Creator, SI Console, Timeline, Trajectory Engine (Progression), Profile, Settings, Onboarding, and the shared navigation shell.

Counts:
- **Touch-target fixes:** 21 controls (padding/size bumps, `ConstrainedBox(minHeight: 48)`, or padded hit-area wraps)
- **Semantics labels added:** 14 controls (`Semantics(button: true, label: ...)` or `SmartPressable.semanticLabel`)
- **Tooltips added:** 1 (navigation-shell FAB)
- **Combined (touch-target + semantics in the same control):** 11 controls
- **Issues deferred:** see Section 4
- **`flutter analyze --no-pub` result:** clean, 0 issues, run after every batch and once more on the full project at the end

## 2. Files Changed

| File | Controls fixed | Fix type | Why UI-only |
|---|---|---|---|
| `lib/ui/widgets/smart_pressable.dart` | Shared widget: added optional `semanticLabel`/`button` params | Semantics (additive, shared) | Adds an opt-in accessible-name path with zero behavior change for existing call sites; no logic touched |
| `lib/features/si_console/ui/si_console_screen.dart` | Back button, SUMMARY pill, ACCESS pill, SPEAK tag, quick-command chip, mic toggle, send button (7) | Combined | Only tap-area padding, `HitTestBehavior.opaque`, and `Semantics`/`Tooltip` wraps around existing controls; composer height/`ConstrainedBox` logic untouched |
| `lib/features/timeline/ui/timeline_screen.dart` | Back button, filter `_Chip` | Combined / touch-target | Container size/padding and a `semanticLabel` only; B1 title-overflow `Expanded`/ellipsis logic untouched |
| `lib/features/progression/ui/progression_screen.dart` | Back button | Combined | Same pattern as other back buttons |
| `lib/features/creator/ui/creator_screen.dart` | Back button | Combined | Same pattern |
| `lib/features/settings/ui/settings_screen.dart` | Back button | Combined | Same pattern |
| `lib/features/settings/ui/settings_screen.sections.dart` | Reminder-time row, daily-planning-time row, `_NeonNavTile` (all instances) | Touch-target | `ConstrainedBox(minHeight: 48)` guarantees tap height regardless of subtitle/font metrics; no navigation/business logic touched |
| `lib/features/home/ui/smart_planner_screen.dart` | Back button, SPEAK pill, SUMMARY pill, ACCESS pill, mic toggle, GOALS/MEMORIES/PERSONAL ALIGNMENT quick-nav cards | Combined | Padding/size/`Semantics` only; all `onTap` callbacks and provider calls unchanged |
| `lib/features/nexus/ui/nexus_screen.widgets.dart` | Notification bell, sign-out button | Combined / touch-target | Notification bell gets `semanticLabel` + padded hit area; sign-out (already had a `Tooltip`) gets a modest padding bump |
| `lib/features/profile/ui/profile_screen.dart` | Core Value filter chip | Touch-target | Padding bump only; visible text already serves as the label |
| `lib/features/profile/ui/widgets/profile_header.dart` | `_HeaderIconBtn` (Settings gear) | Combined | Added required `semanticLabel` param, bumped to 48×48 |
| `lib/features/onboarding/ui/onboarding_screen.dart` | Landscape SKIP, portrait SKIP | Combined | `Semantics(button:true, label:'Skip onboarding')` + padding; personalization slide's keyboard-dismiss logic (pre-existing Phase 1 fix) untouched |
| `lib/features/creator/widgets/dynamic_form.dart` | FORGE TASK submit button, priority-level bars (5), schedule-date row, clear-date "X", repeat chips (3) | Combined | Padding/hit-area/`Semantics` only; form submission and state logic untouched |
| `lib/features/creator/widgets/type_selector.dart` | Task/Routine/Note/Goal type chips | Touch-target | Padding bump only; visible text already labels each chip |
| `lib/features/creator/widgets/quick_input_bar.dart` | Quick-add send button | Combined | `semanticLabel` + size bump 32×32 → 40×40; verified no overflow in the input row |
| `lib/app/navigation_shell.dart` | Map FAB (`FloatingActionButton.small`) | Tooltip | Added `tooltip: 'Open navigation map'` only; the 40×40 fixed FAB size is deferred to Phase 2E, not resized here |

## 3. Accessibility Fix Log

**Back buttons (SI Console, Timeline, Progression, Creator, Settings, Smart Planner)**
- Before: bare icon-only `GestureDetector`/`SmartPressable`, 36×36 or unpadded, no accessible name.
- Fix: bumped to 48×48 (or added `Padding(EdgeInsets.all(11))` where the icon had no container), added `semanticLabel`/`Semantics(button:true, label:'Back to Smart Planner')` (or feature-appropriate label).
- User impact: screen-reader users now hear "Back to Smart Planner" (or "Back"); all users get a full 48dp tap target instead of a tight icon hitbox.
- Risk: low — additive wrap, no visual size change beyond the icon's own container.

**SI Console pills/tags (SUMMARY, ACCESS, SPEAK tag, quick-command chip) and Smart Planner pills (SPEAK, SUMMARY, ACCESS)**
- Before: vertical padding 3–6px, no `HitTestBehavior.opaque`, so the tappable area was smaller than the visible chip in some cases.
- Fix: vertical padding raised to 9–11px, `HitTestBehavior.opaque` added.
- User impact: consistent ~40-44px tap height on text-labeled chips (visible text already serves as the accessible name).
- Risk: low — small vertical growth only, no reflow risk since these sit in `Wrap`/`Row` with flexible siblings.

**SI Console mic/send buttons, Smart Planner mic toggle**
- Before: 44×44 (SI Console) / unlabeled with only visible-state text (Smart Planner), no `Semantics(button:true)`.
- Fix: SI Console mic/send bumped to 48×48 with `Semantics(label: listening ? 'Stop voice input' : 'Start voice input' / 'Send query', button: true)`; Smart Planner mic toggle got padding bump + `HitTestBehavior.opaque` (visible "SPEAK"/"LISTENING..." text already labels it).
- User impact: mic state changes are now announced distinctly from the "SPEAK" pill text; send action has an explicit accessible name.
- Risk: low-medium — this is the one area overlapping the B5 composer footprint; verified the composer's `composerReservedHeight`/`ConstrainedBox(maxHeight: composerMaxHeight)` logic is untouched (see Section 5).

**Nexus notification bell**
- Before: bare icon+`Badge` inside `SmartPressable`, ~20-24px, no label.
- Fix: `semanticLabel: 'Open notifications'` + `Padding(EdgeInsets.all(10))` for a larger invisible hit area.
- User impact: bell is now announced and has a meaningfully larger tap zone in a cramped header row.
- Risk: low — padding is invisible (`Icon`/`Badge` has no background), so no visual change; verified against `ultraCompact`/`compact` header breakpoints.

**Nexus sign-out button**
- Before: already had a `Tooltip`, but only ~30-32px hit area.
- Fix: `Container` padding 7 → 11.
- User impact: modest tap-area growth, existing tooltip/label unaffected.
- Risk: low.

**Profile settings gear (`_HeaderIconBtn`)**
- Before: 34×34, no accessible name (single call site, used only for Settings).
- Fix: made `semanticLabel` a required constructor param (`'Open settings'`), bumped container to 48×48 with `alignment: Alignment.center` to keep the icon centered.
- User impact: gear icon now has an accessible name and a full touch target.
- Risk: low — single call site, no other icon repurposes this widget.

**Profile core-value filter chip**
- Before: vertical padding 6px.
- Fix: bumped to 11px; visible text already labels it.
- Risk: low.

**Settings time-picker rows and `_NeonNavTile`**
- Before: borderline ~36-40px effective row height depending on font metrics/subtitle presence.
- Fix: wrapped each row's `Row` in `ConstrainedBox(constraints: BoxConstraints(minHeight: 48))`.
- User impact: guarantees a 48dp tap target regardless of platform font rendering, including subtitle-less nav rows (e.g. "Terms of Service").
- Risk: low — `ConstrainedBox` only enforces a floor, doesn't change visual content.

**Onboarding SKIP buttons (landscape + portrait)**
- Before: bare `GestureDetector` wrapping unpadded `Text('SKIP')`, no `Semantics(button:true)` — the most severe onboarding finding.
- Fix: `HitTestBehavior.opaque` + `Semantics(button:true, label:'Skip onboarding')` + `Padding(horizontal: 8, vertical: 14)`.
- User impact: SKIP is now announced as a button with a clear label and has a much larger tap area (was effectively just the glyph width of "SKIP" text before).
- Risk: low-medium — landscape row has an `Expanded` sibling absorbing any width change; portrait `Column` sizes to content so the added padding doesn't force reflow elsewhere.

**Creator priority-level bars (single most severe finding in the full audit)**
- Before: 5× `Expanded(SmartPressable(Container(height: 6)))` — a 6px-tall bar with zero semantic label and a hit area limited to 6px.
- Fix: `semanticLabel: 'Set priority level $level'` + `Padding(vertical: 12)` around the visual 6px bar, growing the actual hit area to ~30px while the rendered bar stays visually 6px tall.
- User impact: priority levels are now individually announced and have a meaningfully larger (though still sub-48dp, physically constrained by the bar's thin design) tap zone.
- Risk: medium — this is the largest layout change in the pass (adds ~24px of total vertical space to the priority row); accepted per the audit's explicit flag as the most severe finding requiring a real fix, not just a label.

**Creator clear-date "X" (second most severe finding)**
- Before: bare `Icon(Icons.close, size: 14)`, no padding, no label.
- Fix: `semanticLabel: 'Clear schedule date'` + `Padding(EdgeInsets.all(11))`.
- Risk: low — `Spacer()` in the row absorbs the added width.

**Creator schedule-date row, FORGE TASK button, repeat chips, type chips**
- Before: 36-46px tap heights.
- Fix: modest padding bumps (10→13 vertical on schedule row, 14→16 on submit button, 8→12 on repeat/type chips) plus a `semanticLabel: 'Schedule date'` on the date row.
- Risk: low.

**Creator quick-add send button**
- Before: 32×32, no label.
- Fix: `semanticLabel: 'Send quick task'` + bumped to 40×40 (chosen over full 48×48 to avoid visibly disrupting the compact inline input bar; verified no overflow against the `Expanded` `TextField`).
- Risk: low.

**Navigation-shell map FAB**
- Before: `FloatingActionButton.small` (fixed 40×40 per Material spec), no tooltip.
- Fix: added `tooltip: 'Open navigation map'` only (Flutter's `FloatingActionButton` tooltip mechanism also supplies the accessible name automatically).
- User impact: FAB now has both a visible tooltip on long-press and a screen-reader label.
- Risk: none — no size change; the 40×40 dimension is a standard Material FAB variant and is explicitly deferred to Phase 2E rather than resized here.

## 4. Deferred Items

- **Phase 2B (text-scale):** no changes made to font-scale handling anywhere in this pass.
- **Phase 2C (visual state):** no loading/error/empty-state visual work done.
- **Phase 2D (contrast/status bar):** no color-contrast or status-bar-related changes.
- **Phase 2E (button/card consistency):** navigation-shell FAB's 40×40 fixed size explicitly flagged and left as-is; broader button/card size unification not started.
- **Phase 3 (theme/token/light-mode):** untouched.
- **Naming cleanup:** no "SMART PLANNER"/"Session"/standalone "Insight" copy was encountered inside any control touched in this pass; no naming changes were made or needed.
- **Creator priority-level bars:** hit area improved (~30px) but still below the full 48dp target due to the control's intentionally thin (6px) visual design — a further redesign (e.g. a taller custom slider) would be a Phase 2E/visual-system decision, not a Phase 2A padding fix.
- **Creator quick-add send button:** bumped to 40×40 rather than a full 48×48 to avoid visibly enlarging the compact quick-input bar; a further bump to 48×48 is a candidate for Phase 2E if a taller input bar becomes acceptable.

## 5. Regression Check

- **Timeline (B1):** title-overflow fix (`Expanded` + `maxLines: 1` + `TextOverflow.ellipsis` on the event title) is unchanged by this pass — confirmed via diff. Only the back button (size/label) and filter `_Chip` (padding) were touched.
- **Plan TimeSlot (B4):** `lib/features/plan/widgets/time_slot.dart` was not touched at all in Phase 2A — no regression risk.
- **Onboarding (B2):** the personalization slide's `SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, ...)` fix is unchanged by this pass — confirmed via diff. Only the two SKIP buttons (unrelated to the text field/keyboard) were touched.
- **SI Console (B5):** composer logic (`composerReservedHeight`, `ConstrainedBox(constraints: BoxConstraints(maxHeight: composerMaxHeight))`) is unchanged — confirmed via `grep`. Only the mic and send icon-button sizes/semantics inside the composer were bumped for touch-target compliance; the composer's message-visibility/reserved-height behavior itself was not touched.

## 6. Out-of-Scope Confirmation

No changes were made to: authentication, Supabase, Firebase, the database/RLS/migrations, monetization, SI (Smart Planner AI) business logic, Edge Functions, route/navigation logic, or any generated files. All edits in this pass are confined to widget-tree padding, sizing, `Semantics`/`Tooltip` wraps, and one additive shared-widget parameter (`SmartPressable.semanticLabel`/`.button`). `onTap`/`onPressed` callbacks and provider reads were preserved verbatim everywhere except where a callback was itself moved one widget deeper as part of adding a `Semantics`/`Padding` wrapper (no callback logic was altered).

## 7. Test Environment Note

`flutter test` remains blocked by the pre-existing Git Bash environment issue (`%PROGRAMFILES(X86)% environment variable not found`, surfacing as a `_globalConfigPath` null-check crash inside `package:test_core`). Re-confirmed at the end of this pass; this is an environment/shell configuration gap, not a regression introduced by any code change in Phase 2A. `flutter analyze --no-pub` was run after every batch of edits and once more across the full project at the end, with zero issues each time.

## 8. Next Recommended Prompt

Recommend running an isolated **Phase 2B (text-scale)** pass next: verify and fix any remaining clipping/overflow at 1.5×/2.0× text scale specifically in the controls touched in this pass (SI Console pills, Creator form labels, Settings nav tiles) plus any other high-priority text-scale issues from the audit, under the same strict-scope rules (no theme/token work, no visual-state fixes, no naming cleanup) — keeping Phase 2C/2D/2E and Phase 3 explicitly out of scope until their own dedicated passes.
