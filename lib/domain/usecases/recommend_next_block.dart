import 'package:fantastic_guacamole/domain/entities/time_block.dart';

/// CHRONOSPARK-CLASS: SHIPPING | Feature: Smart Planner
///
/// Selects the block the user should work on next from an already-generated
/// plan. Reads a plan rather than producing one, so planner rules stay in a
/// single place.
class RecommendNextBlock {
  const RecommendNextBlock();

  /// The block currently in progress, else the next one starting after [now].
  ///
  /// Returns null when the plan is empty or entirely in the past.
  TimeBlock? call({required List<TimeBlock> blocks, DateTime? now}) {
    if (blocks.isEmpty) {
      return null;
    }
    final DateTime reference = now ?? DateTime.now();

    TimeBlock? active;
    TimeBlock? upcoming;

    for (final TimeBlock block in blocks) {
      final bool inProgress =
          !block.start.isAfter(reference) && block.end.isAfter(reference);
      if (inProgress) {
        if (active == null || block.start.isBefore(active.start)) {
          active = block;
        }
        continue;
      }
      if (block.start.isAfter(reference)) {
        if (upcoming == null || block.start.isBefore(upcoming.start)) {
          upcoming = block;
        }
      }
    }

    return active ?? upcoming;
  }
}
