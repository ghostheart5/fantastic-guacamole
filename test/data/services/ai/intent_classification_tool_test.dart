import 'package:fantastic_guacamole/data/services/ai/tools/intent_classification_tool.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntentClassificationTool', () {
    test('routes core intents with bounded confidence', () async {
      const IntentClassificationTool tool = IntentClassificationTool();

      final Map<String, dynamic> planning = await tool.run(
        const <String, dynamic>{'text': 'Please plan my week'},
      );
      final Map<String, dynamic> reminder = await tool.run(
        const <String, dynamic>{'text': 'Remind me tomorrow at 9'},
      );
      final Map<String, dynamic> research = await tool.run(
        const <String, dynamic>{'text': 'Research this API change'},
      );
      final Map<String, dynamic> chat = await tool.run(const <String, dynamic>{
        'text': 'hello there',
      });

      expect(planning['label'], 'planning');
      expect(reminder['label'], 'reminder');
      expect(research['label'], 'research');
      expect(chat['label'], 'chat');

      for (final Map<String, dynamic> result in <Map<String, dynamic>>[
        planning,
        reminder,
        research,
        chat,
      ]) {
        expect(
          (result['confidence'] as num).toDouble(),
          inInclusiveRange(0.0, 1.0),
        );
      }
    });
  });
}
