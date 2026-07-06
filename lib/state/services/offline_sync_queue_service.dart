import 'package:fantastic_guacamole/data/local/shared_prefs_storage.dart';
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
  });

  final String id;
  final String actionType;
  final String dedupeKey;
  final Map<String, dynamic> payload;
  final String enqueuedAtUtc;
  final int attempts;
  final String? lastAttemptAtUtc;

  OfflineSyncQueueItem copyWith({int? attempts, String? lastAttemptAtUtc}) {
    return OfflineSyncQueueItem(
      id: id,
      actionType: actionType,
      dedupeKey: dedupeKey,
      payload: payload,
      enqueuedAtUtc: enqueuedAtUtc,
      attempts: attempts ?? this.attempts,
      lastAttemptAtUtc: lastAttemptAtUtc ?? this.lastAttemptAtUtc,
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
    );
  }
}

class OfflineSyncQueueService {
  OfflineSyncQueueService(this._prefs);

  static const String storageKey = 'offline_sync_queue_v1';

  final SharedPrefsStorage _prefs;

  Future<List<OfflineSyncQueueItem>> loadQueue() async {
    final List<dynamic> raw = _prefs.getJsonList(storageKey);
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
              item.id.isNotEmpty && item.actionType.isNotEmpty,
        )
        .toList(growable: false);
  }

  Future<int> queuedCount() async {
    final List<OfflineSyncQueueItem> queue = await loadQueue();
    return queue.length;
  }

  Future<void> enqueue({
    required String actionType,
    required String dedupeKey,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final List<OfflineSyncQueueItem> queue = await loadQueue();
    if (queue.any((OfflineSyncQueueItem item) => item.dedupeKey == dedupeKey)) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final OfflineSyncQueueItem item = OfflineSyncQueueItem(
      id: '${now.millisecondsSinceEpoch}-$actionType',
      actionType: actionType,
      dedupeKey: dedupeKey,
      payload: payload,
      enqueuedAtUtc: now.toIso8601String(),
      attempts: 0,
    );

    await _persist(<OfflineSyncQueueItem>[...queue, item]);
  }

  Future<void> clear() async {
    await _prefs.remove(storageKey);
  }

  Future<int> replay({
    required Future<bool> Function(OfflineSyncQueueItem item) executor,
    int maxItems = 10,
  }) async {
    final List<OfflineSyncQueueItem> queue = await loadQueue();
    if (queue.isEmpty) {
      return 0;
    }

    int processed = 0;
    final List<OfflineSyncQueueItem> working = List<OfflineSyncQueueItem>.from(
      queue,
      growable: true,
    );

    for (final OfflineSyncQueueItem item in queue) {
      if (processed >= maxItems) {
        break;
      }

      final DateTime now = DateTime.now().toUtc();
      final OfflineSyncQueueItem attempted = item.copyWith(
        attempts: item.attempts + 1,
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
      }

      processed++;
    }

    await _persist(working);
    return processed;
  }

  Future<void> _persist(List<OfflineSyncQueueItem> queue) {
    return _prefs.setJsonList(
      storageKey,
      queue
          .map((OfflineSyncQueueItem item) => item.toJson())
          .toList(growable: false),
    );
  }
}
