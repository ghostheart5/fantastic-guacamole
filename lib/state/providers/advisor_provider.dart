import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/state/controllers/momentum_controller.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/milestones_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/optimization_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final productRecommendationsProvider =
    FutureProvider<List<ProductRecommendation>>((ref) async {
      try {
        final accumulator = ref.read(localMetricsAccumulatorProvider);
        final snapshot = await accumulator.snapshot();
        final momentum = ref.watch(momentumProvider);
        return const ProductAdvisorEngine().fromSnapshot(
          snapshot,
          momentum.chainCount,
        );
      } catch (_) {
        return const ProductAdvisorEngine().analyze(
          nextSeen: 0,
          started: 0,
          completed: 0,
          momentumPeak: 0,
        );
      }
    });

enum ProgressionReviewStatus { ready, empty, loading, unavailable }

class ProgressionReview {
  const ProgressionReview(
    this.text, {
    this.status = ProgressionReviewStatus.ready,
    this.spanishText,
  });

  final String text;
  final String? spanishText;
  final ProgressionReviewStatus status;

  bool get canAct =>
      status == ProgressionReviewStatus.ready ||
      status == ProgressionReviewStatus.empty;
}

final progressionReviewProvider = FutureProvider<ProgressionReview>((
  ref,
) async {
  if (!ref.watch(accountStorageScopeProvider).isWritable) {
    return const ProgressionReview(
      'Progress review is unavailable until your account data is ready.',
      spanishText:
          'La revisión de progreso no está disponible hasta que los datos de tu cuenta estén listos.',
      status: ProgressionReviewStatus.unavailable,
    );
  }
  // Read source health before using projections that intentionally default to
  // zero/empty while loading. Those defaults are not evidence of healthy work.
  final tasks = ref.watch(tasksProvider);
  final goals = ref.watch(goalsReadProvider);
  final logs = ref.watch(logsProvider);
  final milestones = ref.watch(milestonesProvider);
  final trajectory = ref.watch(trajectorySummaryProvider);
  if (tasks.hasError ||
      goals.hasError ||
      logs.error != null ||
      milestones.hasError ||
      trajectory.sourceState == TrajectorySourceState.error ||
      trajectory.sourceState == TrajectorySourceState.partial ||
      trajectory.sourceState == TrajectorySourceState.offline) {
    return const ProgressionReview(
      'Progress review is unavailable because some saved planning evidence '
      'could not be read. Retry after your data is available. '
      'No workload or progress rating has been inferred from missing data.',
      spanishText:
          'La revisión de progreso no está disponible porque no se pudo leer parte de la evidencia guardada. Reintenta cuando tus datos estén disponibles. No se ha deducido ninguna valoración de carga o progreso a partir de datos faltantes.',
      status: ProgressionReviewStatus.unavailable,
    );
  }
  if (tasks.isLoading ||
      goals.isLoading ||
      logs.isLoading ||
      milestones.isLoading ||
      trajectory.sourceState == TrajectorySourceState.loading) {
    return const ProgressionReview(
      'Loading your saved planning evidence. Your progress review will appear '
      'when the required data is ready.',
      spanishText:
          'Cargando tu evidencia de planificación guardada. La revisión aparecerá cuando los datos necesarios estén listos.',
      status: ProgressionReviewStatus.loading,
    );
  }
  if (ref.watch(timelinePersistenceCorruptedProvider)) {
    return const ProgressionReview(
      'Progress review is unavailable because saved Timeline evidence could '
      'not be read completely. Recover that data before relying on a rating.',
      spanishText:
          'La revisión de progreso no está disponible porque no se pudo leer por completo la evidencia de la Línea de Tiempo. Recupera esos datos antes de confiar en una valoración.',
      status: ProgressionReviewStatus.unavailable,
    );
  }
  final activeTasks = tasks.requireValue
      .where((task) => !task.isCompleted)
      .length;
  final activeGoals = goals.requireValue
      .where((goal) => !goal.isCompleted)
      .length;
  if (tasks.requireValue.isEmpty &&
      goals.requireValue.isEmpty &&
      logs.entries.isEmpty) {
    return const ProgressionReview(
      'No saved planning history yet. Create a task or goal and record an '
      'outcome to begin your progress review. A progress rating is not available yet.',
      spanishText:
          'Aún no hay historial de planificación guardado. Crea una tarea o meta y registra un resultado para iniciar la revisión. Todavía no hay una valoración de progreso disponible.',
      status: ProgressionReviewStatus.empty,
    );
  }
  final ExecutionSignals execution = ref.watch(executionSignalsProvider);
  final int timelineHealth = ref.watch(timelineHealthScoreProvider);
  final int timelineRisk = ref.watch(timelineRiskScoreProvider);
  final int overdue = ref.watch(timelineOverdueProvider).length;
  final milestoneSummary = ref.watch(milestoneSummaryProvider);
  return ProgressionReview(
    buildProgressionReview(
      execution: execution,
      pressureIndex: trajectory.pressureIndex,
      timelineHealth: timelineHealth,
      timelineRisk: timelineRisk,
      overdue: overdue,
      milestoneHealth: milestoneSummary.healthScore,
      milestoneOverdue: milestoneSummary.overdue,
      milestoneCount: milestones.requireValue.length,
      activeGoals: activeGoals,
      activeTasks: activeTasks,
    ),
    spanishText: buildProgressionReview(
      spanish: true,
      execution: execution,
      pressureIndex: trajectory.pressureIndex,
      timelineHealth: timelineHealth,
      timelineRisk: timelineRisk,
      overdue: overdue,
      milestoneHealth: milestoneSummary.healthScore,
      milestoneOverdue: milestoneSummary.overdue,
      milestoneCount: milestones.requireValue.length,
      activeGoals: activeGoals,
      activeTasks: activeTasks,
    ),
  );
});

// Preserve the existing text consumer contract while exposing typed availability
// to the screen, so unavailable text can never receive a healthy-state action.
final weeklySummaryProvider = FutureProvider<String>(
  (ref) async => (await ref.watch(progressionReviewProvider.future)).text,
);

void retryProgressionReview(WidgetRef ref) {
  ref.invalidate(tasksProvider);
  ref.invalidate(goalsReadProvider);
  ref.invalidate(logsProvider);
  ref.invalidate(milestonesProvider);
  ref.invalidate(timelineProvider);
  ref.invalidate(predictionProvider);
  ref.invalidate(trajectorySummaryProvider);
  ref.invalidate(progressionReviewProvider);
}

String buildProgressionReview({
  required ExecutionSignals execution,
  required int pressureIndex,
  required int timelineHealth,
  required int timelineRisk,
  required int overdue,
  required int milestoneHealth,
  required int milestoneOverdue,
  required int milestoneCount,
  required int activeGoals,
  required int activeTasks,
  bool spanish = false,
}) {
  String pick(String en, String es) => spanish ? es : en;
  final int actioned = execution.actioned7d;
  final int completed = execution.completed7d;
  final double completionRate = actioned <= 0
      ? 0
      : (completed / actioned).clamp(0.0, 1.0).toDouble();

  final String executionState = actioned == 0
      ? pick(
          'A seven-day follow-through baseline is not available yet',
          'Aún no hay una referencia de cumplimiento de siete días',
        )
      : completionRate >= 0.75
      ? pick('Execution is reliable', 'El cumplimiento es fiable')
      : completionRate >= 0.45
      ? pick('Execution is unstable', 'El cumplimiento es irregular')
      : pick('Execution is breaking down', 'El cumplimiento está disminuyendo');

  final String pressureState = pressureIndex >= 75
      ? pick('Pressure is critical', 'La presión es crítica')
      : pressureIndex >= 55
      ? pick('Pressure is elevated', 'La presión es elevada')
      : pick('Pressure is manageable', 'La presión es manejable');

  final String timelineState = overdue > 0 || timelineHealth < 65
      ? pick(
          'Timeline integrity is at risk',
          'La integridad de la Línea de Tiempo está en riesgo',
        )
      : pick(
          'Timeline integrity is stable',
          'La integridad de la Línea de Tiempo es estable',
        );

  final String milestoneState = milestoneCount == 0
      ? pick(
          'No milestones recorded yet; milestone health is not available',
          'Aún no hay hitos registrados; su estado no está disponible',
        )
      : milestoneOverdue > 0
      ? pick('Milestone drift detected', 'Se detectaron desvíos en los hitos')
      : milestoneHealth >= 70
      ? pick('Milestones are on-track', 'Los hitos siguen su curso')
      : pick(
          'Milestones need tighter execution',
          'Los hitos necesitan un seguimiento más constante',
        );

  final String oneAction = activeTasks == 0 && overdue == 0
      ? pick(
          'Choose a new task when you are ready to build your next outcome.',
          'Elige una nueva tarea cuando quieras avanzar hacia tu próximo resultado.',
        )
      : overdue > 0
      ? pick(
          'Clear one overdue timeline item before adding anything new.',
          'Resuelve un elemento vencido de la Línea de Tiempo antes de añadir algo nuevo.',
        )
      : pressureIndex >= 70
      ? pick(
          'Shrink scope to one critical block and finish it today.',
          'Reduce el alcance a un bloque esencial y complétalo hoy.',
        )
      : completionRate < 0.5
      ? pick(
          'Complete one started task fully before opening another.',
          'Completa una tarea iniciada antes de abrir otra.',
        )
      : pick(
          'Keep momentum by finishing one high-impact task now.',
          'Mantén el impulso completando ahora una tarea de gran impacto.',
        );

  final String completionDetail = actioned == 0
      ? pick(
          'No completed, skipped, or delayed outcomes were recorded in this window.',
          'No se registraron resultados completados, omitidos ni aplazados en este intervalo.',
        )
      : pick(
          '$completed of $actioned recorded outcomes were completed '
              '(${(completionRate * 100).round()}%).',
          'Se completaron $completed de $actioned resultados registrados (${(completionRate * 100).round()}%).',
        );

  if (spanish) {
    return 'REVISIÓN DE PROGRESO\n\n'
        '$executionState. $completionDetail $pressureState (índice $pressureIndex). '
        '$timelineState (estado $timelineHealth%, riesgo $timelineRisk%, vencidos $overdue). '
        '$milestoneState${milestoneCount == 0 ? '' : ' (estado $milestoneHealth%, vencidos $milestoneOverdue)'}.\n\n'
        'Carga activa: $activeTasks tareas en $activeGoals metas.\n'
        'Próxima práctica: $oneAction';
  }
  return 'PROGRESS REVIEW\n\n'
      '$executionState. $completionDetail '
      '$pressureState (index $pressureIndex). '
      '$timelineState (health $timelineHealth%, risk $timelineRisk%, overdue $overdue). '
      '$milestoneState${milestoneCount == 0 ? '' : ' (health $milestoneHealth%, overdue $milestoneOverdue)'}.\n\n'
      'Active workload: $activeTasks tasks across $activeGoals goals.\n'
      'Next practice: $oneAction';
}
