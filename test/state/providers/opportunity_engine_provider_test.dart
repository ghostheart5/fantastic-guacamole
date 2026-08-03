import 'package:fantastic_guacamole/state/providers/goal_success_probability_provider.dart';
import 'package:fantastic_guacamole/state/providers/momentum_engine_provider.dart';
import 'package:fantastic_guacamole/state/providers/opportunity_engine_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Opportunity Engine', () {
    test('score calculations map to expected opportunity levels', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          momentumEngineProvider.overrideWithValue(
            const MomentumEngineState(
              score: 82,
              trend: 'Rising',
              recovery: 'Recovered',
              forecast: 'positive',
              energyPercent: 88,
              pressurePercent: 21,
              streak: 7,
              completedToday: 5,
            ),
          ),
          goalSuccessProbabilityProvider.overrideWithValue(
            const GoalSuccessForecast(
              probability: 84,
              band: GoalSuccessBand.high,
              summary: 'high confidence',
              recommendation: 'execute',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final OpportunityEngineState state = container.read(
        opportunityEngineProvider,
      );

      expect(state.opportunities, hasLength(3));
      expect(state.opportunities[0].level, OpportunityLevel.high);
      expect(state.opportunities[1].level, OpportunityLevel.high);
      expect(state.opportunities[2].level, OpportunityLevel.high);
    });

    test('priority rankings preserve deterministic order', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          momentumEngineProvider.overrideWithValue(
            const MomentumEngineState(
              score: 70,
              trend: 'Rising',
              recovery: 'Recovered',
              forecast: 'positive',
              energyPercent: 70,
              pressurePercent: 30,
              streak: 3,
              completedToday: 2,
            ),
          ),
          goalSuccessProbabilityProvider.overrideWithValue(
            const GoalSuccessForecast(
              probability: 75,
              band: GoalSuccessBand.high,
              summary: 'threshold high',
              recommendation: 'focus',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final List<OpportunityInsight> opportunities =
          container.read(opportunityEngineProvider).opportunities;

      expect(opportunities.map((o) => o.title).toList(), <String>[
        'Momentum Expansion Window',
        'Goal Completion Acceleration',
        'Recovery Optimization',
      ]);
    });

    test('edge cases respect strict thresholds at boundaries', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          momentumEngineProvider.overrideWithValue(
            const MomentumEngineState(
              score: 69,
              trend: 'Stable',
              recovery: 'Watch Load',
              forecast: 'stable',
              energyPercent: 60,
              pressurePercent: 45,
              streak: 1,
              completedToday: 1,
            ),
          ),
          goalSuccessProbabilityProvider.overrideWithValue(
            const GoalSuccessForecast(
              probability: 74,
              band: GoalSuccessBand.medium,
              summary: 'threshold medium',
              recommendation: 'tighten',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final List<OpportunityInsight> opportunities =
          container.read(opportunityEngineProvider).opportunities;

      expect(opportunities[0].level, OpportunityLevel.medium);
      expect(opportunities[1].level, OpportunityLevel.medium);
      expect(opportunities[2].level, OpportunityLevel.low);
    });

    test('empty data equivalent still returns actionable opportunities', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          momentumEngineProvider.overrideWithValue(
            const MomentumEngineState(
              score: 0,
              trend: 'Declining',
              recovery: 'Recovery Needed',
              forecast: 'low',
              energyPercent: 0,
              pressurePercent: 100,
              streak: 0,
              completedToday: 0,
            ),
          ),
          goalSuccessProbabilityProvider.overrideWithValue(
            const GoalSuccessForecast(
              probability: 0,
              band: GoalSuccessBand.low,
              summary: 'low confidence',
              recommendation: 'recover',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final List<OpportunityInsight> opportunities =
          container.read(opportunityEngineProvider).opportunities;

      expect(opportunities, hasLength(3));
      for (final OpportunityInsight insight in opportunities) {
        expect(insight.title.trim(), isNotEmpty);
        expect(insight.summary.trim(), isNotEmpty);
        expect(insight.action.trim(), isNotEmpty);
      }
    });
  });
}
