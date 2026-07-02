# ChronoSpark Google Play Release Checklist

## Firebase
- [x] FlutterFire project configured for `chronospark-app`
- [ ] Replace placeholder values in `lib/config/firebase_options.dart` or verify Android release path does not depend on them
- [x] Android `google-services.json` generated
- [ ] iOS `GoogleService-Info.plist` added to `ios/Runner/` (run FlutterFire on macOS or download manually)
- [ ] Firebase Console: enable Email/Password auth provider

## In-App Purchases
- [x] Product IDs in code:
  - `chronospark_premium_monthly`
  - `chronospark_premium_yearly`
- [x] Client-side receipt verification hook added
- [x] Server stub endpoint script added (`scripts/receipt_verifier_stub.js`)
- [ ] Implement real Play Billing purchase and restore flow in app code
- [ ] Create matching products in Google Play Console with exact IDs
- [ ] Add pricing, localized descriptions, and publish products
- [ ] Test purchases with license test account

## Android Compliance
- [x] INTERNET permission in `AndroidManifest.xml`
- [x] BILLING permission in `AndroidManifest.xml`
- [x] Billing dependency `com.android.billingclient:billing:6.0.1`
- [x] Release signing scaffold in `android/app/build.gradle.kts`
- [x] `android/key.properties.example` added
- [ ] Create real `android/key.properties` (not committed)
- [ ] Place upload keystore at `android/app/key.jks` (not committed)

## Policy and Legal
- [x] Privacy policy file at `assets/legal/privacy_policy.html`
- [x] Terms of service file at `assets/legal/terms_of_service.html`
- [x] Support page file added at `web/support/index.html`
- [x] Host privacy policy at public URL (`https://chronospark.app/privacy/` or equivalent deployed path)
- [x] Host terms URL (`https://chronospark.app/terms/` or equivalent deployed path)
- [x] Host support URL (`https://chronospark.app/support/` or equivalent deployed path)
- [ ] Confirm Play Console developer support email/contact is configured

## Versioning and Release
- [x] Gradle release override support for app id and versioning added
- [ ] Set release values via `android/release.properties.example` -> `android/gradle.properties`
- [ ] Build signed Android App Bundle (`flutter build appbundle --release`)
- [ ] Upload `.aab` to Google Play internal testing track

## Testing
- [x] `flutter analyze` clean
- [ ] Expand `test/` and `integration_test/` coverage for critical flows and keep tests green in CI
- [x] Audit script (`python uats.py`) clean

## Closed Testing Notes
- [x] Tester access mode can bypass auth and premium restrictions for QA builds
- [ ] Hide or disable unfinished account-management flows if using community testers
- [ ] Use a signed `.aab` built with QA/tester dart-defines, not production publish flags
