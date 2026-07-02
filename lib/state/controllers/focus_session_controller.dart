import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/engine/learning/learning_history.dart';
import 'package:fantastic_guacamole/engine/scoring/session_scoring_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_core.dart';
import 'package:fantastic_guacamole/engine/si/si_snapshot.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/session_score_view.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionScoringEngineProvider = Provider<SessionScoringEngine>((ref) {
  return SessionScoringEngine();
});

final focusSessionControllerProvider = Provider<FocusSessionController>(
  (ref) => FocusSessionController(ref),
);

class FocusSessionController {
  FocusSessionController(this._ref);

  final Ref _ref;

  Future<void> completeSession({
    required TaskView? task,
    required int elapsedSeconds,
    String? reasoning,
  }) async {
    if (task == null) {
      _applyFallbackScore(elapsedSeconds);
      AppAnalytics.track('focus_session_completed', params: <String, Object?>{'task': 'unknown'});
      return;
    }

    final rawTask = task.toTask();
    final si = _ref.read(siStateProvider);
    final learning = _ref.read(learningProvider);
    final SICoreUpdate update = SICore(si: si, learning: learning).onComplete(rawTask);

    await _ref.read(learningProvider.notifier).apply(update.learning);
    _ref
        .read(learningHistoryProvider.notifier)
        .record(
          type: LearningEventType.completed,
          difficulty: rawTask.difficulty,
          learning: update.learning,
        );
    _ref
        .read(siStateProvider.notifier)
        .replaceState(
          energy: update.si.energy,
          fatigue: update.si.fatigue,
          completedToday: update.si.completedToday,
        );
    _ref
        .read(siMemoryProvider.notifier)
        .capture(
          SISnapshot(
            timestamp: DateTime.now(),
            energy: update.si.energy,
            fatigue: update.si.fatigue,
            completed: update.learning.completed,
            skipped: update.learning.skipped,
            taskId: rawTask.id,
            reasoning: reasoning,
          ),
        );
    await _ref.read(aiResponseProvider.notifier).execute();
    final aiResponse = _ref.read(aiResponseProvider).asData?.value;
    _ref.read(notificationProvider.notifier).pushCompletionFeedback(rawTask.title);

    final score = _ref
        .read(sessionScoringEngineProvider)
        .calculate(
          seconds: elapsedSeconds,
          energy: _ref.read(energyProvider),
          taskPriority: rawTask.priority,
        );
    _ref.read(profileProvider.notifier).addXP(score.xp);
    _ref.read(sessionScoreProvider.notifier).set(SessionScoreView.fromScore(score));

    await _ref
        .read(aiControllerProvider)
        .appendNeuralDumpEntry(
          task: task.title,
          reasoning: aiResponse?.reasoning ?? reasoning ?? '',
          confidence: aiResponse?.confidence ?? 0,
          duration: elapsedSeconds,
          quality: score.quality,
          timestamp: DateTime.now(),
        );

    AppAnalytics.track(
      'focus_session_completed',
      params: <String, Object?>{
        'task_id': rawTask.id,
        'priority': rawTask.priority,
        'elapsed_seconds': elapsedSeconds,
      },
    );
  }

  Future<void> skipSession({required TaskView? task, String? reasoning}) async {
    if (task == null) {
      await _ref.read(aiResponseProvider.notifier).execute();
      AppAnalytics.track('focus_session_skipped', params: <String, Object?>{'task': 'unknown'});
      return;
    }

    final rawTask = task.toTask();
    final si = _ref.read(siStateProvider);
    final learning = _ref.read(learningProvider);
    final SICoreUpdate update = SICore(si: si, learning: learning).onSkip(rawTask);

    await _ref.read(learningProvider.notifier).apply(update.learning);
    _ref
        .read(learningHistoryProvider.notifier)
        .record(
          type: LearningEventType.skipped,
          difficulty: rawTask.difficulty,
          learning: update.learning,
        );
    _ref
        .read(siStateProvider.notifier)
        .replaceState(
          energy: update.si.energy,
          fatigue: update.si.fatigue,
          completedToday: update.si.completedToday,
        );
    _ref
        .read(siMemoryProvider.notifier)
        .capture(
          SISnapshot(
            timestamp: DateTime.now(),
            energy: update.si.energy,
            fatigue: update.si.fatigue,
            completed: update.learning.completed,
            skipped: update.learning.skipped,
            taskId: rawTask.id,
            reasoning: reasoning,
          ),
        );
    _ref.read(notificationProvider.notifier).pushTaskSkipped(rawTask.title);
    await _ref.read(aiResponseProvider.notifier).execute();

    AppAnalytics.track(
      'focus_session_skipped',
      params: <String, Object?>{'task_id': rawTask.id, 'priority': rawTask.priority},
    );
  }

  void _applyFallbackScore(int elapsedSeconds) {
    final score = _ref
        .read(sessionScoringEngineProvider)
        .calculate(seconds: elapsedSeconds, energy: 0.5, taskPriority: 1);
    _ref.read(profileProvider.notifier).addXP(score.xp);
    _ref.read(sessionScoreProvider.notifier).set(SessionScoreView.fromScore(score));
  }
}
