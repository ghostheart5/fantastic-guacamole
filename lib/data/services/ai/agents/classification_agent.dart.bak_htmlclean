import 'package:fantastic_guacamole/data/services/ai/agents/ai_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/tools/intent_classification_tool.dart';

class ClassificationAgent extends AiAgent {
  const ClassificationAgent({
    this.classificationTool = const IntentClassificationTool(),
  });

  final IntentClassificationTool classificationTool;

  @override
  String get name => 'classification';

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    final String text =
        request['text']?.toString() ?? request['prompt']?.toString() ?? '';
    final Map<String, dynamic> result = await classificationTool.run(
      <String, dynamic>{'text': text},
    );
    final String label = result['label']?.toString() ?? 'unclassified';
    final double confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;

    return <String, dynamic>{
      'agent': name,
      'mode': 'classification',
      'label': label,
      'confidence': confidence,
      'text': text,
      'message': 'Intent detected: $label',
      'reasoning': 'Classified using keyword and phrase heuristics.',
      'emotion': 'neutral',
      'status': 'ready',
    };
  }
}
