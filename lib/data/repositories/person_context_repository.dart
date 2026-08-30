import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';

final class PersonContextRepository {
  PersonContextRepository(
    this._store,
    this._scope, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const String _keyPrefix = 'person_context_spine_v1';
  static const String _corruptionPrefix = 'person_context_spine_v1_corrupt';

  final SharedPrefsStore _store;
  final AccountStorageScope _scope;
  final DateTime Function() _clock;
  Future<void> _writeTail = Future<void>.value();
  String? _pendingCorruptPayload;

  String? get storageKey {
    final String? namespace = _scope.v2Namespace;
    return _scope.isWritable && namespace != null
        ? '$_keyPrefix.$namespace'
        : null;
  }

  String? get corruptionKey {
    final String? namespace = _scope.v2Namespace;
    return _scope.isWritable && namespace != null
        ? '$_corruptionPrefix.$namespace'
        : null;
  }

  Future<PersonContextSpine> load() async {
    final String key = _requireStorageKey();
    await _store.init();
    final String? raw = _store.load(key);
    if (raw == null || raw.trim().isEmpty) {
      return PersonContextSpine.empty(_scope.v2Namespace!, _clock());
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<dynamic, dynamic> ||
          decoded.keys.any((dynamic key) => key is! String)) {
        throw const FormatException('Person context envelope is malformed.');
      }
      final PersonContextSpine spine = PersonContextSpine.fromJson(
        decoded.cast<String, dynamic>(),
      );
      if (spine.accountScopeId != _scope.v2Namespace) {
        throw const FormatException('Person context owner does not match.');
      }
      _pendingCorruptPayload = null;
      return spine;
    } on Object {
      _pendingCorruptPayload = raw;
      return PersonContextSpine.empty(_scope.v2Namespace!, _clock());
    }
  }

  Future<void> save(PersonContextSpine spine) {
    return _serialize(() async {
      await _store.init();
      _validateOwned(spine);
      await _preservePendingCorruption();
      await _store.save(_requireStorageKey(), jsonEncode(spine.toJson()));
    });
  }

  Future<void> upsert(PersonContextSignal signal) {
    return _serialize(() async {
      final PersonContextSpine current = await load();
      final List<PersonContextSignal> next = current.signals.toList();
      final int index = next.indexWhere((item) => item.id == signal.id);
      if (index >= 0) {
        next[index] = signal;
      } else {
        next.add(signal);
      }
      final PersonContextSpine updated = PersonContextSpine(
        accountScopeId: current.accountScopeId,
        updatedAt: _clock().toUtc(),
        signals: next,
      );
      await _preservePendingCorruption();
      await _store.save(_requireStorageKey(), jsonEncode(updated.toJson()));
    });
  }

  Future<void> remove(String signalId) {
    return _serialize(() async {
      final PersonContextSpine current = await load();
      final PersonContextSpine updated = PersonContextSpine(
        accountScopeId: current.accountScopeId,
        updatedAt: _clock().toUtc(),
        signals: current.signals
            .where((signal) => signal.id != signalId)
            .toList(growable: false),
      );
      await _preservePendingCorruption();
      await _store.save(_requireStorageKey(), jsonEncode(updated.toJson()));
    });
  }

  Future<void> clear() {
    return _serialize(() async {
      await _store.init();
      await _store.delete(_requireStorageKey());
      final String? recoveryKey = corruptionKey;
      if (recoveryKey != null) await _store.delete(recoveryKey);
      _pendingCorruptPayload = null;
    });
  }

  Future<Map<String, dynamic>> export() async {
    return (await load()).toExportJson(_clock());
  }

  void _validateOwned(PersonContextSpine spine) {
    spine.validate();
    if (spine.accountScopeId != _scope.v2Namespace) {
      throw StateError('Person context does not belong to this account.');
    }
  }

  Future<void> _preservePendingCorruption() async {
    final String? raw = _pendingCorruptPayload;
    final String? recoveryKey = corruptionKey;
    if (raw == null || recoveryKey == null) return;
    final String? existing = _store.load(recoveryKey);
    if (existing != null && existing != raw) {
      throw StateError('A person context corruption backup already exists.');
    }
    if (existing == null) await _store.save(recoveryKey, raw);
    _pendingCorruptPayload = null;
  }

  String _requireStorageKey() {
    final String? key = storageKey;
    if (key == null) {
      throw StateError(
        'Person context is unavailable without a verified account scope.',
      );
    }
    return key;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final Future<void> next = _writeTail.then(
      (_) => action(),
      onError: (Object _, StackTrace _) => action(),
    );
    _writeTail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
