extension ListExt<T> on List<T> {
  // ------------------------------------------------------------------
  // Safe access
  // ------------------------------------------------------------------

  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
  T? safeGet(int index) => index >= 0 && index < length ? this[index] : null;

  // ------------------------------------------------------------------
  // Transformation
  // ------------------------------------------------------------------

  Iterable<R> mapIndexed<R>(R Function(int index, T element) f) sync* {
    for (int i = 0; i < length; i++) {
      yield f(i, this[i]);
    }
  }

  List<T> sortedBy<K extends Comparable<K>>(K Function(T) key) =>
      [...this]..sort((a, b) => key(a).compareTo(key(b)));

  List<T> sortedByDescending<K extends Comparable<K>>(K Function(T) key) =>
      [...this]..sort((a, b) => key(b).compareTo(key(a)));

  Map<K, List<T>> groupBy<K>(K Function(T) key) {
    final Map<K, List<T>> result = {};
    for (final item in this) {
      result.putIfAbsent(key(item), () => []).add(item);
    }
    return result;
  }

  List<T> distinctBy<K>(K Function(T) key) {
    final Set<K> seen = {};
    return where((e) => seen.add(key(e))).toList();
  }

  List<List<T>> chunked(int size) {
    assert(size > 0);
    final List<List<T>> result = [];
    for (int i = 0; i < length; i += size) {
      result.add(sublist(i, (i + size).clamp(0, length)));
    }
    return result;
  }

  // ------------------------------------------------------------------
  // Aggregation
  // ------------------------------------------------------------------

  num sumBy(num Function(T) value) => fold(0, (acc, e) => acc + value(e));

  T? maxBy<K extends Comparable<K>>(K Function(T) key) =>
      isEmpty ? null : reduce((a, b) => key(a).compareTo(key(b)) >= 0 ? a : b);

  T? minBy<K extends Comparable<K>>(K Function(T) key) =>
      isEmpty ? null : reduce((a, b) => key(a).compareTo(key(b)) <= 0 ? a : b);

  int countWhere(bool Function(T) test) => where(test).length;
}
