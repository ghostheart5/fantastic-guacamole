import 'package:fantastic_guacamole/data/services/ai/agents/reminder_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI controller request safeguards', () {
    test('runtime grounding context is merged into an existing request', () {
      const AgentRequest original = AgentRequest(
        prompt: 'What should I do next?',
        context: <String, dynamic>{'source': 'si_console'},
        history: <Map<String, String>>[
          <String, String>{'role': 'user', 'content': 'Earlier question'},
        ],
      );
      final List<Map<String, String>> resolvedHistory = <Map<String, String>>[
        <String, String>{'role': 'assistant', 'content': 'Earlier answer'},
      ];

      final AgentRequest merged = original.mergeRuntimeContext(
        runtimeContext: <String, dynamic>{
          'grounded': <String, dynamic>{
            'memorySummaries': <String>['User prefers short morning tasks'],
            'allowMutationClaims': false,
          },
        },
        resolvedHistory: resolvedHistory,
      );

      expect(merged.context['source'], 'si_console');
      expect(
        (merged.context['grounded'] as Map<String, dynamic>)['memorySummaries'],
        <String>['User prefers short morning tasks'],
      );
      expect(merged.history, resolvedHistory);
    });

    test(
      'reminder agent prepares metadata without claiming it was scheduled',
      () async {
        const ReminderAgent agent = ReminderAgent();

        final Map<String, dynamic> result = await agent.execute(
          <String, dynamic>{'prompt': 'Remind me tomorrow to write the report'},
        );

        expect(result['prepared'], isTrue);
        expect(result['scheduled'], isFalse);
        expect(result['message'], contains('Confirm it to schedule'));
        expect(result['message'], isNot(contains('queued')));
      },
    );
  });
}
