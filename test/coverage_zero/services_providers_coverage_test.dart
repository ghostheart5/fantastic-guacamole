import 'package:fantastic_guacamole/data/di/services_providers.dart';
import 'package:fantastic_guacamole/data/services/ai/orchestration/agent_orchestrator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agent orchestrator provider returns stable orchestrator instance', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final AgentOrchestrator first = container.read(agentOrchestratorProvider);
    final AgentOrchestrator second = container.read(agentOrchestratorProvider);

    expect(first, isA<AgentOrchestrator>());
    expect(identical(first, second), isTrue);
  });
}
