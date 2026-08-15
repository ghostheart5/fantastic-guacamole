import 'dart:async';

import 'package:fantastic_guacamole/data/storage/secure_store.dart';

class ControllableSecureStoreBackend implements SecureStoreBackend {
  final Map<String, String> values = <String, String>{};
  String? heldReadKey;
  Completer<void>? _readGate;
  final List<String> reads = <String>[];
  final Set<String> failingReads = <String>{};
  final Set<String> failingWrites = <String>{};
  final Map<String, Completer<void>> _started = <String, Completer<void>>{};

  void holdNextReadFor(String key) {
    heldReadKey = key;
    _readGate = Completer<void>();
    _started.putIfAbsent(key, () => Completer<void>());
  }

  Future<void> waitUntilReadStarted(String key) {
    return (_started[key] ??= Completer<void>()).future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => throw StateError('Timed out waiting for read of $key'),
    );
  }

  void releaseHeldRead() => _readGate?.complete();

  @override
  Future<String?> read({required String key}) async {
    reads.add(key);
    if (failingReads.contains(key)) throw StateError('read failure for $key');
    final Completer<void>? started = _started[key];
    if (started != null && !started.isCompleted) started.complete();
    if (key == heldReadKey) {
      await _readGate!.future;
      heldReadKey = null;
    }
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    if (failingWrites.contains(key)) throw StateError('write failure for $key');
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}
