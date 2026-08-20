import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QA mock profile cannot contact production-facing services', () {
    final Map<String, dynamic> defines =
        jsonDecode(File('tool/qa_defines.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(defines['CHRONOSPARK_APP_FLAVOR'], 'qa');
    expect(defines['CHRONOSPARK_ENABLE_MOCK_LOGIN'], isTrue);
    expect(defines['CHRONOSPARK_ENABLE_MOCK_MODE'], isTrue);
    expect(defines['CHRONOSPARK_ENABLE_TESTER_FULL_ACCESS'], isTrue);
    expect(defines['CHRONOSPARK_PAYWALL_DISABLED'], isTrue);
    expect(defines['CHRONOSPARK_ENABLE_CLOUD_SYNC'], isFalse);
    expect(defines['CHRONOSPARK_ENABLE_ANALYTICS'], isFalse);
    expect(defines['CHRONOSPARK_ENABLE_CRASH_REPORTING'], isFalse);
  });
}
