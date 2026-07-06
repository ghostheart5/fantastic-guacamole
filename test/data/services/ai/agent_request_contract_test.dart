import 'package:fantastic_guacamole/data/services/ai/models/agent_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentRequest contract', () {
    test('merges runtime context and resolved history for execution planning', () {
      final AgentRequest request = const AgentRequest(
        prompt: 'Plan with current workload and limits',
        context: <String, dynamic>{
          'intent': 'planning',
          'entity': 'tasks',
          'parameters': <String, dynamic>{'timeboxMinutes': 25},
          'modifiers': <String>['low_energy'],
          'executionPlan': <String>['rank', 'select', 'respond'],
        },
        history: <Map<String, String>>[
          <String, String>{'role': 'user', 'content': 'Use my timeline context.'},
        ],
      );

      final AgentRequest merged = request.mergeRuntimeContext(
        runtimeContext: const <String, dynamic>{
          'settings': <String, dynamic>{'maxActions': 3},
          'logs': <String>['milestone:launch-checkpoint'],
          'subscriptionLimits': <String, dynamic>{'tier': 'free', 'remainingCredits': 2},
        },
        resolvedHistory: const <Map<String, String>>[
          <String, String>{'role': 'assistant', 'content': 'Previous recommendation'},
        ],
      );

      expect(merged.context['intent'], 'planning');
      expect((merged.context['parameters'] as Map<String, dynamic>)['timeboxMinutes'], 25);
      expect(merged.context['settings'], isA<Map<String, dynamic>>());
      expect(merged.context['logs'], isA<List<String>>());
      expect(merged.context['subscriptionLimits'], isA<Map<String, dynamic>>());
      expect(merged.history.first['role'], 'assistant');
    });
  });
}
