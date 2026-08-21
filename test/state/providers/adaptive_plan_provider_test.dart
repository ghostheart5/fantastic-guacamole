import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/state/providers/adaptive_plan_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Nexus shows the nearest upcoming scheduled day when today is empty',
    () {
      final DateTime now = DateTime(2026, 8, 20, 17);
      final TimeBlock nearest = TimeBlock(
        id: 'nearest',
        taskId: 'task-nearest',
        title: 'Nearest task',
        start: DateTime(2026, 8, 27, 18, 27),
        end: DateTime(2026, 8, 27, 19, 12),
      );
      final TimeBlock sameDay = TimeBlock(
        id: 'same-day',
        taskId: 'task-same-day',
        title: 'Same day task',
        start: DateTime(2026, 8, 27, 20),
        end: DateTime(2026, 8, 27, 20, 45),
      );
      final TimeBlock later = TimeBlock(
        id: 'later',
        taskId: 'task-later',
        title: 'Later task',
        start: DateTime(2026, 8, 29, 18),
        end: DateTime(2026, 8, 29, 18, 45),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          adaptivePlanClockProvider.overrideWithValue(() => now),
          adaptivePlanProvider.overrideWithValue(
            AsyncData<List<TimeBlock>>(<TimeBlock>[later, sameDay, nearest]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final List<TimeBlock> visible = container
          .read(nexusTimeBlocksProvider)
          .requireValue;

      expect(visible.map((TimeBlock block) => block.id), <String>[
        'nearest',
        'same-day',
      ]);
    },
  );
}
