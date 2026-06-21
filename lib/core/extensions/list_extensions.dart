extension ListExtensions<T> on List<T> {
  T? get safeFirst => isEmpty ? null : first;

  List<T> takeSafe(int count) {
    if (count <= 0) {
      return <T>[];
    }
    return take(count).toList();
  }
}
