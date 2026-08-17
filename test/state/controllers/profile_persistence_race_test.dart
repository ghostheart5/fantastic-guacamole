import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a mutation waits for hydration instead of being overwritten by it',
    () async {
      final _ControlledSecureStoreBackend backend =
          _ControlledSecureStoreBackend.blockedRead(
            jsonEncode(ProfileState(name: 'Saved name', xp: 400).toJson()),
          );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(profileProvider).name, 'ChronoSpark User');
      final Future<void> update = container
          .read(profileProvider.notifier)
          .updateName('Live name');
      await pumpEventQueue();
      expect(container.read(profileProvider).name, 'ChronoSpark User');

      backend.releaseRead();
      await update;

      expect(container.read(profileProvider).name, 'Live name');
      final Map<String, dynamic> stored =
          jsonDecode(backend.storedValue!) as Map<String, dynamic>;
      expect(stored['name'], 'Live name');
      expect(stored['xp'], 400);
    },
  );

  test(
    'overlapping profile writes are serialized and preserve both changes',
    () async {
      final _ControlledSecureStoreBackend backend =
          _ControlledSecureStoreBackend.immediateRead(
            jsonEncode(ProfileState(name: 'Saved name').toJson()),
            blockWrites: true,
          );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(SecureStore(backend: backend)),
        ],
      );
      addTearDown(container.dispose);

      final ProfileController controller = container.read(
        profileProvider.notifier,
      );
      final Future<void> rename = controller.updateName('Current name');
      await backend.waitForWriteCount(1);
      final Future<void> sound = controller.toggleSound(false);
      await pumpEventQueue();

      expect(
        backend.writeCount,
        1,
        reason: 'the second write must wait for the first',
      );
      backend.releaseNextWrite();
      await rename;
      await backend.waitForWriteCount(2);
      backend.releaseNextWrite();
      await sound;

      final Map<String, dynamic> stored =
          jsonDecode(backend.storedValue!) as Map<String, dynamic>;
      expect(stored['name'], 'Current name');
      expect(stored['soundEnabled'], isFalse);
      expect(container.read(profileProvider).name, 'Current name');
      expect(container.read(profileProvider).soundEnabled, isFalse);
    },
  );
}

class _ControlledSecureStoreBackend implements SecureStoreBackend {
  _ControlledSecureStoreBackend.blockedRead(this._readValue)
    : _readGate = Completer<void>(),
      _blockWrites = false;

  _ControlledSecureStoreBackend.immediateRead(
    this._readValue, {
    this._blockWrites = false,
  }) : _readGate = null;

  final String? _readValue;
  final Completer<void>? _readGate;
  final bool _blockWrites;
  final List<Completer<void>> _writeGates = <Completer<void>>[];
  final List<Completer<void>> _writeCountWaiters = <Completer<void>>[];
  String? storedValue;
  int writeCount = 0;

  void releaseRead() => _readGate?.complete();

  Future<void> waitForWriteCount(int count) async {
    while (writeCount < count) {
      final Completer<void> waiter = Completer<void>();
      _writeCountWaiters.add(waiter);
      await waiter.future;
    }
  }

  void releaseNextWrite() {
    final Completer<void> gate = _writeGates.firstWhere(
      (Completer<void> candidate) => !candidate.isCompleted,
    );
    gate.complete();
  }

  @override
  Future<String?> read({required String key}) async {
    await _readGate?.future;
    return _readValue;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writeCount += 1;
    for (final Completer<void> waiter in _writeCountWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _writeCountWaiters.clear();
    if (_blockWrites) {
      final Completer<void> gate = Completer<void>();
      _writeGates.add(gate);
      await gate.future;
    }
    storedValue = value;
  }

  @override
  Future<void> delete({required String key}) async {
    storedValue = null;
  }

  @override
  Future<void> deleteAll() async {
    storedValue = null;
  }
}
