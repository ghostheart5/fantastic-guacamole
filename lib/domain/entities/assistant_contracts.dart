// CHRONOSPARK-CLASS: SHIPPING | Feature: Assistant shared contracts
import 'dart:collection';

import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';

const int assistantContractSchemaVersion = 1;
int _assistantRequestSequence = 0;

enum AssistantRequestKind {
  planningGuidance,
  followUp,
  consoleQuery,
  localShortcut,
  retry,
}

enum AssistantHistoryRole { user, assistant, system }

enum AssistantEvidenceKind {
  userInput,
  domainFact,
  calculation,
  policy,
  fallback,
}

enum AssistantEvidenceFreshness { current, stale, unknown }

enum AssistantResponseStatus { completed, fallback, withheld }

enum AssistantContractProcessingMode {
  unknown,
  onDevice,
  external,
  onDeviceFallback,
}

final class AssistantContractException implements FormatException {
  const AssistantContractException(this.message, [this.source, this.offset]);

  @override
  final String message;

  @override
  final Object? source;

  @override
  final int? offset;

  @override
  String toString() => 'AssistantContractException: $message';
}

final class AssistantHistoryTurn {
  AssistantHistoryTurn({required this.role, required String content})
    : content = content.trim() {
    validate();
  }

  final AssistantHistoryRole role;
  final String content;

  void validate() {
    if (content.isEmpty) {
      throw const AssistantContractException(
        'Assistant history content cannot be empty.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'role': role.name,
    'content': content,
  };

  factory AssistantHistoryTurn.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, required: const <String>{'role', 'content'});
    return AssistantHistoryTurn(
      role: _enumValue(
        AssistantHistoryRole.values,
        _requiredString(json, 'role'),
        'history role',
      ),
      content: _requiredString(json, 'content'),
    );
  }

  factory AssistantHistoryTurn.fromLegacy(Map<String, String> value) {
    return AssistantHistoryTurn.fromJson(<String, Object?>{
      'role': value['role'],
      'content': value['content'],
    });
  }
}

final class AssistantRequestEnvelope {
  AssistantRequestEnvelope({
    this.schemaVersion = assistantContractSchemaVersion,
    required String requestId,
    required String accountScopeId,
    required this.conversation,
    required this.kind,
    required String input,
    required DateTime createdAt,
    List<AssistantHistoryTurn> history = const <AssistantHistoryTurn>[],
    Map<String, Object?> context = const <String, Object?>{},
  }) : requestId = requestId.trim(),
       accountScopeId = accountScopeId.trim(),
       input = input.trim(),
       createdAt = createdAt.toUtc(),
       history = List<AssistantHistoryTurn>.unmodifiable(history),
       context = UnmodifiableMapView<String, Object?>(
         Map<String, Object?>.from(context),
       ) {
    validate();
  }

  final int schemaVersion;
  final String requestId;
  final String accountScopeId;
  final AssistantConversationScope conversation;
  final AssistantRequestKind kind;
  final String input;
  final DateTime createdAt;
  final List<AssistantHistoryTurn> history;
  final Map<String, Object?> context;

  AssistantSurface get surface => conversation.surface;

  void validate() {
    if (schemaVersion != assistantContractSchemaVersion) {
      throw const AssistantContractException(
        'Unsupported assistant request schema version.',
      );
    }
    conversation.validate();
    if (requestId.isEmpty || accountScopeId.isEmpty || input.isEmpty) {
      throw const AssistantContractException(
        'Assistant requests require request, account, and input identity.',
      );
    }
    if (createdAt.year < 2020) {
      throw const AssistantContractException(
        'Assistant request timestamp is outside the supported range.',
      );
    }
    final bool plannerKind =
        kind == AssistantRequestKind.planningGuidance ||
        kind == AssistantRequestKind.followUp;
    if (plannerKind != (surface == AssistantSurface.smartPlanner)) {
      throw const AssistantContractException(
        'Assistant request kind does not match its surface.',
      );
    }
    for (final AssistantHistoryTurn turn in history) {
      turn.validate();
    }
    validateAssistantJsonObject(context, path: 'request.context');
  }

  AssistantRequestEnvelope copyWith({
    List<AssistantHistoryTurn>? history,
    Map<String, Object?>? context,
  }) {
    return AssistantRequestEnvelope(
      schemaVersion: schemaVersion,
      requestId: requestId,
      accountScopeId: accountScopeId,
      conversation: conversation,
      kind: kind,
      input: input,
      createdAt: createdAt,
      history: history ?? this.history,
      context: context ?? this.context,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'requestId': requestId,
    'accountScopeId': accountScopeId,
    'surfaceId': surface.storageId,
    'conversationId': conversation.conversationId,
    'kind': kind.name,
    'input': input,
    'createdAt': createdAt.toIso8601String(),
    'history': history
        .map((AssistantHistoryTurn turn) => turn.toJson())
        .toList(growable: false),
    'context': context,
  };

  factory AssistantRequestEnvelope.fromJson(Map<String, Object?> json) {
    _requireExactKeys(
      json,
      required: const <String>{
        'schemaVersion',
        'requestId',
        'accountScopeId',
        'surfaceId',
        'conversationId',
        'kind',
        'input',
        'createdAt',
        'history',
        'context',
      },
    );
    final DateTime createdAt = _requiredDateTime(json, 'createdAt');
    return AssistantRequestEnvelope(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      requestId: _requiredString(json, 'requestId'),
      accountScopeId: _requiredString(json, 'accountScopeId'),
      conversation: AssistantConversationScope(
        surface: AssistantSurface.fromStorageId(
          _requiredString(json, 'surfaceId'),
        ),
        conversationId: _requiredString(json, 'conversationId'),
      ),
      kind: _enumValue(
        AssistantRequestKind.values,
        _requiredString(json, 'kind'),
        'request kind',
      ),
      input: _requiredString(json, 'input'),
      createdAt: createdAt,
      history: _requiredList(json, 'history')
          .map(
            (Object? item) => AssistantHistoryTurn.fromJson(
              _stringObjectMap(item, 'request.history item'),
            ),
          )
          .toList(growable: false),
      context: _stringObjectMap(json['context'], 'request.context'),
    );
  }

  static List<AssistantHistoryTurn> historyFromLegacy(
    List<Map<String, String>> history,
  ) => history.map(AssistantHistoryTurn.fromLegacy).toList(growable: false);
}

final class AssistantEvidenceItem {
  AssistantEvidenceItem({
    required String evidenceId,
    required this.kind,
    required String sourceId,
    String? entityId,
    required String summary,
    required DateTime observedAt,
    this.freshness = AssistantEvidenceFreshness.unknown,
  }) : evidenceId = evidenceId.trim(),
       sourceId = sourceId.trim(),
       entityId = entityId?.trim(),
       summary = summary.trim(),
       observedAt = observedAt.toUtc() {
    validate();
  }

  final String evidenceId;
  final AssistantEvidenceKind kind;
  final String sourceId;
  final String? entityId;
  final String summary;
  final DateTime observedAt;
  final AssistantEvidenceFreshness freshness;

  void validate() {
    if (evidenceId.isEmpty || sourceId.isEmpty || summary.isEmpty) {
      throw const AssistantContractException(
        'Assistant evidence requires id, source, and summary.',
      );
    }
    if (entityId != null && entityId!.isEmpty) {
      throw const AssistantContractException(
        'Assistant evidence entity ids cannot be blank.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'evidenceId': evidenceId,
    'kind': kind.name,
    'sourceId': sourceId,
    'entityId': entityId,
    'summary': summary,
    'observedAt': observedAt.toIso8601String(),
    'freshness': freshness.name,
  };

  factory AssistantEvidenceItem.fromJson(Map<String, Object?> json) {
    _requireExactKeys(
      json,
      required: const <String>{
        'evidenceId',
        'kind',
        'sourceId',
        'entityId',
        'summary',
        'observedAt',
        'freshness',
      },
    );
    return AssistantEvidenceItem(
      evidenceId: _requiredString(json, 'evidenceId'),
      kind: _enumValue(
        AssistantEvidenceKind.values,
        _requiredString(json, 'kind'),
        'evidence kind',
      ),
      sourceId: _requiredString(json, 'sourceId'),
      entityId: _optionalString(json, 'entityId'),
      summary: _requiredString(json, 'summary'),
      observedAt: _requiredDateTime(json, 'observedAt'),
      freshness: _enumValue(
        AssistantEvidenceFreshness.values,
        _requiredString(json, 'freshness'),
        'evidence freshness',
      ),
    );
  }
}

final class AssistantEvidenceBundle {
  AssistantEvidenceBundle({
    this.schemaVersion = assistantContractSchemaVersion,
    required String requestId,
    required this.conversation,
    required DateTime collectedAt,
    required List<AssistantEvidenceItem> items,
  }) : requestId = requestId.trim(),
       collectedAt = collectedAt.toUtc(),
       items = List<AssistantEvidenceItem>.unmodifiable(items) {
    validate();
  }

  final int schemaVersion;
  final String requestId;
  final AssistantConversationScope conversation;
  final DateTime collectedAt;
  final List<AssistantEvidenceItem> items;

  void validate() {
    if (schemaVersion != assistantContractSchemaVersion || requestId.isEmpty) {
      throw const AssistantContractException(
        'Assistant evidence bundle identity is invalid.',
      );
    }
    conversation.validate();
    if (items.isEmpty) {
      throw const AssistantContractException(
        'Assistant responses require at least one evidence item.',
      );
    }
    final Set<String> ids = <String>{};
    for (final AssistantEvidenceItem item in items) {
      item.validate();
      if (!ids.add(item.evidenceId)) {
        throw const AssistantContractException(
          'Assistant evidence ids must be unique within a response.',
        );
      }
    }
  }

  void validateAgainst(AssistantRequestEnvelope request) {
    validate();
    if (requestId != request.requestId ||
        conversation != request.conversation) {
      throw const AssistantContractException(
        'Assistant evidence does not belong to its request.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'requestId': requestId,
    'surfaceId': conversation.surface.storageId,
    'conversationId': conversation.conversationId,
    'collectedAt': collectedAt.toIso8601String(),
    'items': items
        .map((AssistantEvidenceItem item) => item.toJson())
        .toList(growable: false),
  };

  factory AssistantEvidenceBundle.fromJson(Map<String, Object?> json) {
    _requireExactKeys(
      json,
      required: const <String>{
        'schemaVersion',
        'requestId',
        'surfaceId',
        'conversationId',
        'collectedAt',
        'items',
      },
    );
    return AssistantEvidenceBundle(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      requestId: _requiredString(json, 'requestId'),
      conversation: AssistantConversationScope(
        surface: AssistantSurface.fromStorageId(
          _requiredString(json, 'surfaceId'),
        ),
        conversationId: _requiredString(json, 'conversationId'),
      ),
      collectedAt: _requiredDateTime(json, 'collectedAt'),
      items: _requiredList(json, 'items')
          .map(
            (Object? item) => AssistantEvidenceItem.fromJson(
              _stringObjectMap(item, 'evidence item'),
            ),
          )
          .toList(growable: false),
    );
  }
}

final class AssistantResponseEnvelope {
  AssistantResponseEnvelope({
    this.schemaVersion = assistantContractSchemaVersion,
    required String responseId,
    required String requestId,
    required String accountScopeId,
    required this.conversation,
    required this.status,
    required String message,
    String? reasoning,
    String? emotion,
    this.confidence,
    required this.processingMode,
    required DateTime generatedAt,
    required this.evidence,
    String? taskId,
    String? taskTitle,
    String? proposalId,
  }) : responseId = responseId.trim(),
       requestId = requestId.trim(),
       accountScopeId = accountScopeId.trim(),
       message = message.trim(),
       reasoning = reasoning?.trim(),
       emotion = emotion?.trim(),
       generatedAt = generatedAt.toUtc(),
       taskId = taskId?.trim(),
       taskTitle = taskTitle?.trim(),
       proposalId = proposalId?.trim() {
    validate();
  }

  final int schemaVersion;
  final String responseId;
  final String requestId;
  final String accountScopeId;
  final AssistantConversationScope conversation;
  final AssistantResponseStatus status;
  final String message;
  final String? reasoning;
  final String? emotion;
  final double? confidence;
  final AssistantContractProcessingMode processingMode;
  final DateTime generatedAt;
  final AssistantEvidenceBundle evidence;
  final String? taskId;
  final String? taskTitle;
  final String? proposalId;

  void validate() {
    if (schemaVersion != assistantContractSchemaVersion) {
      throw const AssistantContractException(
        'Unsupported assistant response schema version.',
      );
    }
    conversation.validate();
    if (responseId.isEmpty ||
        requestId.isEmpty ||
        accountScopeId.isEmpty ||
        message.isEmpty) {
      throw const AssistantContractException(
        'Assistant responses require response, request, account, and message.',
      );
    }
    if (confidence != null &&
        (!confidence!.isFinite || confidence! < 0 || confidence! > 1)) {
      throw const AssistantContractException(
        'Assistant response confidence must be between zero and one.',
      );
    }
    if (reasoning != null && reasoning!.isEmpty ||
        emotion != null && emotion!.isEmpty) {
      throw const AssistantContractException(
        'Assistant response reasoning and emotion cannot be blank.',
      );
    }
    if (taskId != null && taskId!.isEmpty ||
        taskTitle != null && taskTitle!.isEmpty ||
        proposalId != null && proposalId!.isEmpty) {
      throw const AssistantContractException(
        'Assistant response references cannot be blank.',
      );
    }
    if ((taskId == null) != (taskTitle == null)) {
      throw const AssistantContractException(
        'Assistant task references require both id and title.',
      );
    }
    if (conversation.surface == AssistantSurface.siConsole &&
        proposalId != null) {
      throw const AssistantContractException(
        'SI Console responses cannot carry mutation proposals.',
      );
    }
    evidence.validate();
  }

  void validateAgainst(AssistantRequestEnvelope request) {
    validate();
    evidence.validateAgainst(request);
    if (requestId != request.requestId ||
        accountScopeId != request.accountScopeId ||
        conversation != request.conversation) {
      throw const AssistantContractException(
        'Assistant response does not belong to its request.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'responseId': responseId,
    'requestId': requestId,
    'accountScopeId': accountScopeId,
    'surfaceId': conversation.surface.storageId,
    'conversationId': conversation.conversationId,
    'status': status.name,
    'message': message,
    'reasoning': reasoning,
    'emotion': emotion,
    'confidence': confidence,
    'processingMode': processingMode.name,
    'generatedAt': generatedAt.toIso8601String(),
    'evidence': evidence.toJson(),
    'taskId': taskId,
    'taskTitle': taskTitle,
    'proposalId': proposalId,
  };

  factory AssistantResponseEnvelope.fromJson(Map<String, Object?> json) {
    _requireExactKeys(
      json,
      required: const <String>{
        'schemaVersion',
        'responseId',
        'requestId',
        'accountScopeId',
        'surfaceId',
        'conversationId',
        'status',
        'message',
        'reasoning',
        'emotion',
        'confidence',
        'processingMode',
        'generatedAt',
        'evidence',
        'taskId',
        'taskTitle',
        'proposalId',
      },
    );
    return AssistantResponseEnvelope(
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      responseId: _requiredString(json, 'responseId'),
      requestId: _requiredString(json, 'requestId'),
      accountScopeId: _requiredString(json, 'accountScopeId'),
      conversation: AssistantConversationScope(
        surface: AssistantSurface.fromStorageId(
          _requiredString(json, 'surfaceId'),
        ),
        conversationId: _requiredString(json, 'conversationId'),
      ),
      status: _enumValue(
        AssistantResponseStatus.values,
        _requiredString(json, 'status'),
        'response status',
      ),
      message: _requiredString(json, 'message'),
      reasoning: _optionalString(json, 'reasoning'),
      emotion: _optionalString(json, 'emotion'),
      confidence: _optionalDouble(json, 'confidence'),
      processingMode: _enumValue(
        AssistantContractProcessingMode.values,
        _requiredString(json, 'processingMode'),
        'processing mode',
      ),
      generatedAt: _requiredDateTime(json, 'generatedAt'),
      evidence: AssistantEvidenceBundle.fromJson(
        _stringObjectMap(json['evidence'], 'response.evidence'),
      ),
      taskId: _optionalString(json, 'taskId'),
      taskTitle: _optionalString(json, 'taskTitle'),
      proposalId: _optionalString(json, 'proposalId'),
    );
  }
}

String assistantAccountScopeId({
  required String? authenticatedNamespace,
  required bool isSignedOut,
}) {
  final String normalized = authenticatedNamespace?.trim() ?? '';
  if (normalized.isNotEmpty) return normalized;
  return isSignedOut ? 'account.signed_out' : 'account.unsafe';
}

AssistantRequestEnvelope createAssistantRequestEnvelope({
  required String accountScopeId,
  required AssistantConversationScope conversation,
  required AssistantRequestKind kind,
  required String input,
  List<Map<String, String>> history = const <Map<String, String>>[],
  Map<String, Object?> context = const <String, Object?>{},
  DateTime? now,
  String? requestId,
}) {
  final DateTime created = (now ?? DateTime.now()).toUtc();
  final int sequence = ++_assistantRequestSequence;
  return AssistantRequestEnvelope(
    requestId:
        requestId ??
        'assistant.${conversation.surface.storageId}.'
            '${created.microsecondsSinceEpoch}.$sequence',
    accountScopeId: accountScopeId,
    conversation: conversation,
    kind: kind,
    input: input,
    createdAt: created,
    history: AssistantRequestEnvelope.historyFromLegacy(history),
    context: context,
  );
}

List<AssistantEvidenceItem> createAssistantEvidenceItems({
  required AssistantRequestEnvelope request,
  required List<String> summaries,
  required String sourceId,
  AssistantEvidenceKind kind = AssistantEvidenceKind.domainFact,
  AssistantEvidenceFreshness freshness = AssistantEvidenceFreshness.current,
  DateTime? observedAt,
}) {
  final DateTime observed = (observedAt ?? DateTime.now()).toUtc();
  final List<String> normalized = summaries
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
  final List<String> effective = normalized.isEmpty
      ? <String>['Request accepted at a typed assistant boundary']
      : normalized;
  return List<AssistantEvidenceItem>.generate(
    effective.length,
    (int index) => AssistantEvidenceItem(
      evidenceId: '${request.requestId}.evidence.$index',
      kind: normalized.isEmpty ? AssistantEvidenceKind.userInput : kind,
      sourceId: normalized.isEmpty ? 'assistant_request' : sourceId,
      summary: effective[index],
      observedAt: observed,
      freshness: freshness,
    ),
    growable: false,
  );
}

void validateAssistantJsonObject(
  Map<String, Object?> value, {
  required String path,
}) {
  for (final MapEntry<String, Object?> entry in value.entries) {
    if (entry.key.trim().isEmpty) {
      throw AssistantContractException('$path contains a blank key.');
    }
    _validateJsonValue(entry.value, path: '$path.${entry.key}');
  }
}

void _validateJsonValue(Object? value, {required String path}) {
  if (value == null || value is String || value is bool || value is int) {
    return;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw AssistantContractException('$path contains a non-finite number.');
    }
    return;
  }
  if (value is List<Object?>) {
    for (int index = 0; index < value.length; index++) {
      _validateJsonValue(value[index], path: '$path[$index]');
    }
    return;
  }
  if (value is Map<String, Object?>) {
    validateAssistantJsonObject(value, path: path);
    return;
  }
  throw AssistantContractException(
    '$path contains unsupported value type ${value.runtimeType}.',
  );
}

void _requireExactKeys(
  Map<String, Object?> json, {
  required Set<String> required,
}) {
  final Set<String> keys = json.keys.toSet();
  final Set<String> missing = required.difference(keys);
  final Set<String> unknown = keys.difference(required);
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw AssistantContractException(
      'Schema keys do not match. Missing: ${missing.join(', ')}; '
      'unknown: ${unknown.join(', ')}.',
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw AssistantContractException('$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw AssistantContractException(
      '$key must be null or a non-empty string.',
    );
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! int) {
    throw AssistantContractException('$key must be an integer.');
  }
  return value;
}

double? _optionalDouble(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) return null;
  if (value is! num) {
    throw AssistantContractException('$key must be null or numeric.');
  }
  return value.toDouble();
}

DateTime _requiredDateTime(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String) {
    throw AssistantContractException('$key must be an ISO-8601 string.');
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw AssistantContractException('$key is not a valid ISO-8601 time.');
  }
  return parsed.toUtc();
}

List<Object?> _requiredList(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! List<Object?>) {
    throw AssistantContractException('$key must be a list.');
  }
  return value;
}

Map<String, Object?> _stringObjectMap(Object? value, String label) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map<Object?, Object?> &&
      value.keys.every((Object? key) => key is String)) {
    return Map<String, Object?>.from(value);
  }
  throw AssistantContractException('$label must be a string-keyed object.');
}

T _enumValue<T extends Enum>(List<T> values, String name, String label) {
  for (final T value in values) {
    if (value.name == name) return value;
  }
  throw AssistantContractException('Unknown $label: $name.');
}
