import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/learning/neural_dump.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/engine/si/si_ai_service.dart';
import 'package:fantastic_guacamole/engine/si/si_engine.dart';
import 'package:fantastic_guacamole/engine/si/si_engine_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A subclass of [SIEngineService] that records the last [SIInputPacket]
/// passed to [handleUserInput]. Used to verify the prompt-length cap applied
/// by [SIAIService.sendText] before the engine sees the text.
class _CapturingEngineService extends SIEngineService {
  SIInputPacket? lastInput;

  @override
  Future<SIFinalOutputBundle> handleUserInput(
    SIInputPacket input, {
    List<NeuralEntry> history = const <NeuralEntry>[],
    Task? task,
    List<String> goals = const <String>[],
    String? previousMood,
    SIEngineRuntimeState? runtime,
  }) {
    lastInput = input;
    return super.handleUserInput(
      input,
      history: history,
      task: task,
      goals: goals,
      previousMood: previousMood,
      runtime: runtime,
    );
  }
}

void main() {
  final SIAIService service = SIAIService();
  const List<Task> tasks = <Task>[
    Task(
      id: 'task-1',
      title: 'Finish project proposal',
      priority: 5,
      difficulty: 3,
      energyRequired: 3,
    ),
  ];

  test('uses task and check-in context for a concrete response', () async {
    final response = await service.handleInput(
      'What should I focus on next?',
      tasks: tasks,
      energy: 0.72,
      learning: const LearningState(completed: 4, skipped: 1),
      personality: AIPersonality.coach,
      context: const <String, dynamic>{'emotion': 'focused'},
    );

    expect(response.message.trim(), isNotEmpty);
    expect(response.message.toLowerCase(), contains('next action'));
    expect(response.reasoning, isA<String>());
  });

  test('avoids repeating the previous assistant response', () async {
    final first = await service.handleInput(
      'I feel overwhelmed and do not know where to start.',
      tasks: tasks,
      energy: 0.35,
      learning: const LearningState(),
      personality: AIPersonality.coach,
      context: const <String, dynamic>{'emotion': 'anxious'},
    );

    final second = await service.handleInput(
      'I feel overwhelmed and do not know where to start.',
      tasks: tasks,
      energy: 0.35,
      learning: const LearningState(),
      personality: AIPersonality.coach,
      history: <Map<String, String>>[
        const <String, String>{
          'role': 'user',
          'content': 'I feel overwhelmed and do not know where to start.',
        },
        <String, String>{'role': 'assistant', 'content': first.message},
      ],
      context: const <String, dynamic>{'emotion': 'anxious'},
    );

    expect(first.message.trim(), isNotEmpty);
    expect(second.message.trim(), isNotEmpty);
  });

  group('sendText prompt-length cap', () {
    test(
      'text at exactly the limit is passed to the engine unchanged',
      () async {
        final _CapturingEngineService capturing = _CapturingEngineService();
        final SIAIService capped = SIAIService(engineService: capturing);
        const int limit = 5000;
        final String exactText = 'a' * limit;

        await capped.sendText(exactText);

        expect(capturing.lastInput, isNotNull);
        expect(capturing.lastInput!.text.length, limit);
        expect(capturing.lastInput!.text, exactText);
      },
    );

    test(
      'text longer than 5000 characters is truncated to exactly 5000',
      () async {
        final _CapturingEngineService capturing = _CapturingEngineService();
        final SIAIService capped = SIAIService(engineService: capturing);
        final String overLong = 'b' * 7500;

        await capped.sendText(overLong);

        expect(capturing.lastInput, isNotNull);
        expect(capturing.lastInput!.text.length, 5000);
        expect(capturing.lastInput!.text, 'b' * 5000);
      },
    );

    test('short text is passed to the engine unchanged', () async {
      final _CapturingEngineService capturing = _CapturingEngineService();
      final SIAIService capped = SIAIService(engineService: capturing);
      const String short = 'Hello, what should I do today?';

      await capped.sendText(short);

      expect(capturing.lastInput, isNotNull);
      expect(capturing.lastInput!.text, short);
    });
  });
}
