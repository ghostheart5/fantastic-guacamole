import 'package:fantastic_guacamole/data/services/ai/agents/ai_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/tools/text_summary_tool.dart';

class SummarizationAgent extends AiAgent {
  const SummarizationAgent({this.summaryTool = const TextSummaryTool()});

  final TextSummaryTool summaryTool;

  @override
  String get name => 'summarization';

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> request) async {
    final String content =
        request['content']?.toString() ?? request['prompt']?.toString() ?? '';
    final Map<String, dynamic> summary = await summaryTool.run(
      <String, dynamic>{'content': content},
    );
    final String summaryText = summary['summary']?.toString() ?? '';

    return <String, dynamic>{
      'agent': name,
      'mode': 'summarization',
      'contentLength': content.length,
      'summary': summaryText,
      'message': summaryText,
      'reasoning':
          'Summarized ${summary['sentences']} sentences into a compact response.',
      'emotion': 'balanced',
      'confidence': 0.72,
      'status': 'ready',
    };
  }
}
