import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('static release guards', () {
    test('lib does not contain forbidden GitHub login strings', () {
      final files = Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>();
      final matches = <String>[];
      final patterns = <RegExp>[
        RegExp(r'github\.com/login'),
        RegExp(
          r'github[^\n]{0,80}(client_secret|personal_access_token|access_token)',
        ),
      ];

      for (final file in files) {
        if (file.path.endsWith('.dart') ||
            file.path.endsWith('.md') ||
            file.path.endsWith('.txt')) {
          final content = file.readAsStringSync();
          final lower = content.toLowerCase();
          if (patterns.any((pattern) => pattern.hasMatch(lower))) {
            matches.add(file.path);
          }
        }
      }

      expect(
        matches,
        isEmpty,
        reason: 'Unexpected GitHub login strings: $matches',
      );
    });

    test('lib does not contain obvious hardcoded secrets', () {
      final files = Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>();
      final forbidden = <String>[];
      final patterns = <RegExp>[
        RegExp(r'https://[A-Za-z0-9-]+\.supabase\.co'),
        RegExp(r'eyJ[A-Za-z0-9_-]+\.'),
        RegExp(r'AIza[0-9A-Za-z\-_]{35}'),
        RegExp(r'-----BEGIN PRIVATE KEY-----'),
      ];

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('firebase_options.dart')) continue;
        final content = file.readAsStringSync();
        for (final pattern in patterns) {
          if (pattern.hasMatch(content)) {
            forbidden.add('${file.path}: ${pattern.pattern}');
          }
        }
      }

      expect(forbidden, isEmpty, reason: 'Hardcoded secrets found: $forbidden');
    });

    test('lib does not contain print calls', () {
      final files = Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>();
      final offenders = <String>[];

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();
        if (content.contains('print(')) {
          offenders.add(file.path);
        }
      }

      expect(offenders, isEmpty, reason: 'Unexpected print calls: $offenders');
    });

    test(
      'lib does not contain TODO/FIXME/HACK in critical auth/storage/payment files',
      () {
        final files = <File>[
          File('lib/data/services/auth_service.dart'),
          File('lib/data/storage/secure_store.dart'),
          File('lib/data/storage/shared_prefs_service.dart'),
          File('lib/data/storage/hive_service.dart'),
          File('lib/features/monetization/data/services/paywall_service.dart'),
        ];

        final offenders = <String>[];
        for (final file in files) {
          if (!file.existsSync()) continue;
          final content = file.readAsStringSync();
          if (content.contains('TODO') ||
              content.contains('FIXME') ||
              content.contains('HACK')) {
            offenders.add(file.path);
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'Critical files contain TODO/FIXME/HACK: $offenders',
        );
      },
    );

    test('lib does not contain mojibake markers', () {
      final files = Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>();
      final offenders = <String>[];
      final markers = <String>['�', 'Ã', 'Â', 'â€', 'â€™', 'â€œ', 'â€�'];

      for (final file in files) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();
        if (markers.any(content.contains)) {
          offenders.add(file.path);
        }
      }

      expect(offenders, isEmpty, reason: 'Mojibake markers found: $offenders');
    });

    test('pubspec assets referenced by lib exist on disk', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final assetMatches =
          RegExp(r'^\s*-\s+([A-Za-z0-9_./-]+)', multiLine: true)
              .allMatches(pubspec)
              .map((match) => match.group(1)!)
              .where((asset) => asset.startsWith('assets/'))
              .toSet();

      final missing = <String>[];
      for (final asset in assetMatches) {
        final path = asset.endsWith('/') ? asset : asset;
        final file = File(path);
        if (!file.existsSync() && !Directory(path).existsSync()) {
          missing.add(asset);
        }
      }

      expect(missing, isEmpty, reason: 'Missing assets: $missing');
    });
  });
}
