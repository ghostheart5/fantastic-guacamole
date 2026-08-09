import 'package:fantastic_guacamole/data/local/task_entity_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TaskEntityMapper rejects a missing or invalid createdAt timestamp', () {
    expect(
      () => TaskEntityMapper.fromJson(<String, dynamic>{
        'id': 'task-1',
        'title': 'Focus',
      }),
      throwsFormatException,
    );
    expect(
      () => TaskEntityMapper.fromJson(<String, dynamic>{
        'id': 'task-1',
        'title': 'Focus',
        'createdAt': 'not-a-date',
      }),
      throwsFormatException,
    );
  });
}
