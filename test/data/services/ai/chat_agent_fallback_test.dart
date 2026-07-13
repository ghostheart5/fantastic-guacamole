import 'package:fantastic_guacamole/data/services/ai/agents/chat_agent.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ChatAgent agent = const ChatAgent();

  test(
    'execute returns structured local response when proxy is not configured',
    () async {
      final Map<String, dynamic> result = await agent.execute(<String, dynamic>{
        'prompt': 'What should I do next?',
        'tasks': const <Task>[
          Task(
            id: 'task-1',
            title: 'Finish release checklist',
            priority: 5,
            difficulty: 2,
            energyRequired: 2,
          ),
        ],
        'si': const SIState(energy: 0.7),
        'learning': const LearningState(completed: 3, skipped: 0),
        'personality': AIPersonality.coach,
        'context': const <String, dynamic>{'emotion': 'focused'},
        'history': const <Map<String, String>>[
          <String, String>{
            'role': 'user',
            'content': 'I am deciding next action.',
          },
        ],
      });

      expect(result['agent'], 'chat');
      expect(result['mode'], 'conversation');
      expect(result['status'], 'ready');
      expect(result['message'], isA<String>());
      expect((result['message'] as String).trim(), isNotEmpty);
      expect(result['response'], result['message']);
    },
  );

  test(
    'execute handles blank prompt without throwing and returns safe payload',
    () async {
      final Map<String, dynamic> result = await agent.execute(
        const <String, dynamic>{'prompt': '   ', 'tasks': <Task>[]},
      );

      expect(result['agent'], 'chat');
      expect(result['status'], 'ready');
      expect(result['message'], isA<String>());
      expect((result['message'] as String).trim(), isNotEmpty);
    },
  );
}
