import 'package:fantastic_guacamole/data/models/task.dart';

class Decision {
  final Task task;

  /// âœ… numeric result from scoring
  final double score;

  /// âœ… explanation for AI / console / UI
  final String reasoning;

  const Decision({
    required this.task,
    required this.score,
    required this.reasoning,
  });
}
