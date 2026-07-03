import 'package:fantastic_guacamole/data/services/ai/agents/ai_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/tools/reminder_planning_tool.dart';

class ReminderAgent extends AiAgent {
  const ReminderAgent({this.reminderTool = const ReminderPlanningTool()});

  final ReminderPlanningTool reminderTool;

  @override
  String get name => 'reminder';

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    final String reminder =
        request['reminder']?.toString() ?? request['prompt']?.toString() ?? '';
    final Map<String, dynamic> plan = await reminderTool.run(<String, dynamic>{
      'prompt': reminder,
    });
    final String window = plan['window']?.toString() ?? 'today';
    final bool scheduled = plan['scheduled'] == true;

    return <String, dynamic>{
      'agent': name,
      'mode': 'reminder',
      'reminder': reminder,
      'window': window,
      'scheduled': scheduled,
      'message': scheduled
          ? 'Reminder queued for $window: $reminder'
          : 'No reminder text provided.',
      'reasoning':
          'Detected time window from the prompt and prepared reminder metadata.',
      'emotion': 'balanced',
      'confidence': scheduled ? 0.8 : 0.3,
      'status': 'ready',
    };
  }
}
