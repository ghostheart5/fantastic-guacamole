import '../integration_test/agent_orchestrator_integration_test.dart'
    as agent_orchestrator;
import '../integration_test/ai_controller_integration_test.dart'
    as ai_controller;
import '../integration_test/ai_memory_selection_integration_test.dart'
    as ai_memory_selection;
import '../integration_test/si_engine_guardrails_integration_test.dart'
    as si_engine_guardrails;

void main() {
  agent_orchestrator.main();
  ai_controller.main();
  ai_memory_selection.main();
  si_engine_guardrails.main();
}
