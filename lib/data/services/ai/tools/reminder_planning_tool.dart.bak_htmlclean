import 'package:fantastic_guacamole/data/services/ai/tools/ai_tool.dart';

class ReminderPlanningTool extends AiTool {
  const ReminderPlanningTool();

  @override
  String get name => 'reminder_planning';

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> input) async {
    final String prompt = input['prompt']?.toString().trim() ?? '';
    final String lowered = prompt.toLowerCase();

    String window = 'today';
    if (lowered.contains('tomorrow')) {
      window = 'tomorrow';
    } else if (lowered.contains('next week')) {
      window = 'next_week';
    } else if (lowered.contains('tonight')) {
      window = 'tonight';
    }

    return <String, dynamic>{
      'window': window,
      'scheduled': prompt.isNotEmpty,
      'message': prompt,
    };
  }
}
