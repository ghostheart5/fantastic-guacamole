/// CHRONOSPARK-CLASS: SHIPPING | Feature: Cross-cutting
///
/// Boundary guards for destructive and bulk use-case inputs.
/// Boundary guards for use-case inputs.
///
/// Centralised so that destructive and bulk operations validate identically
/// everywhere instead of each use case inventing its own check (or, as was the
/// case, none at all).
abstract final class InputGuard {
  /// Rejects blank identifiers before they reach a repository. A blank id
  /// silently matches nothing on delete and is never a legitimate request.
  static String id(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'must not be blank');
    }
    return value;
  }

  /// Guards whole-collection overwrites.
  ///
  /// Bulk savers replace the entire stored collection, so an accidentally empty
  /// list wipes the user's data. Clearing must be explicit via [allowClear].
  static List<T> batch<T>(
    List<T> items,
    String name, {
    required bool allowClear,
  }) {
    if (items.isEmpty && !allowClear) {
      throw ArgumentError.value(
        items,
        name,
        'Refusing to replace the stored collection with an empty list. '
        'Pass allowClear: true to clear it deliberately.',
      );
    }
    return items;
  }
}
