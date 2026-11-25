import 'package:fantastic_guacamole/domain/entities/conversation_extra_sources.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

/// The records the chosen extra sources add to an AI chat request, read from
/// the same evidence snapshot the on-device one-tap questions use (nothing is
/// read a second time). Habit, task and goal titles are the person's own
/// words and are sent only because the person turned the source on and saw
/// them in the review. Nothing from notes, descriptions or emotions is added.
final class ConversationExtraRecords {
  const ConversationExtraRecords._({
    required this.records,
    required this.omitted,
    required this.unavailable,
  });

  /// Context entries, one per chosen source (empty when none is chosen).
  final Map<String, Object?> records;

  /// Records that did not fit the per-source limit.
  final int omitted;

  /// Chosen sources that could not be read.
  final List<String> unavailable;

  static ConversationExtraRecords read({
    required Set<ConversationExtraSource> extras,
    required SIV2EvidenceSnapshot snapshot,
    required String entityFilter,
    required String Function(String) title,
    required String Function(DateTime) localDate,
  }) {
    if (extras.isEmpty) {
      return const ConversationExtraRecords._(
        records: {},
        omitted: 0,
        unavailable: [],
      );
    }
    final filter = entityFilter.trim().toLowerCase();
    bool matches(String text) =>
        filter.isEmpty || text.toLowerCase().contains(filter);
    var omitted = 0;
    List<Map<String, Object?>> limited(List<Map<String, Object?>> items) {
      if (items.length > conversationExtraSourceItemLimit) {
        omitted += items.length - conversationExtraSourceItemLimit;
      }
      return items.take(conversationExtraSourceItemLimit).toList();
    }

    final unreadable = snapshot.unavailableSources;
    final records = <String, Object?>{};
    final unavailable = <String>[];
    // Fixed order, so the same choice always produces the same request.
    for (final source in ConversationExtraSource.values) {
      if (!extras.contains(source)) continue;
      switch (source) {
        case ConversationExtraSource.habits:
          records[source.name] = limited([
            for (final habit in snapshot.habits.where((h) => matches(h.title)))
              {
                'title': title(habit.title),
                'cadence': habit.cadence.name,
                'checkInsLast14Days': habit.checkInsInWindow,
                'currentStreak': habit.currentStreak,
              },
          ]);
          if (snapshot.habitsUnavailable) unavailable.add(source.name);
        case ConversationExtraSource.recentTasks:
          records[source.name] = limited([
            for (final task in snapshot.recentTasks.where(
              (t) => matches(t.title),
            ))
              {
                'title': title(task.title),
                'outcome': task.outcome.name,
                'at': localDate(task.at.toLocal()),
              },
          ]);
          if (unreadable.contains(SIV2Source.tasks)) {
            unavailable.add(source.name);
          }
        case ConversationExtraSource.goalProgress:
          // Goals with linked work first; the order is otherwise stable.
          final goals = [
            ...snapshot.goals.where((g) => matches(g.title) && g.hasProgress),
            ...snapshot.goals.where((g) => matches(g.title) && !g.hasProgress),
          ];
          records[source.name] = limited([
            for (final goal in goals)
              {
                'title': title(goal.title),
                'tasksDone': goal.linkedTasksDone,
                'tasksOpen': goal.linkedTasksOpen,
                'milestonesDone': goal.milestonesDone,
                'milestonesOpen': goal.milestonesOpen,
              },
          ]);
          if (unreadable.contains(SIV2Source.tasks) ||
              unreadable.contains(SIV2Source.goals) ||
              unreadable.contains(SIV2Source.milestones)) {
            unavailable.add(source.name);
          }
      }
    }
    return ConversationExtraRecords._(
      records: records,
      omitted: omitted,
      unavailable: unavailable,
    );
  }
}
