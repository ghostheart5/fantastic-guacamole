import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siConsoleQueryControllerProvider = Provider<SIConsoleQueryController>((
  Ref ref,
) {
  return SIConsoleQueryController(ref);
});

class SIConsoleQueryController {
  const SIConsoleQueryController(this._ref);

  final Ref _ref;

  bool detectsCrisis(String text) => CrisisDetectionPolicy.detects(text);

  AIRecommendation ensureTypedResponse({
    required String query,
    required AIRecommendation recommendation,
  }) {
    if (recommendation.contract != null) {
      recommendation.validateContract();
      final AccountStorageScope account = _ref.read(
        accountStorageScopeProvider,
      );
      final String accountScopeId = assistantAccountScopeId(
        authenticatedNamespace: account.v2Namespace,
        isSignedOut: account.state == AccountStorageScopeState.signedOut,
      );
      if (recommendation.contract!.conversation !=
              AssistantConversationScope.primarySiConsole ||
          recommendation.contract!.accountScopeId != accountScopeId) {
        throw const AssistantContractException(
          'SI display boundary rejected a response from another runtime.',
        );
      }
      return recommendation;
    }
    final AccountStorageScope account = _ref.read(accountStorageScopeProvider);
    final AssistantRequestEnvelope request = createAssistantRequestEnvelope(
      accountScopeId: assistantAccountScopeId(
        authenticatedNamespace: account.v2Namespace,
        isSignedOut: account.state == AccountStorageScopeState.signedOut,
      ),
      conversation: AssistantConversationScope.primarySiConsole,
      kind: AssistantRequestKind.consoleQuery,
      input: query,
      context: const <String, Object?>{'adapter': 'legacy_response_boundary'},
    );
    final AIRecommendation typed = recommendation.withValidatedContract(
      request: request,
      evidence: createAssistantEvidenceItems(
        request: request,
        summaries: const <String>[
          'Response normalized by the typed SI display boundary',
        ],
        sourceId: 'si_console_display_boundary',
        kind: AssistantEvidenceKind.policy,
      ),
      status: recommendation.processingMode == AIProcessingMode.onDeviceFallback
          ? AssistantResponseStatus.fallback
          : AssistantResponseStatus.completed,
    );
    typed.validateContractAgainst(request);
    return typed;
  }

  AIRecommendation localShortcutResponse({
    required String query,
    required String response,
    required String shortcut,
    String emotion = 'engaged',
  }) {
    return _localResponse(
      query: query,
      response: response,
      reason: 'local_shortcut:$shortcut',
      kind: AssistantRequestKind.localShortcut,
      evidence: 'Local shortcut registry match: $shortcut',
      emotion: emotion,
      status: AssistantResponseStatus.completed,
    );
  }

  AIRecommendation localFallbackResponse({
    required String query,
    required String response,
    required String reason,
    String emotion = 'balanced',
  }) {
    return _localResponse(
      query: query,
      response: response,
      reason: reason,
      kind: AssistantRequestKind.consoleQuery,
      evidence: 'Deterministic console fallback: $reason',
      emotion: emotion,
      status: AssistantResponseStatus.fallback,
    );
  }

  AIRecommendation _localResponse({
    required String query,
    required String response,
    required String reason,
    required AssistantRequestKind kind,
    required String evidence,
    required String emotion,
    required AssistantResponseStatus status,
  }) {
    final AccountStorageScope account = _ref.read(accountStorageScopeProvider);
    final AssistantRequestEnvelope request = createAssistantRequestEnvelope(
      accountScopeId: assistantAccountScopeId(
        authenticatedNamespace: account.v2Namespace,
        isSignedOut: account.state == AccountStorageScopeState.signedOut,
      ),
      conversation: AssistantConversationScope.primarySiConsole,
      kind: kind,
      input: query,
      context: <String, Object?>{'reason': reason},
    );
    final AIRecommendation recommendation =
        AIRecommendation(
          message: response,
          reasoning: 'si_console_$reason',
          emotion: emotion,
          processingMode: status == AssistantResponseStatus.fallback
              ? AIProcessingMode.onDeviceFallback
              : AIProcessingMode.onDevice,
        ).withValidatedContract(
          request: request,
          evidence: createAssistantEvidenceItems(
            request: request,
            summaries: <String>[evidence],
            sourceId: 'si_console_local_boundary',
            kind: status == AssistantResponseStatus.fallback
                ? AssistantEvidenceKind.fallback
                : AssistantEvidenceKind.policy,
          ),
          status: status,
        );
    recommendation.validateContractAgainst(request);
    return recommendation;
  }
}
