import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPrefsService.init();
    await SharedPrefsService.clear();
  });

  test('saves primitive settings', () async {
    await SharedPrefsService.save('ui.theme', 'tactical');
    await SharedPrefsService.save('focus.minutes', '25');

    expect(SharedPrefsService.load('ui.theme'), 'tactical');
    expect(SharedPrefsService.load('focus.minutes'), '25');
  });

  test('restores defaults when value is missing', () {
    final String value =
        SharedPrefsService.load('missing.setting') ?? 'default-value';

    expect(value, 'default-value');
  });

  test('handles bad value types without throwing', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bad.type.key', 123);

    expect(SharedPrefsService.load('bad.type.key'), isNull);
  });

  test('does not store secrets', () async {
    await SharedPrefsService.save('auth_token', 'super-secret');

    final prefs = await SharedPreferences.getInstance();
    expect(SharedPrefsService.load('auth_token'), isNull);
    expect(prefs.getString('auth_token'), isNull);
  });
}
