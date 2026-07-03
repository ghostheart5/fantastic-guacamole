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

## Android Google Sign-In OAuth Checklist
- Enable `Authentication -> Sign-in method -> Google` in Firebase Console.
- Add Android app SHA certificates in Firebase Console (`Project settings -> Your apps -> Android app -> Add fingerprint`).
- Download a fresh `android/app/google-services.json` after adding fingerprints and replace the local file.
- Confirm that `google-services.json` contains `oauth_client` entries for `client_type: 3` (Android).

Current debug certificate fingerprints on this machine:

- SHA-1: `5E:F2:18:3E:56:BE:E1:7C:C1:9A:F7:EC:C8:D3:E3:07:B8:9A:BA:20`
- SHA-256: `BA:4E:75:7D:2F:15:17:71:23:9D:01:85:1E:D7:80:83:74:34:98:00:49:82:DC:52:76:95:7B:23:7F:0B:40:D8`

Release signing fingerprints must also be added before Play production/testing sign-in will work.

To print release keystore fingerprints:

```powershell
keytool -list -v -alias <your_release_alias> -keystore <path_to_release_keystore>
```

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
