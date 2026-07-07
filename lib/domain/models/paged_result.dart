class PagedResult<T> {
  const PagedResult({required this.items, required this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
