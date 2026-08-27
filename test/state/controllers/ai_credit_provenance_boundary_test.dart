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
    const AgentResult local = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{'source': 'local', 'modelBacked': false},
    );
    const AgentResult external = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{'source': 'model', 'modelBacked': true},
    );

    expect(shouldRetainExternalModelCredits(local), isFalse);
    expect(shouldRetainExternalModelCredits(external), isTrue);
  });

  test('uses server credit state for low and exhausted prompts', () {
    const AgentResult exhausted = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{
        'billingRejected': true,
        'remainingCredits': 0,
      },
    );
    const AgentResult low = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{'remainingCredits': 3},
    );
    const AgentResult healthy = AgentResult(
      selectedAgent: 'chat',
      workflow: 'execute',
      payload: <String, dynamic>{'remainingCredits': 18},
    );

    expect(serverAiCreditPrompt(exhausted)?.remainingCredits, 0);
    expect(serverAiCreditPrompt(low)?.trigger, 'ai_credit_low');
    expect(serverAiCreditPrompt(healthy), isNull);
  });
}
