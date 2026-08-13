import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Creator persistence feeds shared PlannerInput consumers without planner-owned persistence', () {
    final String plannerInput = File('lib/domain/planning/planner_input.dart').readAsStringSync();
    final String nexus = File('lib/state/providers/si_pipeline_provider.dart').readAsStringSync();
    final String coach = File('lib/state/controllers/coach_query_controller.dart').readAsStringSync();
    final String calendar = File('lib/engine/planning/calendar_service.dart').readAsStringSync();

    expect(plannerInput, contains('fromTaskEntity'));
    expect(plannerInput, contains('fromLegacyTask'));
    expect(nexus, contains('PlannerInputAdapter.fromTaskEntities'));
    expect(nexus, contains('inputs: plannerInputs'));
    expect(coach, contains('PlannerInputAdapter.fromLegacyTasks'));
    expect(calendar, contains('required List<PlannerInput> inputs'));
    expect(plannerInput, isNot(contains('Repository')));
  });
}
