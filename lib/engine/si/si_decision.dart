import 'package:fantastic_guacamole/data/models/task.dart';

class Decision {
  const Decision({
    required this.task,
    required this.score,
    required this.reasoning,
  });

  final Task task;
  final double score;
  final String reasoning;
}
