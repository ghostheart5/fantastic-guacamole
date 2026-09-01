import 'dart:convert';

import 'package:fantastic_guacamole/core/async/account_storage_mutation.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';

final class PersonContextRepository {
  PersonContextRepository(
    this._store,
    this._scope, {
    DateTime Function()? clock,
    bool Function()? isScopeCurrent,
  }) : _clock = clock ?? DateTime.now,
       _isScopeCurrent = isScopeCurrent ?? _alwaysCurrent;

  static const String _keyPrefix = 'person_context_spine_v1';
  static const String _corruptionPrefix = 'person_context_spine_v1_corrupt';

  final SharedPrefsStore _store;
  final AccountStorageScope _scope;
  final DateTime Function() _clock;
  final bool Function() _isScopeCurrent;

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

  Future<PersonContextSpine> load() {
    return runAccountStorageMutation(_loadLocked);
  }

  Future<PersonContextSpine> _loadLocked() async {
    _requireCurrentScope();
    final String key = _requireStorageKey();
    await _store.init();
    _requireCurrentScope();
    final String? raw = _store.load(key);
    if (raw == null) {
      return PersonContextSpine.empty(_scope.v2Namespace!, _clock());
    }
    if (raw.trim().isEmpty) {
      await _preserveCorruption(raw);
      throw const PersonContextCorruptionException();
    }
    late final PersonContextSpine spine;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<dynamic, dynamic> ||
          decoded.keys.any((dynamic key) => key is! String)) {
        throw const FormatException('Person context envelope is malformed.');
      }
      spine = PersonContextSpine.fromJson(decoded.cast<String, dynamic>());
      if (spine.accountScopeId != _scope.v2Namespace) {
        throw const FormatException('Person context owner does not match.');
      }
    } on Object {
      await _preserveCorruption(raw);
      throw const PersonContextCorruptionException();
    }
    final PersonContextSpine retained = await _purgeExpired(spine);
    _requireCurrentScope();
    return retained;
  }

  Future<void> save(PersonContextSpine spine) {
    return runAccountStorageMutation(() async {
      _requireCurrentScope();
      await _store.init();
      await _throwIfCorruptActivePayload();
      _validateOwned(spine);
      await _store.save(_requireStorageKey(), jsonEncode(spine.toJson()));
      _requireCurrentScope();
    });
  }

  Future<void> upsert(PersonContextSignal signal) {
    return runAccountStorageMutation(() async {
      _requireCurrentScope();
      final PersonContextSpine current = await _loadLocked();
      final List<PersonContextSignal> next = current.signals.toList();
      final int index = next.indexWhere((item) => item.id == signal.id);
      if (index >= 0) {
        next[index] = signal;
      } else {
        next.add(signal);
      }
      final PersonContextSpine updated = PersonContextSpine(
        accountScopeId: current.accountScopeId,
        updatedAt: _updatedAtFor(next),
        signals: next,
      );
      await _store.save(_requireStorageKey(), jsonEncode(updated.toJson()));
      _requireCurrentScope();
    });
  }

  Future<void> remove(String signalId) {
    return runAccountStorageMutation(() async {
      _requireCurrentScope();
      final PersonContextSpine current = await _loadLocked();
      final List<PersonContextSignal> retained = current.signals
          .where((signal) => signal.id != signalId)
          .toList(growable: false);
      final PersonContextSpine updated = PersonContextSpine(
        accountScopeId: current.accountScopeId,
        updatedAt: _updatedAtFor(retained),
        signals: retained,
      );
      await _store.save(_requireStorageKey(), jsonEncode(updated.toJson()));
      _requireCurrentScope();
    });
  }

  Future<PersonContextSignal> updateSignal(
    String signalId,
    PersonContextSignal Function(PersonContextSignal current) update,
  ) {
    return runAccountStorageMutation(() async {
      _requireCurrentScope();
      final PersonContextSpine current = await _loadLocked();
      final List<PersonContextSignal> next = current.signals.toList();
      final int index = next.indexWhere((signal) => signal.id == signalId);
      if (index < 0) {
        throw StateError('Person context changed before this update.');
      }
      final PersonContextSignal updatedSignal = update(next[index]);
      if (updatedSignal.id != signalId) {
        throw StateError('Person context updates cannot change identity.');
      }
      next[index] = updatedSignal;
      final PersonContextSpine updated = PersonContextSpine(
        accountScopeId: current.accountScopeId,
        updatedAt: _updatedAtFor(next),
        signals: next,
      );
      await _store.save(_requireStorageKey(), jsonEncode(updated.toJson()));
      _requireCurrentScope();
      return updatedSignal;
    });
  }

  Future<void> clear() {
    return runAccountStorageMutation(() async {
      _requireCurrentScope();
      await _store.init();
      await _store.delete(_requireStorageKey());
      final String? recoveryKey = corruptionKey;
      if (recoveryKey != null) await _store.delete(recoveryKey);
      _requireCurrentScope();
    });
  }

  Future<Map<String, dynamic>> export() {
    return runAccountStorageMutation(() async {
      _requireCurrentScope();
      final Map<String, dynamic> result = (await _loadLocked()).toExportJson(
        _clock(),
      );
      _requireCurrentScope();
      return result;
    });
  }

  void _validateOwned(PersonContextSpine spine) {
    spine.validate();
    if (spine.accountScopeId != _scope.v2Namespace) {
      throw StateError('Person context does not belong to this account.');
    }
  }

  Future<void> _preserveCorruption(String raw) async {
    final String? recoveryKey = corruptionKey;
    if (recoveryKey == null) return;
    final String? existing = _store.load(recoveryKey);
    if (existing != null && existing != raw) {
      throw StateError('A person context corruption backup already exists.');
    }
    if (existing == null) await _store.save(recoveryKey, raw);
  }

  Future<void> _throwIfCorruptActivePayload() async {
    final String key = _requireStorageKey();
    final String? raw = _store.load(key);
    if (raw == null) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<dynamic, dynamic> ||
          decoded.keys.any((dynamic key) => key is! String)) {
        throw const FormatException();
      }
      final PersonContextSpine spine = PersonContextSpine.fromJson(
        decoded.cast<String, dynamic>(),
      );
      if (spine.accountScopeId != _scope.v2Namespace) {
        throw const FormatException();
      }
    } on Object {
      await _preserveCorruption(raw);
      throw const PersonContextCorruptionException();
    }
  }

  Future<PersonContextSpine> _purgeExpired(PersonContextSpine spine) async {
    final DateTime now = _clock().toUtc();
    final List<PersonContextSignal> retained = spine.signals
        .where(
          (PersonContextSignal signal) =>
              signal.deletionBehavior !=
                  PersonContextDeletionBehavior.expiresAutomatically ||
              now.isBefore(signal.expiresAt.toUtc()),
        )
        .toList(growable: false);
    if (retained.length == spine.signals.length) return spine;
    final PersonContextSpine pruned = PersonContextSpine(
      accountScopeId: spine.accountScopeId,
      updatedAt: _updatedAtFor(retained),
      signals: retained,
    );
    await _store.save(_requireStorageKey(), jsonEncode(pruned.toJson()));
    _requireCurrentScope();
    return pruned;
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

  void _requireCurrentScope() {
    if (!_isScopeCurrent()) {
      throw StateError('Person context account scope changed during access.');
    }
  }

  DateTime _updatedAtFor(List<PersonContextSignal> signals) {
    DateTime updatedAt = _clock().toUtc();
    for (final PersonContextSignal signal in signals) {
      final DateTime recordedAt = signal.recordedAt.toUtc();
      if (recordedAt.isAfter(updatedAt)) updatedAt = recordedAt;
    }
    return updatedAt;
  }
}

bool _alwaysCurrent() => true;
