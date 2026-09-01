import 'package:fantastic_guacamole/data/services/ai/models/agent_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentRequest contract', () {
    test(
      'merges runtime context and resolved history for execution planning',
      () {
        final AgentRequest request = AgentRequest(
          prompt: 'Plan with current workload and limits',
          context: <String, dynamic>{
            'intent': 'planning',
            'entity': 'tasks',
            'parameters': <String, dynamic>{'timeboxMinutes': 25},
            'modifiers': <String>['low_energy'],
            'executionPlan': <String>['rank', 'select', 'respond'],
          },
          history: <Map<String, String>>[
            <String, String>{
              'role': 'user',
              'content': 'Use my timeline context.',
            },
          ],
        );

        final AgentRequest merged = request.mergeRuntimeContext(
          runtimeContext: const <String, dynamic>{
            'settings': <String, dynamic>{'maxActions': 3},
            'logs': <String>['milestone:launch-checkpoint'],
            'subscriptionLimits': <String, dynamic>{
              'tier': 'free',
              'remainingCredits': 2,
            },
          },
          resolvedHistory: const <Map<String, String>>[
            <String, String>{
              'role': 'assistant',
              'content': 'Previous recommendation',
            },
          ],
        );

        expect(merged.context['intent'], 'planning');
        expect(
          (merged.context['parameters']
              as Map<String, dynamic>)['timeboxMinutes'],
          25,
        );
        expect(merged.context['settings'], isA<Map<String, dynamic>>());
        expect(merged.context['logs'], isA<List<String>>());
        expect(
          merged.context['subscriptionLimits'],
          isA<Map<String, dynamic>>(),
        );
        expect(merged.history.first['role'], 'assistant');
      },
    );

    test('does not expose mutable request collections', () {
      final Map<String, dynamic> context = <String, dynamic>{
        'mode': 'focus',
        'limits': <String, int>{'actions': 3},
      };
      final List<Map<String, String>> history = <Map<String, String>>[
        <String, String>{'role': 'user', 'content': 'Plan my day.'},
      ];
      final AgentRequest request = AgentRequest(
        prompt: 'Plan my day.',
        context: context,
        history: history,
      );

      context['mode'] = 'changed';
      (context['limits'] as Map<String, int>)['actions'] = 9;
      history.first['content'] = 'changed';

      expect(request.context['mode'], 'focus');
      expect(
        (request.context['limits'] as Map<Object?, Object?>)['actions'],
        3,
      );
      expect(request.history.first['content'], 'Plan my day.');
      expect(() => request.context['mode'] = 'changed', throwsUnsupportedError);
      expect(
        () => request.history.first['content'] = 'changed',
        throwsUnsupportedError,
      );
    });
  });
}
