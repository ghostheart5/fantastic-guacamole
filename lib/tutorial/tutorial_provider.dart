// lib/tutorial/tutorial_provider.dart

import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_analytics.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_controller.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tutorialRepositoryProvider = Provider<TutorialRepository>((ref) {
  return const TutorialRepository();
});

final tutorialAnalyticsProvider = Provider<TutorialAnalytics>((ref) {
  return const TutorialAnalytics();
});

final tutorialControllerProvider = Provider<TutorialController>((ref) {
  final controller = TutorialController();
  ref.onDispose(controller.dispose);
  return controller;
});

final tutorialProgressProvider =
    AsyncNotifierProvider<TutorialProgressController, TutorialProgress>(
      TutorialProgressController.new,
    );

class TutorialProgressController extends AsyncNotifier<TutorialProgress> {
  TutorialRepository get _repository => ref.read(tutorialRepositoryProvider);
  TutorialAnalytics get _analytics => ref.read(tutorialAnalyticsProvider);

  @override
  Future<TutorialProgress> build() async {
    return _repository.loadProgressWithVersion(contentVersion: TutorialContent.contentVersion);
  }

  Future<void> startTutorial() async {
    final TutorialProgress current = await _current();
    final TutorialProgress updated = current.start(targetVersion: TutorialContent.contentVersion);
    await _save(updated);
    _analytics.trackStarted(contentVersion: TutorialContent.contentVersion);
  }

  Future<void> updateTutorialContentVersion() async {
    final TutorialProgress current = await _current();
    final TutorialProgress updated = current.applyContentVersion(TutorialContent.contentVersion);
    await _save(updated);
    _analytics.trackContentVersionUpdated(
      fromVersion: current.contentVersion,
      toVersion: TutorialContent.contentVersion,
    );
  }

  String? showContextualHint(String contextId) {
    final String? hint = TutorialContent.contextualHints[contextId];
    if (hint != null && hint.trim().isNotEmpty) {
      _analytics.trackHintShown(contextId);
    }
    return hint;
  }

  Future<void> markIntroSeen() async {
    final TutorialProgress current = await _current();
    await _save(current.markIntroSeen());
  }

  Future<void> completeStep(String stepId) async {
    final TutorialProgress current = await _current();
    final TutorialProgress updated = current.markCompleted(stepId);
    await _save(updated);
    _analytics.trackStepCompleted(stepId);

    if (updated.completedStepIds.length >= TutorialContent.steps.length) {
      _analytics.trackCompletedAllSteps();
    }
  }

  Future<void> skipStep(String stepId) async {
    final TutorialProgress current = await _current();
    await _save(current.skipStep(stepId));
    _analytics.trackStepSkipped(stepId);
  }

  Future<void> skipStepForever(String stepId) async {
    final TutorialProgress current = await _current();
    await _save(current.skipForever(stepId));
    _analytics.trackStepSkippedForever(stepId);
  }

  Future<void> showAgain(String stepId) async {
    final TutorialProgress current = await _current();
    await _save(current.revealStep(stepId));
    _analytics.trackShowMeAgain(stepId);
  }

  Future<void> revealStep(String stepId) async {
    final TutorialProgress current = await _current();
    await _save(current.revealStep(stepId));
  }

  Future<void> completeStepSilently(String stepId) async {
    final TutorialProgress current = await _current();
    await _save(current.markCompleted(stepId));
  }

  Future<void> reset() async {
    await _repository.resetToVersion(contentVersion: TutorialContent.contentVersion);
    state = const AsyncData(TutorialProgress(contentVersion: TutorialContent.contentVersion));
    _analytics.trackReset();
  }

  Future<void> resetAll() {
    return reset();
  }

  Future<void> replayOnboarding() async {
    ref.read(onboardingCompleteProvider.notifier).set(false);
    await reset();
    _analytics.trackReplayOnboarding();
  }

  Future<TutorialProgress> _current() async {
    final TutorialProgress? value = state.asData?.value;
    if (value != null) {
      return value;
    }
    return future;
  }

  Future<void> _save(TutorialProgress progress) async {
    await _repository.saveProgress(progress);
    state = AsyncData(progress);
  }
}
