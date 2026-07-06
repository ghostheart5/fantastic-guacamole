import 'package:fantastic_guacamole/data/services/ai/agents/chat_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/models/agent_result.dart';
import 'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentOrchestrator', () {
    test('selects planning route for planning prompts', () async {
      const AgentOrchestrator orchestrator = AgentOrchestrator();

      final AgentResult result = await orchestrator.execute(
        prompt: 'Plan my next three steps for the release',
      );

      expect(result.selectedAgent, 'planning');
      expect(result.mode, 'planning');
      expect(result.message.trim(), isNotEmpty);
      expect(result.durationMs, greaterThanOrEqualTo(0));
    });

    test('normalizes malformed payload fields with defaults', () async {
      final AgentOrchestrator orchestrator = const AgentOrchestrator(
        chatAgent: _MalformedChatAgent(),
      );

      final AgentResult result = await orchestrator.execute(prompt: 'hello');

      expect(result.selectedAgent, 'chat');
      expect(result.usedDefaults, isTrue);
      expect(
        result.defaultedFields,
        containsAll(<String>['message', 'reasoning', 'emotion', 'confidence']),
      );
      expect(result.quality, 'agent_defaulted');
      expect(result.confidence, 0.5);
      expect(result.message, '');
    });

    test('malformed command returns safe normalized result', () async {
      const AgentOrchestrator orchestrator = AgentOrchestrator();

      final AgentResult result = await orchestrator.execute(
        prompt: '%%% malformed /// command ???',
      );

      expect(result.selectedAgent, isNotEmpty);
      expect(result.mode, isNotEmpty);
      expect(result.message, isA<String>());
      expect(result.reasoning, isA<String>());
      expect(result.confidence, inInclusiveRange(0.0, 1.0));
      expect(result.payload['usedDefaults'], isA<bool>());
    });
  });
}

class _MalformedChatAgent extends ChatAgent {
  const _MalformedChatAgent();

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    return <String, dynamic>{
      'agent': 'chat',
      'mode': 'conversation',
      'message': '   ',
      'reasoning': '',
      'emotion': '',
      'confidence': double.nan,
    };
  }
}
