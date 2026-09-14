import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/domain/planning/rhythm_planning_context.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/controllers/smart_planner_query_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/person_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/rhythm_planning_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression conversations observed on Play-installed Moto build 3040.
// Exercise the real asynchronous controller; all account/evidence inputs stay
// in memory. Assertions describe planning behavior, not replacement copy.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('departure answers and saved-context choice', () {
    for (final entry in [
      (
        name: 'word-number departure and mixed saved-note decline',
        language: 'en',
        reply:
            'I leave in ten minutes, but I only have two minutes to pack. '
            'Please use only what I wrote here, not my saved notes.',
        declinesSaved: true,
      ),
      (
        name: 'numeric departure and mixed saved-note decline',
        language: 'en',
        reply:
            'I leave in 10 minutes, but I only have 2 minutes to pack. '
            'Please use only what I wrote here, not my saved notes.',
        declinesSaved: true,
      ),
      (
        name: 'numeric departure with named uniform action',
        language: 'en',
        reply:
            'I need to leave in 10 minutes. '
            'I have 2 minutes available to pack the uniform.',
        declinesSaved: false,
      ),
      (
        name: 'Spanish word-number departure and saved-note decline',
        language: 'es',
        reply:
            'Salgo en diez minutos, pero solo tengo dos minutos para preparar el uniforme. '
            'Usa solo lo que escribí aquí, no mis notas guardadas.',
        declinesSaved: true,
      ),
    ]) {
      test(entry.name, () async {
        final scenario = _Scenario(language: entry.language, note: true);
        final original = entry.language == 'es'
            ? 'Tengo un turno en el restaurante en treinta minutos. '
                  'Necesito preparar mi uniforme de trabajo limpio y mi identificación. '
                  'Me siento bien y no necesito descansar. ¿Qué hago ahora?'
            : 'I have a restaurant shift in 30 minutes. I need to pack my clean work '
                  'uniform and name badge. I feel fine and do not need a break. What should I do next?';
        final initial = await scenario.start(original);
        _expectUniform(initial);
        expect(
          initial.usefulQuestion,
          matches(RegExp(r'leave|salir', caseSensitive: false)),
          reason:
              'The initial shift deadline does not state when travel must begin.',
        );

        final reply = await scenario.follow(original, initial, entry.reply);
        _expectUniform(reply);
        _expectWithin(reply, 2);
        expect(reply.userContext?.timeLimitMinutes, 2);
        expect(
          reply.usefulQuestion,
          isNull,
          reason: 'Departure was answered; do not ask the same question again.',
        );
        if (entry.declinesSaved) {
          final context = reply.userContext!;
          expect(context.savedContextDeclined, isTrue);
          final retained =
              '${context.objective} ${context.corrections.join(' ')}';
          expect(
            retained,
            matches(
              RegExp(
                r'(?:leave|depart|salgo|salir|salida)[^.!?]{0,40}\b(?:ten|10|diez)\b',
                caseSensitive: false,
              ),
            ),
            reason:
                'Declining saved context must not discard the stated departure in ten minutes.',
          );
          expect(
            retained,
            matches(RegExp(r'shift|turno', caseSensitive: false)),
            reason: 'The pending shift remains relevant after the answer.',
          );
          expect(
            reply.nextStep,
            isNot(
              matches(
                RegExp(
                  r'care labels|etiquetas|pickup list|lista de recogida',
                  caseSensitive: false,
                ),
              ),
            ),
          );
        }
      });
    }
  });

  group('uncertain or historical departure does not answer a current deadline', () {
    for (final entry in [
      (
        language: 'en',
        reply: 'I might leave in ten minutes, but I do not know yet.',
      ),
      (language: 'en', reply: 'Yesterday I had to leave in ten minutes.'),
      (
        language: 'en',
        reply:
            'My old note says "I leave in ten minutes", but I have not decided today.',
      ),
      (
        language: 'es',
        reply: 'Ayer salí en diez minutos, pero aún no sé cuándo salgo hoy.',
      ),
    ]) {
      test(entry.reply, () async {
        final scenario = _Scenario(language: entry.language);
        final original = entry.language == 'es'
            ? 'Tengo un turno en treinta minutos. Necesito preparar mi uniforme.'
            : 'I have a shift in thirty minutes. I need to pack my uniform.';
        final first = await scenario.start(original);
        expect(
          first.usefulQuestion,
          matches(RegExp(r'leave|salir', caseSensitive: false)),
        );
        final response = await scenario.follow(original, first, entry.reply);
        expect(
          response.userContext?.objective,
          matches(RegExp(r'uniform', caseSensitive: false)),
          reason:
              'A past or tentative answer must not discard the commitment awaiting clarification.',
        );
        expect(
          response.usefulQuestion,
          matches(RegExp(r'leave|salir', caseSensitive: false)),
          reason:
              'A tentative statement or a past/quoted departure is not the current departure answer.',
        );
      });
    }
  });

  test(
    'a newly uncertain departure reopens the previously answered question',
    () async {
      final scenario = _Scenario();
      const original =
          'I have a shift in thirty minutes. I need to pack my uniform.';
      final first = await scenario.start(original);
      final confirmed = await scenario.follow(
        original,
        first,
        'I leave in ten minutes. I only have two minutes to pack.',
      );
      _expectUniform(confirmed);
      expect(confirmed.usefulQuestion, isNull);
      final uncertain = await scenario.follow(
        original,
        confirmed,
        'Actually I might leave in five minutes, but I have not decided yet.',
      );
      expect(
        uncertain.userContext?.objective,
        matches(RegExp(r'uniform', caseSensitive: false)),
      );
      expect(
        uncertain.usefulQuestion,
        matches(RegExp(r'leave|departure', caseSensitive: false)),
        reason:
            'The old ten-minute answer must not override a newer explicit uncertainty.',
      );
      expect(
        uncertain.userContext?.timeLimitMinutes,
        2,
        reason: 'A tentative departure is not a replacement work budget.',
      );
    },
  );

  for (final entry in [
    (
      input: 'I am writing the school note. I have five minutes.',
      action: r'(?:writ|draft)[^.!?]*school note',
    ),
    (
      input: "We're preparing the work uniform. I have five minutes.",
      action: r'uniform',
    ),
  ]) {
    test(
      'present activity remains a supported action: ${entry.input}',
      () async {
        final scenario = _Scenario();
        final response = await scenario.start(entry.input);
        expect(response.isClarification, isFalse);
        expect(
          response.nextStep,
          matches(RegExp(entry.action, caseSensitive: false)),
        );
        _expectWithin(response, 5);
      },
    );
  }

  for (final action in ['pack', 'wash']) {
    test(
      'washing prerequisite applies to $action of the same uniform appropriately',
      () async {
        final scenario = _Scenario(
          note: true,
          noteBody:
              'I have five minutes. Check the care label before washing the uniform. Do not add ironing.',
        );
        final response = await scenario.start(
          'I need to $action my uniform. I have five minutes.',
        );
        _expectWithin(response, 5);
        if (action == 'wash') {
          expect(
            response.nextStep,
            matches(RegExp(r'care[ -]label', caseSensitive: false)),
            reason:
                'Keep the real prerequisite when the user requests its dependent washing action.',
          );
        } else {
          _expectUniform(response);
          expect(
            response.nextStep,
            isNot(matches(RegExp(r'care[ -]label', caseSensitive: false))),
            reason:
                'Sharing the uniform object does not make washing a prerequisite for packing.',
          );
        }
      },
    );
  }

  group('caregiver boundaries keep the receipt objective', () {
    for (final entry in [
      (
        name:
            'cannot leave child does not prohibit leaving other receipts aside',
        language: 'en',
        input:
            'My toddler keeps interrupting while I sort receipts for taxes. '
            'I cannot leave my child or silence the interruptions. I have ten minutes, '
            'and I need a step I can stop and resume.',
      ),
      (
        name: 'reordered interruption constraint has the same meaning',
        language: 'en',
        input:
            'My toddler keeps interrupting while I sort receipts for taxes. '
            'I cannot silence the interruptions or leave my child. I have ten minutes, '
            'and I need a step I can stop and resume.',
      ),
      (
        name: 'Spanish caregiver and receipt sorting',
        language: 'es',
        input:
            'Mi niño me interrumpe mientras necesito ordenar los recibos para los impuestos. '
            'No puedo dejar a mi niño ni silenciar las interrupciones. Tengo diez minutos '
            'y necesito un paso que pueda parar y retomar.',
      ),
    ]) {
      test(entry.name, () async {
        final scenario = _Scenario(language: entry.language, savedWork: true);
        final initial = await scenario.start(entry.input);
        _expectReceipts(initial);
        _expectWithin(initial, 10);
        final correction = entry.language == 'es'
            ? 'Necesito ordenar los recibos de impuestos, no trabajar en mi rutina de la noche. '
                  'Empieza con un recibo y permite que pare inmediatamente si mi niño me necesita.'
            : 'I need to sort the tax receipts, not work on my evening reset. '
                  'Start with one receipt, and let me stop immediately if my toddler needs me.';
        final followUp = await scenario.follow(
          entry.input,
          initial,
          correction,
        );
        _expectReceipts(followUp);
      });
    }
  });

  group('retention wording keeps the care-label object', () {
    for (final entry in [
      (
        name: 'exact care-label check noun phrase',
        language: 'en',
        reply:
            'I only have two minutes now. Keep the care-label check first and leave the pickup list for later.',
      ),
      (
        name: 'care label check without a hyphen',
        language: 'en',
        reply:
            'I only have two minutes now. Keep the care label check first and leave the pickup list for later.',
      ),
      (
        name: 'direct imperative remains valid',
        language: 'en',
        reply:
            'I only have two minutes now. Check the care labels first and leave the pickup list for later.',
      ),
      (
        name: 'Spanish retained label check',
        language: 'es',
        reply:
            'Ahora solo tengo dos minutos. Mantén primero la revisión de las etiquetas de cuidado '
            'y deja la lista de recogida para después.',
      ),
    ]) {
      test(entry.name, () async {
        final scenario = _Scenario(language: entry.language, note: true);
        final original = _noteRequest(entry.language);
        final initial = await scenario.start(original);
        _expectCareLabels(initial);
        expect(
          initial.nextStep,
          matches(
            RegExp(
              r'(?:write|escrib\w*)[^.!?]*(?:pickup list|lista de recogida)',
              caseSensitive: false,
            ),
          ),
          reason:
              'Explicitly using the selected note keeps its requested pickup-list action when the five-minute window allows it.',
        );
        final response = await scenario.follow(original, initial, entry.reply);
        _expectCareLabels(response);
        _expectWithin(response, 2);
        expect(response.userContext?.timeLimitMinutes, 2);
        expect(
          response.nextStep,
          isNot(
            matches(
              RegExp(
                r'(?:then|next|después|luego)[^.!?]*\b(?:write|escrib\w*)\b[^.!?]*(?:pickup|recogida)',
                caseSensitive: false,
              ),
            ),
          ),
          reason:
              'The user deferred the pickup list instead of adding a second task.',
        );
      });
    }
  });

  group('alternative bag answers are not cleaning commands', () {
    for (final entry in [
      (
        name: 'clean adjective',
        language: 'en',
        answer: 'Yes, I have a clean tote bag beside me. Use that instead.',
        newTask: false,
      ),
      (
        name: 'open adjective',
        language: 'en',
        answer: 'Yes, I have an open tote bag beside me. Use that instead.',
        newTask: false,
      ),
      (
        name: 'no adjective control',
        language: 'en',
        answer: 'Yes, I have a tote bag beside me. Use that instead.',
        newTask: false,
      ),
      (
        name: 'spare adjective control',
        language: 'en',
        answer: 'Yes, I have a spare tote bag beside me. Use that instead.',
        newTask: false,
      ),
      (
        name: 'explicit new cleaning task',
        language: 'en',
        answer: 'I need to clean the tote bag instead. I have three minutes.',
        newTask: true,
      ),
      (
        name: 'Spanish clean bag answer',
        language: 'es',
        answer:
            'Sí, tengo una bolsa de tela limpia a mi lado. Usa esa en su lugar.',
        newTask: false,
      ),
      (
        name: 'Spanish explicit new cleaning task',
        language: 'es',
        answer:
            'Necesito limpiar la bolsa de tela en su lugar. Tengo tres minutos.',
        newTask: true,
      ),
    ]) {
      test(entry.name, () async {
        final scenario = _Scenario(language: entry.language);
        final original = entry.language == 'es'
            ? 'Prepara mi uniforme de trabajo. Tengo cinco minutos.'
            : 'Pack my work uniform. I have five minutes.';
        final obstacle = entry.language == 'es'
            ? 'Mi bolsa está encerrada en el coche y no puedo acceder a ella ahora.'
            : 'My bag is locked in the car and I cannot get it right now.';
        final initial = await scenario.start(original);
        final question = await scenario.follow(
          original,
          initial,
          obstacle,
          adjustments: const [
            PlannerAdjustment(
              kind: PlannerAdjustmentKind.rejectedApproach,
              description: 'The user asked for a different approach.',
            ),
          ],
        );
        expect(question.isClarification, isTrue);
        expect(
          question.usefulQuestion,
          matches(RegExp(r'bag|bolsa', caseSensitive: false)),
        );
        final response = await scenario.follow(
          original,
          question,
          entry.answer,
        );
        if (entry.newTask) {
          expect(response.isClarification, isFalse);
          expect(
            response.nextStep,
            matches(RegExp(r'clean|limpi', caseSensitive: false)),
          );
          expect(
            response.nextStep,
            matches(RegExp(r'tote|bolsa', caseSensitive: false)),
          );
          _expectWithin(response, 3);
          expect(response.userContext?.timeLimitMinutes, 3);
        } else {
          _expectUniform(response);
          expect(
            response.nextStep,
            matches(RegExp(r'tote|bolsa', caseSensitive: false)),
            reason:
                'Use the supplied alternative in the actual instruction, not just in the acknowledgement.',
          );
          _expectWithin(response, 5);
          expect(response.userContext?.timeLimitMinutes, 5);
          expect(response.userContext?.objective, original);
          expect(
            response.usefulQuestion,
            isNull,
            reason:
                'An alternative bag was supplied; the clarification has been answered.',
          );
        }
      });
    }
  });

  group('ordinary one-minute rest overrides saved laundry work', () {
    for (final entry in [
      (
        name: 'exact energy-is-zero and give-rest wording',
        language: 'en',
        input:
            'My energy is zero now. Please give me a one-minute rest. Do not plan any laundry work.',
      ),
      (
        name: 'give-rest without an energy claim',
        language: 'en',
        input:
            'Please give me a one-minute rest. Do not plan any laundry work.',
      ),
      (
        name: 'direct need-rest control',
        language: 'en',
        input: 'I need to rest for one minute now. Stop suggesting work.',
      ),
      (
        name: 'Spanish energy-is-zero and give-rest wording',
        language: 'es',
        input:
            'Mi energía es cero ahora. Por favor, dame un descanso de un minuto. '
            'No planifiques trabajo de lavandería.',
      ),
    ]) {
      for (final followUp in [false, true]) {
        test('${entry.name}, ${followUp ? 'follow-up' : 'standalone'}', () async {
          final scenario = _Scenario(language: entry.language, note: true);
          final PlannerV2Response response;
          if (followUp) {
            final original = _noteRequest(entry.language);
            final prior = await scenario.start(original);
            _expectCareLabels(prior);
            expect(
              prior.recommendedOption.estimatedMinutes,
              greaterThan(1),
              reason:
                  'The old plan must not mask failure to parse the new one-minute rest duration.',
            );
            response = await scenario.follow(original, prior, entry.input);
          } else {
            response = await scenario.start(entry.input);
          }
          _expectRecovery(response);
          expect(
            response.options.map((o) => o.estimatedMinutes),
            everyElement(1),
          );
          expect(response.userContext?.timeLimitMinutes, 1);
        });
      }
    }

    test(
      'actual one-minute adjusted plan can still switch from work to rest',
      () async {
        final scenario = _Scenario(note: true);
        final original = _noteRequest('en');
        final initial = await scenario.start(original);
        final corrected = await scenario.follow(
          original,
          initial,
          'Check the care labels before washing the work shirts. Only two minutes. Leave the pickup list for later.',
        );
        final smaller = corrected.copyWith(
          options: corrected.options
              .map((option) => option.copyWith(estimatedMinutes: 1))
              .toList(),
        );
        final response = await scenario.follow(
          original,
          smaller,
          'My energy is zero now. Please give me a one-minute rest. Do not plan any laundry work.',
          adjustments: const [
            PlannerAdjustment(
              kind: PlannerAdjustmentKind.smaller,
              description: 'Selected shorter step',
              previousMinutes: 2,
              currentMinutes: 1,
            ),
          ],
        );
        _expectRecovery(response);
        expect(
          response.options.map((o) => o.estimatedMinutes),
          everyElement(1),
        );
      },
    );
  });

  group('rest negation and history do not replace present work', () {
    for (final entry in [
      (
        language: 'en',
        input: 'I do not need a rest. Pack my work uniform. I have one minute.',
      ),
      (
        language: 'en',
        input:
            'I took a rest earlier. Pack my work uniform now. I have one minute.',
      ),
      (
        language: 'en',
        input:
            'My energy was zero yesterday. I feel fine now and do not need a break. '
            'Pack my work uniform. I have one minute.',
      ),
      (
        language: 'es',
        input:
            'No necesito descansar. Prepara mi uniforme de trabajo. Tengo un minuto.',
      ),
      (
        language: 'es',
        input:
            'Ayer necesitaba descansar. Ahora prepara mi uniforme de trabajo. Tengo un minuto.',
      ),
    ]) {
      test(entry.input, () async {
        final scenario = _Scenario(language: entry.language, note: true);
        final response = await scenario.start(entry.input);
        _expectUniform(response);
        _expectWithin(response, 1);
      });
    }
  });

  for (final language in ['en', 'es']) {
    test('$language current no-rest answer overrides older recovery request', () async {
      final scenario = _Scenario(language: language);
      final original = language == 'es'
          ? 'Necesito preparar mi uniforme, pero necesito descansar ahora. Tengo cinco minutos.'
          : 'I need to pack my uniform, but I need to rest now. I have five minutes.';
      final first = await scenario.start(original);
      _expectRecovery(first);
      final answer = language == 'es'
          ? 'No necesito descansar ahora. Mantén el plan del uniforme dentro de dos minutos.'
          : 'I do not need a rest now. Keep the uniform plan within two minutes.';
      final response = await scenario.follow(original, first, answer);
      _expectUniform(response);
      _expectWithin(response, 2);
      expect(response.userContext?.timeLimitMinutes, 2);
    });
  }

  group('actual prohibitions still exclude their matching action', () {
    for (final entry in [
      (language: 'en', input: 'Cook dinner. Do not cook dinner.'),
      (language: 'en', input: 'Fold a work shirt. Do not fold the work shirt.'),
      (
        language: 'en',
        input: 'I need to clean the tote bag. Do not clean the tote bag.',
      ),
      (
        language: 'es',
        input:
            'Necesito limpiar la bolsa de tela. No limpies la bolsa de tela.',
      ),
      (language: 'en', input: 'Do not iron.'),
      (language: 'es', input: 'No planches.'),
    ]) {
      test(entry.input, () async {
        final scenario = _Scenario(language: entry.language);
        final response = await scenario.start(entry.input);
        expect(
          response.isClarification,
          isTrue,
          reason:
              'There is no permissible concrete task: the sole action is prohibited or no positive action was requested.',
        );
        expect(response.options, isEmpty);
        expect(response.nextStep, isEmpty);
      });
    }
  });

  for (final language in ['en', 'es']) {
    test('$language one-minute work reason uses singular grammar', () async {
      final scenario = _Scenario(language: language);
      final response = await scenario.start(
        language == 'es'
            ? 'Prepara mi uniforme de trabajo. Tengo un minuto.'
            : 'Pack my work uniform. I have one minute.',
      );
      _expectUniform(response);
      _expectWithin(response, 1);
      expect(
        response.recommendationReason,
        isNot(
          matches(
            RegExp(
              r'\b(?:1|one)\s+minutes\b|\b(?:1|un)\s+minutos\b',
              caseSensitive: false,
            ),
          ),
        ),
      );
    });
  }
}

void _expectWithin(PlannerV2Response response, int minutes) {
  expect(response.isClarification, isFalse);
  expect(response.options, isNotEmpty);
  expect(
    response.options.map((o) => o.estimatedMinutes),
    everyElement(inInclusiveRange(1, minutes)),
  );
}

void _expectUniform(PlannerV2Response response) {
  expect(response.isClarification, isFalse);
  expect(response.nextStep, matches(RegExp(r'uniform', caseSensitive: false)));
  expect(
    response.nextStep,
    isNot(
      matches(
        RegExp(r'^\s*(?:clean|open|limpia|abre)\b', caseSensitive: false),
      ),
    ),
  );
}

void _expectReceipts(PlannerV2Response response) {
  expect(
    response.isClarification,
    isFalse,
    reason: 'Receipt sorting and its interruption constraint were explicit.',
  );
  expect(
    response.nextStep,
    matches(RegExp(r'receipt|recibo', caseSensitive: false)),
  );
  expect(
    '${response.nextStep} ${response.recommendationReason}',
    matches(
      RegExp(
        r'pause|stop|resume|paus|parar|retomar|detener',
        caseSensitive: false,
      ),
    ),
  );
  expect(
    '${response.whatIHeard} ${response.nextStep}',
    isNot(
      matches(
        RegExp(
          r'evening reset|rutina de la noche|work uniform|uniforme de trabajo',
          caseSensitive: false,
        ),
      ),
    ),
  );
  expect(
    response.usefulQuestion,
    isNull,
    reason:
        'An unrelated saved rhythm must not append a repetition question to a concrete receipt plan.',
  );
  for (final option in response.options) {
    for (final clause in option.description.split(RegExp(r'[.!?;]+'))) {
      expect(
        clause,
        isNot(
          matches(
            RegExp(
              r'^\s*(?:(?:then|next|luego|después)\s*[:,]?\s*)?'
              r'(?:(?:leave|abandon)\s+(?:your|the)\s+(?:child|toddler|baby)'
              r'|(?:silence|ignore|mute)\s+(?:(?:the|your)\s+)?(?:interruptions|child|toddler)'
              r'|(?:deja|abandona)\s+(?:a\s+)?(?:tu|el)\s+(?:niño|hijo|bebé)'
              r'|(?:silencia|ignora)\s+(?:las\s+)?interrupciones)\b',
              caseSensitive: false,
            ),
          ),
        ),
        reason:
            'Every offered option must respect supervision and unavoidable interruptions.',
      );
    }
  }
}

void _expectCareLabels(PlannerV2Response response) {
  expect(response.isClarification, isFalse);
  expect(
    response.nextStep,
    matches(
      RegExp(r'care[ -]labels?|etiquetas? de cuidado', caseSensitive: false),
    ),
    reason: 'The retained first step needs its meaningful care-label object.',
  );
  expect(
    response.nextStep,
    isNot(matches(RegExp(r'^\s*(?:wash|lava)\b', caseSensitive: false))),
    reason: 'Reading the care labels is a prerequisite to washing.',
  );
  for (final option in response.options) {
    for (final clause in option.description.split(RegExp(r'[.!?;]+'))) {
      if (!RegExp(
        r'\biron(?:ing)?\b|\bplanch\w*',
        caseSensitive: false,
      ).hasMatch(clause)) {
        continue;
      }
      expect(
        clause,
        matches(
          RegExp(
            r'\b(?:do not|without|avoid|skip|no|sin)\b|leave[^.!?]*iron[^.!?]*(?:out|later)|'
            r'defer[^.!?]*iron|deja[^.!?]*planch[^.!?]*(?:otro momento|después)',
            caseSensitive: false,
          ),
        ),
        reason:
            'The selected note excludes ironing: every option must omit it, prohibit it, or explicitly defer it.',
      );
    }
  }
}

void _expectRecovery(PlannerV2Response response) {
  expect(
    response.isClarification,
    isFalse,
    reason:
        'Rest is explicitly requested without requiring a separate energy slider value.',
  );
  expect(
    response.nextStep,
    matches(RegExp(r'pause|rest|descans|pausa', caseSensitive: false)),
  );
  expect(
    response.nextStep,
    isNot(
      matches(
        RegExp(
          r'check[^.!?]*care[ -]label|(?:revisa|leer)[^.!?]*etiqueta|write[^.!?]*pickup|escrib[^.!?]*recogida',
          caseSensitive: false,
        ),
      ),
    ),
  );
}

String _noteRequest(String language) => language == 'es'
    ? 'Usa esta nota seleccionada para planificar cinco minutos para mis camisas de trabajo y la recogida del viernes.'
    : 'Use this selected laundry note to plan five minutes for my work shirts and Friday pickup.';

class _Scenario {
  _Scenario({
    this.language = 'en',
    bool note = false,
    bool savedWork = false,
    String? noteBody,
  }) {
    tasks = _Tasks(
      savedWork
          ? [
              TaskEntity(
                id: 'unrelated-uniform',
                title: '3040 validation - pack the work uniform',
                createdAt: _now,
                estimatedDuration: const Duration(minutes: 30),
              ),
            ]
          : [],
    );
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWithValue(
          AccountStorageScope.authenticated('moto-regression-fixture'),
        ),
        assistantReleaseConfigProvider.overrideWith(
          (ref) async => AssistantReleaseConfig(
            stage: AssistantReleaseStage.general,
            canaryBasisPoints: 0,
            shadowEvaluationEnabled: false,
            internalAccountDigests: const {},
            rollbackCapabilities: const {},
          ),
        ),
        assistantBetaOptInProvider.overrideWith(_NoBetaOptIn.new),
        consentedHumanContextProvider.overrideWithValue(
          const ConsentedHumanContext(
            emotionAllowed: false,
            memoryAllowed: false,
            emotion: null,
            siState: SIState(),
          ),
        ),
        domainTaskRepositoryProvider.overrideWithValue(tasks),
        domainGoalRepositoryProvider.overrideWithValue(goals),
        smartPlannerClockProvider.overrideWithValue(() => _now),
        smartPlannerOperatingReceiptProvider.overrideWithValue(null),
        memoryRecallProvider(
          MemorySurface.smartPlanner,
        ).overrideWithValue(const []),
        personContextForSurfaceProvider(
          PersonContextAccessRequest(
            surface: PersonContextSurface.smartPlanner,
            purposes: operationalPersonContextPurposes,
          ),
        ).overrideWithValue(null),
        rhythmPlanningProvider.overrideWith(
          (ref) async => savedWork
              ? [
                  RhythmPlanningEntry(
                    HabitEntity(
                      id: 'unrelated-evening-reset',
                      title: '3040 - five-minute evening reset',
                      description:
                          'Synthetic journey: sort one work shirt and check its care label after dinner. '
                          'One gentle reset per day is enough; stop when tired.',
                      createdAt: _now,
                      cadence: HabitCadence.daily,
                      targetCount: 1,
                    ),
                    '2026-09-14',
                    RhythmPeriodStatus.unrecorded,
                  ),
                ]
              : [],
        ),
        selectedPlanningNoteProvider.overrideWith(
          (ref) async => note
              ? NoteEntity(
                  id: 'laundry-prerequisite',
                  title: language == 'es'
                      ? 'Lavandería - etiquetas de cuidado antes de lavar'
                      : '3040 laundry - care labels before washing',
                  body:
                      noteBody ??
                      (language == 'es'
                          ? 'Tengo cinco minutos después de cenar. Revisa las etiquetas de cuidado antes de lavar las camisas de trabajo. '
                                'Después escribe la lista de recogida del viernes. No añadas planchado. Necesito descansar después del turno en el restaurante.'
                          : 'Synthetic planning note: I have five minutes after dinner. '
                                'Check the care labels before washing the work shirts. Then write the Friday pickup list. '
                                'Do not add ironing. I need to rest after a restaurant shift.'),
                  createdAt: _now,
                )
              : null,
        ),
      ],
    );
    controller = container.read(smartPlannerQueryControllerProvider);
    addTearDown(() {
      container.dispose();
      expect(
        tasks.writes,
        0,
        reason: 'Planning must not persist a task without confirmation.',
      );
      expect(
        goals.writes,
        0,
        reason: 'Planning must not persist a goal without confirmation.',
      );
    });
  }

  static final _now = DateTime.utc(2026, 9, 14, 1, 40);
  final String language;
  late final _Tasks tasks;
  final goals = _Goals();
  late final ProviderContainer container;
  late final SmartPlannerQueryController controller;

  Future<PlannerV2Response> start(String input) async {
    final response = (await controller.requestPlanningGuidance(
      energy: null,
      emotion: null,
      notes: input,
      history: const [],
      previousSavedNotes: null,
      languageCode: language,
    )).plannerResponse;
    expect(response.languageCode, language);
    return response;
  }

  Future<PlannerV2Response> follow(
    String original,
    PlannerV2Response previous,
    String input, {
    List<PlannerAdjustment> adjustments = const [],
  }) async {
    final response = (await controller.requestFollowUpResult(
      input: input,
      energy: null,
      emotion: null,
      reflection: original,
      languageCode: language,
      history: [
        {'role': 'user', 'content': original},
        {'role': 'assistant', 'content': previous.toConversationText()},
      ],
      currentPlan: PlannerConversationSnapshot(
        originalObjective: original,
        currentPlan: previous,
        userContext: previous.userContext,
        adjustments: adjustments,
      ),
    )).plannerResponse;
    expect(response.languageCode, language);
    return response;
  }
}

class _NoBetaOptIn extends AssistantBetaOptInNotifier {
  @override
  Future<bool> build() async => false;
}

class _Tasks implements ITaskRepository {
  _Tasks(this.values);
  final List<TaskEntity> values;
  int writes = 0;

  @override
  Future<List<TaskEntity>> getAllTasks() async => List.of(values);
  @override
  Future<TaskEntity?> getTaskById(String id) async {
    for (final task in values) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    writes++;
  }

  @override
  Future<void> deleteTask(String id) async {
    writes++;
  }
}

class _Goals implements IGoalRepository {
  int writes = 0;
  @override
  List<GoalEntity> getGoals() => [];
  @override
  Future<void> saveGoal(GoalEntity goal) async {
    writes++;
  }

  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {
    writes++;
  }

  @override
  Future<void> deleteGoal(String id) async {
    writes++;
  }
}
