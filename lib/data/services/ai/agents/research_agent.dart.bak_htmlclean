import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/ai_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/tools/task_research_tool.dart';

class ResearchAgent extends AiAgent {
  const ResearchAgent({this.researchTool = const TaskResearchTool()});

  final TaskResearchTool researchTool;

  @override
  String get name => 'research';

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    final String query =
        request['query']?.toString() ?? request['prompt']?.toString() ?? '';
    final List<Task> tasks =
        (request['tasks'] as List<Task>?) ?? const <Task>[];
    final Map<String, dynamic> findings = await researchTool.run(
      <String, dynamic>{'query': query, 'tasks': tasks},
    );
    final List<Map<String, dynamic>> rows =
        ((findings['findings'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
    final String topTitle = rows.isNotEmpty
        ? (rows.first['title']?.toString() ?? 'No ranked task')
        : 'No ranked task';

    return <String, dynamic>{
      'agent': name,
      'mode': 'research',
      'query': query,
      'sources': rows
          .map((Map<String, dynamic> row) => row['title']?.toString() ?? '')
          .where((String s) => s.isNotEmpty)
          .toList(),
      'message': rows.isEmpty
          ? 'No task data was available to analyze.'
          : 'Local task analysis complete. Top candidate: $topTitle',
      'reasoning':
          'Analyzed only the tasks currently supplied by the app, ranked by priority and energy requirement.',
      'emotion': 'focused',
      'confidence': rows.isEmpty ? 0.38 : 0.77,
      'findings': findings,
      'status': 'ready',
    };
  }
}
