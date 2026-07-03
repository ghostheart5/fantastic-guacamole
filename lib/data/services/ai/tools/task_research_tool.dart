import 'package:fantastic_guacamole/data/models/task.dart';
import 'package:fantastic_guacamole/data/services/ai/tools/ai_tool.dart';

class TaskResearchTool extends AiTool {
  const TaskResearchTool();

  @override
  String get name => 'task_research';

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> input) async {
    final List<Task> tasks = (input['tasks'] as List<Task>?) ?? const <Task>[];
    final String query = input['query']?.toString().trim() ?? '';

    final List<Task> ranked = List<Task>.from(tasks)
      ..sort((Task a, Task b) {
        final int priorityScore = b.priority.compareTo(a.priority);
        if (priorityScore != 0) return priorityScore;
        return a.energyRequired.compareTo(b.energyRequired);
      });

    final List<Map<String, dynamic>> findings = ranked.take(3).map((Task task) {
      return <String, dynamic>{
        'id': task.id,
        'title': task.title,
        'priority': task.priority,
        'difficulty': task.difficulty,
        'energyRequired': task.energyRequired,
      };
    }).toList();

    return <String, dynamic>{
      'query': query,
      'findingCount': findings.length,
      'findings': findings,
    };
  }
}
