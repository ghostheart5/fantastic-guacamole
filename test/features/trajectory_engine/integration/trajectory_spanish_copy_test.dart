import 'package:fantastic_guacamole/domain/predictive/predictive_planning_contract.dart';
import 'package:fantastic_guacamole/domain/trajectory/trajectory_consequence_contract.dart';
import 'package:fantastic_guacamole/engine/trajectory/future_consequence_engine.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_engine_model_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/trajectory_screen_harness.dart';
import '../../../helpers/trajectory_test_fixture.dart';

/// Future outcomes in Spanish: the page, generated option copy and status
/// details. (Split out of the former trajectory_engine_integration_test.dart.)
void main() {
  testWidgets('localizes the observed Spanish page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      trajectoryScreenHarness(locale: const Locale('es')),
    );
    await tester.pump();

    expect(find.text('Perspectivas'), findsOneWidget);
    expect(find.text('Son estimaciones, no promesas.'), findsOneWidget);
    expect(find.text('Si sigues como vas'), findsOneWidget);
    expect(find.text('En los próximos 7 días.'), findsOneWidget);
    // The fixture's v4 workload over the next 7 days is 18 (below 50).
    expect(find.text('Ligera, 18%'), findsOneWidget);
    expect(find.text('Carga de trabajo'), findsWidgets);
    expect(find.text('Estimación'), findsWidgets);
    expect(find.text('De tus registros'), findsWidgets);
    expect(find.text('Opciones'), findsOneWidget);
    expect(
      find.text(
        'Elige una para compararla con seguir como vas. Los rangos más amplios '
        'son menos fiables.',
      ),
      findsOneWidget,
    );
    expect(find.text('Options'), findsNothing);
    expect(find.text('Supuestos de esta estimación'), findsWidgets);
    expect(find.text('What this estimate assumes'), findsNothing);
  });

  testWidgets('localizes current generated Spanish forecast copy and strong pace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = trajectoryTestEngineModel();
    final baseline = trajectoryTestBaseline(momentum: 90);
    final comparison = const FutureConsequenceEngine().compare(
      baseline: baseline,
      generatedAt: trajectoryFixtureNow,
      interventions: [
        TrajectoryIntervention(
          id: 'apply-smart-planner',
          type: TrajectoryInterventionType.applySmartPlanner,
          title: 'Apply Choose a step recommendation',
          description:
              'Protect Ship protected milestone and use the feasible plan as the active schedule.',
          horizon: const Duration(days: 7),
          subjectId: 'task-launch',
          proposedBlocks: baseline.blocks,
        ),
        TrajectoryIntervention(
          id: 'complete-task-launch',
          type: TrajectoryInterventionType.completeTask,
          title: 'Complete Ship protected milestone',
          description:
              'Model the selected Choose a step task as completed in its feasible block.',
          horizon: const Duration(days: 7),
          subjectId: 'task-launch',
        ),
      ],
    );
    await tester.pumpWidget(
      trajectoryScreenHarness(
        locale: const Locale('es'),
        model: TrajectoryEngineModel(
          status: TrajectoryEngineStatus.ready,
          summary: fixture.summary,
          momentum: fixture.momentum,
          comparison: comparison,
          statusDetail: fixture.statusDetail,
          hasAvailableNetworkInterface: true,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Fuerte.'), findsOneWidget);
    expect(find.textContaining('Strong'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Aplicar la recomendación de Elegir un paso').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Apply Choose a step recommendation'), findsNothing);
    await tapTrajectory(
      tester,
      find.text('Completar Ship protected milestone'),
    );
    const description =
        'Modelar la tarea seleccionada de Elegir un paso como completada en su bloque viable.';
    await tester.scrollUntilVisible(
      find.text(description),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(description), findsOneWidget);
    expect(
      find.textContaining('Model the selected Choose a step task'),
      findsNothing,
    );
    expect(
      comparison.outcomes
          .singleWhere(
            (outcome) => outcome.intervention.id == 'complete-task-launch',
          )
          .intervention
          .description,
      'Model the selected Choose a step task as completed in its feasible block.',
    );
    expect(comparison.baseline.momentum, 90);
    expect(tester.takeException(), isNull);
  });

  testWidgets('localizes the fixed custom-removal description in Spanish', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
    final TrajectoryBaseline baseline = trajectoryTestBaseline();
    final TrajectoryComparison
    comparison = const FutureConsequenceEngine().compare(
      baseline: baseline,
      generatedAt: trajectoryFixtureNow,
      interventions: <TrajectoryIntervention>[
        TrajectoryIntervention(
          id: 'custom-remove-task-polish-7',
          type: TrajectoryInterventionType.reduceScope,
          title: 'My scenario: remove Polish optional copy',
          horizon: const Duration(days: 7),
          description:
              'Remove this commitment from the active capacity window and compare the resulting tradeoff.',
          subjectId: 'task-polish',
          displacedSubjectIds: <String>['task-polish'],
        ),
      ],
    );
    expect(
      comparison.outcomes.single.progression.summary,
      'No progress reward is projected from this intervention alone.',
    );
    await tester.pumpWidget(
      trajectoryScreenHarness(
        locale: const Locale('es'),
        model: TrajectoryEngineModel(
          status: TrajectoryEngineStatus.ready,
          summary: fixture.summary,
          momentum: fixture.momentum,
          comparison: comparison,
          statusDetail: fixture.statusDetail,
          hasAvailableNetworkInterface: true,
        ),
      ),
    );
    await tester.pump();

    const String localized =
        'Quitar este compromiso de la ventana de capacidad activa y comparar la compensación resultante.';
    await tester.scrollUntilVisible(
      find.text(localized),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(localized), findsOneWidget);
    expect(find.textContaining('Quitar this commitment'), findsNothing);
    expect(find.textContaining('Remove this commitment'), findsNothing);
    // Render the real engine-produced no-reward result in the expanded panel;
    // a matching dictionary key alone would not catch producer drift.
    await tapTrajectory(tester, find.text('Impacto completo y datos'));
    const noReward =
        'Esta intervención por sí sola no proyecta una recompensa de progreso.';
    await tester.scrollUntilVisible(
      find.text(noReward),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(noReward), findsOneWidget);
    expect(
      find.text(comparison.outcomes.single.progression.summary),
      findsNothing,
    );
  });

  testWidgets('localizes partial evidence details and evidence origins', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final TrajectoryEngineModel fixture = trajectoryTestEngineModel();
    final TrajectoryComparison comparison = trajectoryTestComparison(
      baseline: trajectoryTestBaseline(
        energyOrigin: PredictiveEvidenceOrigin.estimated,
        availabilityOrigin: PredictiveEvidenceOrigin.unavailable,
      ),
    );
    await tester.pumpWidget(
      trajectoryScreenHarness(
        locale: const Locale('es'),
        model: TrajectoryEngineModel(
          status: TrajectoryEngineStatus.partial,
          summary: fixture.summary,
          momentum: fixture.momentum,
          comparison: comparison,
          statusDetail:
              'Future paths are conditional models. Working availability is not configured, so capacity risk, goal dates, and best-fit claims are withheld.',
          hasAvailableNetworkInterface: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Falta algo de información'), findsOneWidget);
    expect(
      find.textContaining('No has configurado tu horario de trabajo'),
      findsOneWidget,
    );
    expect(find.textContaining('Future paths are conditional'), findsNothing);
    await tapTrajectory(tester, find.text('En qué se basa'));
    expect(
      find.textContaining(
        'Energía: estimada; no registrada. Disponibilidad: sin datos registrados.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('unavailable'), findsNothing);
  });
}
