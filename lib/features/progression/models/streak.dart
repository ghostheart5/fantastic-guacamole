class Streak {
  const Streak({
    required this.current,
    required this.longest,
    required this.lastActiveDate,
  });

  final int current;
  final int longest;
  final DateTime? lastActiveDate;
}
