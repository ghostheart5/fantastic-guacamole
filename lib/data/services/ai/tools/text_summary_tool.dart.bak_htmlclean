import 'package:fantastic_guacamole/data/services/ai/tools/ai_tool.dart';

class TextSummaryTool extends AiTool {
  const TextSummaryTool();

  @override
  String get name => 'text_summary';

  @override
  Future<Map<String, dynamic>> run(Map<String, dynamic> input) async {
    final String content = input['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      return <String, dynamic>{'summary': '', 'sentences': 0, 'words': 0};
    }

    final List<String> sentences = content
        .split(RegExp(r'[.!?]+'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();

    final String summary;
    if (sentences.length <= 2) {
      summary = sentences.join('. ');
    } else {
      summary = '${sentences.first}. ${sentences[1]}.';
    }

    return <String, dynamic>{
      'summary': summary.trim(),
      'sentences': sentences.length,
      'words': content
          .split(RegExp(r'\s+'))
          .where((String w) => w.isNotEmpty)
          .length,
    };
  }
}
