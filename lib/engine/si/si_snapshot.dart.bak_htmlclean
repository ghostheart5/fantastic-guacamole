// lib/engine/si/si_snapshot.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SISnapshotPayload {
  const SISnapshotPayload({
    required this.snapshot,
    required this.intent,
    required this.action,
    required this.message,
  });

  final SISnapshot snapshot;
  final String intent;
  final String action;
  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'snapshot': <String, dynamic>{
      'timestamp': snapshot.timestamp.toIso8601String(),
      'energy': siClamp01(snapshot.energy),
      'fatigue': siClamp01(snapshot.fatigue),
      'completed': snapshot.completed,
      'skipped': snapshot.skipped,
      'task_id': snapshot.taskId,
      'reasoning': snapshot.reasoning,
    },
    'intent': intent,
    'action': action,
    'message': message,
  };
}

class SISnapshotEngine {
  const SISnapshotEngine();

  SISnapshotPayload capture({
    required SIContext context,
    required SIIntent intent,
    SIDecision? decision,
    SIResponse? response,
    DateTime? now,
  }) {
    final SISnapshot snapshot = SISnapshot(
      timestamp: now ?? DateTime.now(),
      energy: siClamp01(context.userState.motivation),
      fatigue: siClamp01(context.userState.fatigue),
      completed: _int(context, 'completed'),
      skipped: _int(context, 'skipped'),
      taskId:
          decision?.task?.title ?? context.input.context['taskId']?.toString(),
      reasoning: decision?.reasoning,
    );

    return SISnapshotPayload(
      snapshot: snapshot,
      intent: intent.primary.label,
      action: decision?.action ?? 'respond_conversationally',
      message: response?.message ?? decision?.reasoning ?? '',
    );
  }

  int _int(SIContext context, String key) {
    final Object? raw =
        context.input.metadata[key] ?? context.input.context[key];
    if (raw is int) return raw.clamp(0, 9999);
    if (raw is num) return raw.toInt().clamp(0, 9999);
    return 0;
  }
}
