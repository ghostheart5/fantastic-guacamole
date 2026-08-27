import 'dart:async';

/// Serializes asynchronous mutations that target the same logical resource.
class KeyedMutationCoordinator {
  KeyedMutationCoordinator();

  static final KeyedMutationCoordinator shared = KeyedMutationCoordinator();

  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<T> runExclusive<T>(String key, Future<T> Function() mutation) {
    if (key.isEmpty) {
      return Future<T>.error(
        ArgumentError.value(key, 'key', 'Mutation key must not be empty.'),
      );
    }

    final Future<void> previous = _tails[key] ?? Future<void>.value();
    final Completer<T> result = Completer<T>();
    late final Future<void> current;

    current = previous.then<void>((_) async {
      try {
        result.complete(await mutation());
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        if (identical(_tails[key], current)) {
          _tails.remove(key);
        }
      }
    });
    _tails[key] = current;
    return result.future;
  }
}
