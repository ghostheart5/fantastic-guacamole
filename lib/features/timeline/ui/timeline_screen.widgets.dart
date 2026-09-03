part of 'timeline_screen.dart';

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({
    required this.event,
    required this.tutorialTarget,
    required this.emphasized,
    required this.isLast,
  });

  final TimelineEventEntity event;
  final bool tutorialTarget;
  final bool emphasized;
  final bool isLast;

  bool get _isTaskAdded =>
      event.title.trim().toLowerCase() == 'task added' &&
      RegExp(
        r'\s+added to trajectory\.?$',
        caseSensitive: false,
      ).hasMatch(event.detail);

  TimelineEventType get _visualType =>
      event.phase?.trim().toLowerCase() == 'task' || _isTaskAdded
      ? TimelineEventType.task
      : event.type;

  String get _visualLabel =>
      _visualType == TimelineEventType.task ? 'Task' : event.shortLabel;

  bool get _isScheduledTask =>
      event.type == TimelineEventType.task && event.dueAt != null;

  String get _timingLabel {
    final DateTime date = event.dueAt!;
    if (_isScheduledTask) {
      return 'SCHEDULED ${DateTimeFormats.dateShort(date)}';
    }
    return event.isOverdue
        ? 'OVERDUE SINCE ${DateTimeFormats.dateShort(date)}'
        : 'DUE ${DateTimeFormats.dateShort(date)}';
  }

  Color get _color {
    switch (_visualType) {
      case TimelineEventType.reflection:
        return AppColors.neonViolet;
      case TimelineEventType.levelUp:
        return AppColors.memoryAmber;
      case TimelineEventType.goalComplete:
        return const Color(0xFF4CAF50);
      case TimelineEventType.streak:
        return Colors.deepOrangeAccent;
      case TimelineEventType.task:
        return AppColors.neonCyan;
      case TimelineEventType.goal:
        return const Color(0xFF7AF7C4);
      case TimelineEventType.habit:
        return const Color(0xFFFFB86B);
      case TimelineEventType.project:
        return const Color(0xFFC2A1FF);
      case TimelineEventType.milestone:
        return const Color(0xFFFFD166);
      case TimelineEventType.deadline:
        return event.isOverdue ? AppColors.recallRed : const Color(0xFF59C8FF);
      case TimelineEventType.forecast:
        return const Color(0xFF8CA0FF);
      case TimelineEventType.snapshot:
        return Colors.white70;
      case TimelineEventType.risk:
        return AppColors.recallRed;
      case TimelineEventType.recommendation:
        return AppColors.neonCyan;
      case TimelineEventType.noteCreated:
      case TimelineEventType.noteUpdated:
      case TimelineEventType.noteArchived:
      case TimelineEventType.noteDeleted:
        return AppColors.memoryAmber;
    }
  }

  IconData get _icon {
    switch (_visualType) {
      case TimelineEventType.reflection:
        return Icons.edit_note_rounded;
      case TimelineEventType.levelUp:
        return Icons.bolt_rounded;
      case TimelineEventType.goalComplete:
        return Icons.flag_rounded;
      case TimelineEventType.streak:
        return Icons.local_fire_department_rounded;
      case TimelineEventType.task:
        return Icons.checklist_rounded;
      case TimelineEventType.goal:
        return Icons.flag_rounded;
      case TimelineEventType.habit:
        return Icons.repeat_rounded;
      case TimelineEventType.project:
        return Icons.account_tree_rounded;
      case TimelineEventType.milestone:
        return Icons.emoji_events_rounded;
      case TimelineEventType.deadline:
        return Icons.schedule_rounded;
      case TimelineEventType.forecast:
        return Icons.query_stats_rounded;
      case TimelineEventType.snapshot:
        return Icons.camera_alt_outlined;
      case TimelineEventType.risk:
        return Icons.warning_amber_rounded;
      case TimelineEventType.recommendation:
        return Icons.tips_and_updates_rounded;
      case TimelineEventType.noteCreated:
        return Icons.note_add_rounded;
      case TimelineEventType.noteUpdated:
        return Icons.edit_note_rounded;
      case TimelineEventType.noteArchived:
        return Icons.archive_rounded;
      case TimelineEventType.noteDeleted:
        return Icons.delete_outline_rounded;
    }
  }

  String get _displayTitle {
    if (!_isTaskAdded) return event.title;
    return event.detail.replaceFirst(
      RegExp(r'\s+added to trajectory\.?$', caseSensitive: false),
      '',
    );
  }

  String get _displayDetail =>
      _isTaskAdded ? 'Added to your trajectory' : event.detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: tutorialTarget ? FirstRunTutorialTargets.timelineEvidence : null,
      padding: const EdgeInsets.only(bottom: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 38,
              child: Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[
                  if (!isLast)
                    Positioned(
                      top: 32,
                      bottom: -6,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              _color.withValues(alpha: .42),
                              _color.withValues(alpha: .08),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF081325),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color.withValues(alpha: emphasized ? .9 : .5),
                        width: emphasized ? 2 : 1,
                      ),
                      boxShadow: emphasized
                          ? <BoxShadow>[
                              BoxShadow(
                                color: _color.withValues(alpha: .28),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(_icon, color: _color, size: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(emphasized ? 16 : 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: emphasized
                        ? <Color>[
                            _color.withValues(alpha: .18),
                            const Color(0xE6091428),
                          ]
                        : const <Color>[Color(0xE6081223), Color(0xD9050D1A)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _color.withValues(alpha: emphasized ? .48 : .2),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .24),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: .11),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _visualLabel.toUpperCase(),
                            style: TextStyle(
                              color: _color,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateTimeFormats.timelineTime(_eventMoment(event)),
                          style: const TextStyle(
                            color: Color(0xFF8B99B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      _displayTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: emphasized ? 17 : 14,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_displayDetail.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        _displayDetail,
                        style: const TextStyle(
                          color: Color(0xFFB4C0DA),
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: emphasized ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (event.dueAt != null) ...<Widget>[
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (event.isOverdue
                                      ? AppColors.recallRed
                                      : AppColors.neonCyan)
                                  .withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _timingLabel,
                          style: TextStyle(
                            color: event.isOverdue
                                ? AppColors.recallRed
                                : AppColors.neonCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                    _TimelineEventActions(event: event),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineEventActions extends ConsumerStatefulWidget {
  const _TimelineEventActions({required this.event});

  final TimelineEventEntity event;

  @override
  ConsumerState<_TimelineEventActions> createState() =>
      _TimelineEventActionsState();
}

class _TimelineEventActionsState extends ConsumerState<_TimelineEventActions> {
  bool _busy = false;
  String? _error;

  bool get _isProjectedTask =>
      widget.event.relatedId != null &&
      widget.event.id.startsWith('timeline-projected-task-');

  bool get _canComplete =>
      widget.event.status != TimelineEventStatus.completed &&
      widget.event.status != TimelineEventStatus.canceled &&
      (widget.event.type == TimelineEventType.task ||
          widget.event.type == TimelineEventType.deadline);

  bool get _canSkip =>
      widget.event.status != TimelineEventStatus.skipped &&
      widget.event.status != TimelineEventStatus.completed &&
      widget.event.status != TimelineEventStatus.canceled &&
      (widget.event.type == TimelineEventType.task ||
          widget.event.type == TimelineEventType.deadline);

  bool get _canMove =>
      !_isProjectedTask &&
      (widget.event.status == TimelineEventStatus.overdue ||
          widget.event.status == TimelineEventStatus.skipped);

  @override
  Widget build(BuildContext context) {
    if (!_canComplete && !_canSkip && !_canMove && !_isProjectedTask) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_canComplete)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(_complete),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Complete'),
              ),
            if (_canSkip)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(_skip),
                icon: const Icon(Icons.redo_rounded, size: 16),
                label: const Text('Skip'),
              ),
            if (_canMove)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(_moveTomorrow),
                icon: const Icon(Icons.event_repeat_rounded, size: 16),
                label: Text(
                  widget.event.status == TimelineEventStatus.skipped
                      ? 'Recover Tomorrow'
                      : 'Move Tomorrow',
                ),
              ),
            if (_isProjectedTask)
              OutlinedButton.icon(
                onPressed: _busy ? null : _editTask,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            if (_isProjectedTask)
              OutlinedButton.icon(
                onPressed: _busy ? null : _confirmDeleteTask,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.recallRed,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete'),
              ),
          ],
        ),
        if (_busy) ...[
          const SizedBox(height: 8),
          Semantics(
            label: 'Task action in progress',
            liveRegion: true,
            child: const LinearProgressIndicator(minHeight: 2),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Semantics(
            label: _error,
            liveRegion: true,
            excludeSemantics: true,
            child: Text(
              _error!,
              style: const TextStyle(
                color: AppColors.recallRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await ref
          .read(adaptiveGuidanceProvider.notifier)
          .record(GuidanceMilestone.firstTimelineReview);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Timeline action failed. Refresh and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _editTask() async {
    if (_busy) return;
    final String? taskId = widget.event.relatedId;
    if (taskId == null) return;
    TaskEntity? existing;
    final List<Task> visibleTasks =
        ref.read(tasksProvider).asData?.value ?? const <Task>[];
    for (final Task task in visibleTasks) {
      if (task.id == taskId) {
        existing = task;
        break;
      }
    }
    if (existing == null) {
      try {
        existing = await ref
            .read(domainTaskRepositoryProvider)
            .getTaskById(taskId);
      } on StateError {
        existing = null;
      }
    }
    if (existing == null || !mounted) {
      setState(() => _error = 'Task not found. Refresh and try again.');
      return;
    }
    final TaskEntity editable = existing;
    final List<GoalEntity> goals = ref.read(goalsProvider);
    String draftTitle = editable.title;
    String durationText =
        editable.estimatedDuration?.inMinutes.toString() ?? '';
    String? selectedGoalId =
        goals.any((GoalEntity goal) => goal.id == editable.goalId)
        ? editable.goalId
        : null;
    DateTime? dueDate = editable.dueDate;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final _TaskEditDraft? next = await showDialog<_TaskEditDraft>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Edit task'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    key: const Key('timeline-task-title-field'),
                    initialValue: draftTitle,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Task title'),
                    validator: (String? value) =>
                        value == null || value.trim().isEmpty
                        ? 'Enter a task title.'
                        : null,
                    onChanged: (String value) => draftTitle = value,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: const Key('timeline-task-goal-field'),
                    initialValue: selectedGoalId,
                    decoration: const InputDecoration(labelText: 'Goal'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        child: Text('No linked goal'),
                      ),
                      ...goals.map(
                        (GoalEntity goal) => DropdownMenuItem<String?>(
                          value: goal.id,
                          child: Text(
                            goal.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (String? value) =>
                        setDialogState(() => selectedGoalId = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('timeline-task-duration-field'),
                    initialValue: durationText,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated minutes',
                      hintText: 'Optional',
                    ),
                    validator: (String? value) {
                      final String normalized = value?.trim() ?? '';
                      if (normalized.isEmpty) return null;
                      final int? minutes = int.tryParse(normalized);
                      return minutes == null || minutes < 1 || minutes > 1440
                          ? 'Use 1 to 1440 minutes.'
                          : null;
                    },
                    onChanged: (String value) => durationText = value,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          dueDate == null
                              ? 'No deadline'
                              : 'Deadline ${dueDate!.month}/${dueDate!.day}/${dueDate!.year}',
                        ),
                      ),
                      if (dueDate != null)
                        IconButton(
                          tooltip: 'Clear deadline',
                          onPressed: () => setDialogState(() => dueDate = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      IconButton(
                        key: const Key('timeline-task-deadline-field'),
                        tooltip: 'Choose deadline',
                        onPressed: () async {
                          final DateTime now = DateTime.now();
                          final DateTime? selected = await showDatePicker(
                            context: dialogContext,
                            initialDate: dueDate ?? now,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 10),
                          );
                          if (selected != null) {
                            setDialogState(() => dueDate = selected);
                          }
                        },
                        icon: const Icon(Icons.event_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final String normalizedDuration = durationText.trim();
                Navigator.of(dialogContext).pop(
                  _TaskEditDraft(
                    title: draftTitle.trim(),
                    estimatedDuration: normalizedDuration.isEmpty
                        ? null
                        : Duration(minutes: int.parse(normalizedDuration)),
                    dueDate: dueDate,
                    goalId: selectedGoalId,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (next == null || !mounted) return;

    await _runManagementAction(
      action: () => ref
          .read(taskActionsProvider)
          .updateTaskDetails(
            id: taskId,
            title: next.title,
            estimatedDuration: next.estimatedDuration,
            clearEstimatedDuration: next.estimatedDuration == null,
            dueDate: next.dueDate,
            clearDueDate: next.dueDate == null,
            goalId: next.goalId,
            clearGoalId: next.goalId == null,
          ),
      successMessage: 'Task updated.',
      errorMessage: 'Task could not be updated. Refresh and try again.',
    );
  }

  Future<void> _confirmDeleteTask() async {
    if (_busy) return;
    final String? taskId = widget.event.relatedId;
    if (taskId == null) return;

    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete task?'),
            content: Text(
              '"${widget.event.title}" will be permanently deleted. '
              'This cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.recallRed,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete task'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    await _runManagementAction(
      action: () => ref.read(taskActionsProvider).deleteTask(taskId),
      successMessage: 'Task deleted.',
      errorMessage: 'Task could not be deleted. Refresh and try again.',
    );
  }

  Future<void> _runManagementAction({
    required Future<void> Function() action,
    required String successMessage,
    required String errorMessage,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _complete() {
    final String? taskId = widget.event.relatedId;
    if (_isProjectedTask && taskId != null) {
      return ref.read(taskActionsProvider).completeTask(taskId);
    }
    return ref.read(timelineActionsProvider).complete(widget.event.id);
  }

  Future<void> _skip() {
    final String? taskId = widget.event.relatedId;
    if (_isProjectedTask && taskId != null) {
      return ref.read(taskActionsProvider).skipTask(taskId);
    }
    return ref.read(timelineActionsProvider).skip(widget.event.id);
  }

  Future<void> _moveTomorrow() {
    final DateTime nextDue = DateTime.now().add(const Duration(days: 1));
    return ref.read(timelineActionsProvider).recover(widget.event.id, nextDue);
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({
    required this.eventCount,
    required this.window,
    required this.onBack,
  });

  final int eventCount;
  final _TimelineWindow window;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return TemporalScreenHeader(
      title: 'TIMELINE',
      subtitle: 'Your time, connected into one readable stream.',
      eyebrow: '${_windowLabel(window)} view',
      accent: AppColors.neonViolet,
      onBack: onBack,
      backTooltip: 'Back to Nexus',
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '$eventCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'EVENTS',
            style: TextStyle(
              color: Color(0xFF8B99B8),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineFocusCard extends StatelessWidget {
  const _TimelineFocusCard({
    required this.now,
    required this.dueTodayCount,
    required this.overdueCount,
    required this.upcomingCount,
    required this.milestoneCount,
    required this.riskCount,
    required this.nextDeadline,
  });

  final DateTime now;
  final int dueTodayCount;
  final int overdueCount;
  final int upcomingCount;
  final int milestoneCount;
  final int riskCount;
  final TimelineEventEntity? nextDeadline;

  @override
  Widget build(BuildContext context) {
    final bool needsAttention = overdueCount > 0 || riskCount > 0;
    final Color accent = needsAttention
        ? AppColors.recallRed
        : AppColors.neonCyan;
    final String headline = overdueCount > 0
        ? '$overdueCount overdue ${overdueCount == 1 ? 'item' : 'items'}'
        : dueTodayCount > 0
        ? '$dueTodayCount due today'
        : nextDeadline != null
        ? 'Next commitment is mapped'
        : 'Nothing needs action now';
    final String supporting = nextDeadline != null
        ? '${nextDeadline!.title} is due ${DateTimeFormats.dateShort(nextDeadline!.dueAt ?? nextDeadline!.timestamp)}.'
        : 'Your recent activity remains available in the chronology below.';

    return TemporalGlassSurface(
      accent: accent,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 62,
                height: 68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xA9081427),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: .42)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      '${now.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _monthShort(now.month),
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      needsAttention ? 'NEEDS ATTENTION' : 'CURRENT PRIORITY',
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      headline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      supporting,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFB8C4DE),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _TimelineMetric(
                  label: 'DUE TODAY',
                  value: '$dueTodayCount',
                  accent: AppColors.neonCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimelineMetric(
                  label: 'NEXT 7 DAYS',
                  value: '$upcomingCount',
                  accent: AppColors.neonViolet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimelineMetric(
                  label: overdueCount > 0 ? 'OVERDUE' : 'MILESTONES',
                  value: '${overdueCount > 0 ? overdueCount : milestoneCount}',
                  accent: overdueCount > 0
                      ? AppColors.recallRed
                      : AppColors.memoryAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineMetric extends StatelessWidget {
  const _TimelineMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: .2)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8E9BBA),
              fontSize: 7,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineControls extends StatelessWidget {
  const _TimelineControls({
    required this.window,
    required this.filter,
    required this.searchController,
    required this.expanded,
    required this.visibleCount,
    required this.onWindowChanged,
    required this.onFilterChanged,
    required this.onQueryChanged,
    required this.onToggleExpanded,
  });

  final _TimelineWindow window;
  final _TimelineFilter filter;
  final TextEditingController searchController;
  final bool expanded;
  final int visibleCount;
  final ValueChanged<_TimelineWindow> onWindowChanged;
  final ValueChanged<_TimelineFilter> onFilterChanged;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final bool isRefined =
        filter != _TimelineFilter.all ||
        searchController.text.trim().isNotEmpty;

    return TemporalGlassSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: _TimelineWindow.values
                .map(
                  (_TimelineWindow value) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: value == _TimelineWindow.all ? 0 : 5,
                      ),
                      child: _TimelineRangeButton(
                        label: _windowLabel(value),
                        selected: window == value,
                        onTap: () => onWindowChanged(value),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_motion_rounded,
                color: AppColors.neonViolet,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$visibleCount ${visibleCount == 1 ? 'event' : 'events'} shown',
                  style: const TextStyle(
                    color: Color(0xFFB8C4DE),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onToggleExpanded,
                icon: Icon(
                  expanded ? Icons.expand_less_rounded : Icons.tune_rounded,
                  size: 17,
                ),
                label: Text(isRefined ? 'Refined' : 'Find & filter'),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: searchController,
                    onChanged: onQueryChanged,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Find an event, task, goal, or note',
                      hintStyle: const TextStyle(color: Color(0xFF74809A)),
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: .18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<_TimelineFilter>(
                    initialValue: filter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Activity type',
                      prefixIcon: const Icon(Icons.filter_alt_outlined),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: .18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _TimelineFilter.values
                        .map(
                          (_TimelineFilter value) => DropdownMenuItem(
                            value: value,
                            child: Text(_filterLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (_TimelineFilter? value) {
                      if (value != null) onFilterChanged(value);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRangeButton extends StatelessWidget {
  const _TimelineRangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      semanticLabel: 'Show $label timeline',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonCyan.withValues(alpha: .18)
              : Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.neonCyan.withValues(alpha: .55)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: selected ? AppColors.neonCyan : const Color(0xFF8E9AB5),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TimelineDayHeader extends StatelessWidget {
  const _TimelineDayHeader({required this.label, required this.eventCount});

  final String label;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 0, 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.neonCyan,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: AppColors.neonCyan, blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                letterSpacing: 0,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$eventCount ${eventCount == 1 ? 'EVENT' : 'EVENTS'}',
            style: const TextStyle(
              color: Color(0xFF77839E),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEmptyState extends StatelessWidget {
  const _TimelineEmptyState({required this.isRefined, required this.onReset});

  final bool isRefined;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.neonViolet.withValues(alpha: .1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.neonViolet.withValues(alpha: .3),
                ),
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                color: AppColors.neonViolet,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRefined
                  ? 'No matching moments'
                  : 'No saved activity in this view',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              isRefined
                  ? 'Change the search or activity filter to reveal more of your chronology.'
                  : 'Saved tasks, goals, notes, and completed work will appear here when they exist in this time range.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF93A0BA),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (isRefined) ...<Widget>[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset search and filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineSourceState extends StatelessWidget {
  const _TimelineSourceState.loading()
    : title = 'Loading your Timeline',
      detail = 'Checking saved tasks before showing your chronology.',
      semanticsLabel = 'Loading saved Timeline activity.',
      retryLabel = null,
      retryKey = null,
      onRetry = null;

  const _TimelineSourceState.taskError({required this.onRetry})
    : title = 'Timeline tasks could not be loaded',
      detail = 'Nothing has been labeled empty. Retry the saved-task source.',
      semanticsLabel = 'Timeline tasks could not be loaded.',
      retryLabel = 'Retry loading tasks',
      retryKey = const Key('timeline-task-source-retry');

  const _TimelineSourceState.persistenceError({required this.onRetry})
    : title = 'Saved Timeline activity could not be read',
      detail =
          'Your stored data was not erased. Preserve the original before repairing the active Timeline.',
      semanticsLabel = 'Saved Timeline activity could not be read.',
      retryLabel = 'Preserve and repair Timeline',
      retryKey = const Key('timeline-persistence-retry');

  final String title;
  final String detail;
  final String semanticsLabel;
  final String? retryLabel;
  final Key? retryKey;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool failed = onRetry != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Semantics(
          liveRegion: true,
          label: semanticsLabel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (failed)
                const Icon(
                  Icons.sync_problem_rounded,
                  color: AppColors.recallRed,
                  size: 34,
                )
              else
                const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF93A0BA),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (failed) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: retryKey,
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(retryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineSourceNotice extends StatelessWidget {
  const _TimelineSourceNotice({required this.issue, required this.onRetry});

  final _TimelineSourceIssue issue;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, Color color, String text, String semantics})
    content = switch (issue) {
      _TimelineSourceIssue.persistence => (
        icon: Icons.inventory_2_outlined,
        color: AppColors.recallRed,
        text:
            'Some saved Timeline activity could not be read. Valid activity is shown; preserve the original before repairing it.',
        semantics:
            'Some saved Timeline activity could not be read. Valid activity is shown. Preserve the original before repairing it.',
      ),
      _TimelineSourceIssue.taskError => (
        icon: Icons.sync_problem_rounded,
        color: AppColors.recallRed,
        text:
            'Task projections are unavailable. Saved Timeline activity is still shown.',
        semantics:
            'Task projections are unavailable. Saved Timeline activity is still shown.',
      ),
      _TimelineSourceIssue.taskLoading => (
        icon: Icons.hourglass_top_rounded,
        color: AppColors.neonCyan,
        text:
            'Task projections are still loading. Saved Timeline activity is shown below.',
        semantics:
            'Task projections are still loading. Saved Timeline activity is shown below.',
      ),
    };
    return Semantics(
      liveRegion: true,
      label: content.semantics,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF08131F).withValues(alpha: 0.94),
          border: Border.all(color: content.color.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: <Widget>[
            Icon(content.icon, color: content.color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                content.text,
                style: const TextStyle(
                  color: Color(0xFFD8E1EF),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(width: 8),
              IconButton(
                key: Key(
                  issue == _TimelineSourceIssue.persistence
                      ? 'timeline-persistence-notice-retry'
                      : 'timeline-task-notice-retry',
                ),
                tooltip: issue == _TimelineSourceIssue.persistence
                    ? 'Preserve and repair Timeline source'
                    : 'Retry source',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

DateTime _eventMoment(TimelineEventEntity event) =>
    event.dueAt ?? event.timestamp;

bool _isOpenDeadline(TimelineEventEntity event) {
  final bool hasDeadlineSemantics = switch (event.type) {
    TimelineEventType.deadline ||
    TimelineEventType.goal ||
    TimelineEventType.milestone => true,
    _ => false,
  };
  return hasDeadlineSemantics &&
      event.status != TimelineEventStatus.completed &&
      event.status != TimelineEventStatus.canceled &&
      event.status != TimelineEventStatus.skipped;
}

bool _inWindow({
  required DateTime moment,
  required DateTime now,
  required _TimelineWindow window,
}) {
  switch (window) {
    case _TimelineWindow.today:
      return moment.year == now.year &&
          moment.month == now.month &&
          moment.day == now.day;
    case _TimelineWindow.week:
      final DateTime start = DateTime(now.year, now.month, now.day);
      final DateTime end = DateTime(start.year, start.month, start.day + 7);
      return !moment.isBefore(start) && moment.isBefore(end);
    case _TimelineWindow.month:
      return moment.year == now.year && moment.month == now.month;
    case _TimelineWindow.year:
      return moment.year == now.year;
    case _TimelineWindow.all:
      return true;
  }
}

String _windowLabel(_TimelineWindow value) {
  return switch (value) {
    _TimelineWindow.today => 'Today',
    _TimelineWindow.week => 'Week',
    _TimelineWindow.month => 'Month',
    _TimelineWindow.year => 'Year',
    _TimelineWindow.all => 'All',
  };
}

String _monthShort(int month) => const <String>[
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
][month - 1];

String _filterLabel(_TimelineFilter value) {
  return switch (value) {
    _TimelineFilter.all => 'All',
    _TimelineFilter.overdue => 'Overdue',
    _TimelineFilter.upcoming => 'Upcoming',
    _TimelineFilter.milestones => 'Milestones',
    _TimelineFilter.risks => 'Risks',
    _TimelineFilter.recommendations => 'Recommendations',
  };
}

TimelineEventEntity? _nearestUpcoming(
  List<TimelineEventEntity> events,
  DateTime now,
) {
  final List<TimelineEventEntity> candidates =
      events
          .where((TimelineEventEntity event) {
            final DateTime? due = event.dueAt;
            return due != null &&
                _isOpenDeadline(event) &&
                due.isAfter(now) &&
                !event.isOverdue;
          })
          .toList(growable: false)
        ..sort(
          (a, b) => (a.dueAt ?? a.timestamp).compareTo(b.dueAt ?? b.timestamp),
        );
  return candidates.isEmpty ? null : candidates.first;
}
