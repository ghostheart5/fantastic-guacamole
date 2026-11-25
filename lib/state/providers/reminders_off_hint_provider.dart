import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counts saves of something with a reminder while notifications are off and
/// this account already refused the request. The guide overlay shows the
/// reminders hint once, on the screen in view when a new save is counted.
/// Kept in memory only: whether the hint was seen is stored with the guide.
final remindersOffHintRequestsProvider =
    NotifierProvider<RemindersOffHintRequests, int>(
      RemindersOffHintRequests.new,
    );

class RemindersOffHintRequests extends Notifier<int> {
  @override
  int build() => 0;

  void reminderSavedWhileOff() => state++;
}
