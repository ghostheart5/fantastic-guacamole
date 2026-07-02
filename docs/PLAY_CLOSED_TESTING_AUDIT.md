# Play Closed Testing Audit

## Ready Now

- Android package id is aligned to `com.ghostheart5.chronospark`.
- `flutter analyze` is clean.
- QA builds can use tester access instead of live auth and billing.
- Privacy, terms, and support pages exist in the repo.

## Still Blocking Upload To Play Testers

1. No real upload keystore or `android/key.properties` yet.
2. No verified signed `.aab` has been produced yet.
3. Real Play Billing flow is not implemented.
4. Direct account deletion still depends on a future backend workflow.
5. `lib/config/firebase_options.dart` still contains placeholder values.
6. There is no active `test/` suite.

## Listing Content Checklist

### Required or effectively required
- App name
- Short description
- Full description
- Privacy policy URL
- Developer support email in Play Console
- At least one phone screenshot
- Signed Android App Bundle for the testing track

### Strongly recommended
- 7-inch and 10-inch tablet screenshots if tablet support is claimed
- Feature graphic
- Closed testing notes that explain this is a QA build with tester access enabled
- Support website URL

## Current Listing/Policy Gaps

- Support page route existed in app URLs but was missing from the web content until now.
- Tester billing is still informational only and should not be described as a live subscription experience.
- Account deletion should not be described as a guaranteed self-service feature in tester materials.
- Data Safety answers in Play Console still need manual completion.

## Suggested Closed Testing Description

Use language similar to:

`This is a closed testing build of ChronoSpark for product feedback and stability testing. Some authentication and premium restrictions may be bypassed in this QA build. Live billing and some account-management flows are not final.`

## Suggested Internal Checklist Before Upload

1. Create `android/key.properties` from the example file.
2. Place the upload keystore at `android/app/key.jks`.
3. Build with QA dart-defines.
4. Verify the generated `.aab` installs and opens correctly from Play internal testing.
5. Add Play Console support email, privacy policy URL, and tester notes.
