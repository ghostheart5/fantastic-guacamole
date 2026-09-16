import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/smart_planner_query_controller.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Independent behavioral acceptance cases from the response audit. Assertions
// check the task, feasible method and constraints, not exact replacement copy.
final List<Map<String, Object?>> _capturedResponses = [];

PlannerV2Response _answer(
  String input, {
  List<Map<String, String>> history = const [],
  double? energy,
}) {
  final container = ProviderContainer(
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
  try {
    final response = container
        .read(smartPlannerQueryControllerProvider)
        .buildPlannerResponse(
          input: input,
          energy: energy,
          emotion: null,
          contextWasProvided: true,
          history: history,
          isFollowUp: history.isNotEmpty,
        );
    _capturedResponses.add({
      'input': input,
      'history': history,
      'energy': energy,
      'languageCode': response.languageCode,
      'disposition': response.disposition.name,
      'whatIHeard': response.whatIHeard,
      'nextStep': response.nextStep,
      'reason': response.recommendationReason,
      'question': response.usefulQuestion,
      'conversationText': response.toConversationText(),
      'spokenSummary': response.toSpokenSummary(),
      'fullAccessibleText': response.toAccessibleText(),
      'verifiedEvidence': response.verifiedEvidence,
      'options': [
        for (final option in response.options)
          {
            'kind': option.kind.name,
            'description': option.description,
            'minutes': option.estimatedMinutes,
          },
      ],
    });
    return response;
  } finally {
    container.dispose();
  }
}

String _proposedActions(PlannerV2Response response) => [
  response.nextStep,
  ...response.options.map((option) => option.description),
].join(' ').toLowerCase();

void _expectAction(PlannerV2Response response, String object) {
  expect(
    response.isClarification,
    isFalse,
    reason: 'This request supplies a concrete task and can receive a step.',
  );
  expect(
    response.nextStep.toLowerCase(),
    object == 'email' ? matches(RegExp(r'email|message')) : contains(object),
  );
  expect(response.nextStep, isNot(contains('…')));
  expect(response.nextStep.toLowerCase(), isNot(contains('action cycle')));
  expect(
    response.nextStep.toLowerCase(),
    isNot(contains('bounded focus block')),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(() {
    final path = Platform.environment['CHRONOSPARK_PLANNER_AUDIT_OUTPUT'];
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(_capturedResponses)}\n',
      );
    }
  });

  group('concrete requests preserve constraints', () {
    for (final input in [
      'I start my restaurant shift in 30 minutes and need to pack my uniform. '
          'I feel fine; I do not need a break. What should I do first?',
      'Before heading to the restaurant, I need to put my uniform in my bag. '
          'I have five minutes available and do not want a break.',
      'I am tired, but please do not suggest a break. '
          'I need to email my manager tonight. I have five minutes.',
    ]) {
      test('no unwanted recovery: $input', () {
        final response = _answer(input);
        _expectAction(
          response,
          input.contains('uniform') ? 'uniform' : 'email',
        );
        expect(
          _proposedActions(response),
          isNot(
            matches(
              RegExp(
                r'(take (a |one )?(quiet )?break|recovery block|to recover|for recovery)',
              ),
            ),
          ),
        );
      });
    }

    test('caregiving work remains interruptible', () {
      final response = _answer(
        'My toddler keeps interrupting me while I work on the receipts. '
        'I cannot silence interruptions or leave my child alone. '
        'I have ten minutes. Help me make progress.',
      );
      _expectAction(response, 'receipt');
      expect(
        _proposedActions(response),
        isNot(contains('silence interruptions')),
      );
      expect(_proposedActions(response), matches(RegExp(r'one|single')));
      expect(
        '${response.nextStep} ${response.recommendationReason}'.toLowerCase(),
        matches(RegExp(r'interrupt|pause|stop|restart')),
      );
    });

    test(
      'zero energy does not silently override an explicit no-break request',
      () {
        final response = _answer(
          'I need to pack my uniform now. Please do not suggest a break; '
          'I have two minutes available.',
          energy: 0,
        );
        expect(
          _proposedActions(response),
          isNot(matches(RegExp(r'take a pause|take a break|recovery block'))),
        );
        expect(
          '${response.whatIHeard} ${response.nextStep}'.toLowerCase(),
          contains('uniform'),
        );
      },
    );

    test('long request keeps the actual email objective', () {
      final response = _answer(
        'New situation: I have 20 minutes before school pickup. '
        'I must send an overdue work email. Dinner can wait. '
        'Help me choose my next step.',
      );
      _expectAction(response, 'email');
      expect(response.nextStep.toLowerCase(), isNot(contains('start dinner')));
      expect(response.usefulQuestion ?? '', isNot(contains('artifact')));
      expect(
        response.usefulQuestion?.toLowerCase(),
        matches(RegExp(r'leave|travel|depart')),
        reason: 'Time until pickup does not establish time free for work.',
      );
      expect(
        response.options.map((option) => option.estimatedMinutes),
        everyElement(lessThan(20)),
      );
      expect(
        response.recommendationReason,
        isNot(contains('available 20 minutes')),
      );
    });

    test('explicit work time after allowing for travel remains available', () {
      final response = _answer(
        'I have 20 minutes available for work after allowing for travel to school pickup. '
        'I need to draft an overdue email.',
      );
      _expectAction(response, 'email');
      expect(response.usefulQuestion, isNull);
      expect(response.recommendedOption.estimatedMinutes, 20);
    });

    test('specific household action does not ask user to invent an action', () {
      final response = _answer('I have ten minutes to fold one shirt.');
      _expectAction(response, 'shirt');
      expect(response.nextStep.toLowerCase(), contains('fold'));
      expect(
        response.usefulQuestion ?? '',
        isNot(contains('What outcome matters most')),
      );
    });

    test('deadline does not become an asserted free time budget', () {
      final response = _answer(
        'My restaurant shift starts in 30 minutes. '
        'I need to pack my uniform, and travel time is not included.',
      );
      expect(
        response.recommendationReason,
        isNot(contains('your requested 30-minute limit')),
      );
      expect(
        '${response.usefulQuestion ?? ''} ${response.nextStep}'.toLowerCase(),
        matches(RegExp(r'leave|travel|depart')),
        reason: 'The unknown departure constraint must be addressed.',
      );
    });
  });

  group('conversation corrections', () {
    const original =
        'I have ten minutes to pack my uniform into my bag. No break needed.';
    for (final correction in [
      'I only have two minutes.',
      'Only two minutes now.',
    ]) {
      test('duration-only follow-up preserves objective: $correction', () {
        final response = _answer(
          correction,
          history: const [
            {'role': 'user', 'content': original},
            {'role': 'assistant', 'content': 'Put your uniform in your bag.'},
          ],
        );
        _expectAction(response, 'uniform');
        expect(
          response.options.map((o) => o.estimatedMinutes),
          everyElement(lessThanOrEqualTo(2)),
        );
        expect(
          response.nextStep.toLowerCase(),
          isNot(contains('for i only have')),
        );
      });
    }

    test('natural decline remains a choice after another follow-up', () {
      final response = _answer(
        'I only have two minutes.',
        history: const [
          {'role': 'user', 'content': original},
          {
            'role': 'assistant',
            'content':
                'Which saved task or goal, if any, should this plan support?',
          },
          {
            'role': 'user',
            'content':
                'Neither. This is a new situation; use only what I just told you.',
          },
          {'role': 'assistant', 'content': 'Put your uniform in your bag.'},
        ],
      );
      _expectAction(response, 'uniform');
      expect(
        response.usefulQuestion ?? '',
        isNot(contains('saved task or goal')),
      );
    });

    test('completed objective is replaced by the corrected objective', () {
      final response = _answer(
        'That application is finished. I meant the rent assistance form.',
        history: const [
          {'role': 'user', 'content': 'Help me start my job application.'},
          {'role': 'assistant', 'content': 'Open the job application.'},
        ],
      );
      final responseText =
          '${response.whatIHeard} ${response.nextStep} ${response.usefulQuestion ?? ''}'
              .toLowerCase();
      expect(responseText, contains('rent assistance'));
      expect(_proposedActions(response), isNot(contains('job application')));
    });

    test('new explicit task is not captured by a demonstrative pronoun', () {
      final response = _answer(
        'This evening I need to fold one shirt. I have five minutes.',
        history: const [
          {'role': 'user', 'content': 'I need to email my manager.'},
          {'role': 'assistant', 'content': 'Draft your email.'},
        ],
      );
      _expectAction(response, 'shirt');
      expect(_proposedActions(response), isNot(contains('email my manager')));
    });
  });

  group('Spanish planning and safe uncertainty', () {
    test('English solo work does not switch language or invent dependents', () {
      final response = _answer(
        'I need to work solo on my report. I have ten minutes.',
      );
      expect(response.languageCode, 'en');
      final text =
          '${response.whatIHeard} ${response.nextStep} '
                  '${response.recommendationReason}'
              .toLowerCase();
      expect(text, contains('report'));
      expect(text, isNot(contains('in your care')));
      expect(response.isClarification, isTrue);
      expect(
        response.usefulQuestion?.toLowerCase(),
        contains('report'),
        reason:
            'Ask about the unknown report stage, not the already named goal.',
      );
      expect(response.options, isEmpty);
    });

    test('office interruptions do not imply caregiving', () {
      final response = _answer(
        'I need to sort receipts at my office. Interruptions from coworkers '
        'are unavoidable. I have five minutes.',
      );
      _expectAction(response, 'receipt');
      expect(
        response.recommendationReason.toLowerCase(),
        isNot(matches(RegExp(r'child|toddler|in your care'))),
      );
      expect(
        _proposedActions(response),
        isNot(contains('silence interruptions')),
      );
    });

    test('draft-only instruction does not imply sending the email', () {
      final response = _answer(
        'I want to write an email draft, not send it. I have five minutes.',
      );
      _expectAction(response, 'email');
      expect(response.nextStep.toLowerCase(), contains('draft'));
      expect(
        _proposedActions(response),
        isNot(matches(RegExp(r'before sending|then send|and send|send the'))),
      );
    });

    test('ride arriving soon does not receive a twenty-minute work block', () {
      final response = _answer(
        'My ride arrives in five minutes. Help me pack my uniform.',
      );
      final text =
          '${response.whatIHeard} ${response.nextStep} '
                  '${response.usefulQuestion ?? ''}'
              .toLowerCase();
      expect(text, contains('uniform'));
      if (!response.isClarification) {
        expect(
          response.options.map((o) => o.estimatedMinutes),
          everyElement(lessThanOrEqualTo(5)),
        );
      }
    });

    test('Spanish uniform request has a concrete Spanish next step', () {
      final response = _answer(
        'Solo tengo cinco minutos antes de salir. Necesito guardar mi uniforme '
        'en la mochila. No necesito descansar. ¿Qué hago primero?',
      );
      _expectAction(response, 'uniforme');
      expect(
        response.nextStep,
        matches(RegExp(r'Guarda|Pon|Mete|Coloca|Prepara|Junta')),
      );
      expect(_proposedActions(response), isNot(contains('action cycle')));
      expect(
        response.toAccessibleText(),
        isNot(
          matches(
            RegExp(
              r'Current check-in|Current emotional state|Saved planning evidence|'
              r'No recent saved|No governed|No Timeline|Planning context was supplied',
            ),
          ),
        ),
        reason:
            'Full read-aloud includes generated evidence, not just headings.',
      );
      expect(
        response.options.map((o) => o.estimatedMinutes),
        everyElement(lessThanOrEqualTo(5)),
      );
    });

    test('Spanish duration correction keeps the Spanish task', () {
      final response = _answer(
        'Ahora solo tengo dos minutos.',
        history: const [
          {
            'role': 'user',
            'content':
                'Necesito guardar mi uniforme en la mochila. Tengo cinco minutos.',
          },
          {'role': 'assistant', 'content': 'Guarda el uniforme en tu mochila.'},
        ],
      );
      _expectAction(response, 'uniforme');
      expect(
        response.options.map((o) => o.estimatedMinutes),
        everyElement(lessThanOrEqualTo(2)),
      );
    });

    test('Spanish natural saved-context decline survives the next correction', () {
      final response = _answer(
        'Ahora solo tengo dos minutos.',
        history: const [
          {
            'role': 'user',
            'content': 'Necesito guardar mi uniforme. Tengo cinco minutos.',
          },
          {
            'role': 'assistant',
            'content':
                '¿Qué tarea u objetivo guardado, si lo hay, debe apoyar este plan?',
          },
          {
            'role': 'user',
            'content':
                'No gracias. Es una situación nueva; usa solo lo que te acabo de decir.',
          },
          {'role': 'assistant', 'content': 'Guarda el uniforme.'},
        ],
      );
      _expectAction(response, 'uniforme');
      expect(response.languageCode, 'es');
      expect(response.userContext?.savedContextDeclined, isTrue);
      expect(response.usefulQuestion, isNull);
      expect(
        response.options.map((option) => option.estimatedMinutes),
        everyElement(lessThanOrEqualTo(2)),
      );
    });

    test(
      'unknown work asks a meaningful question instead of a fake action',
      () {
        final response = _answer(
          'Help me with the situation I mentioned elsewhere.',
        );
        expect(response.isClarification, isTrue);
        expect(response.options, isEmpty);
        expect(response.usefulQuestion, isNotEmpty);
        expect(response.usefulQuestion, isNot(contains('saved task or goal')));
      },
    );

    test('one-minute recovery does not add a scheduling decision', () {
      final response = _answer(
        'I have zero energy and only one minute. Help me recover.',
        energy: 0,
      );
      expect(response.isClarification, isFalse);
      expect(
        response.nextStep.toLowerCase(),
        isNot(matches(RegExp(r'choose.*task|review.*commitment|postpone'))),
      );
      expect(
        response.options.map((o) => o.estimatedMinutes),
        everyElement(lessThanOrEqualTo(1)),
      );
    });
  });
}
