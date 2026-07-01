# App-Wide Accessibility Integration Guide

This guide provides step-by-step instructions for integrating accessibility (A11y) support throughout the ChronoSpark app to achieve WCAG AA compliance.

## Quick Start Pattern

### Before (Not Accessible)
```dart
GestureDetector(
  onTap: () => _handleSubmit(),
  child: Container(
    padding: EdgeInsets.all(12),
    child: Icon(Icons.send),
  ),
)
```

### After (Accessible with A11yButton)
```dart
A11yButton(
  label: 'Submit Form',
  onPressed: _handleSubmit,
  icon: Icons.send,
)
```

---

## Step 1: Replace Custom Buttons

### Pattern: Any GestureDetector with custom styling

**File: lib/ui/widgets/holo_button.dart** (example, adjust per actual widget)
```dart
// Before:
class HoloButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        // ... styling
        child: child,
      ),
    );
  }
}

// After:
class HoloButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final String? semanticLabel;
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: semanticLabel,
      onTap: onPressed,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          // ... styling
          child: child,
        ),
      ),
    );
  }
}
```

---

## Step 2: Add Labels to Text Fields

### Pattern: All TextFields need semantic association

**Update all TextFields in forms:**
```dart
// Before:
TextField(
  controller: emailController,
  hintText: 'Enter email',
)

// After:
A11yTextField(
  controller: emailController,
  label: 'Email Address',
  hintText: 'Enter email',
  obscureText: false,
)
```

---

## Step 3: Wrap Interactive Elements

### Pattern: Any widget users tap/interact with needs Semantics

**For Icon Buttons:**
```dart
// Before:
IconButton(
  icon: Icon(Icons.delete),
  onPressed: () => _delete(),
)

// After:
A11yIconButton(
  icon: Icon(Icons.delete),
  label: 'Delete item',
  onPressed: () => _delete(),
)
```

**For Custom Cards/Tiles:**
```dart
// Before:
InkWell(
  onTap: () => _openDetail(),
  child: Card(child: ...,),
)

// After:
A11yWidget(
  label: 'View task details: ${task.title}',
  child: InkWell(
    onTap: () => _openDetail(),
    child: Card(child: ...,),
  ),
)
```

---

## Step 4: Text Scaling Support

### Pattern: Respect MediaQuery.textScaleFactorOf

**Update all Text widgets:**
```dart
// Before:
Text('Hello World', style: TextStyle(fontSize: 16))

// After:
Text(
  'Hello World',
  style: TextStyle(fontSize: 16),
  textScaleFactor: MediaQuery.of(context).textScaleFactorOf(context),
)

// Or use helper:
Text(
  'Hello World',
  style: TextStyle(fontSize: 16),
  textScaleFactor: A11yUtils.getTextScale(context),
)
```

---

## Step 5: Color Contrast Verification

### Pattern: Verify contrast ratios with A11yUtils

**During development:**
```dart
// In theme or constants:
final buttonColor = Colors.blue.shade700;
final textColor = Colors.white;

// Verify contrast:
assert(
  A11yUtils.getContrastRatio(buttonColor, textColor) >= 4.5,
  'Button contrast insufficient for WCAG AA',
);
```

**Dynamic verification:**
```dart
if (A11yUtils.getContrastRatio(bgColor, fgColor) < 4.5) {
  print('Warning: Insufficient contrast');
}
```

---

## Priority Updates Checklist

### Priority 1 - CRITICAL (WCAG A, Must do first)

- [ ] **HoloButton & NeonCard** - Add Semantics
  - Files: `lib/ui/widgets/holo_button.dart`, `lib/ui/widgets/neon_card.dart`
  - Action: Wrap with Semantics(button: true, label: ...)

- [ ] **All TextFields** - Add labels
  - Files: `lib/features/**/widgets/*_screen.dart`
  - Action: Replace with A11yTextField or add Semantics
  - Example screens:
    - `lib/features/auth/screens/login_screen.dart`
    - `lib/features/creator/widgets/task_input.dart`

- [ ] **Navigation buttons** - Add semantic roles
  - Files: `lib/ui/widgets/chronospark_bottom_nav.dart`
  - Action: Ensure all nav items have labels

- [ ] **Icon-only buttons** - Add tooltips/labels
  - Files: Throughout app (search, delete, settings)
  - Action: Add `A11yIconButton` with label

- [ ] **Color contrast check** - Dark cyan text on dark background
  - Files: Theme configuration `lib/theme/`
  - Action: Verify cyan (#00BFFF or similar) has 4.5:1 contrast on background

### Priority 2 - WCAG AA (Important, should complete)

- [ ] **Animations & Motion** - Support reduceMotion
  - Files: `lib/ui/widgets/animated_system_background.dart`, `lib/ui/widgets/pulse_bar.dart`
  - Action: Wrap animations with MediaQuery.of(context).disableAnimations

- [ ] **Toggles & Switches** - Add semantic announcements
  - Files: All settings screens using Switch
  - Action: Add Semantics(label: 'Setting name: [on/off]')

- [ ] **Data visualizations** - Add descriptions
  - Files: `lib/features/temporal_ops/widgets/chronoflow_day.dart`
  - Action: Add Semantics.label with readable description

- [ ] **Form validation** - Announce errors to screen readers
  - Files: All form screens
  - Action: Announce errors via Semantics or SnackBar

- [ ] **Text scaling** - Test at 200% scaling
  - Files: All text throughout app
  - Action: Ensure layouts reflow properly, no text cutoff

### Priority 3 - WCAG AAA (Nice to have)

- [ ] **High contrast mode** - Add toggle in settings
- [ ] **Color-blind mode** - Add filters
- [ ] **Bold text** - Support bold text accessibility setting

---

## Testing Guide

### Manual Screen Reader Testing (TalkBack - Android)

1. **Enable TalkBack:**
   ```bash
   adb shell settings put secure enabled_accessibility_services \
     com.google.android.marmoset.accessibility.service/com.google.android.marmoset.accessibility.service.MarmosetAccessibilityService
   ```

2. **Test navigation:**
   - Swipe right to move between elements
   - Should announce label of each element
   - Double tap to activate

3. **Verify announcements:**
   - "Button: Create task" (not just "Create")
   - "Text field: Email address"
   - "Toggle: Dark mode, off"

### Automated Accessibility Testing

```dart
// In test files:
testWidgets('Button is semantically labeled', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());
  
  final semantics = tester.getSemantics(find.byType(ElevatedButton));
  expect(semantics.label, isNotEmpty);
  expect(semantics.isButton, true);
});

testWidgets('Text field has label', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());
  
  final semantics = tester.getSemantics(find.byType(TextField));
  expect(semantics.label, isNotEmpty);
});
```

### Contrast Ratio Validation

```dart
test('Button colors have sufficient contrast', () {
  const bgColor = Color(0xFF1A1A2E);
  const fgColor = Color(0xFF00BFFF);
  
  final ratio = A11yUtils.getContrastRatio(bgColor, fgColor);
  expect(ratio, greaterThanOrEqualTo(4.5)); // WCAG AA minimum
});
```

---

## Screen-by-Screen Implementation Order

1. **Login Screen** (`lib/features/auth/screens/login_screen.dart`)
   - Add semantic labels to email/password fields
   - Add label to login button
   - Verify contrast on any custom styling

2. **Home Screen** (`lib/features/home/screens/home_screen.dart`)
   - Add semantic labels to navigation
   - Ensure all buttons announced properly

3. **Settings Screen** (`lib/features/settings/screens/settings_home.dart`)
   - All ListTiles → add semantic labels
   - All Switches/Toggles → add on/off state announcements
   - Add semantic labels to account deletion widget

4. **Feature Screens**
   - Temporal Ops: Calendar items with readable dates
   - SI Console: Interaction announcements
   - Creator: Task/goal/routine inputs with field labels
   - Logs: Timeline items with readable descriptions

5. **Paywall & Subscription UI**
   - Plan options with semantic labels
   - Subscribe button with clear action label
   - Subscription status announcements

---

## Code Example: Complete Accessible Screen

```dart
class AccessibleSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: A11yWidget(
          label: 'Settings',
          child: Text(
            'Settings',
            textScaleFactor: MediaQuery.of(context).textScaleFactorOf(context),
          ),
        ),
      ),
      body: ListView(
        children: [
          // Theme Setting
          A11yWidget(
            label: 'Dark mode: ${isDarkMode ? 'on' : 'off'}',
            child: SwitchListTile(
              title: Text(
                'Dark Mode',
                textScaleFactor: MediaQuery.of(context).textScaleFactorOf(context),
              ),
              value: isDarkMode,
              onChanged: (value) => _toggleDarkMode(context, value),
            ),
          ),
          
          // Notification Setting
          A11yWidget(
            label: 'Notifications: on',
            child: SwitchListTile(
              title: Text(
                'Enable Notifications',
                textScaleFactor: MediaQuery.of(context).textScaleFactorOf(context),
              ),
              value: true,
              onChanged: (_) {},
            ),
          ),
          
          // Delete Account
          A11yButton(
            label: 'Delete account permanently',
            onPressed: _showDeleteDialog,
            icon: Icons.delete_outline,
            child: const ListTile(
              title: Text('Delete Account'),
              subtitle: Text('Permanently delete your account'),
              trailing: Icon(Icons.arrow_forward),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Verification Checklist for Production

- [ ] All buttons have semantic labels (use A11yButton or Semantics)
- [ ] All text fields have associated labels (use A11yTextField)
- [ ] All icon-only buttons have tooltips (use A11yIconButton)
- [ ] Color contrast verified (minimum 4.5:1 for WCAG AA)
- [ ] Text scaling tested at 150%, 200%
- [ ] Screen reader tested with TalkBack (Android) or VoiceOver (iOS)
- [ ] Keyboard navigation works (Tab key navigates all interactive elements)
- [ ] Animation respects reduceMotion setting
- [ ] Form errors announced to screen readers
- [ ] Loading states indicated with announcements
- [ ] All interactive elements 48x48dp minimum touch target

---

## Resources

- [Material Design Accessibility](https://material.io/design/usability/accessibility.html)
- [Flutter Semantics](https://flutter.dev/docs/development/accessibility-and-localization/accessibility)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Screen Reader Testing](https://flutter.dev/docs/testing/testing-accessibility)

