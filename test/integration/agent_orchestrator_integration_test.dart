import 'package:fantastic_guacamole/data/services/ai/agents/chat_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentOrchestrator payload normalization', () {
    test('marks payload as defaulted when fields are missing', () async {
      final AgentOrchestrator orchestrator = const AgentOrchestrator(
        chatAgent: _EmptyChatAgent(),
      );

      final result = await orchestrator.execute(
        prompt: 'hello',
        preferredAgent: AgentKind.chat,
      );

      expect(result.usedDefaults, isTrue);
      expect(
        result.defaultedFields,
        containsAll(<String>['message', 'reasoning', 'emotion', 'confidence']),
      );
      expect(result.quality, 'agent_defaulted');
      expect(result.message, isEmpty);
      expect(result.confidence, 0.5);
    });

    test(
      'preserves native payload when agent provides all required fields',
      () async {
        final AgentOrchestrator orchestrator = const AgentOrchestrator(
          chatAgent: _NativeChatAgent(),
        );

        final result = await orchestrator.execute(
          prompt: 'hello',
          preferredAgent: AgentKind.chat,
        );

        expect(result.usedDefaults, isFalse);
        expect(result.defaultedFields, isEmpty);
        expect(result.quality, 'agent_native');
        expect(result.message, 'native message');
        expect(result.confidence, 0.82);
      },
    );

    test('normalizes invalid and out-of-range confidence values', () async {
      final AgentOrchestrator invalid = const AgentOrchestrator(
        chatAgent: _InvalidConfidenceChatAgent(),
      );
      final AgentOrchestrator oversized = const AgentOrchestrator(
        chatAgent: _OversizedConfidenceChatAgent(),
      );

      final invalidResult = await invalid.execute(
        prompt: 'hello',
        preferredAgent: AgentKind.chat,
      );
      final oversizedResult = await oversized.execute(
        prompt: 'hello',
        preferredAgent: AgentKind.chat,
      );

      expect(invalidResult.confidence, 0.5);
      expect(invalidResult.defaultedFields, contains('confidence'));
      expect(oversizedResult.confidence, 1.0);
      expect(oversizedResult.defaultedFields, isNot(contains('confidence')));
    });
  });
}

class _EmptyChatAgent extends ChatAgent {
  const _EmptyChatAgent();

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    return <String, dynamic>{};
  }
}

class _NativeChatAgent extends ChatAgent {
  const _NativeChatAgent();

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    return <String, dynamic>{
      'message': 'native message',
      'reasoning': 'native reasoning',
      'emotion': 'balanced',
      'confidence': 0.82,
    };
  }
}

class _InvalidConfidenceChatAgent extends ChatAgent {
  const _InvalidConfidenceChatAgent();

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    return <String, dynamic>{
      'message': 'native message',
      'reasoning': 'native reasoning',
      'emotion': 'balanced',
      'confidence': 'certain',
    };
  }
}

class _OversizedConfidenceChatAgent extends ChatAgent {
  const _OversizedConfidenceChatAgent();

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    return <String, dynamic>{
      'message': 'native message',
      'reasoning': 'native reasoning',
      'emotion': 'balanced',
      'confidence': 4.2,
    };
  }
}
