import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/creator/ui/creator_screen.dart';
import 'package:fantastic_guacamole/features/timeline/ui/timeline_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/creator_handshake_provider.dart';
import 'package:fantastic_guacamole/state/providers/daily_decision_intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/intelligence_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guide_overlay.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/tutorial/guide_hint_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression coverage for first-run guide dead ends found in the 4.2.2 audit:
// every path into Creator or Timeline must leave a reachable, enabled target.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
    'confirming with the highlighted Creator button keeps the Timeline step',
    (WidgetTester tester) async {
      _tallView(tester);
      final _Tasks repo = _Tasks();
      final ProviderContainer container = _container(repo);
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      await container
          .read(creatorHandshakeProvider.notifier)
          .stage(
            data: CreatorFormData(
              title: 'First scheduled task',
              type: 'Task',
              priority: 4,
              scheduledFor: DateTime.now().add(const Duration(hours: 2)),
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CreatorScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(FirstRunTutorialTargets.creatorConfirm.currentContext, isNotNull);

      final Finder confirm = find.byKey(const Key('creator-confirm-selected'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final AdaptiveGuidanceState state = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(repo.saveCalls, 1);
      expect(
        state.expectedFirstRunCreatorTaskIds,
        equals(repo.tasks.keys.toSet()),
      );
      expect(
        state
            .nextIntervention(
              currentRoute: RoutePaths.timeline,
              decision: _decision,
            )
            ?.id,
        GuidanceLessonId.reviewTimeline,
      );
    },
  );

  testWidgets('restarting the guide mounts every Creator spotlight target', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    final ProviderContainer container = _container(
      _Tasks.withScheduledTask(),
      overlay: true,
    );
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await container.read(adaptiveGuidanceProvider.notifier).restartLessons();

    await _pumpCreatorWithGuide(tester, container);

    expect(find.text('Name your task'), findsOneWidget);
    expect(FirstRunTutorialTargets.creatorTitle.currentContext, isNotNull);
    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Book the dentist');
    await tester.pump();
    expect(_primary(tester, 'Title entered').onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final String language in <String>['en', 'es']) {
    testWidgets('$language Add something guide steps use plain words', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      final ProviderContainer container = _container(
        _Tasks.withScheduledTask(),
        overlay: true,
      );
      addTearDown(container.dispose);
      await container.read(adaptiveGuidanceProvider.future);
      await container.read(adaptiveGuidanceProvider.notifier).restartLessons();
      await _pumpCreatorWithGuide(tester, container, locale: Locale(language));

      final bool es = language == 'es';
      expect(
        find.text(es ? 'Ponle nombre a tu tarea' : 'Name your task'),
        findsOneWidget,
      );
      expect(
        find.text(
          es
              ? 'Escribe lo que necesitas hacer en el campo de título de abajo '
                    'y toca Título escrito.'
              : 'Type what you need to do in the title field below, then tap '
                    'Title entered.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('real task'), findsNothing);
      expect(find.textContaining('tarea real'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'a returning account with restored tasks gets a guided Creator',
    () async {
      final ProviderContainer container = _container(
        _Tasks.withScheduledTask(),
      );
      addTearDown(container.dispose);
      final AdaptiveGuidanceState state = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(state.has(GuidanceMilestone.firstSchedule), isTrue);
      expect(state.activeCoreLesson, GuidanceLessonId.createFirstItem);
      expect(state.guidesCreatorTask, isTrue);
    },
  );

  test('a paused first-run guide no longer forces guided Creator', () async {
    final ProviderContainer container = _container(_Tasks());
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await container
        .read(adaptiveGuidanceProvider.notifier)
        .later(GuidanceLessonId.createFirstItem);
    final AdaptiveGuidanceState state = container
        .read(adaptiveGuidanceProvider)
        .requireValue;
    expect(state.activeCoreLesson, isNull);
    expect(state.guidesCreatorTask, isFalse);
  });

  testWidgets('Creator guide offers Back after the first step', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    final ProviderContainer container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await _pumpCreatorWithGuide(tester, container);

    expect(find.byKey(const Key('guide_step_back')), findsNothing);
    final Finder titleField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.hintText == 'Title *',
    );
    await tester.enterText(titleField, 'Book the dentist');
    await tester.pump();
    await tester.tap(find.text('Title entered'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Set its priority'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guide_step_back')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Name your task'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pausing the guide says where to resume it', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    final ProviderContainer container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await _pumpCreatorWithGuide(tester, container);

    await tester.tap(find.text('Pause guide'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('guide-paused-snackbar')), findsOneWidget);
    expect(find.textContaining('Restart Adaptive Guide'), findsOneWidget);
    expect(find.text('Name your task'), findsNothing);
  });

  testWidgets('core guidance does not cover the Smart Planner first choice', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    final ProviderContainer container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    final GoRouter router = GoRouter(
      initialLocation: RoutePaths.smartPlanner,
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.smartPlanner,
          builder: (_, _) => const Scaffold(body: Text('planner')),
        ),
        GoRoute(
          path: RoutePaths.nexus,
          builder: (_, _) => const Scaffold(body: Text('nexus')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpRouterWithGuide(tester, container, router);

    expect(find.text('Add your first task'), findsNothing);
    router.go(RoutePaths.nexus);
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Add your first task'), findsOneWidget);
  });

  for (final language in <String>['en', 'es']) {
    testWidgets(
      '$language "I found my task" finishes the guide without completing '
      'the task',
      (tester) async {
        _tallView(tester);
        final repo = _Tasks.withScheduledTask();
        final container = _container(repo, overlay: true, timeline: true);
        addTearDown(container.dispose);
        await _prepareTimelineGuide(container);
        await _pumpTimelineWithGuide(tester, container, Locale(language));
        expect(
          find.text(language == 'en' ? 'Step 2 of 2' : 'Paso 2 de 2'),
          findsOneWidget,
        );
        final String found = language == 'en'
            ? 'I found my task'
            : 'Encontré mi tarea';
        // The saved task is on Schedule; nothing has to be marked done.
        expect(
          find.text(
            language == 'en'
                ? 'Your saved task is now on Schedule'
                : 'Tu tarea guardada ya está en agenda',
          ),
          findsOneWidget,
        );
        expect(_primary(tester, found).onPressed, isNotNull);
        final int savesBefore = repo.saveCalls;
        await tester.tap(find.text(found));
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final AdaptiveGuidanceState state = container
            .read(adaptiveGuidanceProvider)
            .requireValue;
        expect(state.coreComplete, isTrue);
        expect(state.has(GuidanceMilestone.firstCompletion), isFalse);
        expect(state.expectedFirstRunCreatorTaskIds, isEmpty);
        expect(repo.tasks['restored']!.isCompleted, isFalse);
        expect(repo.saveCalls, savesBefore);
        expect(find.text(found), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final action in <String>['skip', 'postpone']) {
      testWidgets(
        '$language $action of the saved task does not finish the guide',
        (tester) async {
          _tallView(tester);
          final timelineNow = DateTime(2026, 10, 2, 12);
          final repo = _Tasks.withScheduledTask();
          repo.tasks['restored'] = repo.tasks['restored']!.copyWith(
            scheduledFor: timelineNow.add(const Duration(hours: 1)),
          );
          final container = _container(
            repo,
            overlay: true,
            timeline: true,
            timelineClock: () => timelineNow,
          );
          addTearDown(container.dispose);
          await _prepareTimelineGuide(container);
          await _pumpTimelineWithGuide(tester, container, Locale(language));
          final label = action == 'skip'
              ? (language == 'en' ? 'Skip' : 'Omitir')
              : (language == 'en'
                    ? 'Postpone to Tomorrow'
                    : 'Aplazar hasta mañana');
          final actionButton = find.widgetWithText(OutlinedButton, label);
          expect(actionButton, findsOneWidget);
          await tester.ensureVisible(actionButton);
          await tester.tap(actionButton);
          for (int i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(
            container.read(adaptiveGuidanceProvider).requireValue.coreComplete,
            isFalse,
          );
          expect(
            container
                .read(adaptiveGuidanceProvider)
                .requireValue
                .expectedFirstRunCreatorTaskIds,
            contains('restored'),
          );
          expect(repo.tasks['restored']!.isCompleted, isFalse);
          await tester.tap(
            find.text(language == 'en' ? 'Pause guide' : 'Pausar guía'),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            container
                .read(adaptiveGuidanceProvider)
                .requireValue
                .activeCoreLesson,
            isNull,
          );
          await container
              .read(adaptiveGuidanceProvider.notifier)
              .restartLessons();
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            container
                .read(adaptiveGuidanceProvider)
                .requireValue
                .activeCoreLesson,
            GuidanceLessonId.createFirstItem,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'a task that is no longer on the schedule does not finish the guide; '
    'Skip this step ends it without a false milestone',
    (tester) async {
      _tallView(tester);
      final repo = _Tasks.withScheduledTask();
      repo.tasks['restored'] = repo.tasks['restored']!.complete();
      final container = _container(repo, overlay: true, timeline: true);
      addTearDown(container.dispose);
      await _prepareTimelineGuide(container, taskId: 'different-task');
      await _pumpTimelineWithGuide(tester, container, const Locale('en'));
      expect(find.textContaining('not on your schedule'), findsOneWidget);
      // Nothing here was found, so the review cannot be recorded.
      expect(_primary(tester, 'I found my task').onPressed, isNull);
      await tester.tap(find.text('I found my task'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        container.read(adaptiveGuidanceProvider).requireValue.coreComplete,
        isFalse,
      );
      expect(
        container
            .read(adaptiveGuidanceProvider)
            .requireValue
            .has(GuidanceMilestone.firstTimelineReview),
        isFalse,
      );
      await tester.tap(find.text('Skip this step'));
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final AdaptiveGuidanceState state = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(state.activeCoreLesson, isNull);
      expect(state.coreComplete, isFalse);
      expect(state.has(GuidanceMilestone.firstTimelineReview), isFalse);
      expect(state.coreGuideStatus, CoreGuideStatus.skipped);
      expect(find.text('Skip this step'), findsNothing);
      expect(find.byKey(const Key('guide-skipped-snackbar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Skip this step in Add something moves on to the schedule step', (
    tester,
  ) async {
    _tallView(tester);
    final ProviderContainer container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    // A task the guide saved earlier, without a date yet.
    await container
        .read(adaptiveGuidanceProvider.notifier)
        .recordCreatorHandshakeReceipt(_guideReceipt('restored'));
    await _pumpCreatorWithGuide(tester, container);
    expect(find.text('Step 1 of 2'), findsOneWidget);

    await tester.tap(find.text('Skip this step'));
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final AdaptiveGuidanceState state = container
        .read(adaptiveGuidanceProvider)
        .requireValue;
    expect(state.activeCoreLesson, GuidanceLessonId.reviewTimeline);
    expect(state.has(GuidanceMilestone.firstItem), isFalse);
    expect(state.has(GuidanceMilestone.firstSchedule), isFalse);
    expect(state.has(GuidanceMilestone.guidanceDismissed), isFalse);
    // Step 2 is shown on the schedule, not here.
    expect(find.text('Step 1 of 2'), findsNothing);
    expect(find.text('Step 2 of 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('after skipping step 1 with a task saved without a date, the '
      'schedule step says so and only Skip this step can end it', (
    tester,
  ) async {
    _tallView(tester);
    final repo = _Tasks()
      ..tasks['undated'] = TaskEntity(
        id: 'undated',
        title: 'Undated task',
        createdAt: DateTime.utc(2026, 11, 1, 9),
      );
    final container = _container(repo, overlay: true, timeline: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    final notifier = container.read(adaptiveGuidanceProvider.notifier);
    await notifier.recordCreatorHandshakeReceipt(_guideReceipt('undated'));
    await notifier.skipCoreStep(GuidanceLessonId.createFirstItem);
    expect(
      container.read(adaptiveGuidanceProvider).requireValue.activeCoreLesson,
      GuidanceLessonId.reviewTimeline,
    );
    await _pumpTimelineWithGuide(tester, container, const Locale('es'));
    expect(find.textContaining('no está en tu agenda'), findsOneWidget);
    expect(_primary(tester, 'Encontré mi tarea').onPressed, isNull);
    await tester.tap(find.text('Omitir este paso'));
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final AdaptiveGuidanceState state = container
        .read(adaptiveGuidanceProvider)
        .requireValue;
    expect(state.activeCoreLesson, isNull);
    expect(state.has(GuidanceMilestone.firstTimelineReview), isFalse);
    expect(state.coreGuideStatus, CoreGuideStatus.skipped);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip this step while reviewing leaves the plain Add something '
      'form', (tester) async {
    _tallView(tester);
    final repo = _Tasks();
    final container = _container(repo, overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    await container
        .read(creatorHandshakeProvider.notifier)
        .stage(
          data: CreatorFormData(
            title: 'First scheduled task',
            type: 'Task',
            priority: 4,
            scheduledFor: DateTime.utc(2026, 11, 2, 9),
          ),
        );
    container.read(creatorTutorialDraftProvider.notifier)
      ..setHasTitle(true)
      ..markPriorityChosen()
      ..setHasSchedule(true);
    await _pumpCreatorWithGuide(tester, container);
    expect(container.read(creatorHandshakeProvider).isReviewing, isTrue);
    expect(find.text('Confirm your task'), findsOneWidget);
    // It sends the person to /timeline, named as its navigation label is.
    expect(find.text('Confirm and open My plan'), findsOneWidget);

    await tester.tap(find.text('Skip this step'));
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(creatorHandshakeProvider).isReviewing, isFalse);
    expect(find.byKey(const Key('creator-confirm-selected')), findsNothing);
    final CreatorTutorialDraftState draft = container.read(
      creatorTutorialDraftProvider,
    );
    expect(draft.hasTitle, isFalse);
    expect(draft.hasSchedule, isFalse);
    final AdaptiveGuidanceState state = container
        .read(adaptiveGuidanceProvider)
        .requireValue;
    expect(state.guidesCreatorTask, isFalse);
    expect(state.has(GuidanceMilestone.firstItem), isFalse);
    expect(repo.saveCalls, 0);
    expect(find.text('Step 1 of 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final _CoreStepScreen step in _CoreStepScreen.values) {
    testWidgets(
      'navigation and Settings stay usable during the ${step.name} step',
      (tester) async {
        _tallView(tester);
        final repo = _Tasks.withScheduledTask();
        final container = _container(
          repo,
          overlay: true,
          timeline: step == _CoreStepScreen.schedule,
        );
        addTearDown(container.dispose);
        if (step == _CoreStepScreen.schedule) {
          await _prepareTimelineGuide(container);
        } else {
          await container.read(adaptiveGuidanceProvider.future);
        }
        int settingsTaps = 0;
        final router = GoRouter(
          initialLocation: step.route,
          routes: <RouteBase>[
            ShellRoute(
              builder: (context, state, child) => Scaffold(
                body: child,
                bottomNavigationBar: TextButton(
                  onPressed: () => GoRouter.of(context).go(RoutePaths.settings),
                  child: const Text('Settings tab'),
                ),
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: RoutePaths.nexus,
                  builder: (_, _) => const Center(child: Text('Today page')),
                ),
                GoRoute(
                  path: RoutePaths.creator,
                  builder: (_, _) => const CreatorScreen(),
                ),
                GoRoute(
                  path: RoutePaths.timeline,
                  builder: (_, _) => const TimelineScreen(),
                ),
                GoRoute(
                  path: RoutePaths.settings,
                  builder: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => settingsTaps++,
                      child: const Text('Settings switch'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await _pumpRouterWithGuide(tester, container, router);
        final String stepLabel = step == _CoreStepScreen.schedule
            ? 'Step 2 of 2'
            : 'Step 1 of 2';
        expect(find.text(stepLabel), findsOneWidget);
        // No barrier: the navigation under the card takes the tap.
        await tester.tap(find.text('Settings tab').hitTestable());
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(router.routerDelegate.state.uri.path, RoutePaths.settings);
        await tester.tap(find.text('Settings switch').hitTestable());
        expect(settingsTaps, 1);
        // The step is shown only on its own screen.
        expect(find.text(stepLabel), findsNothing);
        expect(
          container
              .read(adaptiveGuidanceProvider)
              .requireValue
              .activeCoreLesson,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the first step on Today opens Add something', (tester) async {
    _tallView(tester);
    final container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    final router = GoRouter(
      initialLocation: RoutePaths.nexus,
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.nexus,
          builder: (_, _) => const Scaffold(body: Text('Today page')),
        ),
        GoRoute(
          path: RoutePaths.creator,
          builder: (_, _) => const Scaffold(body: Text('Add something page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpRouterWithGuide(tester, container, router);
    expect(find.text('Add your first task'), findsOneWidget);
    await tester.tap(find.text('Add a task'));
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(router.routerDelegate.state.uri.path, RoutePaths.creator);
  });

  for (final language in <String>['en', 'es']) {
    testWidgets(
      '$language step card fits 320 dp at 200 percent text with its buttons '
      'reachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = _container(_Tasks(), overlay: true);
        addTearDown(container.dispose);
        await container.read(adaptiveGuidanceProvider.future);
        final router = GoRouter(
          initialLocation: RoutePaths.nexus,
          routes: <RouteBase>[
            GoRoute(
              path: RoutePaths.nexus,
              builder: (_, _) => const Scaffold(body: Text('Today page')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await _pumpRouterWithGuide(
          tester,
          container,
          router,
          locale: Locale(language),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        for (final String key in <String>[
          'guide_step_primary',
          'guide_step_skip',
          'guide_step_pause',
        ]) {
          // The card scrolls when large text does not fit; every button can
          // be scrolled to and tapped.
          await tester.ensureVisible(find.byKey(Key(key)));
          await tester.pump();
          final Finder button = find.byKey(Key(key)).hitTestable();
          expect(button, findsOneWidget, reason: key);
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        }
        // The page below the card stays usable.
        expect(find.text('Today page').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          find.text(language == 'en' ? 'Skip this step' : 'Omitir este paso'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            RegExp(language == 'en' ? '^Step 1 of 2\\. ' : '^Paso 1 de 2\\. '),
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('a step steps aside for the keyboard and comes back after it', (
    tester,
  ) async {
    _tallView(tester);
    final container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    final router = GoRouter(
      initialLocation: RoutePaths.nexus,
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.nexus,
          builder: (_, _) => const Scaffold(body: Text('Today page')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpRouterWithGuide(tester, container, router);
    expect(find.text('Step 1 of 2'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump();
    expect(find.text('Step 1 of 2'), findsNothing);
    tester.view.resetViewInsets();
    await tester.pump();
    await tester.pump();
    expect(find.text('Step 1 of 2'), findsOneWidget);
  });

  testWidgets('an account that finished the guide gets no step card', (
    tester,
  ) async {
    _tallView(tester);
    final container = _container(_Tasks(), overlay: true);
    addTearDown(container.dispose);
    await container.read(adaptiveGuidanceProvider.future);
    final notifier = container.read(adaptiveGuidanceProvider.notifier);
    await notifier.record(GuidanceMilestone.firstItem);
    await notifier.record(GuidanceMilestone.firstSchedule);
    await notifier.record(GuidanceMilestone.firstTimelineReview);
    final router = GoRouter(
      initialLocation: RoutePaths.nexus,
      routes: <RouteBase>[
        for (final String path in <String>[
          RoutePaths.nexus,
          RoutePaths.creator,
          RoutePaths.timeline,
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text('page $path')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpRouterWithGuide(tester, container, router);
    for (final String path in <String>[
      RoutePaths.nexus,
      RoutePaths.creator,
      RoutePaths.timeline,
    ]) {
      router.go(path);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('page $path'), findsOneWidget);
      expect(find.byKey(const Key('guide_step_primary')), findsNothing);
      expect(find.textContaining('Step '), findsNothing);
    }
  });
}

enum _CoreStepScreen {
  today(RoutePaths.nexus),
  addSomething(RoutePaths.creator),
  schedule(RoutePaths.timeline);

  const _CoreStepScreen(this.route);
  final String route;
}

CreatorHandshakeReceipt _guideReceipt(String taskId) {
  final now = DateTime.utc(2026, 11, 1, 12);
  return CreatorHandshakeReceipt(
    proposalId: 'guide-proposal',
    accountScopeId: AccountStorageScope.authenticated('account-a').v2Namespace!,
    confirmationTokenId: 'guide-confirmation',
    appliedOperationIds: const <String>['guide-operation'],
    taskIds: <String>[taskId],
    appliedAt: now,
    undoExpiresAt: now.add(const Duration(minutes: 10)),
    resultingDomainRevision: 'guide-revision',
  );
}

Future<void> _prepareTimelineGuide(
  ProviderContainer container, {
  String taskId = 'restored',
}) async {
  await container.read(adaptiveGuidanceProvider.future);
  final notifier = container.read(adaptiveGuidanceProvider.notifier);
  await notifier.record(GuidanceMilestone.firstItem);
  await notifier.record(GuidanceMilestone.firstSchedule);
  final now = DateTime.now();
  await notifier.recordCreatorHandshakeReceipt(
    CreatorHandshakeReceipt(
      proposalId: 'guide-proposal',
      accountScopeId: AccountStorageScope.authenticated(
        'account-a',
      ).v2Namespace!,
      confirmationTokenId: 'guide-confirmation',
      appliedOperationIds: const <String>['guide-operation'],
      taskIds: <String>[taskId],
      appliedAt: now,
      undoExpiresAt: now.add(const Duration(minutes: 10)),
      resultingDomainRevision: 'guide-revision',
    ),
  );
}

Future<void> _pumpTimelineWithGuide(
  WidgetTester tester,
  ProviderContainer container,
  Locale locale,
) async {
  final router = GoRouter(
    initialLocation: RoutePaths.timeline,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.timeline,
        builder: (_, _) => const TimelineScreen(),
      ),
      GoRoute(
        path: RoutePaths.creator,
        builder: (_, _) => const CreatorScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await _pumpRouterWithGuide(tester, container, router, locale: locale);
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

FilledButton _primary(WidgetTester tester, String label) {
  return tester.widget<FilledButton>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
    ),
  );
}

Future<void> _pumpCreatorWithGuide(
  WidgetTester tester,
  ProviderContainer container, {
  Locale locale = const Locale('en'),
}) async {
  final GoRouter router = GoRouter(
    initialLocation: RoutePaths.creator,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.creator,
        builder: (_, _) => const CreatorScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await _pumpRouterWithGuide(tester, container, router, locale: locale);
}

Future<void> _pumpRouterWithGuide(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: locale,
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Stack(
            children: <Widget>[
              // Like the app root: the step card moves the page down
              // instead of covering it.
              Positioned.fill(
                child: GuideHintSpace(child: child ?? const SizedBox.shrink()),
              ),
              ListenableBuilder(
                listenable: router.routerDelegate,
                builder: (BuildContext context, Widget? _) {
                  final String location =
                      router.routerDelegate.currentConfiguration.isEmpty
                      ? ''
                      : router.routerDelegate.state.uri.path;
                  return AdaptiveGuideOverlay(
                    key: ValueKey<String>(location),
                    router: router,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await container.read(authUserProvider.future);
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

ProviderContainer _container(
  _Tasks repo, {
  bool overlay = false,
  bool timeline = false,
  DateTime Function()? timelineClock,
}) {
  return ProviderContainer(
    overrides: [
      sensitivePrefsStoreProvider.overrideWithValue(_Prefs()),
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated('account-a'),
      ),
      domainTaskRepositoryProvider.overrideWithValue(repo),
      domainGoalRepositoryProvider.overrideWithValue(const _Goals()),
      domainHabitRepositoryProvider.overrideWithValue(const _Habits()),
      domainNoteRepositoryProvider.overrideWithValue(const _Notes()),
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      if (timeline) ...[
        if (timelineClock != null)
          timelineClockProvider.overrideWithValue(timelineClock),
        timelineProvider.overrideWith(_EmptyTimeline.new),
        timelinePersistenceCorruptedProvider.overrideWith((ref) => false),
        taskActionsProvider.overrideWith((ref) => _GuideTaskActions(ref, repo)),
      ],
      if (overlay) ...[
        accountOnboardingCompleteProvider.overrideWith(_OnboardingDone.new),
        authUserProvider.overrideWith(
          (Ref ref) => Stream<User?>.value(
            const User(
              id: 'account-a',
              email: 'account-a@example.test',
              emailVerified: true,
            ),
          ),
        ),
        authSessionBoundaryProvider.overrideWith(_Boundary.new),
        dailyDecisionIntelligenceProvider.overrideWith((Ref ref) => _decision),
      ],
    ],
  );
}

class _EmptyTimeline extends TimelineNotifier {
  @override
  List<TimelineEventEntity> build() => const <TimelineEventEntity>[];
}

class _GuideTaskActions extends TaskActions {
  // The superclass field is library-private.
  // ignore: use_super_parameters
  _GuideTaskActions(Ref ref, this.repo) : _ref = ref, super(ref);
  final Ref _ref;
  final _Tasks repo;

  @override
  Future<void> completeTask(String id, {bool notify = true}) async {
    await repo.saveTask(repo.tasks[id]!.complete());
    _ref.invalidate(allTasksProvider);
  }

  @override
  Future<void> skipTask(String id, {bool notify = true}) async {
    await repo.saveTask(repo.tasks[id]!.copyWith(isSkipped: true));
    _ref.invalidate(allTasksProvider);
  }

  @override
  Future<void> updateTaskDetails({
    required String id,
    required String title,
    String? description,
    int? priority,
    Duration? estimatedDuration,
    DateTime? scheduledFor,
    DateTime? dueDate,
    String? goalId,
    bool clearDescription = false,
    bool clearEstimatedDuration = false,
    bool clearScheduledFor = false,
    bool clearDueDate = false,
    bool clearGoalId = false,
  }) async {
    await repo.saveTask(
      repo.tasks[id]!.copyWith(scheduledFor: scheduledFor, dueDate: dueDate),
    );
    _ref.invalidate(allTasksProvider);
  }
}

class _OnboardingDone extends AccountOnboardingCompleteNotifier {
  @override
  bool build() => true;
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'account-a',
    isTransitioning: false,
    isStorageReady: true,
  );
}

const DailyDecisionIntelligence _decision = DailyDecisionIntelligence(
  primaryAction: 'Wait for evidence.',
  momentum: '0% stable',
  trajectory: 'No trajectory yet.',
  energy: 'Energy not checked',
  warning: 'No material constraint is supported by current evidence.',
  recovery: 'No recovery signal yet.',
  recommendedAction: 'Wait for evidence.',
  rationale: 'No evidence yet.',
  changeSummary: 'No prior state.',
  evidence: <String>[],
  confidence: 0,
  observedOutcomes: 0,
);

class _Tasks implements ITaskRepository {
  _Tasks();

  factory _Tasks.withScheduledTask() =>
      _Tasks()
        ..tasks['restored'] = TaskEntity(
          id: 'restored',
          title: 'Restored task',
          createdAt: DateTime.now(),
          scheduledFor: DateTime.now().add(const Duration(days: 1)),
        );

  final Map<String, TaskEntity> tasks = <String, TaskEntity>{};
  int saveCalls = 0;

  @override
  Future<void> deleteTask(String id) async => tasks.remove(id);

  @override
  Future<List<TaskEntity>> getAllTasks() async => tasks.values.toList();

  @override
  Future<TaskEntity?> getTaskById(String id) async => tasks[id];

  @override
  Future<void> saveTask(TaskEntity task) async {
    saveCalls += 1;
    tasks[task.id] = task;
  }
}

class _Goals implements IGoalRepository {
  const _Goals();

  @override
  Future<void> deleteGoal(String id) async {}

  @override
  List<GoalEntity> getGoals() => <GoalEntity>[];

  @override
  Future<void> saveGoal(GoalEntity goal) async {}

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}
}

class _Habits implements IHabitRepository {
  const _Habits();

  @override
  Future<List<HabitEntity>> getHabits() async => const <HabitEntity>[];

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {}
}

class _Notes implements INoteRepository {
  const _Notes();

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<List<NoteEntity>> getNotes() async => const <NoteEntity>[];

  @override
  Future<void> saveNote(NoteEntity note) async {}
}

class _Prefs implements SharedPrefsStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> init() async {}

  @override
  String? load(String key) => values[key];

  @override
  Future<void> save(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
