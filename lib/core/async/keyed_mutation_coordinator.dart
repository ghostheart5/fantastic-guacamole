import 'dart:async';

/// Serializes asynchronous mutations that target the same logical resource.
class KeyedMutationCoordinator {
  KeyedMutationCoordinator();

  static final KeyedMutationCoordinator shared = KeyedMutationCoordinator();

  final Map<String, Future<void>> _tails = <String, Future<void>>{};
  final Map<String, int> _generations = <String, int>{};
  final Object _zoneKey = Object();

  int generationFor(String key) => _generations[key] ?? 0;

  Future<T> runExclusive<T>(String key, Future<T> Function() mutation) {
    if (key.isEmpty) {
      return Future<T>.error(
        ArgumentError.value(key, 'key', 'Mutation key must not be empty.'),
      );
    }
    final Set<String>? activeKeys = Zone.current[_zoneKey] as Set<String>?;
    if (activeKeys?.contains(key) ?? false) {
      return Future<T>.sync(mutation);
    }

    final Future<void> previous = _tails[key] ?? Future<void>.value();
    final Completer<T> result = Completer<T>();
    late final Future<void> current;

    current = previous.then<void>((_) async {
      try {
        result.complete(
          await runZoned<Future<T>>(
            mutation,
            zoneValues: <Object, Object>{
              _zoneKey: <String>{...?activeKeys, key},
            },
          ),
        );
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        _generations[key] = generationFor(key) + 1;
        if (identical(_tails[key], current)) {
          _tails.remove(key)?.ignore();
        }
      }
    });
    _tails[key] = current;
    return result.future;
  }
}
