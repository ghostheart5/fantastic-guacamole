import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/engine/si/ai_response.dart';
import 'package:fantastic_guacamole/state/models/task_view.dart';

enum AIProcessingMode { unknown, onDevice, external, onDeviceFallback }

AIProcessingMode aiProcessingModeFromMetadata(Map<String, dynamic> metadata) {
  final String source = metadata['source']?.toString().toLowerCase() ?? '';
  final bool modelBacked = metadata['modelBacked'] == true;
  if (modelBacked || source == 'model' || source == 'external') {
    return AIProcessingMode.external;
  }
  if (source == 'failed' || source == 'withheld') {
    return AIProcessingMode.onDeviceFallback;
  }
  if (source == 'notattempted' ||
      source == 'not_attempted' ||
      source == 'local' ||
      source == 'on_device') {
    return AIProcessingMode.onDevice;
  }
  return AIProcessingMode.unknown;
}

class AIRecommendation {
  const AIRecommendation({
    required this.message,
    this.task,
    this.reasoning,
    this.emotion,
    this.confidence,
    this.processingMode = AIProcessingMode.unknown,
    this.contract,
    this.evidenceManifest,
    this.safetyReceipt,
  });

  final TaskView? task;
  final String message;
  final String? reasoning;
  final String? emotion;
  final double? confidence;
  final AIProcessingMode processingMode;
  final AssistantResponseEnvelope? contract;
  final AssistantEvidenceManifest? evidenceManifest;
  final AssistantSafetyReceipt? safetyReceipt;

  AIRecommendation withValidatedContract({
    required AssistantRequestEnvelope request,
    required List<AssistantEvidenceItem> evidence,
    AssistantResponseStatus status = AssistantResponseStatus.completed,
    DateTime? generatedAt,
    String? proposalId,
    AssistantEvidenceManifest? evidenceManifest,
  }) {
    final DateTime created = (generatedAt ?? DateTime.now()).toUtc();
    final AssistantEvidenceBundle bundle = AssistantEvidenceBundle(
      requestId: request.requestId,
      conversation: request.conversation,
      collectedAt: created,
      items: evidence,
    );
    final AssistantResponseEnvelope response = AssistantResponseEnvelope(
      responseId:
          '${request.requestId}.response.${created.microsecondsSinceEpoch}',
      requestId: request.requestId,
      accountScopeId: request.accountScopeId,
      conversation: request.conversation,
      status: status,
      message: message,
      reasoning: reasoning,
      emotion: emotion,
      confidence: confidence,
      processingMode: _toContractProcessingMode(processingMode),
      generatedAt: created,
      evidence: bundle,
      taskId: task?.id,
      taskTitle: task?.title,
      proposalId: proposalId,
    );
    response.validateAgainst(request);
    final AssistantEvidenceManifest manifest =
        evidenceManifest ??
        createAssistantEvidenceManifest(
          request: request,
          evidence: bundle,
          responseMessage: message,
          createdAt: created,
          claimKind: status == AssistantResponseStatus.completed
              ? EvidenceClaimKind.inference
              : EvidenceClaimKind.systemNotice,
        );
    manifest.validateAgainstRequest(request);
    manifest.validateAgainstResponse(response);
    return AIRecommendation(
      task: task,
      message: message,
      reasoning: reasoning,
      emotion: emotion,
      confidence: confidence,
      processingMode: processingMode,
      contract: response,
      evidenceManifest: manifest,
      safetyReceipt: safetyReceipt,
    );
  }

  AIRecommendation withSafetyReceipt(AssistantSafetyReceipt receipt) =>
      AIRecommendation(
        task: task,
        message: message,
        reasoning: reasoning,
        emotion: emotion,
        confidence: confidence,
        processingMode: processingMode,
        contract: contract,
        evidenceManifest: evidenceManifest,
        safetyReceipt: receipt,
      );

  void validateContractAgainst(AssistantRequestEnvelope request) {
    validateContract();
    contract!.validateAgainst(request);
    evidenceManifest!.validateAgainstRequest(request);
  }

  void validateContract() {
    final AssistantResponseEnvelope? value = contract;
    if (value == null) {
      throw const AssistantContractException(
        'Production assistant response is missing its typed contract.',
      );
    }
    value.validate();
    final AssistantEvidenceManifest? manifest = evidenceManifest;
    if (manifest == null) {
      throw const EvidencePlaneException(
        'Production assistant response is missing its evidence manifest.',
      );
    }
    manifest.validateAgainstResponse(value);
    if (value.message != message.trim() ||
        value.reasoning != reasoning?.trim() ||
        value.emotion != emotion?.trim() ||
        value.confidence != confidence ||
        value.processingMode != _toContractProcessingMode(processingMode) ||
        value.taskId != task?.id.trim() ||
        value.taskTitle != task?.title.trim()) {
      throw const AssistantContractException(
        'Assistant response data does not match its typed contract.',
      );
    }
  }

  factory AIRecommendation.fromResponse(AIResponse response) {
    final task = response.task;
    return AIRecommendation(
      task: task == null ? null : TaskView.fromTask(task),
      message: response.message,
      reasoning: response.reasoning,
      emotion: response.emotion,
      confidence: response.confidence,
      processingMode: aiProcessingModeFromMetadata(response.metadata),
    );
  }
}

AssistantContractProcessingMode _toContractProcessingMode(
  AIProcessingMode mode,
) => switch (mode) {
  AIProcessingMode.unknown => AssistantContractProcessingMode.unknown,
  AIProcessingMode.onDevice => AssistantContractProcessingMode.onDevice,
  AIProcessingMode.external => AssistantContractProcessingMode.external,
  AIProcessingMode.onDeviceFallback =>
    AssistantContractProcessingMode.onDeviceFallback,
};
