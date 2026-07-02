import 'dart:convert';

import 'package:fantastic_guacamole/data/di/services_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final learningProvider = NotifierProvider<LearningController, LearningState>(
  LearningController.new,
);

class LearningController extends Notifier<LearningState> {
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
    } catch (_) {
      // Keep defaults when persistence is empty or invalid.
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
    state = updated;
    await _store.writeString(_storageKey, jsonEncode(updated.toJson()));
  }

  Future<void> reset() async {
    state = const LearningState();
    await _store.delete(_storageKey);
  }
}
