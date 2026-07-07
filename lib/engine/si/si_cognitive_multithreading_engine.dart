// lib/engine/si/si_cognitive_multithreading_engine.dart

import 'dart:async';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

enum SIThreadPriority { low, normal, high, critical }

class SIThreadTask<T> {
  const SIThreadTask({
    required this.id,
    required this.label,
    required this.priority,
    required this.run,
  });

  final String id;
  final String label;
  final SIThreadPriority priority;
  final FutureOr<T> Function() run;
}

class SIThreadResult<T> {
  const SIThreadResult({
    required this.id,
    required this.label,
    required this.success,
    this.value,
    this.error,
  });

  final String id;
  final String label;
  final bool success;
  final T? value;
  final Object? error;
}

class SIMultithreadingEngine {
  const SIMultithreadingEngine();

  Future<List<SIThreadResult<T>>> runLogical<T>({
    required List<SIThreadTask<T>> tasks,
    int maxTasks = 12,
  }) async {
    final List<SIThreadTask<T>> ordered = tasks.toList()
      ..sort((SIThreadTask<T> a, SIThreadTask<T> b) {
        return _rank(b.priority).compareTo(_rank(a.priority));
      });

    final List<SIThreadResult<T>> results = <SIThreadResult<T>>[];

    for (final SIThreadTask<T> task in ordered.take(maxTasks.clamp(1, 50))) {
      try {
        final T value = await Future<T>.value(task.run());
        results.add(
          SIThreadResult<T>(
            id: task.id,
            label: task.label,
            success: true,
            value: value,
          ),
        );
      } catch (error) {
        results.add(
          SIThreadResult<T>(
            id: task.id,
            label: task.label,
            success: false,
            error: error,
          ),
        );
      }
    }

    return List<SIThreadResult<T>>.unmodifiable(results);
  }

  SIThreadPriority priorityFor({
    required SIContext context,
    required SIIntent intent,
    required InstinctGuidance instinct,
    String taskType = 'analysis',
  }) {
    if (instinct.safetyFirst || context.userState.stress >= 0.72) {
      return SIThreadPriority.critical;
    }
    if (taskType.contains('ethics') || taskType.contains('repair')) {
      return SIThreadPriority.high;
    }
    if (intent.confidence < 0.5 || instinct.reduceConfusion) {
      return SIThreadPriority.high;
    }
    return SIThreadPriority.normal;
  }

  int _rank(SIThreadPriority priority) {
    switch (priority) {
      case SIThreadPriority.critical:
        return 4;
      case SIThreadPriority.high:
        return 3;
      case SIThreadPriority.normal:
        return 2;
      case SIThreadPriority.low:
        return 1;
    }
  }
}
