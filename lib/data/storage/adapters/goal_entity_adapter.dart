import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// TODO(persistence): this adapter does not round-trip `GoalEntity.completedAt`
/// — a goal serialized through it would silently lose its completion state.
/// It is currently inert: `HiveBoxes.goals` is opened as `Box<String>` and
/// `GoalRepository` persists JSON, so nothing goes through this path. Adding
/// the field changes the binary layout, so it is deliberately left alone until
/// this adapter is either used or removed.
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
