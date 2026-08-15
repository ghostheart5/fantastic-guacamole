import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lifecycle keeps the legacy Routine box outside current-state cleanup', () {
    final String source = File(
      'lib/state/providers/auth_session_lifecycle_provider.dart',
    ).readAsStringSync();
    final String privateHiveSet = source.substring(
      source.indexOf('const Set<String> privateHiveBoxes'),
      source.indexOf('await _hive.init();'),
    );

    expect(privateHiveSet, isNot(contains('HiveBoxes.routines')));
    expect(
      File('lib/data/repositories/routine_repository.dart').readAsStringSync(),
      contains("static const String _key = 'routines_v1'"),
    );
  });
}
