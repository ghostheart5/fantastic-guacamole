import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release permits screenshots for user support and QA', () {
    final String source = File(
      'android/app/src/main/kotlin/com/ghostheart5/chronospark/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('class MainActivity : FlutterActivity()'));
    expect(source, isNot(contains('FLAG_SECURE')));
    expect(source, isNot(contains('WindowManager.LayoutParams')));
  });
}
