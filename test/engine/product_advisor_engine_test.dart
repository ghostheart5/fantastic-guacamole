import 'package:flutter_test/flutter_test.dart';
import 'package:fantastic_guacamole/engine/advisor/product_advisor_engine.dart';

void main() {
  test('does not infer seen or started tasks from task creation', () {
    const ProductAdvisorEngine engine = ProductAdvisorEngine();

    final List<ProductRecommendation> recommendations = engine.fromSnapshot(
      <String, dynamic>{'tasks_created': 20, 'tasks_completed': 0},
      0,
    );

    expect(
      recommendations.map((ProductRecommendation item) => item.issue),
      contains('Not enough data yet'),
    );
    expect(
      recommendations.map((ProductRecommendation item) => item.issue),
      isNot(contains("Users see next step but don't start")),
    );
  });
}
