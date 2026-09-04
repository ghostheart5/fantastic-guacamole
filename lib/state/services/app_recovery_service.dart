import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:flutter/foundation.dart';

@immutable
class AppRecoveryState {
  const AppRecoveryState({required this.lastPrimaryViewName});

  final String lastPrimaryViewName;
}

class AppRecoveryService {
  AppRecoveryService({SharedPrefsStore? store})
    : _store = store ?? const SharedPrefsStoreAdapter();

  // Keep the established key so existing route recovery survives this model
  // tightening. The unsupported task/draft keys are removed on read/clear.
  static const _kLastPrimaryViewName = 'rec_last_route';
  static const _kLegacyTaskId = 'rec_active_task';
  static const _kLegacyDraftTitle = 'rec_draft_title';
  final SharedPrefsStore _store;

  Future<void> saveState({
    String? lastPrimaryViewName,
    bool clearLastPrimaryView = false,
  }) async {
    try {
      await _store.init();
      if (clearLastPrimaryView) {
        await _store.delete(_kLastPrimaryViewName);
      } else if (lastPrimaryViewName != null) {
        await _saveNormalized(_kLastPrimaryViewName, lastPrimaryViewName);
      }
    } on Object catch (error) {
      Logger.warn('RECOVERY_SAVE_FAILED: $error');
      // Non-fatal — recovery state is best-effort
    }
  }

  Future<void> _saveNormalized(String key, String value) async {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      await _store.delete(key);
      return;
    }
    await _store.save(key, normalized);
  }

  Future<AppRecoveryState?> loadState() async {
    try {
      await _store.init();
      final String? lastPrimaryViewName = _normalizedOrNull(
        _store.load(_kLastPrimaryViewName),
      );
      try {
        await _removeUnsupportedLegacyFields();
      } on Object catch (error) {
        Logger.warn('RECOVERY_LEGACY_CLEANUP_FAILED: $error');
      }
      if (lastPrimaryViewName == null) {
        return null;
      }
      return AppRecoveryState(lastPrimaryViewName: lastPrimaryViewName);
    } on Object catch (error) {
      Logger.warn('RECOVERY_LOAD_FAILED: $error');
      return null;
    }
  }

  String? _normalizedOrNull(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _removeUnsupportedLegacyFields() async {
    for (final String key in <String>[_kLegacyTaskId, _kLegacyDraftTitle]) {
      if (_store.load(key) != null) {
        await _store.delete(key);
      }
    }
  }

  Future<void> clearAll() async {
    try {
      await _store.init();
      await _store.delete(_kLastPrimaryViewName);
      await _store.delete(_kLegacyTaskId);
      await _store.delete(_kLegacyDraftTitle);
    } on Object catch (error) {
      Logger.warn('RECOVERY_CLEAR_FAILED: $error');
    }
  }
}
