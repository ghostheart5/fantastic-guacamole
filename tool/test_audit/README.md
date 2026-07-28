# Test audit commands

Run these from the repository root:

- flutter analyze
- flutter test --coverage
- flutter test test/release_guards
- flutter test test/features/auth
- flutter test test/data/storage
- flutter test test/providers
- flutter test integration_test
- adb logcat -d | grep -iE 'flutter|fatal|crash|chronospark'
- flutter run --verbose --debug --no-sound-null-safety
- flutter test lab --project <project-id> <test-arg>
