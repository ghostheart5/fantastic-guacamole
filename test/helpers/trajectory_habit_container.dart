import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/habit_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/notification_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_notification_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/decision_outcome_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/services/habit_occurrence_coordinator.dart';
import 'package:fantastic_guacamole/state/services/notifications_service.dart';
import 'package:fantastic_guacamole/state/services/reminder_orchestrator_service.dart';
import 'package:fantastic_guacamole/system/notifications/notification_scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'trajectory_live_container.dart';

/// A habit created on 2026-09-01 (daily unless [cadence] says otherwise).
HabitEntity trajectoryTestHabit(
  String id,
  String title, {
  HabitCadence cadence = HabitCadence.daily,
}) => HabitEntity(
  id: id,
  title: title,
  cadence: cadence,
  createdAt: DateTime(2026, 9, 1, 8),
);

/// A completed check-in of [habit] for the period containing [at].
HabitOccurrenceEntity trajectoryTestCheckIn(HabitEntity habit, DateTime at) =>
    HabitOccurrenceEntity(
      habitId: habit.id,
      occurrenceKey: RhythmPlanningContext.occurrenceKey(habit, at),
      operationId: 'op-${habit.id}-${at.toIso8601String()}',
      outcome: HabitOccurrenceOutcome.completed,
      recordedAt: at.toUtc(),
    );

/// Stores [records] as [userId]'s check-ins in [store].
Future<void> trajectorySeedCheckIns(
  TrajectoryMemoryStore store,
  String userId,
  List<HabitOccurrenceEntity> records,
) => HabitOccurrenceRepository(
  store,
  AccountStorageScope.authenticated(userId),
).replaceSnapshot(records);

/// The auth boundary for habit tests; tests move it like a real sign-in.
class TrajectoryTestBoundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'account-a',
    isTransitioning: false,
    isStorageReady: true,
  );

  void moveTo(AuthSessionBoundary next) => state = next;
}

/// The live account follows the auth boundary like the real scope does.
class _BoundaryAccount extends TrajectoryLiveAccount {
  @override
  AccountStorageScope build() {
    final AuthSessionBoundary b = ref.watch(authSessionBoundaryProvider);
    return b.userId != null && b.isStorageReady && !b.isTransitioning
        ? AccountStorageScope.authenticated(b.userId!)
        : const AccountStorageScope.unsafe();
  }
}

/// The live forecast container with real habit providers over in-memory
/// stores: habits per user in [habitsByUser] (a user in [failingUsers] has a
/// habit store that fails to read), check-ins in [store], check-ins recorded
/// at [clock] through the real habit list and coordinator.
ProviderContainer trajectoryHabitContainer({
  required DateTime now,
  required DateTime Function() clock,
  required TrajectoryMemoryStore store,
  required Map<String, List<HabitEntity>> habitsByUser,
  Set<String> failingUsers = const <String>{},
  int completed7d = 7,
}) {
  return trajectoryLiveContainer(
    now: now,
    clock: () => clock().toUtc(),
    store: store,
    completed7d: completed7d,
    overrides: [
      authSessionBoundaryProvider.overrideWith(TrajectoryTestBoundary.new),
      trajectoryLiveAccountProvider.overrideWith(_BoundaryAccount.new),
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      siStateProvider.overrideWith(_FixedSiStateController.new),
      learningProvider.overrideWith(_FixedLearningController.new),
      profileProvider.overrideWith(_TestProfileController.new),
      decisionOutcomeRepositoryProvider.overrideWithValue(null),
      domainHabitRepositoryProvider.overrideWith((Ref ref) {
        final String user =
            ref.watch(trajectoryLiveAccountProvider).rawUserId ?? '';
        return _Habits(
          habitsByUser.putIfAbsent(user, () => <HabitEntity>[]),
          fails: failingUsers.contains(user),
        );
      }),
      habitOccurrenceCoordinatorProvider.overrideWith((Ref ref) {
        final AccountStorageScope scope = ref.watch(
          trajectoryLiveAccountProvider,
        );
        final HabitOccurrenceRepository? repository = ref.watch(
          habitOccurrenceRepositoryProvider,
        );
        if (repository == null) return null;
        return HabitOccurrenceCoordinator(
          scope: scope,
          habitRepository: ref.watch(domainHabitRepositoryProvider),
          occurrenceRepository: repository,
          outcomeRepository: _Outcomes(),
          learningPaused: () async => true,
          clock: clock,
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

class _Habits implements IHabitRepository {
  _Habits(this._records, {required this.fails});
  final List<HabitEntity> _records;
  final bool fails;

  @override
  Future<List<HabitEntity>> getHabits() async {
    if (fails) throw const FormatException('habit store unreadable');
    return List<HabitEntity>.of(_records);
  }

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
