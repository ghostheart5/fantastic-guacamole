import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encryptedBoxes includes critical persisted stores', () {
    expect(HiveBoxes.encryptedBoxes.contains(HiveBoxes.offlineQueue), isTrue);
    expect(HiveBoxes.encryptedBoxes.contains(HiveBoxes.tasks), isTrue);
    expect(HiveBoxes.encryptedBoxes.contains(HiveBoxes.notifications), isTrue);
  });
}
