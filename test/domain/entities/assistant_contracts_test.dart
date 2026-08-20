import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 20, 17);

  AssistantRequestEnvelope request({
    AssistantSurface surface = AssistantSurface.smartPlanner,
    AssistantRequestKind kind = AssistantRequestKind.planningGuidance,
    String id = 'request-1',
  }) => createAssistantRequestEnvelope(
    accountScopeId: 'v2.user-test',
    conversation: AssistantConversationScope(
      surface: surface,
      conversationId: 'conversation-1',
    ),
    kind: kind,
    input: 'Help me choose the next step.',
    history: const <Map<String, String>>[
      <String, String>{'role': 'user', 'content': 'Earlier question'},
      <String, String>{'role': 'assistant', 'content': 'Earlier answer'},
    ],
    context: const <String, Object?>{
      'energy': 0.7,
      'filters': <Object?>['tasks', 'goals'],
      'nested': <String, Object?>{'enabled': true},
    },
    now: now,
    requestId: id,
  );

  test('request schema strictly round-trips every production request kind', () {
    final Map<AssistantRequestKind, AssistantSurface> paths =
        <AssistantRequestKind, AssistantSurface>{
          AssistantRequestKind.planningGuidance: AssistantSurface.smartPlanner,
          AssistantRequestKind.followUp: AssistantSurface.smartPlanner,
          AssistantRequestKind.consoleQuery: AssistantSurface.siConsole,
          AssistantRequestKind.localShortcut: AssistantSurface.siConsole,
          AssistantRequestKind.retry: AssistantSurface.siConsole,
        };

    for (final MapEntry<AssistantRequestKind, AssistantSurface> path
        in paths.entries) {
      final AssistantRequestEnvelope original = request(
        surface: path.value,
        kind: path.key,
        id: 'request-${path.key.name}',
      );
      final AssistantRequestEnvelope decoded =
          AssistantRequestEnvelope.fromJson(original.toJson());

      decoded.validate();
      expect(decoded.kind, path.key);
      expect(decoded.surface, path.value);
      expect(decoded.accountScopeId, original.accountScopeId);
      expect(decoded.history.length, 2);
      expect(decoded.context['energy'], 0.7);
    }
  });

  test('evidence and response schemas round-trip and remain request-bound', () {
    final AssistantRequestEnvelope originalRequest = request();
    final AssistantEvidenceBundle evidence = AssistantEvidenceBundle(
      requestId: originalRequest.requestId,
      conversation: originalRequest.conversation,
      collectedAt: now,
      items: <AssistantEvidenceItem>[
        AssistantEvidenceItem(
          evidenceId: 'evidence-1',
          kind: AssistantEvidenceKind.domainFact,
          sourceId: 'tasks',
          entityId: 'task-1',
          summary: 'One active task is available.',
          observedAt: now,
          freshness: AssistantEvidenceFreshness.current,
        ),
      ],
    );
    final AssistantResponseEnvelope response = AssistantResponseEnvelope(
      responseId: 'response-1',
      requestId: originalRequest.requestId,
      accountScopeId: originalRequest.accountScopeId,
      conversation: originalRequest.conversation,
      status: AssistantResponseStatus.completed,
      message: 'Start with the active task.',
      reasoning: 'Task evidence is current.',
      emotion: 'balanced',
      confidence: 0.7,
      processingMode: AssistantContractProcessingMode.onDevice,
      generatedAt: now,
      evidence: evidence,
      taskId: 'task-1',
      taskTitle: 'Active task',
    );

    response.validateAgainst(originalRequest);
    final AssistantResponseEnvelope decoded =
        AssistantResponseEnvelope.fromJson(response.toJson());
    decoded.validateAgainst(originalRequest);

    expect(decoded.message, response.message);
    expect(decoded.evidence.items.single.evidenceId, 'evidence-1');
    expect(decoded.taskId, 'task-1');
  });

  test(
    'request rejects wrong surface, unknown fields, and non-JSON context',
    () {
      expect(
        () => request(
          surface: AssistantSurface.siConsole,
          kind: AssistantRequestKind.followUp,
        ),
        throwsA(isA<AssistantContractException>()),
      );

      final Map<String, Object?> unknown = request().toJson()
        ..['unexpected'] = true;
      expect(
        () => AssistantRequestEnvelope.fromJson(unknown),
        throwsA(isA<AssistantContractException>()),
      );

      expect(
        () => createAssistantRequestEnvelope(
          accountScopeId: 'v2.user-test',
          conversation: AssistantConversationScope.primarySmartPlanner,
          kind: AssistantRequestKind.planningGuidance,
          input: 'Plan this',
          context: <String, Object?>{'notJson': now},
          now: now,
        ),
        throwsA(isA<AssistantContractException>()),
      );
    },
  );

  test('response rejects mismatched identity and SI mutation proposals', () {
    final AssistantRequestEnvelope first = request(id: 'request-first');
    final AssistantRequestEnvelope second = request(id: 'request-second');
    final AssistantEvidenceBundle evidence = AssistantEvidenceBundle(
      requestId: first.requestId,
      conversation: first.conversation,
      collectedAt: now,
      items: <AssistantEvidenceItem>[
        AssistantEvidenceItem(
          evidenceId: 'evidence-first',
          kind: AssistantEvidenceKind.userInput,
          sourceId: 'assistant_request',
          summary: 'User supplied a planning request.',
          observedAt: now,
        ),
      ],
    );
    final AssistantResponseEnvelope response = AssistantResponseEnvelope(
      responseId: 'response-first',
      requestId: first.requestId,
      accountScopeId: first.accountScopeId,
      conversation: first.conversation,
      status: AssistantResponseStatus.completed,
      message: 'Typed response',
      processingMode: AssistantContractProcessingMode.onDevice,
      generatedAt: now,
      evidence: evidence,
    );

    expect(
      () => response.validateAgainst(second),
      throwsA(isA<AssistantContractException>()),
    );

    final AssistantRequestEnvelope consoleRequest = request(
      surface: AssistantSurface.siConsole,
      kind: AssistantRequestKind.consoleQuery,
      id: 'console-request',
    );
    final AssistantEvidenceBundle consoleEvidence = AssistantEvidenceBundle(
      requestId: consoleRequest.requestId,
      conversation: consoleRequest.conversation,
      collectedAt: now,
      items: <AssistantEvidenceItem>[
        AssistantEvidenceItem(
          evidenceId: 'console-evidence',
          kind: AssistantEvidenceKind.domainFact,
          sourceId: 'tasks',
          summary: 'Current task evidence.',
          observedAt: now,
        ),
      ],
    );
    expect(
      () => AssistantResponseEnvelope(
        responseId: 'console-response',
        requestId: consoleRequest.requestId,
        accountScopeId: consoleRequest.accountScopeId,
        conversation: consoleRequest.conversation,
        status: AssistantResponseStatus.completed,
        message: 'SI cannot propose a write.',
        processingMode: AssistantContractProcessingMode.onDevice,
        generatedAt: now,
        evidence: consoleEvidence,
        proposalId: 'forbidden-proposal',
      ),
      throwsA(isA<AssistantContractException>()),
    );

    expect(
      () => AssistantResponseEnvelope(
        responseId: 'blank-emotion-response',
        requestId: first.requestId,
        accountScopeId: first.accountScopeId,
        conversation: first.conversation,
        status: AssistantResponseStatus.completed,
        message: 'Typed response',
        emotion: '   ',
        processingMode: AssistantContractProcessingMode.onDevice,
        generatedAt: now,
        evidence: evidence,
      ),
      throwsA(isA<AssistantContractException>()),
    );
  });

  test('evidence rejects duplicate ids and unsupported schema versions', () {
    final AssistantRequestEnvelope originalRequest = request();
    AssistantEvidenceItem item() => AssistantEvidenceItem(
      evidenceId: 'duplicate',
      kind: AssistantEvidenceKind.policy,
      sourceId: 'validator',
      summary: 'Schema validator ran.',
      observedAt: now,
    );
    expect(
      () => AssistantEvidenceBundle(
        requestId: originalRequest.requestId,
        conversation: originalRequest.conversation,
        collectedAt: now,
        items: <AssistantEvidenceItem>[item(), item()],
      ),
      throwsA(isA<AssistantContractException>()),
    );

    final Map<String, Object?> unsupported = originalRequest.toJson()
      ..['schemaVersion'] = 999;
    expect(
      () => AssistantRequestEnvelope.fromJson(unsupported),
      throwsA(isA<AssistantContractException>()),
    );
  });
}
