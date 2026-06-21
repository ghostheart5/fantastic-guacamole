# FlutterFire Setup Notes

## Completed
- Installed FlutterFire CLI via `dart pub global activate flutterfire_cli`
- Ran:

```powershell
flutterfire configure --platforms=android,ios,web,windows,macos,linux
```

- Selected Firebase project: `chronospark-app`
- Generated `lib/firebase_options.dart`
- Generated `android/app/google-services.json`

## Required Follow-up
- Add iOS config file `ios/Runner/GoogleService-Info.plist`.
  - If not generated automatically on Windows, re-run FlutterFire on macOS with Xcode environment,
    or download file from Firebase Console and add it manually.
- In Firebase Console, enable `Authentication -> Sign-in method -> Email/Password`.

## Runtime Initialization
`lib/main.dart` now initializes Firebase using:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## Release App Id and Version Overrides
Android release identity/version can now be set without editing Gradle files.

Use `android/release.properties.example` values in `android/gradle.properties`, or pass as Gradle properties:

- `CHRONOSPARK_APPLICATION_ID`
- `CHRONOSPARK_VERSION_CODE`
- `CHRONOSPARK_VERSION_NAME`

After changing application id, re-run FlutterFire configure so Firebase apps and config files match the new id.

## Receipt Verification Hook
Client hook is wired through `PaywallReceiptVerifier`.

Provide defines at runtime:

- `CHRONOSPARK_RECEIPT_VERIFY_ENDPOINT`
- `CHRONOSPARK_RECEIPT_VERIFY_KEY` (optional)
