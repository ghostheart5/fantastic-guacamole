import 'package:fantastic_guacamole/data/services/ai/agents/planner_agent.dart';
import 'package:fantastic_guacamole/data/services/ai/agents/recommendation_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Planner and recommendation agent contracts', () {
    test('publish expected mode and ready status', () async {
      const PlannerAgent planner = PlannerAgent();
      const RecommendationAgent recommendation = RecommendationAgent();

      final Map<String, dynamic> plan = await planner.execute(const <String, dynamic>{
        'goal': 'Ship by Friday',
      });
      final Map<String, dynamic> rec = await recommendation.execute(const <String, dynamic>{
        'prompt': 'What is best now?',
      });

      expect(plan['agent'], 'planning');
      expect(plan['mode'], 'planning');
      expect(plan['status'], 'ready');
      expect(plan['steps'], isA<List<String>>());

      expect(rec['agent'], 'recommendation');
      expect(rec['mode'], 'recommendation');
      expect(rec['status'], 'ready');
      expect(rec['recommendations'], isA<List<String>>());
    });
  });
}
