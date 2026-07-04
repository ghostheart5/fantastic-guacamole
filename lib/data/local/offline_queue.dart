import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/storage/shared_prefs_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class OfflineAction {
  const OfflineAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.queuedAt,
  });

  final String id;
  final String type; // 'task_created' | 'task_completed' | 'log'
  final Map<String, dynamic> payload;
  final String queuedAt; // ISO-8601

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'payload': payload,
    'queuedAt': queuedAt,
  };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
    id: json['id'] as String,
    type: json['type'] as String,
    payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    queuedAt: json['queuedAt'] as String,
  );

  static String generateId() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}

class OfflineQueue {
  static const _key = 'offline_queue_v1';

  Future<List<OfflineAction>> getAll() async {
    try {
      final raw = SharedPrefsService.load(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => OfflineAction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      Logger.warn('OfflineQueue.getAll failed: $e');
      return [];
    }
  }

  Future<void> enqueue(OfflineAction action) async {
    try {
      final current = await getAll();
      current.add(action);
      await SharedPrefsService.save(
        _key,
        jsonEncode(current.map((a) => a.toJson()).toList()),
      );
    } catch (e) {
      Logger.warn('OfflineQueue.enqueue failed: $e');
    }
  }

  Future<void> remove(String id) async {
    try {
      final current = await getAll();
      final filtered = current.where((a) => a.id != id).toList();
      await SharedPrefsService.save(
        _key,
        jsonEncode(filtered.map((a) => a.toJson()).toList()),
      );
    } catch (e) {
      Logger.warn('OfflineQueue.remove failed: $e');
    }
  }

  Future<void> clear() async {
    try {
      await SharedPrefsService.delete(_key);
    } catch (e) {
      Logger.warn('OfflineQueue.clear failed: $e');
    }
  }

  Future<int> get length async => (await getAll()).length;

  /// Processes each action with [processor]. Removes successfully processed
  /// actions. Leaves failures in queue for the next sync attempt.
  Future<void> replay(Future<void> Function(OfflineAction) processor) async {
    final actions = await getAll();
    if (actions.isEmpty) return;

    Logger.log('OfflineQueue', 'Replaying ${actions.length} queued action(s)');
    for (final action in actions) {
      try {
        await processor(action);
        await remove(action.id);
      } catch (e) {
        Logger.warn(
          'OfflineQueue: failed to replay ${action.type} (${action.id}): $e',
        );
      }
    }
  }
}

final offlineQueueProvider = Provider<OfflineQueue>((_) => OfflineQueue());
