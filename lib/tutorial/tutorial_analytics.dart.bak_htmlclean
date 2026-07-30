import 'package:fantastic_guacamole/core/debug/app_analytics.dart';

class TutorialAnalytics {
  const TutorialAnalytics();

  void trackStarted({required int contentVersion}) {
    AppAnalytics.track(
      'tutorial_started',
      params: <String, Object?>{'content_version': contentVersion},
    );
  }

  void trackHintShown(String contextId) {
    AppAnalytics.track(
      'tutorial_context_hint_shown',
      params: <String, Object?>{'context_id': contextId},
    );
  }

  void trackCardViewed(String stepId) {
    AppAnalytics.track(
      'tutorial_card_viewed',
      params: <String, Object?>{'step_id': stepId},
    );
  }

  void trackStepCompleted(String stepId) {
    AppAnalytics.track(
      'tutorial_step_completed',
      params: <String, Object?>{'step_id': stepId},
    );
  }

  void trackStepSkipped(String stepId) {
    AppAnalytics.track(
      'tutorial_step_skipped',
      params: <String, Object?>{'step_id': stepId},
    );
  }

  void trackStepSkippedForever(String stepId) {
    AppAnalytics.track(
      'tutorial_step_skipped_forever',
      params: <String, Object?>{'step_id': stepId},
    );
  }

  void trackShowMeAgain(String stepId) {
    AppAnalytics.track(
      'tutorial_show_me_again_tapped',
      params: <String, Object?>{'step_id': stepId},
    );
  }

  void trackCompletedAllSteps() {
    AppAnalytics.track('tutorial_completed_all_steps');
  }

  void trackResumeTutorial(String stepId) {
    AppAnalytics.track(
      'tutorial_resumed',
      params: <String, Object?>{'step_id': stepId},
    );
  }

  void trackAbandoned({required int completedSteps, required int totalSteps}) {
    AppAnalytics.track(
      'tutorial_abandoned',
      params: <String, Object?>{
        'completed_steps': completedSteps,
        'total_steps': totalSteps,
      },
    );
  }

  void trackTutorialFinishedDuration(int seconds) {
    AppAnalytics.track(
      'tutorial_finished_duration',
      params: <String, Object?>{'duration_seconds': seconds},
    );
  }

  void trackReset() {
    AppAnalytics.track('tutorial_progress_reset');
  }

  void trackReplayOnboarding() {
    AppAnalytics.track('tutorial_replay_onboarding');
  }

  void trackContentVersionUpdated({
    required int fromVersion,
    required int toVersion,
  }) {
    AppAnalytics.track(
      'tutorial_content_version_updated',
      params: <String, Object?>{
        'from_version': fromVersion,
        'to_version': toVersion,
      },
    );
  }
}
