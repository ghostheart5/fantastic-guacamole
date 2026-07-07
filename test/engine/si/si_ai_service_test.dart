import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/si_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
