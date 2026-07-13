# ChronoSpark UX Polish Checklist

> Run this checklist before each tester drop.  
> Fix all items in the **Must Fix** tier before distributing to new testers.  
> Assign items in the **Should Fix** and **Nice to Have** tiers to the v1.2 cycle.

Status: ✅ Done · ❌ Not done · ⏳ In progress · N/A Not applicable

---

## Empty States

| Screen | Status | Notes |
|--------|--------|-------|
| Tasks — no tasks created yet | ❌ | Show illustrated placeholder + "Add your first task" CTA |
| Goals — no goals created yet | ❌ | Show illustrated placeholder + "Set a goal" CTA |
| Habits — no habits tracked yet | ❌ | Show illustrated placeholder |
| Logs — no entries yet | ❌ | Show illustrated placeholder |
| Smart Coach — first time, no history | ❌ | Show example queries to guide first use |
| SI Console — no data context yet | ❌ | Explain what SI needs to give useful answers |

---

## Loading States

| Interaction | Status | Notes |
|-------------|--------|-------|
| Initial data fetch on home/dashboard | ❌ | Add shimmer skeleton |
| Smart Coach response in flight | ⏳ | Typing indicator exists — verify it always shows |
| SI Console query in flight | ❌ | Add spinner or progress indicator |
| Paywall restore purchases in flight | ❌ | **Must Fix** — currently no loading feedback |
| Cloud sync in progress | ⏳ | Offline banner exists — verify sync indicator shows |
| Task list refresh | ❌ | Add pull-to-refresh loading indicator |

---

## Error Messages

| Scenario | Status | Notes |
|----------|--------|-------|
| Login failed — wrong password | ⏳ | Verify copy is user-friendly, not a raw code |
| Login failed — network error | ❌ | Distinguish from auth error; add "Try again" action |
| Task save failed | ❌ | Snackbar with retry action |
| Coach response error | ⏳ | Fallback response exists — verify copy is helpful |
| Sync failed | ❌ | Show banner with actionable message |
| Invalid deep link | ❌ | **Must Fix** — currently silently ignored; add snackbar |
| Purchase failed | ❌ | Show descriptive error + contact link |
| Restore failed — no purchases found | ❌ | Show "No active subscription found" message |

---

## Permission Prompts

| Permission | Status | Notes |
|-----------|--------|-------|
| Notification permission — rationale shown before request | ❌ | Add "ChronoSpark needs this to remind you of focus sessions" |
| Notification permission — denied state visible in Settings | ❌ | **Must Fix** — show status + link to system settings |
| Microphone (if shipped) — rationale shown | N/A | Not shipped in v1.0 |

---

## Onboarding / First-Run Tutorial

| Item | Status | Notes |
|------|--------|-------|
| Onboarding → home transition is smooth | ❌ | Replace abrupt push with a fade/slide transition |
| Tutorial steps are skippable | ✅ | |
| Tutorial tracks `tutorial_started` event | ❌ | Wire analytics per ANALYTICS_TAXONOMY.md |
| Tutorial tracks `tutorial_completed` event | ❌ | Wire analytics per ANALYTICS_TAXONOMY.md |
| Tutorial tracks `tutorial_skipped` event | ❌ | Wire analytics per ANALYTICS_TAXONOMY.md |
| Contextual hint shown for Smart Coach on first open | ❌ | Add "Ask me anything about your goals" prompt |
| Contextual hint shown for SI Console on first open | ❌ | Add "I'll analyse your tasks and timeline" prompt |

---

## Account Creation Flow

| Item | Status | Notes |
|------|--------|-------|
| Sign-up form validates email format inline | ⏳ | Verify inline validation fires on blur |
| Sign-up form validates password strength inline | ❌ | Add strength indicator |
| Post-creation route goes to onboarding, not home | ⏳ | Verify routing logic |
| Confirmation email copy is friendly and on-brand | ❌ | Review Supabase email template |
| Sign-up error messages are clear | ❌ | Audit all error code → message mappings |

---

## Transitions and Animation

| Item | Status | Notes |
|------|--------|-------|
| Screen transitions are consistent (≤300 ms) | ❌ | Audit all route transitions |
| Focus session complete animation plays correctly | ✅ | `session_complete.json` present |
| Level-up animation plays correctly | ✅ | `level_up.json` present |
| Paywall dismiss animation is smooth | ❌ | Test on low-end device |

---

## Spacing, Alignment, and Typography

| Item | Status | Notes |
|------|--------|-------|
| Consistent horizontal padding on all screens (16/24 dp) | ❌ | Spot-check at least 5 screens |
| List items are vertically aligned | ❌ | Check task list and coach history |
| Text does not overflow on small screens (360 dp wide) | ❌ | Test on Pixel 3a or equivalent emulator |
| Text does not overflow with large accessibility fonts | ❌ | Enable 2× text scale and spot-check |
| Icon sizes are consistent (24 dp nav icons, 20 dp inline) | ❌ | Audit bottom nav bar |

---

## Color and Label Consistency

| Item | Status | Notes |
|------|--------|-------|
| Primary action buttons use consistent colour token | ❌ | Audit across all screens |
| Destructive actions use red/error colour consistently | ❌ | Verify delete/logout buttons |
| Labels for identical actions are identical strings | ❌ | E.g., "Complete" vs "Mark complete" — pick one |
| Dark-mode contrast meets WCAG AA (4.5:1 for text) | ❌ | Use Flutter accessibility tools to check |

---

## Accessibility

| Item | Status | Notes |
|------|--------|-------|
| All icon-only buttons have `semanticsLabel` | ❌ | **Must Fix** — screen readers need these |
| Focus order is logical in all forms | ❌ | Tab through login and task creation forms |
| Images have `excludeFromSemantics: true` or a label | ❌ | Audit background images |
| Minimum tap target is 44 × 44 dp | ❌ | Check small icon buttons |

---

## Priority Summary

**Must Fix before next tester drop:**
1. Paywall restore: add loading state
2. Invalid deep link: add snackbar feedback
3. Notification permission denied state: show in Settings
4. Icon-only buttons: add `semanticsLabel`

**Should Fix for v1.2:**
- All empty states
- All loading shimmer skeletons
- Onboarding → home transition fade
- Tutorial analytics events
- Error message copy audit
- Typography overflow at small/large sizes
