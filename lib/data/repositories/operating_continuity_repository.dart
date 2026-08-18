import 'dart:convert';

import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/operating_system/i_operating_continuity_repository.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';

class OperatingContinuityRepository implements IOperatingContinuityRepository {
  OperatingContinuityRepository(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const int _schemaVersion = 1;
  static const int _historyLimit = 12;

  final SharedPrefsStore _store;
  final DateTime Function() _clock;

  String _historyKey(String scope) => 'chronospark.operating.history.v1.$scope';
  String _ackKey(String scope) => 'chronospark.operating.ack.v1.$scope';

  @override
  Future<List<OperatingSnapshot>> loadHistory(String accountScope) async {
    await _store.init();
    final String key = _historyKey(accountScope);
    final String? raw = _store.load(key);
    if (raw == null || raw.trim().isEmpty) return const <OperatingSnapshot>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<Object?, Object?>) {
        throw const FormatException('Expected an object.');
      }
      final Map<String, dynamic> envelope = Map<String, dynamic>.from(decoded);
      if ((envelope['schemaVersion'] as num?)?.toInt() != _schemaVersion) {
        throw const FormatException('Unsupported history schema.');
      }
      final List<dynamic> records =
          envelope['snapshots'] as List<dynamic>? ?? const <dynamic>[];
      return records
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<dynamic, dynamic> item) =>
                OperatingSnapshot.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((OperatingSnapshot item) => item.accountScope == accountScope)
          .toList(growable: false);
    } on Object {
      final String quarantineKey =
          '$key.corrupt.${_clock().toUtc().millisecondsSinceEpoch}';
      await _store.save(quarantineKey, raw);
      await _store.delete(key);
      return const <OperatingSnapshot>[];
    }
  }

  @override
  Future<void> saveSnapshot(
    String accountScope,
    OperatingSnapshot snapshot,
  ) async {
    if (snapshot.accountScope != accountScope) {
      throw StateError('Operating snapshot cannot cross account scopes.');
    }
    final List<OperatingSnapshot> existing = await loadHistory(accountScope);
    if (existing.isNotEmpty &&
        existing.last.snapshotId == snapshot.snapshotId) {
      return;
    }
    final List<OperatingSnapshot> next = <OperatingSnapshot>[
      ...existing,
      snapshot,
    ];
    final List<OperatingSnapshot> bounded = next.length <= _historyLimit
        ? next
        : next.sublist(next.length - _historyLimit);
    await _store.save(
      _historyKey(accountScope),
      jsonEncode(<String, dynamic>{
        'schemaVersion': _schemaVersion,
        'writtenAt': _clock().toUtc().toIso8601String(),
        'snapshots': bounded
            .map((OperatingSnapshot item) => item.toJson())
            .toList(growable: false),
      }),
    );
  }

  @override
  Future<String?> loadAcknowledgedSnapshotId(String accountScope) async {
    await _store.init();
    return _store.load(_ackKey(accountScope));
  }

  @override
  Future<void> acknowledge(String accountScope, String snapshotId) async {
    final List<OperatingSnapshot> history = await loadHistory(accountScope);
    if (!history.any(
      (OperatingSnapshot item) => item.snapshotId == snapshotId,
    )) {
      throw StateError(
        'Only a persisted operating snapshot can be acknowledged.',
      );
    }
    await _store.save(_ackKey(accountScope), snapshotId);
  }
}
