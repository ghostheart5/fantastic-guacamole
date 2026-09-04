import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/services/app_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes and restores the last primary view', () async {
    final _MemoryStore store = _MemoryStore();
    final AppRecoveryService service = AppRecoveryService(store: store);

    await service.saveState(lastPrimaryViewName: '  timeline  ');

    final AppRecoveryState? restored = await service.loadState();
    expect(restored?.lastPrimaryViewName, 'timeline');
  });

  test('empty primary view removes stale recovery state', () async {
    final _MemoryStore store = _MemoryStore();
    final AppRecoveryService service = AppRecoveryService(store: store);

    await service.saveState(lastPrimaryViewName: 'timeline');
    await service.saveState(lastPrimaryViewName: '   ');

    expect(await service.loadState(), isNull);
    expect(store.values, isEmpty);
  });

  test('load removes unsupported task and draft recovery fields', () async {
    final _MemoryStore store = _MemoryStore()
      ..values.addAll(<String, String>{
        'rec_last_route': 'profile',
        'rec_active_task': 'task-7',
        'rec_draft_title': 'unsupported draft',
      });
    final AppRecoveryService service = AppRecoveryService(store: store);

    final AppRecoveryState? restored = await service.loadState();

    expect(restored?.lastPrimaryViewName, 'profile');
    expect(store.values, <String, String>{'rec_last_route': 'profile'});
  });

  test(
    'legacy cleanup failure does not discard a valid recovered view',
    () async {
      final _DeleteFailingStore store = _DeleteFailingStore()
        ..values.addAll(<String, String>{
          'rec_last_route': 'timeline',
          'rec_active_task': 'task-7',
        });
      final AppRecoveryService service = AppRecoveryService(store: store);

      final AppRecoveryState? restored = await service.loadState();

      expect(restored?.lastPrimaryViewName, 'timeline');
    },
  );

  test('clearAll removes supported and obsolete recovery values', () async {
    final _MemoryStore store = _MemoryStore()
      ..values.addAll(<String, String>{
        'rec_last_route': 'timeline',
        'rec_active_task': 'task-7',
        'rec_draft_title': 'unsupported draft',
      });
    final AppRecoveryService service = AppRecoveryService(store: store);

    await service.clearAll();

    expect(store.values, isEmpty);
  });
}

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;
}

class _DeleteFailingStore extends _MemoryStore {
  @override
  Future<void> delete(String key) async {
    throw StateError('delete unavailable');
  }
}
