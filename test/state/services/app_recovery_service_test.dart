import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/services/app_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPrefsService.init();
    await SharedPrefsService.clear();
  });

  test('interrupted app state restores from recovery storage', () async {
    final AppRecoveryService service = AppRecoveryService();

    await service.saveState(
      lastRoute: '/timeline',
      activeTaskId: 'task-99',
      draftTaskTitle: 'resume planning',
    );

    final AppRecoveryState? restored = await service.loadState();

    expect(restored, isNotNull);
    expect(restored?.lastRoute, '/timeline');
    expect(restored?.activeTaskId, 'task-99');
    expect(restored?.draftTaskTitle, 'resume planning');
  });
}
