import 'package:fantastic_guacamole/state/providers/trajectory_consequence_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom trajectory scenario is explicit, stable, and clearable', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(trajectoryCustomScenarioProvider), isNull);

    const TrajectoryCustomScenarioDraft draft = TrajectoryCustomScenarioDraft(
      subjectId: 'task-42',
      adjustment: TrajectoryCustomAdjustment.delay,
      delayDays: 3,
    );
    container.read(trajectoryCustomScenarioProvider.notifier).compose(draft);

    expect(container.read(trajectoryCustomScenarioProvider), same(draft));
    expect(
      trajectoryCustomScenarioId(draft, horizonDays: 30),
      'custom-delay-task-42-3-30',
    );
    expect(
      trajectoryCustomScenarioId(
        const TrajectoryCustomScenarioDraft(
          subjectId: 'task-42',
          adjustment: TrajectoryCustomAdjustment.delay,
          delayDays: 99,
        ),
        horizonDays: 30,
      ),
      'custom-delay-task-42-30-30',
    );

    container.read(trajectoryCustomScenarioProvider.notifier).clear();
    expect(container.read(trajectoryCustomScenarioProvider), isNull);
  });

  test('scenario ids keep complete and scope-reduction paths distinct', () {
    expect(
      trajectoryCustomScenarioId(
        const TrajectoryCustomScenarioDraft(
          subjectId: 'task-a',
          adjustment: TrajectoryCustomAdjustment.complete,
        ),
        horizonDays: 7,
      ),
      'custom-complete-task-a-7',
    );
    expect(
      trajectoryCustomScenarioId(
        const TrajectoryCustomScenarioDraft(
          subjectId: 'task-a',
          adjustment: TrajectoryCustomAdjustment.reduceScope,
        ),
        horizonDays: 7,
      ),
      'custom-reduce-task-a-7',
    );
  });
}
