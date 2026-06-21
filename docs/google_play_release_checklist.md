# ChronoSpark Google Play Release Checklist

## Firebase
- [x] FlutterFire configured for project `chronospark-app`
- [x] `lib/firebase_options.dart` generated
- [x] Android `google-services.json` generated
- [ ] iOS `GoogleService-Info.plist` added to `ios/Runner/` (run FlutterFire on macOS or download manually)
- [ ] Firebase Console: enable Email/Password auth provider

## In-App Purchases
- [x] Product IDs in code:
  - `chronospark_premium_monthly`
  - `chronospark_premium_yearly`
- [x] Client-side receipt verification hook added
- [x] Server stub endpoint script added (`scripts/receipt_verifier_stub.js`)
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
- [x] Host privacy policy at public URL and add to Google Play listing (`https://ghostheart5.github.io/fantastic-guacamole/privacy/`)
- [x] Host terms URL (recommended) (`https://ghostheart5.github.io/fantastic-guacamole/terms/`)

## Versioning and Release
- [x] Gradle release override support for app id and versioning added
- [ ] Set release values via `android/release.properties.example` -> `android/gradle.properties`
- [ ] Build signed Android App Bundle (`flutter build appbundle --release`)
- [ ] Upload `.aab` to Google Play internal testing track

## Testing
- [x] `flutter analyze` clean
- [x] `flutter test` passing
- [x] Audit script (`python uats.py`) clean
