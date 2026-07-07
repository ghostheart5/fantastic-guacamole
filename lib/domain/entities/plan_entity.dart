import 'package:fantastic_guacamole/domain/entities/time_block.dart';

class PlanEntity {
  const PlanEntity({
    required this.id,
    required this.date,
    required this.blocks,
    this.updatedAt,
  });

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
