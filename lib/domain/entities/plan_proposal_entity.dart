import 'package:fantastic_guacamole/domain/entities/time_block.dart';

enum PlanProposalStatus { preview, applied, rejected }

class PlanConflict {
  const PlanConflict({
    required this.firstBlockId,
    required this.secondBlockId,
    required this.reason,
  });

  final String firstBlockId;
  final String secondBlockId;
  final String reason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'firstBlockId': firstBlockId,
    'secondBlockId': secondBlockId,
    'reason': reason,
  };

  factory PlanConflict.fromJson(Map<String, dynamic> json) => PlanConflict(
    firstBlockId: json['firstBlockId']?.toString() ?? '',
    secondBlockId: json['secondBlockId']?.toString() ?? '',
    reason: json['reason']?.toString() ?? 'Schedule conflict',
  );
}

class PlanProposalEntity {
  const PlanProposalEntity({
    required this.id,
    required this.date,
    required this.blocks,
    required this.generatedAt,
    this.status = PlanProposalStatus.preview,
    this.conflicts = const <PlanConflict>[],
    this.evidenceSources = const <String>[],
    this.sourceDecisionId,
    this.rejectionReason,
    this.resolvedAt,
  });

  final String id;
  final DateTime date;
  final List<TimeBlock> blocks;
  final DateTime generatedAt;
  final PlanProposalStatus status;
  final List<PlanConflict> conflicts;
  final List<String> evidenceSources;
  final String? sourceDecisionId;
  final String? rejectionReason;
  final DateTime? resolvedAt;

  bool get isFeasible =>
      conflicts.isEmpty && blocks.every((TimeBlock block) => block.validate());

  PlanProposalEntity copyWith({
    PlanProposalStatus? status,
    String? rejectionReason,
    DateTime? resolvedAt,
  }) {
    return PlanProposalEntity(
      id: id,
      date: date,
      blocks: blocks,
      generatedAt: generatedAt,
      status: status ?? this.status,
      conflicts: conflicts,
      evidenceSources: evidenceSources,
      sourceDecisionId: sourceDecisionId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}
