import 'package:fantastic_guacamole/data/services/ai/agents/chat_agent.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/engine/si/ai_personality.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatAgent contract', () {
    test('returns stable conversation contract without proxy dependency', () async {
      final ChatAgent agent = const ChatAgent();

      final Map<String, dynamic> payload = await agent.execute(<String, dynamic>{
        'prompt': 'What should I do next?',
        'tasks': const <Task>[
          Task(
            id: 'task-1',
            title: 'Finish QA checklist',
            priority: 5,
            difficulty: 2,
            energyRequired: 2,
          ),
        ],
        'si': const SIState(energy: 0.7),
        'learning': const LearningState(completed: 2),
        'personality': AIPersonality.coach,
      });

      expect(payload['agent'], 'chat');
      expect(payload['mode'], 'conversation');
      expect(payload['status'], 'ready');
      expect(payload['message'], isA<String>());
      expect((payload['message'] as String).trim(), isNotEmpty);
      expect(payload['response'], payload['message']);
    });

    test('system-console response returns bounded action bundle with signal and insight', () async {
      final ChatAgent agent = const ChatAgent();

      final Map<String, dynamic> payload = await agent.execute(<String, dynamic>{
        'prompt': 'Give me a task module briefing',
        'si': const SIState(energy: 0.6),
        'learning': const LearningState(completed: 1),
        'context': const <String, dynamic>{
          'mode': 'system_console',
          'querySurface': 'tasks',
          'featureSnapshot': <String, dynamic>{
            'tasks': <String, dynamic>{
              'count': 3,
              'top': <String>['Task A', 'Task B', 'Task C'],
            },
          },
        },
      });

      final String message = payload['message'] as String;
      expect(message.trim(), isNotEmpty);
      expect(message.toLowerCase(), contains('action'));
      final int actionMarkers = RegExp(r'\b1\)|\b2\)|\b3\)').allMatches(message).length;
      expect(actionMarkers, lessThanOrEqualTo(3));
    });
  });
}
