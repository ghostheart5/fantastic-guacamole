import 'package:fantastic_guacamole/data/services/ai/models/agent_result.dart';
import 'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reserves credits only for an opted-in external chat attempt', () {
    expect(
      shouldReserveExternalModelCredits(
        externalAiAllowed: false,
        preferredAgent: AgentKind.chat,
      ),
      isFalse,
    );
    expect(
      shouldReserveExternalModelCredits(
        externalAiAllowed: true,
        preferredAgent: AgentKind.planning,
      ),
      isFalse,
    );
    expect(
      shouldReserveExternalModelCredits(
        externalAiAllowed: true,
        preferredAgent: AgentKind.chat,
      ),
      isTrue,
    );
  });

  test('retains reserved credits only for a model-backed result', () {
    final AgentResult local = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{'source': 'local', 'modelBacked': false},
    );
    final AgentResult external = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{'source': 'model', 'modelBacked': true},
    );

    expect(shouldRetainExternalModelCredits(local), isFalse);
    expect(shouldRetainExternalModelCredits(external), isTrue);
  });

  test('uses server credit state for low and exhausted prompts', () {
    final AgentResult exhausted = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{
        'billingRejected': true,
        'remainingCredits': 0,
      },
    );
    final AgentResult low = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{'remainingCredits': 3},
    );
    final AgentResult healthy = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{'remainingCredits': 18},
    );

    expect(serverAiCreditPrompt(exhausted)?.remainingCredits, 0);
    expect(serverAiCreditPrompt(low)?.trigger, 'ai_credit_low');
    expect(serverAiCreditPrompt(healthy), isNull);
  });

  test('normalizes a decoded task map without exposing mutable payload', () {
    final Map<dynamic, dynamic> task = <dynamic, dynamic>{'id': 'task-1'};
    final Map<String, dynamic> payload = <String, dynamic>{'task': task};
    final AgentResult result = AgentResult(
      selectedAgent: 'planning',
      workflow: 'execute',
      payload: payload,
    );

    payload['source'] = 'changed';
    task['id'] = 'changed';

    expect(result.source, 'local');
    expect(result.taskMap?['id'], 'task-1');
    expect(() => result.payload['source'] = 'changed', throwsUnsupportedError);
    expect(() => result.taskMap?['id'] = 'changed', throwsUnsupportedError);
  });
}
