import 'package:fantastic_guacamole/features/progression/models/streak.dart';

class StreakLogic {
  const StreakLogic();

  Streak update(Streak streak, DateTime today) {
    final DateTime day = DateTime(today.year, today.month, today.day);
    final DateTime? lastActiveDate = streak.lastActiveDate;
    final DateTime? last = lastActiveDate == null
        ? null
        : DateTime(
            lastActiveDate.year,
            lastActiveDate.month,
            lastActiveDate.day,
          );

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
      final int nextCurrent = streak.current + 1;
      return Streak(
        current: nextCurrent,
        longest: nextCurrent > streak.longest ? nextCurrent : streak.longest,
        lastActiveDate: day,
      );
    }

    return Streak(current: 1, longest: streak.longest, lastActiveDate: day);
  }
}
