import 'package:fantastic_guacamole/domain/history/history_event.dart';

enum InterventionOutcomeStatus {
  accepted,
  modified,
  dismissed,
  snoozed,
  disabled,
  legacy,
}

/// A user decision about an intervention, distinct from the intervention.
class InterventionOutcome {
  const InterventionOutcome({
    required this.id,
    required this.interventionId,
    required this.status,
    required this.occurredAt,
    this.modifiedAction,
    this.snoozedUntil,
    this.disabledScope,
    this.explanationRequestedAt,
    this.metadata = const <String, dynamic>{},
    this.legacyStatus,
    this.version = 1,
  });

  final String id;
  final String interventionId;
  final InterventionOutcomeStatus status;
  final DateTime occurredAt;
  final String? modifiedAction;
  final DateTime? snoozedUntil;
  final String? disabledScope;
  final DateTime? explanationRequestedAt;
  final Map<String, dynamic> metadata;
  final String? legacyStatus;
  final int version;

  bool get requestedExplanation => explanationRequestedAt != null;

  void validate() {
    if (id.trim().isEmpty || interventionId.trim().isEmpty) {
      throw StateError('InterventionOutcome requires id and interventionId.');
    }
    if (status == InterventionOutcomeStatus.modified &&
        (modifiedAction == null || modifiedAction!.trim().isEmpty)) {
      throw StateError('Modified outcome requires a modified action.');
    }
    if (status == InterventionOutcomeStatus.snoozed && snoozedUntil == null) {
      throw StateError('Snoozed outcome requires a snooze time.');
    }
    if (status == InterventionOutcomeStatus.disabled &&
        (disabledScope == null || disabledScope!.trim().isEmpty)) {
      throw StateError('Disabled outcome requires its disabled scope.');
    }
    if (status == InterventionOutcomeStatus.legacy &&
        (legacyStatus == null || legacyStatus!.trim().isEmpty)) {
      throw StateError('Legacy outcome requires its original status.');
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': version,
    'id': id,
    'interventionId': interventionId,
    'status': status.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'modifiedAction': modifiedAction,
    'snoozedUntil': snoozedUntil?.toUtc().toIso8601String(),
    'disabledScope': disabledScope,
    'explanationRequestedAt': explanationRequestedAt?.toUtc().toIso8601String(),
    'metadata': metadata,
    'legacyStatus': legacyStatus,
  };

  factory InterventionOutcome.fromJson(Map<String, dynamic> json) {
    final String rawStatus = json['status']?.toString() ?? '';
    final InterventionOutcomeStatus status = InterventionOutcomeStatus.values
        .firstWhere(
          (InterventionOutcomeStatus value) => value.name == rawStatus,
          orElse: () => InterventionOutcomeStatus.legacy,
        );
    return InterventionOutcome(
      id: json['id']?.toString() ?? '',
      interventionId: json['interventionId']?.toString() ?? '',
      status: status,
      occurredAt: _date(json['occurredAt']),
      modifiedAction: json['modifiedAction']?.toString(),
      snoozedUntil: _optionalDate(json['snoozedUntil']),
      disabledScope: json['disabledScope']?.toString(),
      explanationRequestedAt: _optionalDate(json['explanationRequestedAt']),
      metadata: _map(json['metadata']),
      legacyStatus: status == InterventionOutcomeStatus.legacy
          ? (json['legacyStatus']?.toString() ?? rawStatus)
          : json['legacyStatus']?.toString(),
      version: json['schemaVersion'] is int ? json['schemaVersion'] as int : 1,
    );
  }

  HistoryEvent toHistoryEvent() {
    final HistoryEventKind? kind = switch (status) {
      InterventionOutcomeStatus.accepted => HistoryEventKind.interventionAccepted,
      InterventionOutcomeStatus.modified => HistoryEventKind.interventionModified,
      InterventionOutcomeStatus.dismissed => HistoryEventKind.interventionDismissed,
      InterventionOutcomeStatus.snoozed => HistoryEventKind.interventionSnoozed,
      InterventionOutcomeStatus.disabled => HistoryEventKind.interventionDisabled,
      InterventionOutcomeStatus.legacy => null,
    };
    return HistoryEvent(
      id: 'history-$id',
      kind: kind ?? HistoryEventKind.legacyTimeline,
      occurredAt: occurredAt.toUtc(),
      entityType: HistoryEntityType.intervention,
      entityId: interventionId,
      source: HistoryEventSource.user,
      legacyKind: kind == null ? 'intervention:$legacyStatus' : null,
      payload: <String, dynamic>{
        'outcomeId': id,
        'status': status.name,
        'modifiedAction': modifiedAction,
        'snoozedUntil': snoozedUntil?.toUtc().toIso8601String(),
        'disabledScope': disabledScope,
        'explanationRequestedAt': explanationRequestedAt?.toUtc().toIso8601String(),
      },
    );
  }

  static DateTime _date(Object? value) =>
      _optionalDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static DateTime? _optionalDate(Object? value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toUtc();

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map) return const <String, dynamic>{};
    return raw.map((Object? key, Object? value) => MapEntry(key.toString(), value));
  }
}
