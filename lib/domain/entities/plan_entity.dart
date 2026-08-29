import 'package:fantastic_guacamole/domain/entities/time_block.dart';

/// CHRONOSPARK-CLASS: PLANNED | Feature: Smart Planner
///
/// Persisted schedule data used by canonical planning flows.
class PlanEntity {
  PlanEntity({
    required this.id,
    required this.date,
    required List<TimeBlock> blocks,
    this.updatedAt,
  }) : blocks = List<TimeBlock>.unmodifiable(blocks);

  final String id;
  final DateTime date;
  final List<TimeBlock> blocks;
  final DateTime? updatedAt;

  PlanEntity copyWith({
    String? id,
    DateTime? date,
    List<TimeBlock>? blocks,
    DateTime? updatedAt,
  }) {
    return PlanEntity(
      id: id ?? this.id,
      date: date ?? this.date,
      blocks: blocks ?? this.blocks,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
