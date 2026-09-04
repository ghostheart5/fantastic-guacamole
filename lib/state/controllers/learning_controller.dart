import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/persisted_payload_failure.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/engine/learning/adaptive_learning.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final learningProvider = NotifierProvider<LearningController, LearningState>(
  LearningController.new,
);

class LearningController extends Notifier<LearningState> {
  late SecureStore _store;

  @override
  LearningState build() {
    _store = ref.watch(accountSecureStoreProvider);
    unawaited(_load());
    return const LearningState();
  }

  static const String _storageKey = 'ai_learning';

  Future<void> _load() async {
    try {
      final String? raw = await _store.readString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return;
      }

      state = LearningState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (error, stackTrace) {
      try {
        handlePersistedPayloadDecodeFailure(
          diagnosticCode: 'storage.learning_state_decode_failed',
          error: error,
          stackTrace: stackTrace,
        );
      } on Object {
        Logger.recordDiagnostic(
          code: AppDiagnosticCode.storageLearningStateLoadFailed,
          stackTrace: stackTrace,
        );
      }
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
