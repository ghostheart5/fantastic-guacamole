import 'package:fantastic_guacamole/data/services/ai/tools/ai_tool.dart';

class IntentClassificationTool extends AiTool {
  const IntentClassificationTool();

  @override
  String get name => 'intent_classification';

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> input) async {
    final String text = input['text']?.toString().trim().toLowerCase() ?? '';

    if (text.isEmpty) {
      return <String, dynamic>{'label': 'empty', 'confidence': 0.2};
    }
    if (_containsAny(text, const <String>['remind', 'notify', 'later', 'tomorrow', 'alarm'])) {
      return <String, dynamic>{'label': 'reminder', 'confidence': 0.84};
    }
    if (_containsAny(text, const <String>['plan', 'roadmap', 'schedule', 'next step'])) {
      return <String, dynamic>{'label': 'planning', 'confidence': 0.8};
    }
    if (_containsAny(text, const <String>['research', 'find out', 'lookup', 'investigate'])) {
      return <String, dynamic>{'label': 'research', 'confidence': 0.82};
    }
    if (_containsAny(text, const <String>['recommend', 'suggest', 'best'])) {
      return <String, dynamic>{'label': 'recommendation', 'confidence': 0.78};
    }
    if (_containsAny(text, const <String>['summarize', 'summary', 'tl;dr'])) {
      return <String, dynamic>{'label': 'summarization', 'confidence': 0.8};
    }

    return <String, dynamic>{'label': 'chat', 'confidence': 0.55};
  }

  bool _containsAny(String text, List<String> candidates) {
    for (final String candidate in candidates) {
      if (text.contains(candidate)) {
        return true;
      }
    }
    return false;
  }
}
