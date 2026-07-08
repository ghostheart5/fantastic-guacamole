import 'package:fantastic_guacamole/state/models/streak.dart';

class StreakService {
  const StreakService();

  bool didBreak(Streak streak, DateTime today) {
    final DateTime day = DateTime(today.year, today.month, today.day);
    final DateTime? active = streak.lastActiveDate;
    if (active == null || streak.current <= 0) {
      return false;
    }
    final DateTime last = DateTime(active.year, active.month, active.day);
    return day.difference(last).inDays > 1;
  }

  Streak update(Streak streak, DateTime today) {
    final DateTime day = DateTime(today.year, today.month, today.day);
    final DateTime? active = streak.lastActiveDate;
    final DateTime? last = active == null
        ? null
        : DateTime(active.year, active.month, active.day);
    if (last == null) {
      return Streak(current: 1, longest: 1, lastActiveDate: day);
    }
    final int difference = day.difference(last).inDays;
    if (difference == 0) {
      return Streak(
        current: streak.current,
        longest: streak.longest,
        lastActiveDate: day,
      );
    }
    if (difference == 1) {
      final int current = streak.current + 1;
      return Streak(
        current: current,
        longest: current > streak.longest ? current : streak.longest,
        lastActiveDate: day,
      );
    }
    return Streak(current: 1, longest: streak.longest, lastActiveDate: day);
  }
}
