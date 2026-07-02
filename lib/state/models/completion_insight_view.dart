import 'package:fantastic_guacamole/engine/insights/insight_engine.dart';

class CompletionInsightView {
  const CompletionInsightView({
    required this.summary,
    required this.observation,
    required this.suggestion,
  });

  final String summary;
  final String observation;
  final String suggestion;

  factory CompletionInsightView.fromInsight(CompletionInsight insight) {
    return CompletionInsightView(
      summary: insight.summary,
      observation: insight.observation,
      suggestion: insight.suggestion,
    );
  }
}
