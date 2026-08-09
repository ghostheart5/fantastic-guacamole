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
  @override
  LearningState build() {
    _load();
    return const LearningState();
  }

  SecureStore get _store => ref.read(secureStoreProvider);
  static const String _storageKey = 'ai_learning';

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
    await _store.writeString(_storageKey, jsonEncode(updated.toJson()));
  }

  Future<void> reset() async {
    state = const LearningState();
    await _store.delete(_storageKey);
  }
}
