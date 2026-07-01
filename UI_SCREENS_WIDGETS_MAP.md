# ChronoSpark Flutter App - UI Screens & Widgets Map

**Generated**: 2026-06-22 | **Purpose**: Complete UI accessibility audit preparation

---

## 📋 Table of Contents
1. [App Architecture Overview](#architecture)
2. [Feature Modules](#features)
3. [Screen Files](#screens)
4. [Custom Widgets](#widgets)
5. [Interactive Components](#interactive)
6. [Theme Configuration](#theme)
7. [Accessibility Audit](#accessibility)

---

## <a id="architecture"></a>🏗️ App Architecture Overview

### Main Entry Point
- **[lib/features/system_shell/main_shell.dart](lib/features/system_shell/main_shell.dart)** 
  - Root shell managing 6 main tabs with premium trial gates
  - Interactive elements: Tab navigation, premium feature blocking

### Tab Structure (via ShellTab model)
```
Home → ChronoCreator → ChronoLogs → Temporal Ops → SI Console → Settings
```

---

## <a id="features"></a>📦 Feature Modules Structure

### 1. **AUTH Module** (`lib/features/auth/`)
| File | Type | Purpose | Interactive Elements |
|------|------|---------|----------------------|
| [screens/login_screen.dart](lib/features/auth/screens/login_screen.dart) | Screen | Authentication UI | TextFields (email/password), FormState validation, Submit button, Error SnackBar |
| [widgets/auth_gate.dart](lib/features/auth/widgets/auth_gate.dart) | Widget | Auth wrapper | Conditional rendering |
| [auth_session_controller.dart](lib/features/auth/auth_session_controller.dart) | Controller | Auth state mgmt | - |

**Accessibility Needs:**
- ✗ Email/password fields missing labels
- ✗ Submit button needs more descriptive semantics
- ✗ Error messages should be announced to screen readers
- ✗ Form validation errors need semantic association

---

### 2. **HOME Module** (`lib/features/home/`)
| File | Type | Purpose | Interactive Elements |
|------|------|---------|----------------------|
| [screens/home_screen.dart](lib/features/home/screens/home_screen.dart) | Screen | Main dashboard | InkWell gadget icons, AnimationController, Spark tiles |
| [screens/gadget_screen.dart](lib/features/home/screens/gadget_screen.dart) | Screen | Gadget panel | Icon grid, navigation |

**Key Interactive Components:**
- `_gadgetIcon()`: InkWell with custom borderRadius - **needs tooltip + semantic label**
- `_sparkTile()`: Display-only tiles with time/title - **read-only, but needs aria-labels**

**Accessibility Needs:**
- ✗ Gadget icons missing tooltips (onTap callbacks without labels)
- ✗ Animation controller effects not accessible to motion-sensitive users
- ✗ No keyboard focus indicators visible

---

### 3. **CHRONOCREATOR Module** (`lib/features/chronocreator/`)
| File | Type | Purpose | Interactive Elements |
|------|------|---------|----------------------|
| [screens/creator_home.dart](lib/features/chronocreator/screens/creator_home.dart) | Screen | Task/Goal/Routine creation | TextEditingController, Multiple FilledButtons, List operations |
| [widgets/task_input.dart](lib/features/chronocreator/widgets/task_input.dart) | Widget | Form input pattern | TextField + FilledButton combo, onSubmitted callback |
| [widgets/mission_tile.dart](lib/features/chronocreator/widgets/mission_tile.dart) | Widget | Task/mission display | ExpansionTile, CheckboxListTile, IconButton (delete) |
| [controllers/creator_controller.dart](lib/features/chronocreator/controllers/creator_controller.dart) | Controller | State management | - |

**Key Interactive Components:**
- `_createAction()`: InkWell with icon + label - **partial label, needs improvement**
- `TaskInput`: Text field auto-submits on Enter - **good pattern, but needs aria-label**
- `MissionTile`: ExpansionTile with nested CheckboxListTile - **complex hierarchy needs testing**
- `IconButton` (delete): Has tooltip 'Delete task' - **✓ Good practice**

**Accessibility Needs:**
- ✗ Task input field needs descriptive label
- ✗ Create action buttons need semantic descriptions (accessible labels)
- ✗ Mission expansion state changes should announce to screen readers
- ✗ Checkbox state changes need verbal confirmation
- ⚠ Delete button icon-only - needs tooltip enforcement

---

### 4. **CHRONOLOGS Module** (`lib/features/chronologs/`)
| File | Type | Purpose | Interactive Elements |
|------|------|---------|----------------------|
| [screens/chronologs_home.dart](lib/features/chronologs/screens/chronologs_home.dart) | Screen | Activity logs viewer | List, navigation |
| [controllers/chronologs_controller.dart](lib/features/chronologs/controllers/chronologs_controller.dart) | Controller | State management | - |

**Accessibility Needs:**
- TBD after code review

---

### 5. **SI_CONSOLE Module** (`lib/features/si_console/`)
| File | Type | Purpose | Interactive Elements |
|------|------|---------|----------------------|
| [screens/si_console_home.dart](lib/features/si_console/screens/si_console_home.dart) | Screen | AI reflection/insight panel | TextField, FilledButton, Reflection list |
| [widgets/thoughts_panel.dart](lib/features/si_console/widgets/thoughts_panel.dart) | Widget | Thoughts display | List rendering |
| [widgets/insights_panel.dart](lib/features/si_console/widgets/insights_panel.dart) | Widget | Insights display | List rendering |
| [widgets/emotions_panel.dart](lib/features/si_console/widgets/emotions_panel.dart) | Widget | Emotions tracking | Display (unknown controls) |
| [widgets/diagnostics_panel.dart](lib/features/si_console/widgets/diagnostics_panel.dart) | Widget | Diagnostic data | Display (unknown controls) |
| [controllers/si_console_controller.dart](lib/features/si_console/controllers/si_console_controller.dart) | Controller | State management | - |

**Key Interactive Components:**
- Reflection console: TextField + FilledButton - **needs label association**
- Reflection list: Text items - **read-only, needs semantic structure**

**Accessibility Needs:**
- ✗ Reflection input field needs semantic label
- ✗ Save button needs descriptive text
- ✗ Panel titles should be proper heading elements
- ✗ Need to verify emotions_panel & diagnostics_panel controls

---

### 6. **TEMPORAL_OPS Module** (`lib/features/temporal_ops/`)
| File | Type | Purpose | Interactive Elements |
|------|------|---------|----------------------|
| [screens/temporal_ops_home.dart](lib/features/temporal_ops/screens/temporal_ops_home.dart) | Screen | Weekly/day calendar planner | ChoiceChip (day selection), Timeline visualization |
| [widgets/chronoflow_day.dart](lib/features/temporal_ops/widgets/chronoflow_day.dart) | Widget | Day flow visualization | Bars display (read-only rendering) |
| [widgets/arcview_week.dart](lib/features/temporal_ops/widgets/arcview_week.dart) | Widget | Week view | Display only |
| [widgets/constellation_month.dart](lib/features/temporal_ops/widgets/constellation_month.dart) | Widget | Month visualization | Display only |
| [controllers/temporal_ops_controller.dart](lib/features/temporal_ops/controllers/temporal_ops_controller.dart) | Controller | State management | - |

**Key Interactive Components:**
- `_dayChip()`: ChoiceChip - **needs proper semantics for selected state**
- `_timelineRow()`: Display items - **structure needs verification**
- Day/Week/Month visualizations: Data visualization - **needs alt text/descriptions**

**Accessibility Needs:**
- ✗ ChoiceChip selected state needs screen reader announcement
- ✗ Data visualizations need accessible descriptions
- ✗ Timeline interactions (if any) need keyboard support
- ⚠ Color-coded items in visualizations need text fallback

---

### 7. **SETTINGS Module** (`lib/features/settings/`)
| File | Type | Purpose | Interactive Elements |
|------|------|---------|----------------------|
| [screens/settings_home.dart](lib/features/settings/screens/settings_home.dart) | Screen | Settings panel | Toggle switches, URL launcher buttons, Text fields |
| [widgets/subscription_billing_widget.dart](lib/features/settings/widgets/subscription_billing_widget.dart) | Widget | Billing/premium UI | SegmentedButton (monthly/yearly toggle), Multiple buttons |
| [widgets/account_deletion_widget.dart](lib/features/settings/widgets/account_deletion_widget.dart) | Widget | Destructive action | Confirmation dialog (need to verify) |
| [widgets/module_toggle_tile.dart](lib/features/settings/widgets/module_toggle_tile.dart) | Widget | Feature toggles | SwitchListTile |
| [widgets/theme_settings_tile.dart](lib/features/settings/widgets/theme_settings_tile.dart) | Widget | Theme selection | Toggle/switch |
| [controllers/settings_controller.dart](lib/features/settings/controllers/settings_controller.dart) | Controller | State management | - |

**Key Interactive Components:**
- `ModuleToggleTile`: SwitchListTile - **✓ Has title + subtitle, good semantics**
- `SegmentedButton<BillingCycle>`: Monthly/Yearly toggle - **needs semantic labels**
- URL launchers: Links to legal docs - **needs error handling UI**
- Text scale controls: Unknown input type - **needs review**

**Accessibility Needs:**
- ✗ SegmentedButton: segments should have clear semantic meaning
- ✗ Text scale input needs label and validation feedback
- ✗ Destructive actions (account deletion) need confirmation modal testing
- ⚠ SwitchListTile: Verify state changes announce properly

---

### 8. **SYSTEM_SHELL Module** (`lib/features/system_shell/`)
| File | Type | Purpose | Interactive Elements |
|------|------|---------|----------------------|
| [main_shell.dart](lib/features/system_shell/main_shell.dart) | Screen | Root tab controller | Bottom nav tap, premium trial gates |
| [pages/nexus_page.dart](lib/features/system_shell/pages/nexus_page.dart) | Page | Home content wrapper | - |
| [pages/chronocreator_page.dart](lib/features/system_shell/pages/chronocreator_page.dart) | Page | Creator content wrapper | - |
| [pages/chronologs_page.dart](lib/features/system_shell/pages/chronologs_page.dart) | Page | Logs content wrapper | - |
| [pages/temporal_ops_page.dart](lib/features/system_shell/pages/temporal_ops_page.dart) | Page | Temporal Ops content wrapper | - |
| [pages/si_console_page.dart](lib/features/system_shell/pages/si_console_page.dart) | Page | SI Console content wrapper | - |
| [pages/settings_page.dart](lib/features/system_shell/pages/settings_page.dart) | Page | Settings content wrapper | - |
| [models/shell_tab.dart](lib/features/system_shell/models/shell_tab.dart) | Model | Tab definition | - |

**Accessibility Needs:**
- ✗ Tab switching logic needs keyboard support verification
- ✗ Premium trial gate messages need semantic structure
- ✗ SnackBar messages should not be the only notification

---

## <a id="widgets"></a>🎨 Shared UI Widgets & Components

### Layout Components (`lib/ui/layout/`)
| File | Type | Interactive Elements | Status |
|------|------|----------------------|--------|
| [app_scaffold.dart](lib/ui/layout/app_scaffold.dart) | Layout | Scaffold wrapper | - |
| [holo_background.dart](lib/ui/layout/holo_background.dart) | Background | Image display | Decorative |

### System Components (`lib/ui/system/`)
| File | Type | Interactive Elements | Accessibility Needs |
|------|------|----------------------|----------------------|
| [system_header.dart](lib/ui/system/system_header.dart) | Header | Icon display, notification badge | ⚠ Alert count badge needs announcement |
| [system_bottom_nav.dart](lib/ui/system/system_bottom_nav.dart) | Nav | InkWell items, icon + label + badge | ✓ Labels present, verify focus indicators |
| [premium_feature_gate.dart](lib/ui/system/premium_feature_gate.dart) | Gate | FilledButton.icon (Upgrade) | ✗ Button text clear, needs focus management |
| [pulse_bar.dart](lib/ui/system/pulse_bar.dart) | Progress | Animation indicator | ✗ Animated effect, needs motion sensitivity check |
| [spark_card.dart](lib/ui/system/spark_card.dart) | Card | Display (TBD) | - |
| [glass_panel.dart](lib/ui/system/glass_panel.dart) | Container | Visual wrapper | - |
| [animated_system_background.dart](lib/ui/system/animated_system_background.dart) | Background | Animation | ✗ Motion sensitivity needed |

### Reusable Widgets (`lib/ui/widgets/`)
| File | Type | Interactive Elements | Accessibility Needs |
|------|------|----------------------|----------------------|
| [holo_button.dart](lib/ui/widgets/holo_button.dart) | Button | GestureDetector (custom button) | ✗ No semantic button role, custom tap detector |
| [chronospark_bottom_nav.dart](lib/ui/widgets/chronospark_bottom_nav.dart) | Nav | NavigationBar (built-in) | ✓ Good (NavigationBar has semantics) |
| [neon_card.dart](lib/ui/widgets/neon_card.dart) | Card | Display (likely static) | - |
| [panel_container.dart](lib/ui/widgets/panel_container.dart) | Container | Title + content wrapper | ✓ Title provided, verify heading level |
| [section_header.dart](lib/ui/widgets/section_header.dart) | Header | Title + subtitle display | ✓ Text structure, verify heading semantics |

---

## <a id="interactive"></a>🖱️ Interactive Components Summary

### Button Types Found
```
1. GestureDetector (HoloButton)           → ✗ Custom, needs semantics
2. InkWell (gadget icons, nav items)      → ⚠ Partial labels
3. FilledButton (form submission)         → ✓ Good (built-in semantic)
4. FilledButton.icon (upgrade CTA)        → ✓ Good
5. NavigationBar (bottom nav)             → ✓ Good (built-in semantic)
6. ChoiceChip (day selection)             → ✗ Needs selected state announcement
7. IconButton (delete in lists)           → ✓ Has tooltips
```

### Input Types Found
```
1. TextField (task input, reflection)     → ✗ Missing labels/hints
2. TextEditingController usage            → ✗ No form-level semantics
3. SwitchListTile (module toggle)        → ✓ Good (title + subtitle)
4. SegmentedButton (billing cycle)       → ✗ Needs semantic labels
5. CheckboxListTile (mission tasks)      → ✓ Built-in semantic
```

### Navigation Patterns
```
1. SystemBottomNav (InkWell-based)       → ⚠ Custom, needs testing
2. ChronoSparkBottomNav (NavigationBar)  → ✓ Built-in semantic
3. TabBar alternatives                   → Need to verify if used
```

### Data Display
```
1. ExpansionTile (mission list)          → ✓ Built-in semantic
2. ListView/lists                        → ⚠ Verify item semantics
3. Data visualizations (charts/graphs)   → ✗ No alt text found
```

---

## <a id="theme"></a>🎨 Theme Configuration Files

| File | Purpose | Scope |
|------|---------|-------|
| [theme/app_theme.dart](lib/theme/app_theme.dart) | Theme factory | Dark + Neon Recall variants |
| [theme/dark_theme.dart](lib/theme/dark_theme.dart) | Dark theme | Primary colors, typography |
| [theme/neon_recall_theme.dart](lib/theme/neon_recall_theme.dart) | Neon variant | Vibrant neon colors (cyan, magenta) |
| [theme/decorations.dart](lib/theme/decorations.dart) | Shared decorations | Box decorations, borders |

**Accessibility Concerns in Themes:**
- ✗ Cyan (`#00FFFF`) on dark backgrounds may fail WCAG contrast (4.5:1 minimum)
- ✗ Magenta (`#FF00FF`) might fail contrast tests
- ⚠ Verify text on neon_recall_theme colors meets WCAG AA standards
- ⚠ No reduced-motion/prefers-reduced-motion support seen

---

## <a id="accessibility"></a>♿ Accessibility Audit Checklist

### Priority 1: Critical Issues (WCAG A - Must Fix)
- [ ] **Semantic HTML/Flutter Semantics**
  - Custom buttons (HoloButton) need `Semantics` widget wrapping
  - Tab roles need verification in main_shell navigation
  - Icon-only buttons need `tooltip` property

- [ ] **Form Accessibility**
  - TextFields need `label` parameter or associated semantics
  - ChoiceChip selections need `onSelected` state announcement
  - Form validation errors must be associated with fields

- [ ] **Color Contrast**
  - Test cyan (`#00FFFF`) text on dark backgrounds
  - Test magenta text on dark backgrounds
  - Verify all text meets 4.5:1 (normal text) or 3:1 (large text) ratio

- [ ] **Keyboard Navigation**
  - Test tab order through all screens
  - Verify custom GestureDetectors respond to Enter key
  - Check navigation item focus indicators

### Priority 2: Important Issues (WCAG AA - Should Fix)
- [ ] **Screen Reader Announcements**
  - Animated transitions should announce state changes
  - Premium trial gate messages need semantic markup
  - List changes (add/delete items) need announcements
  - Modal dialogs (account deletion) need focus management

- [ ] **Motion & Animations**
  - AnimatedSystemBackground should respect `MediaQuery.of(context).disableAnimations`
  - PulseBar animation needs reduced-motion support
  - Transition animations may cause vestibular issues

- [ ] **Data Visualizations**
  - ChronoflowDay bars need description text/alt text
  - ArcviewWeek needs accessible data representation
  - ConstellationMonth visualization needs alt text

### Priority 3: Enhancement Issues (WCAG AAA - Nice to Have)
- [ ] **Magnification Support**
  - Text scale settings exist but need testing at 200%
  - Panel layouts should reflow gracefully
  
- [ ] **Customization**
  - Add color blind filter options (deuteranopia, protanopia, tritanopia)
  - Provide high-contrast mode
  - Add dyslexia-friendly font option

- [ ] **Localization**
  - Verify RTL language support (if applicable)
  - Screen reader labels should support i18n

---

## 📊 Interactive Components Quick Reference

### Files Needing Immediate Accessibility Review
```
CRITICAL:
├── lib/ui/widgets/holo_button.dart              (GestureDetector button)
├── lib/features/auth/screens/login_screen.dart  (Form fields)
├── lib/features/home/screens/home_screen.dart   (Icon tappables)
├── lib/features/chronocreator/screens/creator_home.dart (Multiple forms)
├── lib/ui/system/system_bottom_nav.dart         (Custom nav)
└── lib/theme/neon_recall_theme.dart             (Color contrast)

HIGH:
├── lib/features/temporal_ops/screens/temporal_ops_home.dart (ChoiceChip)
├── lib/features/settings/widgets/subscription_billing_widget.dart (SegmentedButton)
├── lib/features/si_console/screens/si_console_home.dart (TextField)
└── lib/features/chronocreator/widgets/mission_tile.dart (Complex list)
```

### Widget Implementation Patterns to Standardize
1. **All buttons**: Add `semanticLabel` + tooltip
2. **All inputs**: Add `label` + `semanticLabel`
3. **All selectable items**: Add state announcement mechanism
4. **All animations**: Wrap with `reduceMotion` check
5. **All custom tappables**: Replace with semantic buttons where possible

---

## 🔗 Related Files to Review
- [SECURITY.md](SECURITY.md) - For premium feature gating
- [PRODUCTION_REVIEW_COMPLETE.md](PRODUCTION_REVIEW_COMPLETE.md) - For known issues
- [pubspec.yaml](pubspec.yaml) - Dependencies including accessibility libs
- [analysis_options.yaml](analysis_options.yaml) - Lint rules

---

## Summary Statistics
- **Total Screens**: 14 (3 visible in home + feature modules)
- **Total Custom Widgets**: 18+
- **Total Interactive Components**: 25+
- **Theme Variants**: 2 (Dark + Neon Recall)
- **Accessibility Issues Found**: 35+ (Priority 1-3)
- **Files Requiring Update**: 15-20

**Last Updated**: 2026-06-22
