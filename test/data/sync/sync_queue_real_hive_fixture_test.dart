import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/sync/sync_mutation_dispatcher.dart';
import 'package:fantastic_guacamole/data/sync/sync_queue_store.dart';
import '../../helpers/real_hive_test_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real Hive storage and scoped SyncQueueStore isolate and persist A/B',
    () async {
      final RealHiveTestFixture fixture = await RealHiveTestFixture.create();
      addTearDown(fixture.dispose);
      final AccountStorageScope a = AccountStorageScope.authenticated(
        'fixture-a',
      );
      final AccountStorageScope b = AccountStorageScope.authenticated(
        'fixture-b',
      );
      final HiveStorage<String> direct = HiveStorage<String>(
        'direct',
        hive: fixture.hiveStore,
      );
      await direct.open();
      expect(direct.get('value'), isNull);
      await direct.put('value', 'first');
      await direct.put('value', 'second');
      expect(
        HiveStorage<String>('direct', hive: fixture.hiveStore).get('value'),
        'second',
      );

      final SyncQueueStore queueA = SyncQueueStore(
        HiveStorage<String>(
          HiveBoxes.accountScoped(HiveBoxes.offlineQueue, a),
          hive: fixture.hiveStore,
        ),
        storageScope: a,
      );
      final SyncQueueStore queueB = SyncQueueStore(
        HiveStorage<String>(
          HiveBoxes.accountScoped(HiveBoxes.offlineQueue, b),
          hive: fixture.hiveStore,
        ),
        storageScope: b,
      );
      expect(await queueA.readAll(), isEmpty);
      await SyncMutationDispatcher(
        queueStore: queueA,
        userId: 'fixture-a',
      ).enqueueUpsert(
        tableName: 'habit_occurrences',
        recordId: 'same',
        payload: const <String, dynamic>{'status': 'completed'},
      );
      expect((await queueA.readAll()).single.userId, 'fixture-a');
      expect(await queueB.readAll(), isEmpty);
      await SyncMutationDispatcher(
        queueStore: queueB,
        userId: 'fixture-b',
      ).enqueueUpsert(
        tableName: 'habit_occurrences',
        recordId: 'same',
        payload: const <String, dynamic>{'status': 'skipped'},
      );
      expect((await queueB.readAll()).single.userId, 'fixture-b');
      final SyncQueueStore reconstructedA = SyncQueueStore(
        HiveStorage<String>(
          HiveBoxes.accountScoped(HiveBoxes.offlineQueue, a),
          hive: fixture.hiveStore,
        ),
        storageScope: a,
      );
      expect((await reconstructedA.readAll()).single.recordId, 'same');
      expect(await fixture.directory.exists(), isTrue);
    },
  );
}
