import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'signed-out deletion receipts can reach their explicitly secured handler',
    () {
      final String config = File('supabase/config.toml').readAsStringSync();
      final String? section = RegExp(
        r'\[functions\.account-delete\]([^\[]*)',
      ).firstMatch(config)?.group(1);
      expect(section, isNotNull);
      expect(section, contains('verify_jwt = false'));
    },
  );
}
