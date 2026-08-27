import 'dart:convert';
import 'dart:math';

import 'package:fantastic_guacamole/core/async/keyed_mutation_coordinator.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:flutter/foundation.dart';

@immutable
class OfflineSyncQueueItem {
  const OfflineSyncQueueItem({
    required this.id,
    required this.actionType,
    required this.dedupeKey,
    required this.payload,
    required this.enqueuedAtUtc,
    required this.attempts,
    this.lastAttemptAtUtc,
    this.nextAttemptAtUtc,
    this.deadLettered = false,
    this.accountId,
  });

  final String id;
  final String actionType;
  final String dedupeKey;
  final Map<String, dynamic> payload;
  final String enqueuedAtUtc;
  final int attempts;
  final String? lastAttemptAtUtc;
  final String? nextAttemptAtUtc;
  final bool deadLettered;
  final String? accountId;

  OfflineSyncQueueItem copyWith({
    int? attempts,
    String? lastAttemptAtUtc,
    String? nextAttemptAtUtc,
    bool? deadLettered,
  }) {
    return OfflineSyncQueueItem(
      id: id,
      actionType: actionType,
      dedupeKey: dedupeKey,
      payload: payload,
      enqueuedAtUtc: enqueuedAtUtc,
      attempts: attempts ?? this.attempts,
      lastAttemptAtUtc: lastAttemptAtUtc ?? this.lastAttemptAtUtc,
      nextAttemptAtUtc: nextAttemptAtUtc ?? this.nextAttemptAtUtc,
      deadLettered: deadLettered ?? this.deadLettered,
      accountId: accountId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'actionType': actionType,
      'dedupeKey': dedupeKey,
      'payload': payload,
      'enqueuedAtUtc': enqueuedAtUtc,
      'attempts': attempts,
      'lastAttemptAtUtc': lastAttemptAtUtc,
      'nextAttemptAtUtc': nextAttemptAtUtc,
      'deadLettered': deadLettered,
      'accountId': accountId,
    };
  }

  factory OfflineSyncQueueItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> payload =
        (json['payload'] as Map?)?.map<String, dynamic>(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        ) ??
        <String, dynamic>{};

    return OfflineSyncQueueItem(
      id: json['id']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? '',
      dedupeKey: json['dedupeKey']?.toString() ?? '',
      payload: payload,
      enqueuedAtUtc: json['enqueuedAtUtc']?.toString() ?? '',
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastAttemptAtUtc: json['lastAttemptAtUtc']?.toString(),
      nextAttemptAtUtc: json['nextAttemptAtUtc']?.toString(),
      deadLettered: json['deadLettered'] == true,
      accountId: json['accountId']?.toString(),
    );
  }
}

class OfflineSyncQueueService {
  OfflineSyncQueueService(
    this._prefs, {
    String? accountId,
    this._enforceAccountBinding = false,
    KeyedMutationCoordinator? mutationCoordinator,
  }) : _accountId = accountId?.trim().isEmpty == true
           ? null
           : accountId?.trim(),
       _mutations = mutationCoordinator ?? KeyedMutationCoordinator.shared;

  static const String storageKey = 'offline_sync_queue_v1';
  static const String corruptStorageKey = 'offline_sync_queue_corrupt_v1';
  static const int maxAttempts = 8;
  static const Duration deadLetterRetention = Duration(days: 30);

  final HiveStorage<String> _prefs;
  final bool _enforceAccountBinding;
  final String? _accountId;
  final KeyedMutationCoordinator _mutations;

  String? get accountId => _accountId;
  bool get requiresAccountBinding => _enforceAccountBinding;

  String get _scopedStorageKey => !_enforceAccountBinding || _accountId == null
      ? storageKey
      : '$storageKey:$_accountId';

  String get _scopedCorruptStorageKey =>
      !_enforceAccountBinding || _accountId == null
      ? corruptStorageKey
      : '$corruptStorageKey:$_accountId';

  String get _mutationKey => 'offline-sync-queue:$_scopedStorageKey';

  Future<List<OfflineSyncQueueItem>> loadQueue() async {
    // Reads stay available while replay executors run. Only read-modify-write
    // operations are serialized; serializing this read would deadlock an
    // executor that observes queue state during replay.
    return _loadQueue();
  }

  Future<List<OfflineSyncQueueItem>> _loadQueue() async {
    if (_enforceAccountBinding && _accountId == null) {
      return const <OfflineSyncQueueItem>[];
    }
    await _prefs.open();
    final String? encoded = _prefs.get(_scopedStorageKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return const <OfflineSyncQueueItem>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      await _preserveCorruptPayload(encoded);
      return const <OfflineSyncQueueItem>[];
    }
    if (decoded is! List<dynamic>) {
      await _preserveCorruptPayload(encoded);
      return const <OfflineSyncQueueItem>[];
    }
    final List<dynamic> raw = decoded;
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> value) => OfflineSyncQueueItem.fromJson(
            value.map<String, dynamic>(
              (dynamic key, dynamic item) => MapEntry(key.toString(), item),
            ),
          ),
        )
        .where(
          (OfflineSyncQueueItem item) =>
              item.id.isNotEmpty &&
              item.actionType.isNotEmpty &&
              (!_enforceAccountBinding || item.accountId == _accountId),
        )
        .toList(growable: false);
  }

  Future<int> queuedCount() async {
    final List<OfflineSyncQueueItem> queue = await loadQueue();
    return queue.length;
  }

  Future<List<OfflineSyncQueueItem>> deadLetteredItems() async {
    final List<OfflineSyncQueueItem> queue = await loadQueue();
    return queue
        .where((OfflineSyncQueueItem item) => item.deadLettered)
        .toList(growable: false);
  }

  Future<int> deadLetteredCount() async {
    return (await deadLetteredItems()).length;
  }

  Future<void> enqueue({
    required String actionType,
    required String dedupeKey,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    return _serialize(() async {
      if (_enforceAccountBinding && _accountId == null) return;
      final List<OfflineSyncQueueItem> queue = await _loadQueue();
      if (queue.any(
        (OfflineSyncQueueItem item) => item.dedupeKey == dedupeKey,
      )) {
        return;
      }

      final DateTime now = DateTime.now().toUtc();
      final OfflineSyncQueueItem item = OfflineSyncQueueItem(
        id: '${now.microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}-$actionType',
        actionType: actionType,
        dedupeKey: dedupeKey,
        payload: payload,
        enqueuedAtUtc: now.toIso8601String(),
        attempts: 0,
        accountId: _enforceAccountBinding ? _accountId : null,
      );

      await _persist(<OfflineSyncQueueItem>[...queue, item]);
    });
  }

  Future<void> clear() async {
    return _serialize(() async {
      if (_enforceAccountBinding && _accountId == null) return;
      await _prefs.delete(_scopedStorageKey);
    });
  }

  Future<int> retryDeadLetters({String? actionType}) {
    return _serialize(() async {
      if (_enforceAccountBinding && _accountId == null) return 0;
      final List<OfflineSyncQueueItem> queue = await _loadQueue();
      int restored = 0;
      final List<OfflineSyncQueueItem> updated = queue
          .map((OfflineSyncQueueItem item) {
            final bool matches =
                item.deadLettered &&
                (actionType == null || item.actionType == actionType);
            if (!matches) return item;
            restored++;
            return item.copyWith(
              attempts: 0,
              lastAttemptAtUtc: '',
              nextAttemptAtUtc: '',
              deadLettered: false,
            );
          })
          .toList(growable: false);
      if (restored > 0) {
        await _persist(updated);
      }
      return restored;
    });
  }

  Future<int> pruneExpiredDeadLetters({DateTime? nowUtc}) {
    return _serialize(() async {
      if (_enforceAccountBinding && _accountId == null) return 0;
      final DateTime now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
      final List<OfflineSyncQueueItem> queue = await _loadQueue();
      final List<OfflineSyncQueueItem> retained = <OfflineSyncQueueItem>[];
      int pruned = 0;
      for (final OfflineSyncQueueItem item in queue) {
        if (item.deadLettered && _isExpiredDeadLetter(item, now)) {
          pruned++;
          continue;
        }
        retained.add(item);
      }
      if (pruned > 0) {
        await _persist(retained);
      }
      return pruned;
    });
  }

  Future<int> replay({
    required Future<bool> Function(OfflineSyncQueueItem item) executor,
    int maxItems = 10,
  }) async {
    return _serialize(() async {
      if (_enforceAccountBinding && _accountId == null) return 0;
      final List<OfflineSyncQueueItem> queue = await _loadQueue();
      if (queue.isEmpty) {
        return 0;
      }

      int processed = 0;
      final List<OfflineSyncQueueItem> working =
          List<OfflineSyncQueueItem>.from(queue, growable: true);

      for (final OfflineSyncQueueItem item in queue) {
        if (processed >= maxItems) {
          break;
        }
        if (item.deadLettered || !_isEligible(item)) {
          continue;
        }

        final DateTime now = DateTime.now().toUtc();
        final int nextAttempts = item.attempts + 1;
        final OfflineSyncQueueItem attempted = item.copyWith(
          attempts: nextAttempts,
          lastAttemptAtUtc: now.toIso8601String(),
        );

        final int index = working.indexWhere(
          (OfflineSyncQueueItem queued) => queued.id == item.id,
        );
        if (index != -1) {
          working[index] = attempted;
        }

        bool success = false;
        try {
          success = await executor(attempted);
        } on Object {
          success = false;
        }

        if (success) {
          working.removeWhere(
            (OfflineSyncQueueItem queued) => queued.id == item.id,
          );
        } else if (nextAttempts >= maxAttempts) {
          working[index] = attempted.copyWith(deadLettered: true);
        } else {
          working[index] = attempted.copyWith(
            nextAttemptAtUtc: now
                .add(_retryDelay(nextAttempts))
                .toIso8601String(),
          );
        }

        processed++;
        // Checkpoint every completed attempt. If the process exits while a later
        // item is executing, an already-successful item is not replayed again.
        await _persist(working);
      }

      return processed;
    });
  }

  bool _isEligible(OfflineSyncQueueItem item) {
    final String? nextAttempt = item.nextAttemptAtUtc;
    if (nextAttempt == null || nextAttempt.trim().isEmpty) return true;
    final DateTime? scheduled = DateTime.tryParse(nextAttempt)?.toUtc();
    return scheduled == null || !scheduled.isAfter(DateTime.now().toUtc());
  }

  Duration _retryDelay(int attempts) {
    final int exponent = attempts <= 1
        ? 0
        : attempts >= 6
        ? 5
        : attempts - 1;
    return Duration(minutes: 1 << exponent);
  }

  bool _isExpiredDeadLetter(OfflineSyncQueueItem item, DateTime nowUtc) {
    final DateTime? lastAttempt = DateTime.tryParse(
      item.lastAttemptAtUtc ?? '',
    )?.toUtc();
    final DateTime? enqueuedAt = DateTime.tryParse(item.enqueuedAtUtc)?.toUtc();
    final DateTime basis = lastAttempt ?? enqueuedAt ?? nowUtc;
    return nowUtc.difference(basis) >= deadLetterRetention;
  }

  Future<void> _persist(List<OfflineSyncQueueItem> queue) {
    return _prefs.put(
      _scopedStorageKey,
      jsonEncode(
        queue
            .map((OfflineSyncQueueItem item) => item.toJson())
            .toList(growable: false),
      ),
    );
  }

  Future<void> _preserveCorruptPayload(String payload) async {
    await _prefs.put(_scopedCorruptStorageKey, payload);
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    return _mutations.runExclusive<T>(_mutationKey, operation);
  }
}
