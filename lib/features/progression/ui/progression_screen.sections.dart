part of 'progression_screen.dart';

/// A sentence on the page, in the page's secondary colour.
class _PageLine extends StatelessWidget {
  const _PageLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: PlainPalette.of(context).secondary),
  );
}

/// First read of this account's records: nothing to show yet.
class _Reading extends StatelessWidget {
  const _Reading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: <Widget>[
        CircularProgressIndicator(color: PlainPalette.of(context).accent),
        const SizedBox(height: 12),
        _PageLine(text),
      ],
    ),
  );
}

/// A refresh is running; the figures below are this account's earlier ones.
class _Updating extends StatelessWidget {
  const _Updating(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Semantics(liveRegion: true, child: _PageLine(text)),
  );
}

/// Names under a count: at most five, then "and N more".
class _Names extends StatelessWidget {
  const _Names({required this.names, required this.copy});

  static const int shown = 5;

  final List<String> names;
  final _PatternsCopy copy;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String name in names.take(shown))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(name, style: style),
            ),
          if (names.length > shown)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                copy.andMore(names.length - shown),
                style: style?.copyWith(
                  color: PlainPalette.of(context).secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

/// "Today", "Yesterday", "Tomorrow" or the date.
String _dayLabel(_PatternsCopy copy, DateTime day, DateTime now) {
  final DateTime today = _dayOf(now);
  final DateTime d = _dayOf(day);
  if (d == today) return copy.today;
  if (d == DateTime(today.year, today.month, today.day - 1)) {
    return copy.yesterday;
  }
  if (d == DateTime(today.year, today.month, today.day + 1)) {
    return copy.tomorrow;
  }
  return copy.date(d);
}

class _HabitsSection extends StatelessWidget {
  const _HabitsSection({required this.result, required this.copy});

  final PatternsResult result;
  final _PatternsCopy copy;

  @override
  Widget build(BuildContext context) {
    final List<HabitPattern> habits = result.habits.value;
    return PlainSection(
      key: const ValueKey<String>('patterns-habits'),
      title: copy.habits,
      description: habits.isEmpty ? null : copy.habitsDescription,
      children: <Widget>[
        if (!result.habits.evidence.enough || habits.isEmpty)
          PlainEmptyState(message: copy.noHabits)
        else
          PlainCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final HabitPattern habit in habits) _habitRow(habit),
                const ProvenanceLabel(ProvenanceKind.recorded),
              ],
            ),
          ),
      ],
    );
  }

  Widget _habitRow(HabitPattern habit) {
    final HabitConsistency c = habit.consistency;
    // Only the current period, still open: nothing has been judged yet.
    final bool tooNew = c.closedPeriodsSinceTracked == 0 && c.currentPeriodOpen;
    final List<String> notes = <String>[
      if (tooNew)
        copy.startedNow(c.cadence)
      else
        copy.streaks(c.cadence, c.currentStreak, c.longestStreak),
      if (c.currentPeriodSkipped) copy.skippedNow(c.cadence),
      if (!tooNew && c.currentPeriodOpen) copy.openNow(c.cadence),
    ];
    return PlainMetricRow(
      key: ValueKey<String>('patterns-habit-${habit.habitId}'),
      label: habit.title,
      value: tooNew
          ? copy.notEnoughHistory
          : copy.consistency(c.cadence, c.completed, c.windowPeriods),
      caption: notes.join('\n'),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.result, required this.copy});

  final PatternsResult result;
  final _PatternsCopy copy;

  @override
  Widget build(BuildContext context) {
    final PatternMetric<CompletionTrend> metric = result.trend;
    final CompletionTrend trend = metric.value;
    int most = 0;
    for (final TrendBucket b in trend.buckets) {
      final int total = b.tasksFinished + b.habitCheckIns;
      if (total > most) most = total;
    }
    return PlainSection(
      key: const ValueKey<String>('patterns-trend'),
      title: copy.trend,
      description: copy.trendDescription(trend.bucketDays, trend.coveredDays),
      children: <Widget>[
        if (!metric.evidence.enough)
          PlainEmptyState(message: copy.trendEmpty)
        else
          PlainCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PlainMetricRow(
                  label: copy.tasksFinished,
                  value: '${trend.tasksFinished}',
                ),
                PlainMetricRow(
                  label: copy.habitCheckIns,
                  value: '${trend.habitCheckIns}',
                ),
                const Divider(),
                for (int i = 0; i < trend.buckets.length; i++)
                  _TrendRow(
                    key: ValueKey<String>('patterns-trend-$i'),
                    label: trend.bucketDays == 1
                        ? _dayLabel(copy, trend.buckets[i].start, result.now)
                        : copy.span(
                            trend.buckets[i].start,
                            trend.buckets[i].end,
                          ),
                    value: copy.bucketValue(
                      trend.buckets[i].tasksFinished,
                      trend.buckets[i].habitCheckIns,
                    ),
                    share: most == 0
                        ? 0
                        : (trend.buckets[i].tasksFinished +
                                  trend.buckets[i].habitCheckIns) /
                              most,
                  ),
                const ProvenanceLabel(ProvenanceKind.recorded),
              ],
            ),
          ),
      ],
    );
  }
}

/// One stretch of days: the numbers as text, and a plain bar that screen
/// readers skip (the text says the same).
class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.label,
    required this.value,
    required this.share,
    super.key,
  });

  final String label;
  final String value;
  final double share;

  @override
  Widget build(BuildContext context) {
    final PlainPalette colors = PlainPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PlainMetricRow(label: label, value: value),
        ExcludeSemantics(
          child: Container(
            key: const ValueKey<String>('patterns-trend-track'),
            height: 6,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: colors.line,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: share.clamp(0.0, 1.0),
              // The track's alignment loosens the height; fill all of it.
              heightFactor: 1,
              child: DecoratedBox(
                key: const ValueKey<String>('patterns-trend-fill'),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WhenDoneSection extends StatelessWidget {
  const _WhenDoneSection({required this.result, required this.copy});

  final PatternsResult result;
  final _PatternsCopy copy;

  @override
  Widget build(BuildContext context) {
    final PatternMetric<WhenThingsGetDone> metric = result.whenDone;
    final WhenThingsGetDone when = metric.value;
    final int? weekday = when.weekday;
    final PartOfDay? part = when.partOfDay;
    return PlainSection(
      key: const ValueKey<String>('patterns-when-done'),
      title: copy.whenDone,
      // The look-back is the result's own window, not the selected range.
      description: copy.whenDoneDescription(when.windowDays, when.windowStart),
      children: <Widget>[
        if (!metric.evidence.enough)
          PlainEmptyState(
            message: copy.whenDoneNotEnough(
              metric.evidence.have,
              metric.evidence.need,
            ),
          )
        else
          PlainCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PlainMetricRow(
                  label: copy.finishedTasks,
                  value: '${when.finishedTasks}',
                ),
                PlainMetricRow(
                  label: copy.dayOfWeek,
                  value: weekday == null
                      ? copy.noDayStandsOut
                      : copy.weekdays(weekday),
                  caption: weekday == null
                      ? null
                      : copy.ofFinished(when.weekdayCount, when.finishedTasks),
                ),
                PlainMetricRow(
                  label: copy.partOfDay,
                  value: part == null
                      ? copy.noPartStandsOut
                      : copy.partName(part),
                  caption: part == null
                      ? null
                      : copy.ofFinishedBetween(
                          when.partOfDayCount,
                          when.finishedTasks,
                          part,
                        ),
                ),
                const ProvenanceLabel(ProvenanceKind.recorded),
              ],
            ),
          ),
      ],
    );
  }
}

class _WorkloadSection extends StatelessWidget {
  const _WorkloadSection({
    required this.result,
    required this.copy,
    required this.onOpenPlan,
  });

  final PatternsResult result;
  final _PatternsCopy copy;
  final void Function({required bool hasWork}) onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final List<WorkloadDay> days = result.workload.value;
    final UnplacedWork unplaced = result.unplaced.value;
    final bool planned = result.workload.evidence.enough;
    // An empty unplaced list is "not enough" even with tasks: nothing to show.
    final bool hasUnplaced =
        result.unplaced.evidence.enough && unplaced.taskCount > 0;
    final bool anyWithoutEstimate =
        unplaced.withoutEstimateCount > 0 ||
        days.any((WorkloadDay d) => d.hasTasksWithoutEstimate);
    return PlainSection(
      key: const ValueKey<String>('patterns-workload'),
      title: copy.workload,
      description: copy.workloadDescription(days.length),
      children: <Widget>[
        if (!planned && !hasUnplaced)
          PlainEmptyState(
            message: copy.workloadEmpty,
            actionLabel: copy.addSomething,
            onAction: () => onOpenPlan(hasWork: false),
          )
        else
          PlainCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < days.length; i++)
                  PlainMetricRow(
                    key: ValueKey<String>('patterns-workload-$i'),
                    label: _dayLabel(copy, days[i].day, result.now),
                    value: copy.minutes(days[i].plannedMinutes),
                    caption: days[i].taskCount == 0
                        ? null
                        : copy.dayTasks(
                            days[i].taskCount,
                            days[i].withoutEstimateCount,
                          ),
                  ),
                const Divider(),
                PlainMetricRow(
                  key: const ValueKey<String>('patterns-unplaced'),
                  label: copy.notOnADay,
                  value: hasUnplaced
                      ? copy.minutes(unplaced.plannedMinutes)
                      : copy.none,
                  caption: hasUnplaced
                      ? copy.unplacedCaption(
                          unplaced.taskCount,
                          unplaced.withoutEstimateCount,
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  copy.workloadFootnote(anyWithoutEstimate: anyWithoutEstimate),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PlainPalette.of(context).secondary,
                  ),
                ),
                const SizedBox(height: 4),
                const ProvenanceLabel(ProvenanceKind.plan),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => onOpenPlan(hasWork: true),
                    child: Text(copy.openMyPlan),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MissedSection extends StatelessWidget {
  const _MissedSection({required this.result, required this.copy});

  final PatternsResult result;
  final _PatternsCopy copy;

  @override
  Widget build(BuildContext context) {
    final MissedItems missed = result.missed;
    // Evidence here means "there were tasks (or habits) to look at": with
    // some, an empty list is a real zero.
    final bool anyTasks = missed.skippedTasks.evidence.enough;
    final bool anyHabits = missed.habitPeriods.evidence.enough;
    final Map<String, HabitCadence> cadences = <String, HabitCadence>{
      for (final HabitPattern h in result.habits.value)
        h.habitId: h.consistency.cadence,
    };
    final List<ActivityRecord> skipped = missed.skippedTasks.value;
    final List<TaskEntity> overdue = missed.overdueTasks.value;
    final List<HabitPeriodMiss> periods = missed.habitPeriods.value;
    return PlainSection(
      key: const ValueKey<String>('patterns-missed'),
      title: copy.missed,
      description: copy.missedDescription(result.rangeDays),
      children: <Widget>[
        if (!anyTasks && !anyHabits)
          PlainEmptyState(message: copy.missedEmpty)
        else
          PlainCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PlainMetricRow(
                  label: copy.tasksSkipped,
                  value: anyTasks ? '${skipped.length}' : copy.noTasksYet,
                ),
                _Names(
                  names: <String>[
                    for (final ActivityRecord r in skipped) r.title,
                  ],
                  copy: copy,
                ),
                PlainMetricRow(
                  label: copy.overdueNow,
                  value: anyTasks ? '${overdue.length}' : copy.noTasksYet,
                ),
                _Names(
                  names: <String>[for (final TaskEntity t in overdue) t.title],
                  copy: copy,
                ),
                PlainMetricRow(
                  label: copy.habitPeriodsMissed,
                  value: anyHabits ? '${periods.length}' : copy.noHabitsYet,
                ),
                _Names(
                  names: <String>[
                    for (final HabitPeriodMiss p in periods)
                      '${p.title} · '
                          '${copy.period(cadences[p.habitId] ?? HabitCadence.daily, p.start)} · '
                          '${copy.periodState(p.state)}',
                  ],
                  copy: copy,
                ),
                const ProvenanceLabel(ProvenanceKind.recorded),
              ],
            ),
          ),
      ],
    );
  }
}

class _LevelSection extends ConsumerWidget {
  const _LevelSection({required this.copy, required this.onShare});

  final _PatternsCopy copy;
  final Future<void> Function(_ProgressionShareAction action) onShare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProgressionState progression = ref.watch(progressionProvider);
    final progress = progression.progress;
    final MilestoneSummary milestones = ref.watch(milestoneSummaryProvider);
    return PlainSection(
      key: const ValueKey<String>('patterns-level'),
      title: copy.levelAndPoints,
      children: <Widget>[
        PlainCard(
          child: progression.loading
              ? const Center(child: CircularProgressIndicator())
              : progression.error != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(copy.progressUnavailable),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () =>
                          ref.read(profileProvider.notifier).retryLoad(),
                      child: Text(copy.retry),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PlainMetricRow(
                      label: copy.level,
                      value: '${progress.level}',
                      caption: journeyLabel(context, progress.levelTitle),
                    ),
                    PlainMetricRow(
                      label: copy.points,
                      value: '${progress.xp} XP',
                      caption: copy.pointsToNext(
                        progress.xpToNext,
                        progress.level + 1,
                      ),
                    ),
                    PlainMetricRow(
                      label: copy.streak,
                      value: copy.streakDays(progress.streak),
                      caption: journeyLabel(context, progress.streakMessage),
                    ),
                    PlainMetricRow(
                      label: copy.longestStreak,
                      value: copy.streakDays(progress.longestStreak),
                    ),
                    PlainMetricRow(
                      label: copy.milestonesReached,
                      value: milestones.total == 0
                          ? copy.noneYet
                          : copy.milestonesOf(
                              milestones.completed,
                              milestones.total,
                            ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _ShareMenu(copy: copy, onShare: onShare),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ShareMenu extends StatelessWidget {
  const _ShareMenu({required this.copy, required this.onShare});

  final _PatternsCopy copy;
  final Future<void> Function(_ProgressionShareAction action) onShare;

  @override
  Widget build(BuildContext context) {
    final PlainPalette colors = PlainPalette.of(context);
    return PopupMenuButton<_ProgressionShareAction>(
      key: const ValueKey<String>('patterns-share'),
      tooltip: copy.shareProgress,
      onSelected: onShare,
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<_ProgressionShareAction>>[
            PopupMenuItem<_ProgressionShareAction>(
              value: _ProgressionShareAction.progress,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.insights_rounded),
                  const SizedBox(width: 10),
                  Flexible(child: Text(copy.progressSnapshot)),
                ],
              ),
            ),
            PopupMenuItem<_ProgressionShareAction>(
              value: _ProgressionShareAction.achievement,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.emoji_events_outlined),
                  const SizedBox(width: 10),
                  Flexible(child: Text(copy.achievement)),
                ],
              ),
            ),
          ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.ios_share_rounded, color: colors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  copy.shareProgress,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
