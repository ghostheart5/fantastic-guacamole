import 'package:fantastic_guacamole/data/repositories/operating_continuity_repository.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'history is account scoped and acknowledgement requires persisted data',
    () async {
      final _MemoryStore store = _MemoryStore();
      final OperatingContinuityRepository repository =
          OperatingContinuityRepository(store);
      final OperatingSnapshot a = _snapshot('v2.a', 1);
      final OperatingSnapshot b = _snapshot('v2.b', 2);

      await repository.saveSnapshot('v2.a', a);
      await repository.saveSnapshot('v2.b', b);
      await repository.acknowledge('v2.a', a.snapshotId);

      expect(await repository.loadHistory('v2.a'), hasLength(1));
      expect(
        (await repository.loadHistory('v2.a')).single.accountScope,
        'v2.a',
      );
      expect(
        (await repository.loadHistory('v2.b')).single.accountScope,
        'v2.b',
      );
      expect(await repository.loadAcknowledgedSnapshotId('v2.a'), a.snapshotId);
      expect(
        () => repository.acknowledge('v2.a', b.snapshotId),
        throwsStateError,
      );
    },
  );

  test('duplicate revisions are not appended', () async {
    final _MemoryStore store = _MemoryStore();
    final OperatingContinuityRepository repository =
        OperatingContinuityRepository(store);
    final OperatingSnapshot snapshot = _snapshot('v2.a', 1);
    await repository.saveSnapshot('v2.a', snapshot);
    await repository.saveSnapshot('v2.a', snapshot);
    expect(await repository.loadHistory('v2.a'), hasLength(1));
  });

  test('corrupt history is quarantined and safely rebuilt', () async {
    final _MemoryStore store = _MemoryStore();
    final OperatingContinuityRepository repository =
        OperatingContinuityRepository(store, clock: () => DateTime.utc(2026));
    store.values['chronospark.operating.history.v1.v2.a'] = '{broken';
    expect(await repository.loadHistory('v2.a'), isEmpty);
    expect(
      store.values.keys.any((String key) => key.contains('.corrupt.')),
      isTrue,
    );
    await repository.saveSnapshot('v2.a', _snapshot('v2.a', 3));
    expect(await repository.loadHistory('v2.a'), hasLength(1));
  });
}

OperatingSnapshot _snapshot(String scope, int completed) => OperatingSnapshot(
  accountScope: scope,
  observedAt: DateTime.utc(2026, 8, 16, completed),
  sourceRevisions: <String, String>{'completed': '$completed'},
  activeGoalCount: 1,
  actionableCount: 1,
  overdueCount: 0,
  completedToday: completed,
  energy: .7,
  fatigue: .2,
  momentum: 60,
  pressure: 30,
  topActionId: 'task-$completed',
  topActionLabel: 'Task $completed',
  activeRisks: const <String>[],
  evidenceCoverage: 1,
);

class _MemoryStore implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
