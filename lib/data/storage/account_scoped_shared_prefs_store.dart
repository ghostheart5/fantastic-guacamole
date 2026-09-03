import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';

/// Account-owned preference storage with preservation-only legacy access.
///
/// Mutations always target the exact V2 namespace. A legacy value may be read
/// only after ownership is proven; it is never copied or deleted implicitly.
final class AccountScopedSharedPrefsStore
    implements SharedPrefsStore, EnumerableSharedPrefsStore {
  static const String _legacyClearMarker =
      '__chronospark_internal_legacy_fallback_cleared__';
  static const String _legacyDeleteMarkerPrefix =
      '__chronospark_internal_legacy_fallback_deleted__.';

  AccountScopedSharedPrefsStore({
    required this.delegate,
    required this.scope,
    this.legacyOwnership = LegacyScopeOwnership.ambiguous,
  });

  final SharedPrefsStore delegate;
  final AccountStorageScope scope;
  final LegacyScopeOwnership legacyOwnership;

  @override
  Future<void> init() => delegate.init();

  @override
  Future<void> save(String key, String value) {
    return delegate.save(_storageKey(key), value);
  }

  @override
  String? load(String key) {
    final String? scoped = delegate.load(_storageKey(key));
    if (scoped != null || legacyOwnership != LegacyScopeOwnership.provenOwned) {
      return scoped;
    }
    if (_legacyFallbackIsSuppressed(key)) {
      return null;
    }
    return delegate.load(key);
  }

  @override
  Future<void> delete(String key) async {
    // Persist suppression first so a partially failed delete cannot expose a
    // preserved legacy value that belongs to this proven account.
    await delegate.save(_storageKey(_legacyDeleteMarkerFor(key)), 'true');
    await delegate.delete(_storageKey(key));
  }

  @override
  Future<void> clear() async {
    final EnumerableSharedPrefsStore? enumerable =
        delegate is EnumerableSharedPrefsStore
        ? delegate as EnumerableSharedPrefsStore
        : null;
    if (enumerable == null) {
      throw StateError(
        'Account-scoped preference clearing requires enumerable storage.',
      );
    }
    final String suffix = _scopeSuffix();
    final String clearMarkerStorageKey = _storageKey(_legacyClearMarker);
    await delegate.save(clearMarkerStorageKey, 'true');
    final Set<String> storedKeys = await enumerable.keys();
    for (final String key in storedKeys.where(
      (String key) => key.endsWith(suffix) && key != clearMarkerStorageKey,
    )) {
      await delegate.delete(key);
    }
  }

  @override
  Future<Set<String>> keys() async {
    final EnumerableSharedPrefsStore? enumerable =
        delegate is EnumerableSharedPrefsStore
        ? delegate as EnumerableSharedPrefsStore
        : null;
    if (enumerable == null) {
      return const <String>{};
    }
    final String suffix = _scopeSuffix();
    final Set<String> storedKeys = await enumerable.keys();
    return Set<String>.unmodifiable(
      storedKeys
          .where(
            (String key) => key.endsWith(suffix) && !_isInternalStorageKey(key),
          )
          .map((String key) => key.substring(0, key.length - suffix.length)),
    );
  }

  bool _legacyFallbackIsSuppressed(String key) {
    return delegate.load(_storageKey(_legacyClearMarker)) != null ||
        delegate.load(_storageKey(_legacyDeleteMarkerFor(key))) != null;
  }

  String _legacyDeleteMarkerFor(String key) {
    return '$_legacyDeleteMarkerPrefix${base64UrlEncode(utf8.encode(key))}';
  }

  bool _isInternalStorageKey(String storageKey) {
    return storageKey.startsWith(_legacyDeleteMarkerPrefix) ||
        storageKey.startsWith(_legacyClearMarker);
  }

  String _storageKey(String key) {
    final AccountStorageNamespace? namespace = scope.namespace;
    if (!scope.isWritable || namespace == null) {
      throw StateError('Account-owned preference storage is not writable.');
    }
    return namespace.scopedKey(key);
  }

  String _scopeSuffix() {
    final String? namespace = scope.v2Namespace;
    if (!scope.isWritable || namespace == null) {
      throw StateError('Account-owned preference storage is not writable.');
    }
    return '.$namespace';
  }
}
