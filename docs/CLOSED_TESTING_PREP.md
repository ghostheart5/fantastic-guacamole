## Closed Testing Prep

This checklist is for Google Play internal or closed testing only.
It assumes the app may keep tester-only access overrides enabled and is not yet ready for public production release.

### Current Status

- `flutter analyze` is clean.
- Tester auth access can be enabled through Dart defines.
- Premium restrictions can be bypassed in tester builds through Dart defines.
- Real Play Billing flow is not implemented yet.
- Direct account deletion still requires a backend endpoint.

### Android Prerequisites

1. Create `android/key.properties` from `android/key.properties.example`.
2. Place the upload keystore at `android/app/key.jks`.
3. Keep both files out of git.
4. Confirm the Android application id remains `com.ghostheart5.chronospark`.
5. Confirm Firebase in `android/app/google-services.json` contains a client for `com.ghostheart5.chronospark`.

### Recommended Tester Build Command

Use a QA flavor-style release build with explicit tester overrides:

```powershell
flutter build appbundle --release \
	--dart-define=CHRONOSPARK_APP_FLAVOR=qa \
	--dart-define=CHRONOSPARK_ENABLE_MOCK_LOGIN=true \
	--dart-define=CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS=true \
	--dart-define=CHRONOSPARK_ENABLE_CLOUD_SYNC=false
```

If Supabase auth should be available for testers, add:

```powershell
	--dart-define=CHRONOSPARK_SUPABASE_URL=<your-supabase-url> \
	--dart-define=CHRONOSPARK_SUPABASE_ANON_KEY=<your-supabase-publishable-key>
```

### What Testers Should Expect

- Login screen shows `Tester Access` instead of exposing mock credentials.
- Settings shows `Tester Access` when QA full access is enabled.
- SI Console is reachable in tester mode.
- Billing UI is informational only, not a real subscription purchase flow.

### Remaining Blockers Before Play Tester Upload

1. A real upload keystore and `android/key.properties` must exist.
2. A signed `.aab` must build successfully from the current tree.
3. Firebase placeholder values in `lib/config/firebase_options.dart` should be replaced or intentionally excluded from the Android path you ship.
4. Decide whether tester signup/account creation should be available before backend deletion support exists.
5. Play listing content still needs final screenshots, tester notes, privacy policy URL, and support contact details.

### Not Ready For Public Release Yet

- Real Play Billing purchase flow
- Real entitlement verification
- Direct account deletion endpoint
- Full release configuration enforcement across all platforms
