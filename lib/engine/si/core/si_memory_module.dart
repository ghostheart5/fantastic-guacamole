// lib/engine/si/core/si_memory_module.dart

import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

class SIMemoryModule {
  const SIMemoryModule();

  SIMemoryUpdate update({
    required SIMemoryStore current,
    required SIContext context,
    required SIDecision decision,
    required SIResponse response,
  }) {
    final DateTime now = DateTime.now();
    final double energy = siClamp01(context.userState.motivation);
    final double fatigue = siClamp01(context.userState.fatigue);

    final int completed = _intFrom(context, 'completed');
    final int skipped = _intFrom(context, 'skipped');

    final SISnapshot snapshot = SISnapshot(
      timestamp: now,
      energy: energy,
      fatigue: fatigue,
      completed: completed,
      skipped: skipped,
      taskId: _taskId(context, decision),
      reasoning: decision.reasoning,
    );

    final MemoryRecord record = MemoryRecord(
      content: _recordContent(decision, response),
      timestamp: now,
      relevance: _relevance(decision, context),
      recency: 1.0,
      confidence: decision.confidence,
      emotionalWeight: fatigue,
      reinforcement: _reinforcement(completed, skipped, decision.safe),
    );

    final SIMemoryStore updated = current
        .pushSnapshot(snapshot)
        .pushRecord(MemoryTier.shortTerm, record)
        .dedupe()
        .decay(now);

    return SIMemoryUpdate(store: updated, addedSnapshot: snapshot);
  }

  int _intFrom(SIContext context, String key) {
    final Object? value =
        context.input.metadata[key] ?? context.input.context[key];
    if (value is int) return value.clamp(0, 9999);
    if (value is num) return value.toInt().clamp(0, 9999);
    return 0;
  }

  String? _taskId(SIContext context, SIDecision decision) {
    final Object? explicit =
        context.input.metadata['taskId'] ?? context.input.context['taskId'];
    final String clean = siClean(explicit?.toString());
    if (clean.isNotEmpty) return clean;
    final String title = siClean(decision.task?.title);
    return title.isEmpty ? null : title;
  }

  String _recordContent(SIDecision decision, SIResponse response) {
    final String action = siClean(decision.action, fallback: 'respond');
    final String task = siClean(decision.task?.title);
    final String msg = siClean(response.message, fallback: decision.reasoning);
    final String content = task.isEmpty
        ? '$action | $msg'
        : '$action | $task | $msg';
    return content.length <= 360 ? content : '${content.substring(0, 357)}...';
  }

  double _relevance(SIDecision decision, SIContext context) {
    final double actionWeight =
        decision.action == 'present_task_recommendation' ||
            decision.action == 'launch_focus_session'
        ? 0.85
        : 0.65;
    return siClamp01(
      (actionWeight + decision.confidence + context.userState.engagement) / 3,
    );
  }

  int _reinforcement(int completed, int skipped, bool safe) {
    if (!safe) return 0;
    if (completed > skipped) return 2;
    if (completed == skipped && completed > 0) return 1;
    return 0;
  }
}
