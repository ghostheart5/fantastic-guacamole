import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/session_recovery_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SharedPrefsService.init();
    await SharedPrefsService.clear();
  });

  test('detects active session from storage', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(sessionRecoveryProvider);

    await service.saveState(lastRoute: '/plan', activeTaskId: 'task-1');
    final state = await service.loadState();

    expect(state, isNotNull);
    expect(state?.lastRoute, '/plan');
    expect(state?.activeTaskId, 'task-1');
  });

  test('restores interrupted session with draft metadata', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(sessionRecoveryProvider);

    await service.saveState(
      lastRoute: '/timeline/session',
      activeTaskId: 'task-9',
      draftTaskTitle: 'resume deep work',
    );

    final restored = await service.loadState();

    expect(restored, isNotNull);
    expect(restored?.lastRoute, '/timeline/session');
    expect(restored?.activeTaskId, 'task-9');
    expect(restored?.draftTaskTitle, 'resume deep work');
  });

  test('clears completed session state', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(sessionRecoveryProvider);

    await service.saveState(
      lastRoute: '/timeline',
      activeTaskId: 'task-9',
      draftTaskTitle: 'temporary',
    );
    await service.clearDraft();

    final afterDraftClear = await service.loadState();
    expect(afterDraftClear?.draftTaskTitle, isNull);

    await service.clearAll();
    final afterAllClear = await service.loadState();
    expect(afterAllClear, isNull);
  });

  test('handles corrupted recovery state safely', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rec_last_route', 42);
    await prefs.setBool('rec_draft_title', true);

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final service = container.read(sessionRecoveryProvider);

    final state = await service.loadState();
    expect(state, isNull);
  });
}
