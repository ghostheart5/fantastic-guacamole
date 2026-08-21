import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Creator owns persistence while Planner V2 keeps its handoff transient',
    () {
      final String plannerInput = File(
        'lib/domain/planning/planner_input.dart',
      ).readAsStringSync();
      final String nexus = File(
        'lib/state/providers/si_pipeline_provider.dart',
      ).readAsStringSync();
      final String smartPlanner = File(
        'lib/state/controllers/smart_planner_query_controller.dart',
      ).readAsStringSync();
      final String creator = File(
        'lib/features/creator/ui/creator_screen.dart',
      ).readAsStringSync();
      final String creatorDraft = File(
        'lib/state/providers/creator_draft_provider.dart',
      ).readAsStringSync();
      final String creatorHandshake = File(
        'lib/state/providers/creator_handshake_provider.dart',
      ).readAsStringSync();
      final String calendar = File(
        'lib/engine/planning/calendar_service.dart',
      ).readAsStringSync();

      expect(plannerInput, contains('fromTaskEntity'));
      expect(plannerInput, contains('fromLegacyTask'));
      expect(nexus, contains('PlannerInputAdapter.fromTaskEntities'));
      expect(nexus, contains('inputs: plannerInputs'));
      expect(smartPlanner, contains('PlannerV2Response'));
      expect(
        smartPlanner,
        contains("'persistenceMode': 'ephemeral_read_only'"),
      );
      expect(smartPlanner, isNot(contains('PlannerInputAdapter')));
      expect(smartPlanner, isNot(contains('planProposalProvider')));
      expect(creator, isNot(contains('creatorActionsProvider).createTask')));
      expect(creator, contains('creatorHandshakeProvider.notifier'));
      expect(creator, contains('.stage('));
      expect(creator, contains('.confirm()'));
      expect(creator, contains('.undo()'));
      expect(creator, contains('creatorDraftPreviewProvider'));
      expect(creatorDraft, isNot(contains('Repository')));
      expect(creatorDraft, isNot(contains('UseCase')));
      expect(creatorHandshake, contains('CreatorConfirmationToken'));
      expect(creatorHandshake, contains('baseDomainRevision'));
      expect(calendar, contains('required List<PlannerInput> inputs'));
      expect(plannerInput, isNot(contains('Repository')));
    },
  );
}
