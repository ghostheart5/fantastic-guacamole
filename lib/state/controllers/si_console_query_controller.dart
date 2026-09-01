import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/crisis_detection_policy.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
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

  EmotionalSafetyAssessment assessEmotionalSafety(String text) =>
      EmotionalSafetyPolicy.assess(text);

  AIRecommendation ensureTypedResponse({
    required String query,
    required AIRecommendation recommendation,
  }) {
    _requireSafeConsoleRoute(query);
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
      return _attachSafety(recommendation);
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
    return _attachSafety(typed);
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

  AIRecommendation supportiveSafetyResponse({required String query}) {
    final EmotionalSafetyAssessment assessment = assessEmotionalSafety(query);
    if (!assessment.requiresSupportivePause) {
      throw const AssistantSafetyRouteException(
        'supportive_distress_route_not_required',
        'A supportive safety response requires non-crisis distress language.',
      );
    }
    return _localResponse(
      query: query,
      response:
          '${EmotionalSafetyPolicy.planningPauseReason(assessment)}\n\n'
          '${EmotionalSafetyPolicy.supportiveQuestion(assessment)}',
      reason: 'supportive_distress_pause',
      kind: AssistantRequestKind.consoleQuery,
      evidence: 'Privacy-safe supportive distress route selected by the user',
      emotion: 'balanced',
      status: AssistantResponseStatus.completed,
      allowSupportivePause: true,
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
    bool allowSupportivePause = false,
  }) {
    _requireSafeConsoleRoute(query, allowSupportivePause: allowSupportivePause);
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
    return _attachSafety(recommendation);
  }

  void _requireSafeConsoleRoute(
    String query, {
    bool allowSupportivePause = false,
  }) {
    final EmotionalSafetyAssessment safety = assessEmotionalSafety(query);
    if (safety.requiresImmediateSafety) {
      throw const AssistantSafetyRouteException(
        'crisis_route_required',
        'SI Console must show the dedicated crisis support route.',
      );
    }
    if (safety.requiresSupportivePause && !allowSupportivePause) {
      throw const AssistantSafetyRouteException(
        'distress_route_required',
        'SI Console must show the dedicated non-crisis support route.',
      );
    }
  }

  AIRecommendation _attachSafety(AIRecommendation recommendation) {
    recommendation.validateContract();
    final AssistantResponseEnvelope response = recommendation.contract!;
    final AssistantSafetyOutcome safety = const AssistantSafetyPipeline()
        .evaluate(
          AssistantSafetyReview(
            requestId: response.requestId,
            accountScopeId: response.accountScopeId,
            surface: AssistantSafetySurface.siConsole,
            responseText: response.message,
            evidenceIds: response.evidence.items.map(
              (AssistantEvidenceItem item) => item.evidenceId,
            ),
            authority: AssistantActionAuthority.readOnly,
            risk: AssistantSafetyRisk.routine,
          ),
        );
    if (!safety.mayPublish || safety.publishableText != response.message) {
      throw const AssistantSafetyRouteException(
        'si_response_withheld',
        'The SI response did not pass the safety boundary.',
      );
    }
    return recommendation.withSafetyReceipt(safety.receipt);
  }
}
