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
    final bool prepared = plan['scheduled'] == true;

    return <String, dynamic>{
      'agent': name,
      'mode': 'reminder',
      'reminder': reminder,
      'window': window,
      'scheduled': false,
      'prepared': prepared,
      'message': prepared
          ? 'Reminder plan prepared for $window: $reminder. Confirm it to schedule the notification.'
          : 'No reminder text provided.',
      'reasoning':
          'Detected a time window and prepared metadata without claiming the notification was scheduled.',
      'emotion': 'balanced',
      'confidence': prepared ? 0.68 : 0.3,
      'status': 'ready',
    };
  }
}
