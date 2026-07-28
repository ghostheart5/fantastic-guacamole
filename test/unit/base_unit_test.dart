import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('base unit coverage', () {
    test('app bootstrap files exist', () {
      expect(File('lib/main.dart').existsSync(), isTrue);
      expect(File('lib/app/startup/app_bootstrap.dart').existsSync(), isTrue);
    });

    test('app bootstrap sources are concrete', () {
      final String mainSource = File('lib/main.dart').readAsStringSync();
      final String bootstrapSource = File(
        'lib/app/startup/app_bootstrap.dart',
      ).readAsStringSync();

      expect(mainSource, contains('AppBootstrapper'));
      expect(bootstrapSource.trim(), isNotEmpty);
      expect(mainSource.contains('.bak'), isFalse);
      expect(bootstrapSource.contains('.bak'), isFalse);
    });
  });
}
