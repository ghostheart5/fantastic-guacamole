@Timeout(Duration(seconds: 90))
library;

import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/completion_side_effect_policy.dart';
import 'package:fantastic_guacamole/domain/usecases/complete_task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/features/progression/ui/progression_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/patterns_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/patterns_screen_harness.dart';

/// Patterns with the real patternsProvider over fake account-scoped stores:
/// it stays live, it is fresh when the tab comes back, and an account switch
/// never shows the previous account's records.
void main() {
  late AccountStorageScope scope;
  late Map<String, List<TaskEntity>> tasksByUser;
  late Map<String, List<HabitEntity>> habitsByUser;
  late bool boundaryDriven;

  setUp(() {
    scope = AccountStorageScope.authenticated('account-a');
    boundaryDriven = false;
    tasksByUser = <String, List<TaskEntity>>{
      'account-a': <TaskEntity>[
        openTask('open', title: 'Write report', minutes: 30),
        skippedTask('a2', patternsAt(2), title: 'Tax skipped'),
      ],
      'account-b': <TaskEntity>[
        skippedTask('b2', patternsAt(2), title: 'Fence skipped'),
      ],
    };
    habitsByUser = <String, List<HabitEntity>>{
      'account-a': <HabitEntity>[patternsHabit('ha', title: 'Walk A')],
      'account-b': <HabitEntity>[patternsHabit('hb', title: 'Stretch B')],
    };
  });

  ProviderContainer build() {
    final _MemoryPrefs prefs = _MemoryPrefs();
    return ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((ref) {
          if (!boundaryDriven) return scope;
          final AuthSessionBoundary b = ref.watch(authSessionBoundaryProvider);
          return b.userId != null && b.isStorageReady && !b.isTransitioning
              ? AccountStorageScope.authenticated(b.userId!)
              : const AccountStorageScope.unsafe();
        }),
        authSessionBoundaryProvider.overrideWith(_Boundary.new),
        patternsClockProvider.overrideWithValue(() => patternsNow),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        siStateProvider.overrideWith(_FixedSiStateController.new),
        learningProvider.overrideWith(_FixedLearningController.new),
        profileProvider.overrideWith(_TestProfileController.new),
        adaptiveGuidanceProvider.overrideWith(PatternsGuidanceSpy.new),
        decisionOutcomeRepositoryProvider.overrideWithValue(null),
        sharedPrefsStoreProvider.overrideWithValue(prefs),
        domainTaskRepositoryProvider.overrideWith((ref) {
          final String? user = ref.watch(accountStorageScopeProvider).rawUserId;
          return _Tasks(
            tasksByUser.putIfAbsent(user ?? '', () => <TaskEntity>[]),
          );
        }),
        completeTaskUseCaseProvider.overrideWith((ref) {
          final ITaskRepository repository = ref.watch(
            domainTaskRepositoryProvider,
          );
          return CompleteTask(
            repository,
            durableMutation: (String id) async {
              final TaskEntity? task = await repository.getTaskById(id);
              if (task == null) return CompletionMutationOutcome.conflict;
              await repository.saveTask(
                task.copyWith(isCompleted: true, completedAt: patternsNow),
              );
              return CompletionMutationOutcome.applied;
            },
          );
        }),
        domainHabitRepositoryProvider.overrideWith((ref) {
          final String? user = ref.watch(accountStorageScopeProvider).rawUserId;
          return _Habits(habitsByUser.putIfAbsent(user ?? '', () => []));
        }),
        habitOccurrenceCoordinatorProvider.overrideWith((ref) {
          final AccountStorageScope current = ref.watch(
            accountStorageScopeProvider,
          );
          final repository = ref.watch(habitOccurrenceRepositoryProvider);
          if (repository == null) return null;
          return HabitOccurrenceCoordinator(
            scope: current,
            habitRepository: ref.watch(domainHabitRepositoryProvider),
            occurrenceRepository: repository,
            outcomeRepository: _Outcomes(),
            learningPaused: () async => true,
            clock: () => patternsNow,
          );
        }),
        reminderOrchestratorServiceProvider.overrideWithValue(
          ReminderOrchestratorService(
            preferences: _DisabledPreferences(),
            notifications: NotificationsService(_NoopNotifications()),
            scheduler: NotificationScheduler(),
            accountScope: null,
          ),
        ),
      ],
    );
  }

  /// The screen under a TickerMode the test can turn off, as the navigation
  /// shell does for a tab that is not in view.
  Future<(ProviderContainer, ValueNotifier<bool>)> mount(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final ProviderContainer container = build();
    final ValueNotifier<bool> inView = ValueNotifier<bool>(true);
    addTearDown(inView.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: appTheme,
          supportedLocales: ChronoSparkLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            ChronoSparkLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: ValueListenableBuilder<bool>(
            valueListenable: inView,
            builder: (BuildContext context, bool enabled, Widget? child) =>
                TickerMode(enabled: enabled, child: child!),
            child: const ProgressionScreen(),
          ),
        ),
      ),
    );
    return (container, inView);
  }

  /// A task finished elsewhere (Today): the saved task changes and the task
  /// list reloads, which is what TaskActions.completeTask ends with. (The
  /// real TaskActions path is covered in patterns_provider_test.dart; under
  /// widget-test fake time it does not complete.)
  void finishOnToday(ProviderContainer container) {
    final List<TaskEntity> tasks = tasksByUser['account-a']!;
    final int i = tasks.indexWhere((TaskEntity t) => t.id == 'open');
    tasks[i] = tasks[i].copyWith(isCompleted: true, completedAt: patternsNow);
    container.invalidate(allTasksProvider);
  }

  /// Runs [work] under fake time: pumps until it completes.
  Future<void> drive(WidgetTester tester, Future<Object?> work) async {
    bool done = false;
    Object? error;
    unawaited(
      work.then(
        (_) => done = true,
        onError: (Object e) {
          error = e;
          done = true;
        },
      ),
    );
    for (int i = 0; i < 200 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    if (error != null) fail('the action failed: $error');
    if (!done) fail('the action never finished');
  }

  /// Pumps until the figures are settled (no first read, no update).
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      if (find.text('Reading your records…').evaluate().isEmpty &&
          find.text('Updating from your records…').evaluate().isEmpty) {
        return;
      }
    }
    fail('Patterns never settled');
  }

  /// The day-change timer goes with the provider.
  Future<void> unmount(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  }

  Finder value(String section, String label, String text) => find.descendant(
    of: inPatternsSection(
      section,
      find.ancestor(
        of: find.text(label),
        matching: find.byType(PlainMetricRow),
      ),
    ),
    matching: find.text(text),
  );

  testWidgets('finishing a task updates the screen, keeping the earlier '
      'figures while it updates', (tester) async {
    final (ProviderContainer container, _) = await mount(tester);
    await settle(tester);
    expect(find.text('Write report'), findsNothing);
    expect(
      value('patterns-workload', 'Not on a day', '30 min'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Nothing recorded in these days.'),
      findsOneWidget,
    );

    finishOnToday(container);
    // Every frame until it settles: the fresh figure, or the earlier figures
    // of this account marked as updating; never the old ones unmarked.
    bool sawFresh = false;
    for (int i = 0; i < 100 && !sawFresh; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      sawFresh = value(
        'patterns-trend',
        'Tasks finished',
        '1',
      ).evaluate().isNotEmpty;
      if (!sawFresh) {
        expect(find.text('Updating from your records…'), findsOneWidget);
        expect(find.text('Walk A'), findsOneWidget);
      }
    }
    expect(sawFresh, isTrue);
    await settle(tester);
    expect(value('patterns-trend', 'Tasks finished', '1'), findsOneWidget);
    // The only open task is finished: nothing is planned or unplaced now.
    expect(
      find.textContaining('Nothing planned for the next 7 days'),
      findsOneWidget,
    );
    await unmount(tester, container);
  });

  testWidgets('checking in a habit updates the screen', (tester) async {
    final (ProviderContainer container, _) = await mount(tester);
    await settle(tester);
    expect(find.text('0 of 7 days'), findsOneWidget);

    await drive(tester, container.read(habitsProvider.future));
    await drive(
      tester,
      container.read(habitsProvider.notifier).completeHabit('ha'),
    );
    await settle(tester);
    expect(find.text('1 of 7 days'), findsOneWidget);
    expect(value('patterns-trend', 'Habit check-ins', '1'), findsOneWidget);
    await unmount(tester, container);
  });

  testWidgets('the first frame after the tab comes back into view shows '
      'fresh data', (tester) async {
    final (ProviderContainer container, ValueNotifier<bool> inView) =
        await mount(tester);
    await settle(tester);
    expect(
      find.textContaining('Nothing recorded in these days.'),
      findsOneWidget,
    );

    // The tab goes out of view; a task is finished on Today meanwhile.
    inView.value = false;
    await tester.pump();
    finishOnToday(container);
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    inView.value = true;
    await tester.pump();
    // First frame back: the earlier figures, marked as updating (the
    // re-read starts right after this frame), not announced aloud.
    final Finder updating = find.text('Updating from your records…');
    expect(
      updating,
      findsOneWidget,
      reason: 'the first frame shows stale figures without saying so',
    );
    expect(
      tester
          .widget<Semantics>(
            find.ancestor(of: updating, matching: find.byType(Semantics)).first,
          )
          .properties
          .liveRegion,
      isFalse,
    );
    // Then: the fresh figures, and the updating line is gone.
    await settle(tester);
    expect(value('patterns-trend', 'Tasks finished', '1'), findsOneWidget);
    expect(updating, findsNothing);
    await unmount(tester, container);
  });

  testWidgets('an account switch while out of view: back in view, nothing '
      'of the previous account is shown', (tester) async {
    boundaryDriven = true;
    final (ProviderContainer container, ValueNotifier<bool> inView) =
        await mount(tester);
    final _Boundary boundary =
        container.read(authSessionBoundaryProvider.notifier) as _Boundary;
    boundary.moveTo(
      const AuthSessionBoundary(
        generation: 2,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    await settle(tester);
    expect(find.text('Walk A'), findsOneWidget);

    inView.value = false;
    await tester.pump();
    for (final AuthSessionBoundary next in const <AuthSessionBoundary>[
      AuthSessionBoundary(
        generation: 3,
        userId: 'account-b',
        isTransitioning: true,
        isStorageReady: false,
      ),
      AuthSessionBoundary(
        generation: 4,
        userId: 'account-b',
        isTransitioning: false,
        isStorageReady: true,
      ),
    ]) {
      boundary.moveTo(next);
      container.invalidate(habitsProvider);
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
    }

    inView.value = true;
    final List<String> leaks = <String>[];
    for (int i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 1));
      for (final String text in <String>['Walk A', 'Tax skipped']) {
        if (find.text(text).evaluate().isNotEmpty) leaks.add('$text at $i');
      }
    }
    expect(leaks, isEmpty, reason: leaks.join(' / '));
    await settle(tester);
    expect(find.text('Stretch B'), findsOneWidget);
    await unmount(tester, container);
  });

  testWidgets('after an account switch nothing of the previous account is '
      'ever shown, including while loading', (tester) async {
    boundaryDriven = true;
    final (ProviderContainer container, _) = await mount(tester);
    final _Boundary boundary =
        container.read(authSessionBoundaryProvider.notifier) as _Boundary;
    boundary.moveTo(
      const AuthSessionBoundary(
        generation: 2,
        userId: 'account-a',
        isTransitioning: false,
        isStorageReady: true,
      ),
    );
    await settle(tester);
    expect(find.text('Walk A'), findsOneWidget);
    expect(find.text('Tax skipped'), findsOneWidget);

    final List<String> leaks = <String>[];
    void check(String step) {
      for (final String text in <String>['Walk A', 'Tax skipped']) {
        if (find.text(text).evaluate().isNotEmpty) leaks.add('$text at $step');
      }
    }

    Future<void> move(AuthSessionBoundary next, String step) async {
      boundary.moveTo(next);
      // The account fence invalidates the habit list.
      container.invalidate(habitsProvider);
      await tester.pump();
      check('$step, first frame');
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 1));
        check('$step, frame $i');
      }
    }

    await move(
      const AuthSessionBoundary(
        generation: 3,
        userId: 'account-b',
        isTransitioning: true,
        isStorageReady: false,
      ),
      'transition',
    );
    await move(
      const AuthSessionBoundary(
        generation: 4,
        userId: 'account-b',
        isTransitioning: false,
        isStorageReady: true,
      ),
      'signed in as B',
    );
    await settle(tester);
    check('settled');
    expect(leaks, isEmpty, reason: leaks.join(' / '));
    expect(find.text('Stretch B'), findsOneWidget);
    expect(find.text('Fence skipped'), findsOneWidget);
    await unmount(tester, container);
  });
}

class _FixedSiStateController extends SIStateController {
  @override
  SIState build() =>
      const SIState(energy: 0.8, fatigue: 0.1, completedToday: 0);
}

class _FixedLearningController extends LearningController {
  @override
  LearningState build() => const LearningState();
}

class _TestProfileController extends ProfileController {
  @override
  ProfileState build() => ProfileState();

  @override
  Future<void> addXP(int amount) async {
    state = state.copyWith(xp: state.xp + amount);
  }
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'synthetic-scope',
    isTransitioning: false,
    isStorageReady: true,
  );

  void moveTo(AuthSessionBoundary next) => state = next;
}

class _Tasks implements ITaskRepository {
  _Tasks(this._records);
  final List<TaskEntity> _records;

  @override
  Future<List<TaskEntity>> getAllTasks() async {
    final List<TaskEntity> values = List<TaskEntity>.of(_records);
    await Future<void>.delayed(Duration.zero);
    return values;
  }

  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      _records.where((TaskEntity t) => t.id == id).firstOrNull;

  @override
  Future<void> saveTask(TaskEntity task) async {
    final int i = _records.indexWhere((TaskEntity t) => t.id == task.id);
    if (i >= 0) {
      _records[i] = task;
    } else {
      _records.add(task);
    }
  }

  @override
  Future<void> deleteTask(String id) async =>
      _records.removeWhere((TaskEntity t) => t.id == id);
}

class _Habits implements IHabitRepository {
  _Habits(this._records);
  final List<HabitEntity> _records;

  @override
  Future<List<HabitEntity>> getHabits() async => List<HabitEntity>.of(_records);

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {
    _records
      ..clear()
      ..addAll(habits);
  }
}

class _Outcomes implements IDecisionOutcomeRepository {
  @override
  Future<List<DecisionOutcomeEntity>> load() async =>
      const <DecisionOutcomeEntity>[];

  @override
  Future<void> record(DecisionOutcomeEntity outcome) async {}
}

class _MemoryPrefs implements SharedPrefsStore {
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

final class _DisabledPreferences implements SharedPrefsStore {
  @override
  Future<void> clear() async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> init() async {}
  @override
  String? load(String key) => 'false';
  @override
  Future<void> save(String key, String value) async {}
}

final class _NoopNotifications implements INotificationRepository {
  @override
  Future<void> cancelNotification(String id) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<NotificationEntity>> getNotifications() async =>
      const <NotificationEntity>[];
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> scheduleNotification(NotificationEntity notification) async {}
}
