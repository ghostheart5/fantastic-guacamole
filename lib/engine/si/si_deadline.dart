/// When an assistant answer counts a deadline as past: one definition for the
/// one-tap questions, typed free answers and the evidence picked for a paid
/// request, so they never disagree.
library;

/// A task or milestone deadline chosen as a whole day ([wholeDay], that
/// calendar day) is past once that local day has ended; one with a time is
/// past from that [moment]. A UTC time of midnight does not make a deadline a
/// whole day: only [wholeDay] says so.
bool siDeadlinePast(DateTime moment, DateTime? wholeDay, DateTime now) =>
    wholeDay != null ? _dayBefore(wholeDay, now) : moment.isBefore(now);

/// Goal targets come from a date picker, as on Home and Schedule: a goal is
/// late once its target day ([wholeDay], or else the local day of [target])
/// has ended.
bool siGoalLate(DateTime target, DateTime? wholeDay, DateTime now) =>
    _dayBefore(wholeDay ?? target.toLocal(), now);

bool _dayBefore(DateTime day, DateTime now) {
  final DateTime local = now.toLocal();
  return DateTime(
    day.year,
    day.month,
    day.day,
  ).isBefore(DateTime(local.year, local.month, local.day));
}
