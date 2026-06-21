class TimeUtils {
  static int minutesBetween(DateTime start, DateTime end) {
    return end.difference(start).inMinutes;
  }

  static bool overlaps({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    return startA.isBefore(endB) && startB.isBefore(endA);
  }
}
