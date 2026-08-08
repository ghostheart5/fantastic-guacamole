import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/entities/si_state_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/si_policy.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: SI Console
///
/// Resolved by taskProvider/coach flows. All outputs pass SiPolicy.sanitize.
class GenerateSiDecision {
  GenerateSiDecision(
    this.taskRepo,
    this.siRepo, {
    this.hasSettings = true,
    this.hasLogs = true,
    this.withinSubscriptionLimits = true,
  });

  final ITaskRepository taskRepo;
  final ISiRepository siRepo;

  /// Context-availability signals fed to [SiPolicy.hasRequiredContext]. They
  /// default to true so existing callers keep working; pass real signals as
  /// they become available rather than asserting context that was never checked.
  final bool hasSettings;
  final bool hasLogs;
  final bool withinSubscriptionLimits;

  Future<SiDecisionEntity> call([String input = '']) async {
    final SiStateEntity? state = await siRepo.getCurrentState();

    if (!SiPolicy.hasRequiredContext(
      hasCurrentContext: state != null,
      hasSettings: hasSettings,
      hasLogs: hasLogs,
      withinSubscriptionLimits: withinSubscriptionLimits,
    )) {
      return SiPolicy.sanitize(
        const SiDecisionEntity(rationale: 'No state available.'),
      );
    }

    final tasks = await taskRepo.getAllTasks();

    if (SiPolicy.shouldSuggestBreak(state!)) {
      return SiPolicy.sanitize(
        const SiDecisionEntity(
          rationale: 'Fatigue high or energy low — take a break.',
          shouldTakeBreak: true,
        ),
      );
    }

    if (tasks.isEmpty) {
      return SiPolicy.sanitize(
        const SiDecisionEntity(rationale: 'No tasks available.'),
      );
    }

    final sorted = [...tasks]..sort((a, b) => b.priority.compareTo(a.priority));
    final top = sorted.first;

    return SiPolicy.sanitize(
      SiDecisionEntity(
        selectedTaskId: top.id,
        rationale: 'Highest priority task selected.',
        action: 'Focus on: ${top.title}',
        orderedTaskIds: sorted.map((t) => t.id).toList(),
        recommendedFocusMinutes: 25,
      ),
    );
  }
}
