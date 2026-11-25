// CHRONOSPARK-CLASS: SHIPPING | Feature: Consented assistant conversations

/// Optional information AI chat can add to a request, beyond "My plan". Each
/// is off until the person turns it on for the chat they are in, and each is
/// shown line by line in the review before anything is sent.
enum ConversationExtraSource {
  /// Habit titles with cadence, check-ins in the last 14 days and streak.
  habits,

  /// Titles of tasks finished or skipped in the last 14 days.
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
