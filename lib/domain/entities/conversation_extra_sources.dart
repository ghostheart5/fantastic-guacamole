// CHRONOSPARK-CLASS: SHIPPING | Feature: Consented assistant conversations
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

/// Optional information AI chat can add to a request, beyond "My plan". Each
/// is off until the person turns it on, stays on for every later message in
/// that open chat until they turn it off, and is shown line by line in the
/// review before the first message that carries it.
enum ConversationExtraSource {
  /// Habit titles with cadence, check-ins in the last 14 days and streak.
  habits,

  /// Titles of tasks finished or skipped, with the outcome and when.
  recentTasks,

  /// For each goal, how many linked tasks and milestones are done or open.
  goalProgress,
}

/// The most records one extra source adds to a request (the same limit as
/// every other source).
const int conversationExtraSourceItemLimit = 12;

/// Habit, task and goal titles are the person's own words; they are shortened
/// to this many characters before they are sent.
const int conversationExtraTitleLimit = 120;

/// How far back recent results reach: the person's selected dates when they
/// are 14 days or shorter, and never more than 14 days.
enum ConversationRecentWindow {
  today(0, 'recentTasksToday'),
  last7Days(6, 'recentTasksLast7Days'),
  last14Days(13, 'recentTasksLast14Days');

  const ConversationRecentWindow(this.daysBeforeToday, this.contextKey);

  /// Calendar days before today where the window starts (today counts).
  final int daysBeforeToday;

  /// The window is part of the key the AI reads.
  final String contextKey;

  static ConversationRecentWindow forRange(SIV2TimeRange range) =>
      switch (range) {
        SIV2TimeRange.today => today,
        SIV2TimeRange.sevenDays => last7Days,
        SIV2TimeRange.thirtyDays || SIV2TimeRange.all => last14Days,
      };
}

/// The context keys each source can be carried under. Goal progress counts
/// everything linked to the goal, so its key says so.
extension ConversationExtraSourceKeys on ConversationExtraSource {
  List<String> get contextKeys => switch (this) {
    ConversationExtraSource.habits => const ['habits'],
    ConversationExtraSource.recentTasks => [
      for (final window in ConversationRecentWindow.values) window.contextKey,
    ],
    ConversationExtraSource.goalProgress => const ['goalProgressAllTime'],
  };

  String contextKey(ConversationRecentWindow window) => switch (this) {
    ConversationExtraSource.recentTasks => window.contextKey,
    _ => contextKeys.single,
  };
}

/// Every context key an extra source can use (for size trimming).
List<String> get conversationExtraContextKeys => [
  for (final source in ConversationExtraSource.values) ...source.contextKeys,
];
