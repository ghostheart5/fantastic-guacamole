import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/services/session_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPrefsService.init();
    await SharedPrefsService.clear();
  });

  test('interrupted session restores from service state', () async {
    final SessionRecoveryService service = SessionRecoveryService();

    await service.saveState(
      lastRoute: '/timeline/session',
      activeTaskId: 'task-99',
      draftTaskTitle: 'resume session',
    );

    final SessionRecoveryState? restored = await service.loadState();

    expect(restored, isNotNull);
    expect(restored?.lastRoute, '/timeline/session');
    expect(restored?.activeTaskId, 'task-99');
    expect(restored?.draftTaskTitle, 'resume session');
  });
}
