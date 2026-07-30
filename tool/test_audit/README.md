# Test audit commands

Run these from the repository root (PowerShell):

- flutter test test/behavior/secrets_guard_test.dart
- flutter test test/coverage_expansion
- flutter test test/release_guards
- flutter test --coverage
- dart run tool/test_audit/lib_coverage_targets.dart
- dart run tool/test_audit/coverage_gate.dart --min=20
- dart run tool/test_audit/coverage_gate.dart --min=40
- dart run tool/test_audit/coverage_gate.dart --min=60
- dart run tool/test_audit/coverage_gate.dart --min=80
