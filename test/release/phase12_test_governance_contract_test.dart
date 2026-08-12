import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 12 policy and registries retain non-silent release controls', () {
    final String policy = File('docs/testing/FLAKY_TEST_POLICY.md').readAsStringSync();
    expect(policy, contains('first failure remains visible'));
    expect(policy, contains('There is no permanent'));
    expect(policy, contains('Complete suite'));

    for (final String registry in <String>[
      'docs/testing/governance/FLAKY_TEST_REGISTRY.md',
      'docs/testing/governance/QUARANTINE_REGISTRY.md',
      'docs/testing/governance/DUPLICATE_TEST_CANDIDATES.md',
    ]) {
      expect(File(registry).readAsStringSync(), contains('| ID |'));
    }
  });

  test('Phase 12 selector preserves complete pre-release selection', () {
    final String selector = File('tool/testing/select_phase12_tests.ps1').readAsStringSync();
    expect(selector, contains(r"$Mode -eq 'pre-release'"));
    expect(selector, contains("testTargets = @('test')"));
    expect(selector, contains('test/release'));
  });
}
