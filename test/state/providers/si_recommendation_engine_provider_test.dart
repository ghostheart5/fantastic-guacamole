import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SI Recommendation Engine', () {
    test('recommendations returned from mixed timeline events', () {
      final List<TimelineEventEntity> events = <TimelineEventEntity>[
        _event(id: 't-1', type: TimelineEventType.task, title: 'Task A'),
        _event(
          id: 'r-1',
          type: TimelineEventType.recommendation,
          title: 'Recommend A',
        ),
        _event(id: 'k-1', type: TimelineEventType.risk, title: 'Risk A'),
        _event(
          id: 'r-2',
          type: TimelineEventType.recommendation,
          title: 'Recommend B',
        ),
      ];

      final ProviderContainer container = ProviderContainer(
        overrides: [
          timelineProvider.overrideWith(() => _StaticTimelineNotifier(events)),
        ],
      );
      addTearDown(container.dispose);

      final List<TimelineEventEntity> recommendations = container.read(
        timelineRecommendationsProvider,
      );

      expect(recommendations, hasLength(2));
      expect(recommendations.every((e) => e.isRecommendation), isTrue);
      expect(recommendations.map((e) => e.id).toList(), <String>['r-1', 'r-2']);
    });

    test('priority ordering is preserved from source recommendation order', () {
      final List<TimelineEventEntity> events = <TimelineEventEntity>[
        _event(
          id: 'rec-high',
          type: TimelineEventType.recommendation,
          title: 'High Priority',
        ),
        _event(
          id: 'rec-medium',
          type: TimelineEventType.recommendation,
          title: 'Medium Priority',
        ),
        _event(
          id: 'rec-low',
          type: TimelineEventType.recommendation,
          title: 'Low Priority',
        ),
      ];

      final ProviderContainer container = ProviderContainer(
        overrides: [
          timelineProvider.overrideWith(() => _StaticTimelineNotifier(events)),
        ],
      );
      addTearDown(container.dispose);

      final List<TimelineEventEntity> recommendations = container.read(
        timelineRecommendationsProvider,
      );

      expect(recommendations.map((e) => e.id).toList(), <String>[
        'rec-high',
        'rec-medium',
        'rec-low',
      ]);
    });

    test(
      'no-crash scenarios return safely for empty and non-recommendation data',
      () {
        final ProviderContainer emptyContainer = ProviderContainer(
          overrides: [
            timelineProvider.overrideWith(
              () => _StaticTimelineNotifier(const <TimelineEventEntity>[]),
            ),
          ],
        );
        final ProviderContainer noRecommendationContainer = ProviderContainer(
          overrides: [
            timelineProvider.overrideWith(
              () => _StaticTimelineNotifier(<TimelineEventEntity>[
                _event(id: 't-1', type: TimelineEventType.task, title: 'Task'),
                _event(id: 'g-1', type: TimelineEventType.goal, title: 'Goal'),
              ]),
            ),
          ],
        );
        addTearDown(emptyContainer.dispose);
        addTearDown(noRecommendationContainer.dispose);

        expect(
          () => emptyContainer.read(timelineRecommendationsProvider),
          returnsNormally,
        );
        expect(
          () => noRecommendationContainer.read(timelineRecommendationsProvider),
          returnsNormally,
        );
        expect(emptyContainer.read(timelineRecommendationsProvider), isEmpty);
        expect(
          noRecommendationContainer.read(timelineRecommendationsProvider),
          isEmpty,
        );
      },
    );
  });
}

TimelineEventEntity _event({
  required String id,
  required TimelineEventType type,
  required String title,
}) {
  return TimelineEventEntity(
    id: id,
    type: type,
    title: title,
    detail: 'detail:$id',
    timestamp: DateTime(2026, 1, 1),
  );
}

class _StaticTimelineNotifier extends TimelineNotifier {
  _StaticTimelineNotifier(this._events);

  final List<TimelineEventEntity> _events;

  @override
  List<TimelineEventEntity> build() => _events;
}
