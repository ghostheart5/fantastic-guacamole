import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';

/// Shared canonical interpretation of Creator input; it does not persist data.
enum IntakeKind { task, goal, routine, note, plan, milestone, mission }

class IntakeRequest {
  const IntakeRequest({
    required this.title,
    required this.description,
    required this.kind,
    required this.priority,
    required this.scheduledFor,
    required this.recurrenceRule,
  });
  final String title;
  final String? description;
  final IntakeKind kind;
  final int priority;
  final DateTime? scheduledFor;
  final RecurrenceRule recurrenceRule;

  factory IntakeRequest.fromRaw({
    required String title,
    required String? description,
    required String type,
    required String creatorMode,
    required int priority,
    required DateTime? scheduledFor,
    required RecurrenceRule recurrenceRule,
  }) => IntakeRequest(
    title: title.trim(),
    description: description?.trim().isEmpty ?? true ? null : description!.trim(),
    kind: IntakeKindResolver.resolve(type: type, creatorMode: creatorMode),
    priority: priority,
    scheduledFor: scheduledFor,
    recurrenceRule: recurrenceRule,
  );
  String get taskKind => kind == IntakeKind.routine ? 'habit' : kind.name;
  RecurrenceRule get resolvedRecurrence => recurrenceRule != RecurrenceRule.none ? recurrenceRule : kind == IntakeKind.routine ? RecurrenceRule.daily : RecurrenceRule.none;
  int get resolvedPriority => switch (kind) {
    IntakeKind.goal || IntakeKind.mission => priority < 4 ? 4 : priority,
    IntakeKind.milestone => priority < 3 ? 3 : priority,
    IntakeKind.plan => priority < 2 ? 2 : priority,
    IntakeKind.note => 1,
    _ => priority,
  };
  int get difficulty => switch (kind) { IntakeKind.goal || IntakeKind.mission => 5, IntakeKind.milestone => 4, _ => 3 };
  int get energyRequired => switch (kind) { IntakeKind.goal => 4, IntakeKind.mission || IntakeKind.milestone => 3, IntakeKind.plan || IntakeKind.routine => 2, IntakeKind.note => 1, _ => 3 };
  void validate() {
    if (title.isEmpty) throw StateError('Intake requests require a title.');
    if (priority < 1 || priority > 5) {
      throw StateError('Intake request priority must be between 1 and 5.');
    }
  }
}

class IntakeKindResolver {
  const IntakeKindResolver._();
  static IntakeKind resolve({required String type, required String creatorMode}) {
    final raw = switch (creatorMode.trim().toLowerCase()) {
      'goals' => 'goal',
      'milestones' => 'milestone',
      'plan' => 'plan',
      'habits' => 'routine',
      _ => type.trim().toLowerCase(),
    };
    return switch (raw) {
      'goal' => IntakeKind.goal,
      'routine' || 'daily rhythm' || 'habit' => IntakeKind.routine,
      'note' || 'notes' || 'memo' || 'memory' || 'journal' => IntakeKind.note,
      'plan' => IntakeKind.plan,
      'milestone' => IntakeKind.milestone,
      'mission' => IntakeKind.mission,
      _ => IntakeKind.task,
    };
  }
}
