import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive adapter for the legacy typed goal box.
///
/// Completion state is stored as an optional trailing field. Reads remain
/// backward-compatible with records written before completion state was added:
/// old records have no remaining bytes and are treated as active.
class GoalEntityAdapter extends TypeAdapter<GoalEntity> {
  @override
  final int typeId = 101;

  @override
  GoalEntity read(BinaryReader reader) {
    final DateTime? completedAt = reader.availableBytes > 0
        ? reader.read() as DateTime?
        : null;
    return GoalEntity(
      id: reader.readString(),
      title: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      description: reader.read() as String?,
      targetDate: reader.read() as DateTime?,
      colorHex: reader.readInt(),
      completedAt: completedAt,
    );
  }

  @override
  void write(BinaryWriter writer, GoalEntity obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.write(obj.description);
    writer.write(obj.targetDate);
    writer.writeInt(obj.colorHex);
    writer.write(obj.completedAt);
  }
}
