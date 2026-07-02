class TaskId {
  TaskId(String value) : value = _validate(value);

  final String value;

  static String _validate(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'Task id cannot be empty.');
    }
    return value;
  }
}
