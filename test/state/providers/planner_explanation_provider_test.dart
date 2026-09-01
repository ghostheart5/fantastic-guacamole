import 'package:fantastic_guacamole/data/services/ai/planner_explanation_service.dart';
import 'package:fantastic_guacamole/state/providers/planner_explanation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release defaults contain external Planner explanation before I/O',
    () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(plannerExplanationAvailabilityProvider.future),
        PlannerExplanationAvailability.launchContained,
      );
      expect(
        await container.read(plannerExplanationPortProvider.future),
        isA<DisabledPlannerExplanationPort>(),
      );
    },
  );
}
