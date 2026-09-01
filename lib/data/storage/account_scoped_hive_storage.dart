import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:hive/hive.dart';

/// Account-owned String storage with preservation-only legacy migration.
///
/// Legacy data is copied only when the authentication boundary has proven the
/// current account owns it. The legacy box is deliberately never cleared.
final class AccountScopedHiveStorage extends HiveStorage<String> {
  AccountScopedHiveStorage({
    required String baseBox,
    required AccountStorageScope scope,
    required HiveStore hive,
    required this.legacyOwnership,
  }) : _scope = scope,
       _hive = hive,
       _legacy = HiveStorage<String>(baseBox, hive: hive),
       super(_scopedBoxName(baseBox, scope), hive: hive);

  static const String migrationMarkerKey =
      '__chronospark_account_scope_migration_v1__';

  final AccountStorageScope _scope;
  final HiveStore _hive;
  final LegacyScopeOwnership legacyOwnership;
  final HiveStorage<String> _legacy;
  Future<void>? _prepareFuture;

  static String _scopedBoxName(String baseBox, AccountStorageScope scope) =>
      scope.isWritable
      ? HiveBoxes.accountScoped(baseBox, scope)
      : '__unavailable_account_storage__';

  bool get isWritable => _scope.isWritable;

  Future<void> prepare() => _prepareFuture ??= _prepare();

  Future<void> _prepare() async {
    _requireWritable();
    final Box<String> scoped = await super.open();
    if (scoped.containsKey(migrationMarkerKey)) return;

    final bool scopedHasData = scoped.keys.any(
      (dynamic key) => key.toString() != migrationMarkerKey,
    );
    if (!scopedHasData && legacyOwnership == LegacyScopeOwnership.provenOwned) {
      await _legacy.open();
      final Map<String, String> legacyValues = <String, String>{
        for (final MapEntry<dynamic, String> entry in _legacy.getAll().entries)
          entry.key.toString(): entry.value,
      };
      if (legacyValues.isNotEmpty) await super.putAll(legacyValues);
    }
    await super.put(migrationMarkerKey, legacyOwnership.name);
  }

  @override
  Future<Box<String>> open() async {
    await prepare();
    return super.open();
  }

  @override
  String? get(String key) {
    _requireWritable();
    if (_hive.isBoxOpen(boxKey)) {
      final Box<String> scoped = super.box();
      if (scoped.containsKey(migrationMarkerKey) || scoped.isNotEmpty) {
        return scoped.get(key);
      }
    }
    if (legacyOwnership == LegacyScopeOwnership.provenOwned &&
        _hive.isBoxOpen(_legacy.boxKey)) {
      unawaited(prepare());
      return _legacy.get(key);
    }
    unawaited(prepare());
    throw StateError('Account-scoped Hive storage is not ready.');
  }

  @override
  Map<dynamic, String> getAll() {
    _requireWritable();
    Map<dynamic, String> values;
    if (_hive.isBoxOpen(boxKey)) {
      final Box<String> scoped = super.box();
      if (scoped.containsKey(migrationMarkerKey) || scoped.isNotEmpty) {
        values = scoped.toMap().cast<dynamic, String>();
      } else if (legacyOwnership == LegacyScopeOwnership.provenOwned &&
          _hive.isBoxOpen(_legacy.boxKey)) {
        unawaited(prepare());
        values = _legacy.getAll();
      } else {
        unawaited(prepare());
        throw StateError('Account-scoped Hive storage is not ready.');
      }
    } else if (legacyOwnership == LegacyScopeOwnership.provenOwned &&
        _hive.isBoxOpen(_legacy.boxKey)) {
      unawaited(prepare());
      values = _legacy.getAll();
    } else {
      unawaited(prepare());
      throw StateError('Account-scoped Hive storage is not ready.');
    }
    return <dynamic, String>{
      for (final MapEntry<dynamic, String> entry in values.entries)
        if (entry.key.toString() != migrationMarkerKey) entry.key: entry.value,
    };
  }

  @override
  Future<void> put(String key, String value) async {
    _requireApplicationKey(key);
    await prepare();
    await super.put(key, value);
  }

  @override
  Future<void> putAll(Map<String, String> values) async {
    if (values.containsKey(migrationMarkerKey)) {
      throw ArgumentError('The account migration marker is reserved.');
    }
    await prepare();
    await super.putAll(values);
  }

  @override
  Future<void> delete(String key) async {
    _requireApplicationKey(key);
    await prepare();
    await super.delete(key);
  }

  @override
  Future<void> clear() async {
    await prepare();
    await super.clear();
    await super.put(migrationMarkerKey, legacyOwnership.name);
  }

  void _requireWritable() {
    if (!_scope.isWritable) {
      throw StateError('Account-owned Hive storage is not writable.');
    }
  }

  void _requireApplicationKey(String key) {
    _requireWritable();
    if (key == migrationMarkerKey) {
      throw ArgumentError('The account migration marker is reserved.');
    }
  }
}
