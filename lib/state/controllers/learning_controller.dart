import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final learningProvider = NotifierProvider<LearningController, LearningState>(
  LearningController.new,
);

class LearningController extends Notifier<LearningState> {
  bool _storageCorrupted = false;
  int _initGeneration = 0;
  int _writeGeneration = 0;
  Future<void> _writeTail = Future<void>.value();
  String? _activeStorageKey;

  @override
  LearningState build() {
    final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
    _storageCorrupted = false;
    _writeGeneration++;
    final int generation = ++_initGeneration;
    _activeStorageKey = null;
    if (scope.isAuthenticated && scope.v2Namespace != null) {
      final String key = canonicalStorageKeyForScope(scope);
      _activeStorageKey = key;
      Future<void>.microtask(() => _load(key, generation));
    }
    return const LearningState();
  }

  SecureStore get _store => ref.read(secureStoreProvider);
  static const String _canonicalStorageKey = 'ai_learning_v2';
  static const String _legacyStorageKey = 'ai_learning';

  /// Legacy V1 helper retained only to identify preserved, ambiguous records.
  static String storageKeyForUser(String? userId) {
    final String value = userId?.trim() ?? '';
    final String scope = value.isEmpty
        ? 'signed_out'
        : value.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
    return '$_legacyStorageKey.$scope';
  }

  static String canonicalStorageKeyForScope(AccountStorageScope scope) {
    final String? namespace = scope.v2Namespace;
    if (!scope.isAuthenticated || namespace == null) {
      throw StateError(
        'Learning persistence is unavailable outside a safe authenticated scope.',
      );
    }
    return '$_canonicalStorageKey.$namespace';
  }

  static String canonicalStorageKeyForUser(String userId) {
    return canonicalStorageKeyForScope(
      AccountStorageScope.authenticated(userId),
    );
  }

  /// Global and V1-sanitized Learning records carry no owner proof. They are
  /// deliberately retained as inactive legacy data.
  static Future<LearningLegacyMigrationResult> migrateLegacyStorage({
    required SecureStore store,
    required String userId,
  }) async => LearningLegacyMigrationResult.preservedAmbiguous;

  bool get _isStorageAvailable => _activeStorageKey != null;

  Future<void> _load(String key, int generation) async {
    try {
      final String? raw = await _store.readString(key);
      if (generation != _initGeneration || key != _activeStorageKey) return;
      if (raw == null || raw.trim().isEmpty) {
        return;
      }

      state = LearningState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (error) {
      _storageCorrupted = true;
      Logger.error('Learning state storage is corrupted.', error);
    }
  }

  Future<void> update({required bool success, required int difficulty}) async {
    final AdaptiveLearning adaptiveLearning = AdaptiveLearning(state);
    final LearningState updated = success
        ? adaptiveLearning.onTaskComplete(difficulty)
        : adaptiveLearning.onTaskSkipped(difficulty);
    await apply(updated);
  }

  Future<void> apply(LearningState updated) async {
    if (!_isStorageAvailable) return;
    if (_storageCorrupted) {
      throw const StorageException(
        'Learning state storage is corrupted. Reset or recover it before saving.',
      );
    }
    state = updated;
    final String key = _activeStorageKey!;
    final int generation = _writeGeneration;
    final String encoded = jsonEncode(updated.toJson());
    final Future<void> previous = _writeTail.catchError((Object _) {});
    final Future<void> write = previous.then((_) async {
      if (generation != _writeGeneration || key != _activeStorageKey) return;
      await _store.writeString(key, encoded);
    });
    _writeTail = write;
    await write;
  }

  Future<void> reset() async {
    if (!_isStorageAvailable) return;
    state = const LearningState();
    final String key = _activeStorageKey!;
    final int generation = _writeGeneration;
    final Future<void> previous = _writeTail.catchError((Object _) {});
    final Future<void> delete = previous.then((_) async {
      if (generation != _writeGeneration || key != _activeStorageKey) return;
      await _store.delete(key);
    });
    _writeTail = delete;
    await delete;
  }

  Future<void> cancelAndDrainWrites() async {
    _writeGeneration++;
    await _writeTail.catchError((Object _) {});
  }
}

enum LearningLegacyMigrationResult { preservedAmbiguous }
