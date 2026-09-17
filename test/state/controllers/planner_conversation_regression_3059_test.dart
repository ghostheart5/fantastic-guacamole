import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/smart_planner_query_controller.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late SmartPlannerQueryController planner;
  setUp(() {
    container = ProviderContainer(
      overrides: [
        consentedHumanContextProvider.overrideWithValue(
          const ConsentedHumanContext(
            emotionAllowed: false,
            memoryAllowed: false,
            emotion: null,
            siState: SIState(),
          ),
        ),
      ],
    );
    planner = container.read(smartPlannerQueryControllerProvider);
  });
  tearDown(() => container.dispose());

  PlannerV2Response reply(
    String input, {
    PlannerV2Response? previous,
  }) => planner.buildPlannerResponse(
    input: input,
    energy: 0.6,
    emotion: null,
    contextWasProvided: true,
    isFollowUp: previous != null,
    currentPlan: previous == null
        ? null
        : PlannerConversationSnapshot(
            originalObjective:
                'I need to write an email to my landlord about a leaking sink.',
            currentPlan: previous,
            userContext: previous.userContext,
          ),
  );

  test('asking why answers the question instead of replaying the plan', () {
    final first = reply(
      'I need to write an email to my landlord about a leaking sink.',
    );
    final next = reply('Why?', previous: first);
    expect(next.toConversationText(), isNot(first.toConversationText()));
    expect(
      next.nextStep,
      first.nextStep,
      reason: 'Explaining must not silently replace the agreed action.',
    );
    expect(next.whatIHeard.toLowerCase(), contains('why'));
  });

  test('a smaller request reduces the actual recommended duration', () {
    final first = reply(
      'I need to write an email to my landlord about a leaking sink.',
    );
    final next = reply('Make it smaller please.', previous: first);
    expect(
      next.recommendedOption.estimatedMinutes,
      lessThan(first.recommendedOption.estimatedMinutes),
    );
    expect(next.userContext?.objective, first.userContext?.objective);
  });

  test('reported completion never repeats the completed proposal', () {
    final first = reply(
      'I need to write an email to my landlord about a leaking sink.',
    );
    final next = reply('I already did that. What next?', previous: first);
    expect(next.nextStep, isNot(first.nextStep));
    expect(next.toConversationText().toLowerCase(), contains('completed'));
    expect(next.verifiedEvidence.join(' '), contains('not changed'));
  });

  test('plain conversational rejection does not require a special button', () {
    final first = reply(
      'I need to write an email to my landlord about a leaking sink.',
    );
    final next = reply("That won't work for me.", previous: first);
    expect(next.isClarification, isTrue);
    expect(next.nextStep, isEmpty);
    expect(next.usefulQuestion, isNotNull);
  });
}
