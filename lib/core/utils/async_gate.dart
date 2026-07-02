import 'dart:async';

class AsyncGate<T> {
  Future<void> _tail = Future<void>.value();

  Future<T> run(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final T result = await operation();
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
