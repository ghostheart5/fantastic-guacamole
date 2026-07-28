import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  bool existsAny(List<String> paths) {
    return paths.any((path) => Directory(path).existsSync() || File(path).existsSync());
  }

  test('core ChronoSpark user-facing feature areas exist', () {
    final features = <String, List<String>>{
      'nexus': [
        'lib/features/nexus',
        'lib/nexus',
      ],
      'creator': [
        'lib/features/creator',
        'lib/creator',
      ],
      'coach': [
        'lib/features/coach',
        'lib/features/smart_coach',
        'lib/features/home',
        'lib/coach',
        'lib/smart_coach',
      ],
      'timeline': [
        'lib/features/timeline',
        'lib/timeline',
      ],
      'profile_or_settings': [
        'lib/features/profile',
        'lib/features/settings',
        'lib/profile',
        'lib/settings',
      ],
      'progression': [
        'lib/features/progression',
        'lib/progression',
      ],
      'trajectory': [
        'lib/features/trajectory',
        'lib/features/trajectory_engine',
        'lib/trajectory',
        'lib/trajectory_engine',
      ],
      'si_console': [
        'lib/features/si_console',
        'lib/features/si',
        'lib/si_console',
        'lib/si',
      ],
      'tutorial': [
        'lib/tutorial',
        'lib/features/tutorial',
      ],
    };

    final missing = <String>[];

    features.forEach((name, paths) {
      if (!existsAny(paths)) {
        missing.add(name);
      }
    });

    expect(
      missing,
      isEmpty,
      reason: 'Missing expected ChronoSpark feature areas: $missing',
    );
  });

  test('test folders exist for core ChronoSpark features', () {
    final expected = <String, List<String>>{
      'auth': ['test/features/auth'],
      'daily_plan': ['test/features/daily_plan'],
      'tasks': ['test/features/tasks'],
      'timeline': ['test/features/timeline'],
      'storage': ['test/features/storage'],
      'sync': ['test/features/sync'],
      'settings_or_profile': ['test/features/settings', 'test/features/profile'],
      'ui': ['test/features/ui'],
      'nexus': ['test/features/nexus'],
      'creator': ['test/features/creator'],
      'coach': ['test/features/smart_coach', 'test/features/coach'],
      'progression': ['test/features/progression'],
      'trajectory': ['test/features/trajectory_engine', 'test/features/trajectory'],
      'si_console': ['test/features/si_console', 'test/features/si'],
      'tutorial': ['test/features/tutorial'],
      'action_hub': ['test/features/action_hub'],
      'navigation': ['test/features/navigation'],
    };

    final missing = <String>[];
    expected.forEach((name, paths) {
      if (!paths.any((path) => Directory(path).existsSync())) {
        missing.add(name);
      }
    });

    expect(
      missing,
      isEmpty,
      reason: 'Missing test feature areas: $missing',
    );
  });
}
