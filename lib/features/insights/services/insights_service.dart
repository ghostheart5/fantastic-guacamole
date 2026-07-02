import 'package:fantastic_guacamole/data/models/si_state.dart';
import 'package:fantastic_guacamole/features/insights/insight_engine.dart';
import 'package:fantastic_guacamole/features/insights/models/insight_model.dart';
import 'package:fantastic_guacamole/features/insights/logic/insights_logic.dart';
import 'package:fantastic_guacamole/features/insights/models/insights_models.dart';

class InsightsService {
  const InsightsService({this.logic = const InsightsLogic()});

  final InsightsLogic logic;

  InsightsBundle build(SIState state) {
    final List<Insight> insights = InsightEngine(state).generate();
    final double score = logic.computeHealthScore(state);
    final String summary = logic.summarize(insights);
    return InsightsBundle(
      items: insights,
      summary: summary,
      healthScore: score,
    );
  }
}
