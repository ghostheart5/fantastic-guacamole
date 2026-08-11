import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Monkey profiles define bounded levels, multiple seeds and safe event mixes', () {
    final Map<String, dynamic> root = jsonDecode(
      File('tool/chaos/phase10_monkey_profiles.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final Map<String, dynamic> levels = root['levels'] as Map<String, dynamic>;
    expect(levels['pr-smoke']['eventCount'], 1000);
    expect(levels['nightly']['eventCount'], 10000);
    expect((levels['pre-release']['eventCount'] as int), inInclusiveRange(50000, 100000));
    for (final String name in levels.keys) {
      final Map<String, dynamic> profile = levels[name] as Map<String, dynamic>;
      expect((profile['seeds'] as List<dynamic>).length, greaterThanOrEqualTo(2));
      final Map<String, dynamic> distribution =
          profile['distribution'] as Map<String, dynamic>;
      final int total = distribution.values.fold<int>(
        0,
        (int sum, dynamic value) => sum + (value as int),
      );
      expect(total, 100, reason: name);
      expect(distribution['systemKeys'], 0, reason: name);
    }
  });

  test('Monkey runner is explicit, derives the package from the APK and records replay evidence', () {
    final String runner = File('tool/chaos/run_phase10_monkey.ps1').readAsStringSync();
    expect(runner, contains('[switch]$Execute'));
    expect(runner, contains('aapt dump badging'));
    expect(runner, contains('Refusing Monkey target'));
    expect(runner, contains('failed-replay-required'));
    expect(runner, contains('replay-command.txt'));
    expect(runner, contains('binarySha256'));
    expect(runner, contains('droppedEvents'));
  });
}
