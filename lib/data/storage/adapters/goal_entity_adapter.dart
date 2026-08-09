import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// LEGACY/STALE: GoalRepository persists versioned JSON and does not use this
/// binary adapter. Do not register or use it without a versioned migration.
@Deprecated('Legacy GoalEntity binary adapter; do not register for new data.')
class GoalEntityAdapter extends TypeAdapter<GoalEntity> {
  @override
  final int typeId = 101;

  @override
  GoalEntity read(BinaryReader reader) {
    return GoalEntity(
      id: reader.readString(),
      title: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      description: reader.read() as String?,
      targetDate: reader.read() as DateTime?,
      colorHex: reader.readInt(),
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
  }
}
