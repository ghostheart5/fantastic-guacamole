import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('drains a pending write and is repeat-safe', () async {
    final _ControlledSecureStoreBackend backend = _ControlledSecureStoreBackend(
      holdWrites: true,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => AccountStorageScope.authenticated('drain-user'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final LearningController controller = container.read(
      learningProvider.notifier,
    );

    final Future<void> write = controller.apply(
      const LearningState(completed: 1),
    );
    await backend.writeStarted.future;
    final Future<void> drain = controller.cancelAndDrainWrites();
    var drainCompleted = false;
    unawaited(drain.then((_) => drainCompleted = true));
    await Future<void>.delayed(Duration.zero);
    expect(drainCompleted, isFalse);

    backend.releaseNextWrite();
    await write;
    await drain;
    await controller.cancelAndDrainWrites();
    await controller.cancelAndDrainWrites();

    final String key = LearningController.canonicalStorageKeyForUser(
      'drain-user',
    );
    expect(backend.writeKeys, <String>[key]);
    expect(backend.values[key], contains('"completed":1'));
    expect(container.read(learningProvider).completed, 1);
  });

  test('a failed write does not poison the following write or drain', () async {
    final _ControlledSecureStoreBackend backend = _ControlledSecureStoreBackend(
      failNextWrite: true,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
        accountStorageScopeProvider.overrideWith(
          (Ref ref) => AccountStorageScope.authenticated('drain-user'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final LearningController controller = container.read(
      learningProvider.notifier,
    );

    await expectLater(
      controller.apply(const LearningState(completed: 1)),
      throwsStateError,
    );
    await controller.apply(const LearningState(completed: 2));
    await controller.cancelAndDrainWrites();

    final String key = LearningController.canonicalStorageKeyForUser(
      'drain-user',
    );
    expect(backend.writeKeys, <String>[key, key]);
    expect(backend.values[key], contains('"completed":2'));
  });

  test(
    'ambiguous Learning migration preserves global legacy storage',
    () async {
      final _ControlledSecureStoreBackend backend =
          _ControlledSecureStoreBackend();
      final SecureStore store = SecureStore(backend: backend);
      backend.values['ai_learning'] = 'legacy-learning';

      final LearningLegacyMigrationResult result =
          await LearningController.migrateLegacyStorage(
            store: store,
            userId: 'user A',
          );
      expect(result, LearningLegacyMigrationResult.preservedAmbiguous);
      expect(await store.readString('ai_learning'), 'legacy-learning');
      expect(await store.readString('ai_learning.user_A'), isNull);
    },
  );
}

class _ControlledSecureStoreBackend implements SecureStoreBackend {
  _ControlledSecureStoreBackend({
    this.holdWrites = false,
    this.failNextWrite = false,
  });

  final Map<String, String> values = <String, String>{};
  final List<String> writeKeys = <String>[];
  final Completer<void> writeStarted = Completer<void>();
  final List<Completer<void>> _heldWrites = <Completer<void>>[];
  bool holdWrites;
  bool failNextWrite;

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read({required String key}) async => values[key];

  void releaseNextWrite() => _heldWrites.removeAt(0).complete();

  @override
  Future<void> write({required String key, required String value}) async {
    writeKeys.add(key);
    if (!writeStarted.isCompleted) writeStarted.complete();
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('controlled write failure');
    }
    if (holdWrites) {
      final Completer<void> gate = Completer<void>();
      _heldWrites.add(gate);
      await gate.future;
    }
    values[key] = value;
  }
}
