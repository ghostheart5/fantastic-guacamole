import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_analytics.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_content.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_progress_store.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTutorialRepository extends TutorialRepository {
  _FakeTutorialRepository({
    required this.initial,
    this.loadDelay = Duration.zero,
    this.throwOnLoad = false,
  }) : stored = initial;

  final TutorialProgress initial;
  final Duration loadDelay;
  final bool throwOnLoad;
  TutorialProgress stored;

  @override
  Future<TutorialProgress> loadProgressWithVersion({
    required int contentVersion,
  }) async {
    if (throwOnLoad) {
      throw StateError('repo-load-failed');
    }
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    stored = stored.applyContentVersion(contentVersion);
    return stored;
  }

  @override
  Future<void> saveProgress(TutorialProgress progress) async {
    stored = progress;
  }

  @override
  Future<void> resetToVersion({required int contentVersion}) async {
    stored = TutorialProgress(contentVersion: contentVersion);
  }
}

class _FakeTutorialAnalytics extends TutorialAnalytics {
  final List<String> completedSteps = <String>[];
  final List<String> skippedSteps = <String>[];
  final List<String> showAgainSteps = <String>[];
  int startedCount = 0;
  int resetCount = 0;

  @override
  void trackStarted({required int contentVersion}) {
    startedCount += 1;
  }

  @override
  void trackStepCompleted(String stepId) {
    completedSteps.add(stepId);
  }

  @override
  void trackStepSkipped(String stepId) {
    skippedSteps.add(stepId);
  }

  @override
  void trackShowMeAgain(String stepId) {
    showAgainSteps.add(stepId);
  }

  @override
  void trackReset() {
    resetCount += 1;
  }
}

void main() {
  group('provider state transitions', () {
    test('onboarding and route providers expose expected defaults', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(onboardingCompleteProvider), isFalse);
      container.read(onboardingCompleteProvider.notifier).set(true);
      expect(container.read(onboardingCompleteProvider), isTrue);

      expect(
        container.read(onboardingStatusProvider),
        OnboardingStatus.unknown,
      );
      container
          .read(onboardingStatusProvider.notifier)
          .set(OnboardingStatus.complete);
      expect(
        container.read(onboardingStatusProvider),
        OnboardingStatus.complete,
      );

      expect(container.read(creatorFirstItemCreatedProvider), isFalse);
      container.read(creatorFirstItemCreatedProvider.notifier).set(true);
      expect(container.read(creatorFirstItemCreatedProvider), isTrue);

      expect(container.read(timelineFirstActionCompletedProvider), isFalse);
      container.read(timelineFirstActionCompletedProvider.notifier).set(true);
      expect(container.read(timelineFirstActionCompletedProvider), isTrue);

      final RouteSurface routes = container.read(routeSurfaceProvider);
      expect(routes.login, '/login');
      expect(routes.settings, '/settings');
      expect(
        routes.notificationPermissionRecovery,
        '/settings/notifications/recovery',
      );
    });

    test(
      'tutorial progress provider supports loading success transitions',
      () async {
        final _FakeTutorialRepository repo = _FakeTutorialRepository(
          initial: const TutorialProgress(contentVersion: 1),
        );
        final _FakeTutorialAnalytics analytics = _FakeTutorialAnalytics();

        final ProviderContainer container = ProviderContainer(
          overrides: [
            tutorialRepositoryProvider.overrideWithValue(repo),
            tutorialAnalyticsProvider.overrideWithValue(analytics),
          ],
        );
        addTearDown(container.dispose);

        final TutorialProgress initial = await container.read(
          tutorialProgressProvider.future,
        );
        expect(initial.contentVersion, TutorialContent.contentVersion);

        final TutorialProgressController notifier = container.read(
          tutorialProgressProvider.notifier,
        );

        container
            .read(onboardingStatusProvider.notifier)
            .set(OnboardingStatus.complete);

        await notifier.startTutorial();
        expect(container.read(tutorialProgressProvider).value?.started, isTrue);
        expect(analytics.startedCount, 1);

        await notifier.completeStep('nexus_overview');
        expect(
          container
              .read(tutorialProgressProvider)
              .value
              ?.isStepCompleted('nexus_overview'),
          isTrue,
        );
        expect(analytics.completedSteps, contains('nexus_overview'));

        await notifier.skipStep('trajectory_overview');
        expect(
          container
              .read(tutorialProgressProvider)
              .value
              ?.isStepDismissed('trajectory_overview'),
          isTrue,
        );
        expect(analytics.skippedSteps, contains('trajectory_overview'));

        await notifier.showAgain('trajectory_overview');
        expect(
          container
              .read(tutorialProgressProvider)
              .value
              ?.isStepDismissed('trajectory_overview'),
          isFalse,
        );
        expect(analytics.showAgainSteps, contains('trajectory_overview'));

        await notifier.reset();
        expect(
          container.read(tutorialProgressProvider).value?.started,
          isFalse,
        );
        expect(analytics.resetCount, 1);

        expect(() => container.dispose(), returnsNormally);
      },
    );

    test(
      'tutorial progress provider exposes loading and error states',
      () async {
        final ProviderContainer loadingContainer = ProviderContainer(
          overrides: [
            tutorialRepositoryProvider.overrideWithValue(
              _FakeTutorialRepository(
                initial: const TutorialProgress(),
                loadDelay: const Duration(milliseconds: 25),
              ),
            ),
            tutorialAnalyticsProvider.overrideWithValue(
              _FakeTutorialAnalytics(),
            ),
          ],
        );
        addTearDown(loadingContainer.dispose);

        final AsyncValue<TutorialProgress> loadingState = loadingContainer.read(
          tutorialProgressProvider,
        );
        expect(loadingState, isA<AsyncLoading<TutorialProgress>>());
        await loadingContainer.read(tutorialProgressProvider.future);

        final ProviderContainer errorContainer = ProviderContainer(
          overrides: [
            tutorialRepositoryProvider.overrideWithValue(
              _FakeTutorialRepository(
                initial: const TutorialProgress(),
                throwOnLoad: true,
              ),
            ),
            tutorialAnalyticsProvider.overrideWithValue(
              _FakeTutorialAnalytics(),
            ),
          ],
        );
        addTearDown(errorContainer.dispose);

        await expectLater(
          errorContainer.read(tutorialProgressProvider.future),
          throwsA(isA<StateError>()),
        );
        expect(errorContainer.read(tutorialProgressProvider).hasError, isTrue);
      },
    );
  });
}
