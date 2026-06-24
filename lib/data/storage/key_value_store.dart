import 'dart:async';

abstract class KeyValueStore {
  Future<void> putString(String key, String value);
  Future<String?> getString(String key);
}

/// A simple async gate (mutex) that serialises concurrent async operations.
class _AsyncGate {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() fn) {
    final Completer<void> completer = Completer<void>();
    final Future<T> result = _tail.then<T>((_) => fn());
    _tail = completer.future;
    result.whenComplete(() => completer.complete());
    return result;
  }
}

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _store = <String, String>{};
  final _AsyncGate _gate = _AsyncGate();

  @override
  Future<String?> getString(String key) {
    return _gate.run(() async => _store[key]);
  }

  @override
  Future<void> putString(String key, String value) {
    return _gate.run(() async {
      _store[key] = value;
    });
  }
}
