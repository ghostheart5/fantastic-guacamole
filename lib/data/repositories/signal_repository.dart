import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/signal_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_signal_repository.dart';

class SignalRepository implements ISignalRepository {
  SignalRepository(this._store);

  static const String _key = 'signals_v1';

  final SharedPrefsStore _store;

  @override
  Future<List<SignalEntity>> getSignals() async {
    final String? raw = _store.load(_key);
    if (raw == null || raw.trim().isEmpty) {
      return const <SignalEntity>[];
    }
    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .toList(growable: false);
    } catch (error, stackTrace) {
      // Corrupted payload: return the empty/absent value so the app stays
      // usable, but make it observable instead of silently
      // indistinguishable from "user has no signals".
      Logger.errorCategory(
        'StorageCorruption',
        'Failed to decode stored signals; returning empty result.',
        error,
        stackTrace,
      );
      return const <SignalEntity>[];
    }
  }

  @override
  Future<void> saveSignal(SignalEntity signal) async {
    final List<SignalEntity> existing = (await getSignals()).toList(
      growable: true,
    );
    final int index = existing.indexWhere(
      (SignalEntity item) => item.id == signal.id,
    );
    if (index >= 0) {
      existing[index] = signal;
    } else {
      existing.insert(0, signal);
    }
    await _store.save(
      _key,
      jsonEncode(existing.map(_toJson).toList(growable: false)),
    );
  }

  @override
  Future<bool> exists(String id) async {
    final List<SignalEntity> signals = await getSignals();
    return signals.any((SignalEntity item) => item.id == id);
  }

  @override
  Future<void> removeSignal(String id) async {
    final List<SignalEntity> next = (await getSignals())
        .where((SignalEntity item) => item.id != id)
        .toList(growable: false);
    await _store.save(
      _key,
      jsonEncode(next.map(_toJson).toList(growable: false)),
    );
  }

  @override
  Future<List<SignalEntity>> searchSignals(String query) async {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return getSignals();
    }
    final List<SignalEntity> signals = await getSignals();
    return signals
        .where((SignalEntity item) => item.matches(normalized))
        .toList(growable: false);
  }

  static SignalEntity _fromJson(Map<String, dynamic> json) {
    return SignalEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Signal',
      summary: json['summary'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
      action: json['action'] as String?,
    );
  }

  static Map<String, dynamic> _toJson(SignalEntity signal) {
    return <String, dynamic>{
      'id': signal.id,
      'title': signal.title,
      'summary': signal.summary,
      'createdAt': signal.createdAt.toIso8601String(),
      'tags': signal.tags,
      'action': signal.action,
    };
  }
}
