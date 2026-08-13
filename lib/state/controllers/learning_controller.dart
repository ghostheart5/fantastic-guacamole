import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/app_exception.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final learningProvider = NotifierProvider<LearningController, LearningState>(
  LearningController.new,
);

class LearningController extends Notifier<LearningState> {
  bool _storageCorrupted = false;
  int _writeGeneration = 0;
  Future<void> _writeTail = Future<void>.value();
  @override
  LearningState build() {
    _load();
    return const LearningState();
  }

  SecureStore get _store => ref.read(secureStoreProvider);
  static const String _storageKey = 'ai_learning';

  static String storageKeyForUser(String? userId) {
    final String value = userId?.trim() ?? '';
    final String scope = value.isEmpty
        ? 'signed_out'
        : value.replaceAll(RegExp('[^a-zA-Z0-9._-]'), '_');
    return '$_storageKey.$scope';
  }

  static Future<void> migrateLegacyStorage({
    required SecureStore store,
    required String userId,
  }) async {
    final String targetKey = storageKeyForUser(userId);
    if (await store.readString(targetKey) != null) return;

    final String? legacyValue = await store.readString(_storageKey);
    if (legacyValue == null) return;

    await store.writeString(targetKey, legacyValue);
    await store.delete(_storageKey);
  }

  Future<void> _load() async {
    try {
      final String? raw = await _store.readString(_storageKey);
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
    if (_storageCorrupted) {
      throw const StorageException(
        'Learning state storage is corrupted. Reset or recover it before saving.',
      );
    }
    state = updated;
    final int generation = _writeGeneration;
    final String encoded = jsonEncode(updated.toJson());
    final Future<void> previous = _writeTail.catchError((Object _) {});
    final Future<void> write = previous.then((_) async {
      if (generation != _writeGeneration) return;
      await _store.writeString(_storageKey, encoded);
    });
    _writeTail = write;
    await write;
  }

  Future<void> reset() async {
    state = const LearningState();
    final int generation = _writeGeneration;
    final Future<void> previous = _writeTail.catchError((Object _) {});
    final Future<void> delete = previous.then((_) async {
      if (generation != _writeGeneration) return;
      await _store.delete(_storageKey);
    });
    _writeTail = delete;
    await delete;
  }

  Future<void> cancelAndDrainWrites() async {
    _writeGeneration++;
    await _writeTail.catchError((Object _) {});
  }
}
