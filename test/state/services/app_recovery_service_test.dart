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

  test('restores an active task when it is the only recovery value', () async {
    final AppRecoveryService service = AppRecoveryService();

    await service.saveState(activeTaskId: 'task-only');

    final AppRecoveryState? restored = await service.loadState();
    expect(restored?.activeTaskId, 'task-only');
    expect(restored?.lastRoute, isNull);
    expect(restored?.draftTaskTitle, isNull);
  });

  test(
    'normalizes values and explicitly clears stale recovery fields',
    () async {
      final AppRecoveryService service = AppRecoveryService();
      await service.saveState(
        lastRoute: '  /timeline  ',
        activeTaskId: '  task-7  ',
        draftTaskTitle: '  resume this  ',
      );

      final AppRecoveryState? normalized = await service.loadState();
      expect(normalized?.lastRoute, '/timeline');
      expect(normalized?.activeTaskId, 'task-7');
      expect(normalized?.draftTaskTitle, 'resume this');

      await service.saveState(
        clearLastRoute: true,
        clearActiveTask: true,
        clearDraftTitle: true,
      );
      expect(await service.loadState(), isNull);
    },
  );

  test(
    'empty recovery values remove stale state instead of restoring blanks',
    () async {
      final AppRecoveryService service = AppRecoveryService();
      await service.saveState(
        lastRoute: '/timeline',
        activeTaskId: 'task-7',
        draftTaskTitle: 'resume this',
      );
      await service.saveState(
        lastRoute: '   ',
        activeTaskId: '',
        draftTaskTitle: '\n',
      );

      expect(await service.loadState(), isNull);
    },
  );
}
