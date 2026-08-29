// CHRONOSPARK-CLASS: SHIPPING | Feature: Creator handshake
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

enum CreatorMutationKind { createTask }

enum CreatorHandshakeSource { creator, smartPlanner }

enum CreatorHandshakePhase {
  idle,
  preview,
  confirming,
  stale,
  expired,
  applied,
  idempotent,
  conflict,
  undone,
  failed,
}

final class CreatorTaskMutation {
  const CreatorTaskMutation({
    required this.taskId,
    required this.creatorKind,
    required this.title,
    required this.description,
    required this.priority,
    required this.difficulty,
    required this.energyRequired,
    required this.createdAt,
    required this.scheduledFor,
    required this.recurrenceRule,
  });

  final String taskId;
  final String creatorKind;
  final String title;
  final String? description;
  final int priority;
  final int difficulty;
  final int energyRequired;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final RecurrenceRule recurrenceRule;

  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'creatorKind': creatorKind,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'description': description,
    'difficulty': difficulty,
    'energyRequired': energyRequired,
    'priority': priority,
    'recurrenceRule': recurrenceRule.name,
    'scheduledFor': scheduledFor?.toUtc().toIso8601String(),
    'taskId': taskId,
    'title': title,
  };

  String get digest => creatorHandshakeDigest(toCanonicalJson());
}

final class CreatorMutationOperation {
  const CreatorMutationOperation({
    required this.operationId,
    required this.kind,
    required this.label,
    required this.task,
  });

  final String operationId;
  final CreatorMutationKind kind;
  final String label;
  final CreatorTaskMutation task;

  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'kind': kind.name,
    'label': label,
    'operationId': operationId,
    'task': task.toCanonicalJson(),
  };
}

final class CreatorHandshakePreview {
  CreatorHandshakePreview({
    this.schemaVersion = currentSchemaVersion,
    required this.proposalId,
    required this.accountScopeId,
    required this.source,
    required this.baseDomainRevision,
    required this.createdAt,
    required this.expiresAt,
    required List<CreatorMutationOperation> operations,
    required Set<String> selectedOperationIds,
  }) : operations = List<CreatorMutationOperation>.unmodifiable(operations),
       selectedOperationIds = Set<String>.unmodifiable(selectedOperationIds) {
    _validate();
  }

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String proposalId;
  final String accountScopeId;
  final CreatorHandshakeSource source;
  final String baseDomainRevision;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<CreatorMutationOperation> operations;
  final Set<String> selectedOperationIds;

  List<CreatorMutationOperation> get selectedOperations => operations
      .where(
        (CreatorMutationOperation operation) =>
            selectedOperationIds.contains(operation.operationId),
      )
      .toList(growable: false);

  String get displayedDiffDigest => creatorHandshakeDigest(<String, Object?>{
    'accountScopeId': accountScopeId,
    'baseDomainRevision': baseDomainRevision,
    'operations': operations
        .map((CreatorMutationOperation item) => item.toCanonicalJson())
        .toList(growable: false),
    'proposalId': proposalId,
    'schemaVersion': schemaVersion,
    'selectedOperationIds': selectedOperationIds.toList()..sort(),
    'source': source.name,
  });

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt.toUtc());

  CreatorHandshakePreview copyWith({
    String? baseDomainRevision,
    DateTime? createdAt,
    DateTime? expiresAt,
    Set<String>? selectedOperationIds,
  }) => CreatorHandshakePreview(
    schemaVersion: schemaVersion,
    proposalId: proposalId,
    accountScopeId: accountScopeId,
    source: source,
    baseDomainRevision: baseDomainRevision ?? this.baseDomainRevision,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    operations: operations,
    selectedOperationIds: selectedOperationIds ?? this.selectedOperationIds,
  );

  void _validate() {
    if (schemaVersion != currentSchemaVersion) {
      throw StateError('Unsupported Creator handshake schema version.');
    }
    if (proposalId.trim().isEmpty || accountScopeId.trim().isEmpty) {
      throw ArgumentError('Creator handshake identity cannot be blank.');
    }
    if (operations.isEmpty) {
      throw ArgumentError('Creator handshake requires at least one operation.');
    }
    final Set<String> operationIds = operations
        .map((CreatorMutationOperation item) => item.operationId)
        .toSet();
    if (operationIds.length != operations.length ||
        !operationIds.containsAll(selectedOperationIds)) {
      throw ArgumentError(
        'Selected Creator operations must be unique members of the preview.',
      );
    }
    if (!expiresAt.toUtc().isAfter(createdAt.toUtc())) {
      throw ArgumentError('Creator handshake expiry must follow creation.');
    }
  }
}

final class CreatorConfirmationToken {
  CreatorConfirmationToken._({
    required this.tokenId,
    required this.proposalId,
    required this.accountScopeId,
    required this.surfaceId,
    required this.baseDomainRevision,
    required this.displayedDiffDigest,
    required this.selectedOperationIds,
    required this.issuedAt,
    required this.expiresAt,
    required this.bindingDigest,
  });

  factory CreatorConfirmationToken.issue({
    required CreatorHandshakePreview preview,
    required DateTime issuedAt,
  }) {
    final List<String> selected = preview.selectedOperationIds.toList()..sort();
    final Map<String, Object?> binding = <String, Object?>{
      'accountScopeId': preview.accountScopeId,
      'baseDomainRevision': preview.baseDomainRevision,
      'displayedDiffDigest': preview.displayedDiffDigest,
      'expiresAt': preview.expiresAt.toUtc().toIso8601String(),
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'proposalId': preview.proposalId,
      'selectedOperationIds': selected,
      'surfaceId': 'creator',
    };
    final String digest = creatorHandshakeDigest(binding);
    return CreatorConfirmationToken._(
      tokenId: 'creator-confirm-${digest.substring(0, 24)}',
      proposalId: preview.proposalId,
      accountScopeId: preview.accountScopeId,
      surfaceId: 'creator',
      baseDomainRevision: preview.baseDomainRevision,
      displayedDiffDigest: preview.displayedDiffDigest,
      selectedOperationIds: List<String>.unmodifiable(selected),
      issuedAt: issuedAt.toUtc(),
      expiresAt: preview.expiresAt.toUtc(),
      bindingDigest: digest,
    );
  }

  final String tokenId;
  final String proposalId;
  final String accountScopeId;
  final String surfaceId;
  final String baseDomainRevision;
  final String displayedDiffDigest;
  final List<String> selectedOperationIds;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String bindingDigest;

  bool validates({
    required CreatorHandshakePreview preview,
    required String currentAccountScopeId,
    required DateTime now,
  }) {
    if (surfaceId != 'creator' ||
        currentAccountScopeId != accountScopeId ||
        preview.accountScopeId != accountScopeId ||
        preview.proposalId != proposalId ||
        preview.baseDomainRevision != baseDomainRevision ||
        preview.displayedDiffDigest != displayedDiffDigest ||
        !setEquals(
          preview.selectedOperationIds,
          selectedOperationIds.toSet(),
        ) ||
        !now.toUtc().isBefore(expiresAt)) {
      return false;
    }
    final Map<String, Object?> binding = <String, Object?>{
      'accountScopeId': accountScopeId,
      'baseDomainRevision': baseDomainRevision,
      'displayedDiffDigest': displayedDiffDigest,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'issuedAt': issuedAt.toUtc().toIso8601String(),
      'proposalId': proposalId,
      'selectedOperationIds': selectedOperationIds,
      'surfaceId': surfaceId,
    };
    return creatorHandshakeDigest(binding) == bindingDigest;
  }
}

final class CreatorHandshakeReceipt {
  const CreatorHandshakeReceipt({
    required this.proposalId,
    required this.accountScopeId,
    required this.confirmationTokenId,
    required this.appliedOperationIds,
    required this.taskIds,
    required this.appliedAt,
    required this.undoExpiresAt,
    required this.resultingDomainRevision,
  });

  final String proposalId;
  final String accountScopeId;
  final String confirmationTokenId;
  final List<String> appliedOperationIds;
  final List<String> taskIds;
  final DateTime appliedAt;
  final DateTime undoExpiresAt;
  final String resultingDomainRevision;

  bool canUndoAt(DateTime now) => now.toUtc().isBefore(undoExpiresAt.toUtc());
}

final class CreatorHandshakeState {
  const CreatorHandshakeState({
    this.phase = CreatorHandshakePhase.idle,
    this.preview,
    this.token,
    this.receipt,
    this.message,
    this.formRevision = 0,
  });

  final CreatorHandshakePhase phase;
  final CreatorHandshakePreview? preview;
  final CreatorConfirmationToken? token;
  final CreatorHandshakeReceipt? receipt;
  final String? message;
  final int formRevision;

  bool get isReviewing => preview != null && receipt == null;
  bool get canConfirm =>
      isReviewing &&
      preview!.selectedOperationIds.isNotEmpty &&
      phase != CreatorHandshakePhase.confirming;

  CreatorHandshakeState copyWith({
    CreatorHandshakePhase? phase,
    CreatorHandshakePreview? preview,
    CreatorConfirmationToken? token,
    CreatorHandshakeReceipt? receipt,
    String? message,
    int? formRevision,
    bool clearPreview = false,
    bool clearToken = false,
    bool clearReceipt = false,
    bool clearMessage = false,
  }) => CreatorHandshakeState(
    phase: phase ?? this.phase,
    preview: clearPreview ? null : preview ?? this.preview,
    token: clearToken ? null : token ?? this.token,
    receipt: clearReceipt ? null : receipt ?? this.receipt,
    message: clearMessage ? null : message ?? this.message,
    formRevision: formRevision ?? this.formRevision,
  );
}

bool setEquals<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

String creatorHandshakeDigest(Object? value) {
  final Object? canonical = _canonicalize(value);
  return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final List<String> keys = value.keys.map((Object? key) => '$key').toList()
      ..sort();
    return <String, Object?>{
      for (final String key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map<Object?>(_canonicalize).toList(growable: false);
  }
  if (value is DateTime) return value.toUtc().toIso8601String();
  return value;
}
