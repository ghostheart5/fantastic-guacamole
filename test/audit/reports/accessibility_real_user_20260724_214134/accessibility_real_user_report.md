# Accessibility + Real-User Usability Automated Audit

- Timestamp: 2026-07-24 21:41:38
- Project root: C:\Users\keegan radetski\fantastic-guacamole
- Passed: 9
- Failed: 1

| Check | Status | Details | Evidence |
|---|---|---|---|
| Accessibility surface present | PASS | Core user-facing surfaces found. | lib\ui\widgets\holo_button.dart, lib\ui\widgets\offline_banner.dart, lib\ui\widgets\typing_text.dart, lib\ui\layout\animated_system_background.dart, lib\theme\widgets\neon_input.dart, lib\features\auth\screens\auth_gate.dart, lib\features\settings\ui\settings_screen.dart, lib\features\settings\ui\settings_screen.sections.dart, lib\features\home\ui\smart_coach_screen.dart, lib\features\nexus\ui\nexus_screen.dart, lib\features\goals\ui\goals_screen.dart, lib\features\paywall\ui\paywall_page.dart, lib\tutorial\tutorial_content.dart |
| Screen reader labels and form labels | PASS | Labels/semantics/validators signals detected. | Hits: 49 |
| Tap target sizing signals | PASS | Thumb-friendly control sizing signals detected. | Hits: 7 |
| Reduced motion respected or planned | PASS | Reduced-motion/lifecycle controls detected. | Hits: 6 |
| Offline/error states understandable | PASS | Offline and retry copy signals found. | Hits: 7 |
| Forms have clear labels and validation messages | PASS | Form labels and validation signals found. | Hits: 5 |
| Error messages say what happened and next step | PASS | Helpful recovery/error language detected. | Hits: 7 |
| First-time user can complete first task | PASS | Onboarding/tutorial/empty-state guidance detected. | Hits: 8 |
| No internal module names in user-facing copy | FAIL | Potential internal module names found in string literals. | C:\Users\keegan radetski\fantastic-guacamole\lib\app\app_root.dart:365; C:\Users\keegan radetski\fantastic-guacamole\lib\app\navigation_shell.dart:66; C:\Users\keegan radetski\fantastic-guacamole\lib\app\router\app_router.dart:381; C:\Users\keegan radetski\fantastic-guacamole\lib\app\router\app_router.dart:383; C:\Users\keegan radetski\fantastic-guacamole\lib\app\router\info_pages.dart:33 |
| Contrast signals for body/secondary text | PASS | Theme and UI contrast signals detected. | Hits: 9 |

Overall result: FAIL
