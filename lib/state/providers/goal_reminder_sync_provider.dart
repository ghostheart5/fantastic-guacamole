import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/service_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_reminder_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalReminderSyncProvider = Provider<GoalReminderSync>(
  (Ref ref) => GoalReminderSync(ref),
);

/// Brings this account's goal reminders up to date after a change to a
/// goal's linked tasks, so the step counts and the "almost there" nudge stay
/// current.
class GoalReminderSync extends ReminderSyncRunner {
  GoalReminderSync(super.ref) : super(name: 'Goal', sync: _syncGoals);

  static Future<void> _syncGoals(
    Ref ref,
    AccountOperation owner,
    bool granted,
  ) async {
    final List<GoalEntity> goals = ref.read(getGoalsUseCaseProvider).call();
    owner.check();
    await owner.wait(
      ref
          .read(reminderOrchestratorServiceProvider)
          .syncGoalReminderGroup(
            goals: goals,
            permissionGranted: granted,
            shouldContinue: () => owner.isCurrent,
          ),
    );
  }
}

/// Wraps the task store so every write to a task that has or had a goal
/// (create, edit including linking and unlinking, complete, skip, delete,
/// restore) asks [GoalReminderSync] to update the goal reminders.
ITaskRepository goalReminderSyncingTaskStore(
  ITaskRepository store,
  void Function() goalsChanged,
) => reminderSyncingTaskStore(store, goalsChanged, concerns: _hasGoal);

bool _hasGoal(TaskEntity task) => task.goalId?.trim().isNotEmpty ?? false;
