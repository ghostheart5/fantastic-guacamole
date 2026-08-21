import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:fantastic_guacamole/state/controllers/si_console_query_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local shortcut production path emits a schema-valid SI response', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final AIRecommendation result = container
        .read(siConsoleQueryControllerProvider)
        .localShortcutResponse(
          query: '/tasks',
          response: 'TASKS SNAPSHOT\n\nNo active tasks yet.',
          shortcut: '/tasks',
        );

    final AssistantResponseEnvelope contract = result.contract!;
    contract.validate();
    expect(contract.conversation.surface, AssistantSurface.siConsole);
    expect(contract.status, AssistantResponseStatus.completed);
    expect(contract.evidence.items, isNotEmpty);
    expect(contract.proposalId, isNull);
    final AssistantEvidenceManifest manifest = result.evidenceManifest!;
    manifest.validateAgainstResponse(contract);
    expect(manifest.conversation.surface, AssistantSurface.siConsole);
    expect(
      manifest.recordIds,
      contract.evidence.items.map((item) => item.evidenceId).toSet(),
    );
  });

  test('local failure production path is typed and marked as fallback', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final AIRecommendation result = container
        .read(siConsoleQueryControllerProvider)
        .localFallbackResponse(
          query: 'What needs attention?',
          response: 'No grounded response was generated.',
          reason: 'response_schema_validation',
        );

    expect(result.contract?.status, AssistantResponseStatus.fallback);
    expect(
      result.contract?.processingMode,
      AssistantContractProcessingMode.onDeviceFallback,
    );
    result.contract!.validate();
    result.evidenceManifest!.validateAgainstResponse(result.contract!);
  });

  test('display boundary rejects recommendation and contract divergence', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final SIConsoleQueryController controller = container.read(
      siConsoleQueryControllerProvider,
    );
    final AIRecommendation typed = controller.localShortcutResponse(
      query: '/tasks',
      response: 'TASKS SNAPSHOT',
      shortcut: '/tasks',
    );
    final AIRecommendation tampered = AIRecommendation(
      message: 'Different display text',
      processingMode: typed.processingMode,
      contract: typed.contract,
      evidenceManifest: typed.evidenceManifest,
    );

    expect(
      () => controller.ensureTypedResponse(
        query: '/tasks',
        recommendation: tampered,
      ),
      throwsA(isA<AssistantContractException>()),
    );
  });

  test(
    'display boundary rejects a typed response without evidence manifest',
    () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final SIConsoleQueryController controller = container.read(
        siConsoleQueryControllerProvider,
      );
      final AIRecommendation typed = controller.localShortcutResponse(
        query: '/tasks',
        response: 'TASKS SNAPSHOT',
        shortcut: '/tasks',
      );
      final AIRecommendation missingManifest = AIRecommendation(
        message: typed.message,
        reasoning: typed.reasoning,
        emotion: typed.emotion,
        confidence: typed.confidence,
        processingMode: typed.processingMode,
        contract: typed.contract,
      );

      expect(
        () => controller.ensureTypedResponse(
          query: '/tasks',
          recommendation: missingManifest,
        ),
        throwsA(isA<EvidencePlaneException>()),
      );
    },
  );
}
