import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_si_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/policies/si_policy.dart';

class GenerateSiDecision {
  GenerateSiDecision(this.taskRepo, this.siRepo);

  final ITaskRepository taskRepo;
  final ISiRepository siRepo;

  Future<SiDecisionEntity> call([String input = '']) async {
    final state = await siRepo.getCurrentState();
    if (state == null) return const SiDecisionEntity(rationale: 'No state available.');

    final tasks = await taskRepo.getAllTasks();

    if (SiPolicy.shouldSuggestBreak(state)) {
      return const SiDecisionEntity(
        rationale: 'Fatigue high or energy low — take a break.',
        shouldTakeBreak: true,
      );
    }

    if (tasks.isEmpty) {
      return const SiDecisionEntity(rationale: 'No tasks available.');
    }

    final sorted = [...tasks]..sort((a, b) => b.priority.compareTo(a.priority));
    final top = sorted.first;

    return SiDecisionEntity(
      selectedTaskId: top.id,
      rationale: 'Highest priority task selected.',
      action: 'Focus on: ${top.title}',
      orderedTaskIds: sorted.map((t) => t.id).toList(),
      recommendedFocusMinutes: 25,
    );
  }
}
