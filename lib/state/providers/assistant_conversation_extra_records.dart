import 'package:fantastic_guacamole/domain/entities/conversation_extra_sources.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';

/// The records the chosen extra sources add to an AI chat request, read from
/// the same evidence snapshot the on-device one-tap questions use (nothing is
/// read a second time). Habit, task and goal titles are the person's own
/// words and are sent only because the person turned the source on and saw
/// them in the review. Nothing from notes, descriptions or emotions is added.
///
/// What each source covers is part of what the AI reads: recent results sit
/// under a key naming their window, goal progress under a key saying all
/// time, and habit fields name their 14 days and their periods.
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

  /// A local date and time to the minute, as shown in the review.
  static String readableLocal(DateTime time) {
    final l = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  static ConversationExtraRecords read({
    required Set<ConversationExtraSource> extras,
    required SIV2EvidenceSnapshot snapshot,
    required String entityFilter,
    required ConversationRecentWindow window,
    required DateTime now,
    required String Function(String) title,
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
      final key = source.contextKey(window);
      switch (source) {
        case ConversationExtraSource.habits:
          // The read applied the title filter and returned every match, so
          // what does not fit the 12 is counted exactly.
          records[key] = limited([
            for (final habit in snapshot.habits)
              {
                'title': title(habit.title),
                'cadence': habit.cadence.name,
                'checkInsLast14Days': habit.checkInsInWindow,
                // Days, weeks or months in a row by the cadence, counted
                // from the habit's last change to how often it repeats.
                'streakPeriods': habit.currentStreak,
              },
          ]);
          if (snapshot.habitsUnavailable) unavailable.add(source.name);
        case ConversationExtraSource.recentTasks:
          // The person's selected dates when 14 days or shorter, counted in
          // calendar days with today as the first.
          final start = oneTapAddDays(now.toLocal(), -window.daysBeforeToday);
          records[key] = limited([
            for (final task in snapshot.recentTasks.where(
              (t) =>
                  !t.at.toLocal().isBefore(start) &&
                  // Never later than the moment of the request.
                  !t.at.toLocal().isAfter(now),
            ))
              {
                'title': title(task.title),
                'outcome': task.outcome.name,
                'at': readableLocal(task.at),
              },
          ]);
          if (unreadable.contains(SIV2Source.tasks)) {
            unavailable.add(source.name);
          }
        case ConversationExtraSource.goalProgress:
          final tasksUnreadable = unreadable.contains(SIV2Source.tasks);
          final milestonesUnreadable = unreadable.contains(
            SIV2Source.milestones,
          );
          // Goals with linked work first; the order is otherwise stable.
          final goals = [
            ...snapshot.goals.where((g) => matches(g.title) && g.hasProgress),
            ...snapshot.goals.where((g) => matches(g.title) && !g.hasProgress),
          ];
          records[key] = limited([
            for (final goal in goals)
              {
                'title': title(goal.title),
                // A count that could not be read is left out, never a zero.
                if (!tasksUnreadable) 'tasksDone': goal.linkedTasksDone,
                if (!tasksUnreadable) 'tasksOpen': goal.linkedTasksOpen,
                if (!milestonesUnreadable)
                  'milestonesDone': goal.milestonesDone,
                if (!milestonesUnreadable)
                  'milestonesOpen': goal.milestonesOpen,
              },
          ]);
          if (tasksUnreadable ||
              milestonesUnreadable ||
              unreadable.contains(SIV2Source.goals)) {
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
