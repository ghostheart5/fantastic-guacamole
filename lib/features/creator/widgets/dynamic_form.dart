import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_navigation_intent_provider.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';

class DynamicForm extends StatefulWidget {
  const DynamicForm({
    super.key,
    required this.onSubmit,
    this.initialType = CreatorFormKind.task,
    this.activeGoals = const <GoalEntity>[],
    this.onTypeChanged,
    this.guidedFirstTask = false,
    this.onTitleValidityChanged,
    this.onPriorityChosen,
    this.onScheduleValidityChanged,
    this.tutorialController,
    this.onPickerVisibilityChanged,
    this.initialDraftId,
    this.initialTitle,
    this.initialDescription,
    this.submitLabel,
    this.clearAfterSubmit = true,
  });

  final Future<void> Function(CreatorFormData data) onSubmit;
  final CreatorFormKind initialType;
  final List<GoalEntity> activeGoals;
  final ValueChanged<CreatorFormKind>? onTypeChanged;
  final bool guidedFirstTask;
  final ValueChanged<bool>? onTitleValidityChanged;
  final VoidCallback? onPriorityChosen;
  final ValueChanged<bool>? onScheduleValidityChanged;
  final CreatorTutorialFormController? tutorialController;
  final ValueChanged<bool>? onPickerVisibilityChanged;
  final String? initialDraftId;
  final String? initialTitle;
  final String? initialDescription;
  final String? submitLabel;
  final bool clearAfterSubmit;

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  static const List<Duration> _estimates = <Duration>[
    Duration(minutes: 15),
    Duration(minutes: 25),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
    Duration(minutes: 90),
  ];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  int _priority = 3;
  DateTime? _scheduledFor;
  DateTime? _dueDate;
  DateTime? _targetDate;
  String? _goalId;
  Duration _estimatedDuration = const Duration(minutes: 30);
  HabitCadence _habitCadence = HabitCadence.daily;
  int _habitTargetCount = 1;
  bool _submitting = false;
  bool _replacingDraftText = false;
  String? _errorMessage;
  String? _appliedDraftId;
  late CreatorFormKind _type;
  late final Future<void> Function() _tutorialSubmitAction;

  String get _createActionLabel =>
      widget.submitLabel ?? 'CREATE ${_type.label.toUpperCase()}';

  @override
  void initState() {
    super.initState();
    _type = widget.guidedFirstTask ? CreatorFormKind.task : widget.initialType;
    _tutorialSubmitAction = _submit;
    widget.tutorialController?.attach(_tutorialSubmitAction);
    _titleController.addListener(_notifyTitleValidity);
    _applyDraftIfNeeded();
  }

  @override
  void didUpdateWidget(covariant DynamicForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final CreatorFormKind requestedType = widget.guidedFirstTask
        ? CreatorFormKind.task
        : widget.initialType;
    if (requestedType != _type) {
      _type = requestedType;
      _errorMessage = null;
    }
    if (oldWidget.initialDraftId != widget.initialDraftId) {
      if (oldWidget.initialDraftId != null && widget.initialDraftId == null) {
        _appliedDraftId = null;
        _replaceDraftText(title: '', description: '');
      } else {
        _applyDraftIfNeeded();
      }
    }
  }

  void _applyDraftIfNeeded() {
    final String? draftId = widget.initialDraftId;
    if (draftId == null || draftId == _appliedDraftId) return;
    _appliedDraftId = draftId;
    _replaceDraftText(
      title: widget.initialTitle?.trim() ?? '',
      description: widget.initialDescription?.trim() ?? '',
    );
  }

  void _replaceDraftText({required String title, required String description}) {
    _replacingDraftText = true;
    try {
      _titleController.text = title;
      _descriptionController.text = description;
    } finally {
      _replacingDraftText = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyTitleValidity();
    });
  }

  void _notifyTitleValidity() {
    if (_replacingDraftText) return;
    widget.onTitleValidityChanged?.call(
      _titleController.text.trim().isNotEmpty,
    );
  }

  @override
  void dispose() {
    widget.tutorialController?.detach(_tutorialSubmitAction);
    _titleController.removeListener(_notifyTitleValidity);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectType(CreatorFormKind type) {
    if (widget.guidedFirstTask || type == _type) return;
    setState(() {
      _type = type;
      _errorMessage = null;
    });
    widget.onTypeChanged?.call(type);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(
        () => _errorMessage =
            'Add a title before creating the ${_type.label.toLowerCase()}.',
      );
      return;
    }
    if (widget.guidedFirstTask && _scheduledFor == null) {
      setState(
        () => _errorMessage =
            'Choose a date and time so your first task can appear on Timeline.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final String description = _descriptionController.text.trim();
      await widget.onSubmit(
        CreatorFormData(
          title: title,
          description: description.isEmpty ? null : description,
          type: _type.label,
          priority: switch (_type) {
            CreatorFormKind.task => _priority,
            CreatorFormKind.goal => 4,
            CreatorFormKind.habit => 3,
            CreatorFormKind.note => 1,
          },
          scheduledFor: _type == CreatorFormKind.task ? _scheduledFor : null,
          recurrenceRule: _recurrenceForCadence,
          goalId: _type == CreatorFormKind.task ? _goalId : null,
          estimatedDuration: _type == CreatorFormKind.task
              ? _estimatedDuration
              : null,
          dueDate: _type == CreatorFormKind.task ? _dueDate : null,
          targetDate: _type == CreatorFormKind.goal ? _targetDate : null,
          habitCadence: _habitCadence,
          habitTargetCount: _habitTargetCount,
        ),
      );
      if (!mounted) return;
      if (widget.clearAfterSubmit) {
        _titleController.clear();
        _descriptionController.clear();
        setState(_resetFields);
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'The ${_type.label.toLowerCase()} could not be saved. '
            'Your entry is still here - retry.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  RecurrenceRule get _recurrenceForCadence {
    if (_type != CreatorFormKind.habit) return RecurrenceRule.none;
    return switch (_habitCadence) {
      HabitCadence.daily => RecurrenceRule.daily,
      HabitCadence.weekly => RecurrenceRule.weekly,
      HabitCadence.monthly => RecurrenceRule.none,
    };
  }

  void _resetFields() {
    _priority = 3;
    _scheduledFor = null;
    _dueDate = null;
    _targetDate = null;
    _goalId = null;
    _estimatedDuration = const Duration(minutes: 30);
    _habitCadence = HabitCadence.daily;
    _habitTargetCount = 1;
  }

  @override
  Widget build(BuildContext context) {
    return TemporalGlassSurface(
      padding: const EdgeInsets.all(16),
      accent: _accentFor(_type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _FieldLabel(text: 'CREATE', color: _accentFor(_type)),
          const SizedBox(height: 10),
          _CreatorTypePicker(
            selected: _type,
            enabled: !widget.guidedFirstTask,
            onChanged: _selectType,
          ),
          const SizedBox(height: 18),
          _FieldLabel(text: '${_type.label.toUpperCase()} DETAILS'),
          const SizedBox(height: 12),
          _buildTextField(
            _titleController,
            'Title *',
            key: widget.guidedFirstTask
                ? FirstRunTutorialTargets.creatorTitle
                : null,
            maxLines: 1,
          ),
          const SizedBox(height: 10),
          _buildTextField(
            _descriptionController,
            _type == CreatorFormKind.note
                ? 'Body (optional)'
                : 'Description (optional)',
            maxLines: _type == CreatorFormKind.note ? 6 : 3,
          ),
          if (_type == CreatorFormKind.task) ..._buildTaskFields(),
          if (_type == CreatorFormKind.goal) ..._buildGoalFields(),
          if (_type == CreatorFormKind.habit) ..._buildRhythmFields(),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              key: const Key('creator-form-error'),
              style: const TextStyle(color: AppColors.recallRed, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          KeyedSubtree(
            key: widget.guidedFirstTask
                ? FirstRunTutorialTargets.creatorSave
                : null,
            child: TemporalActionButton(
              label: _submitting ? 'WORKING...' : _createActionLabel,
              onPressed: _submitting ? null : _submit,
              icon: _submitting ? Icons.hourglass_top_rounded : _iconFor(_type),
              accent: _accentFor(_type),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTaskFields() => <Widget>[
    const SizedBox(height: 18),
    const _FieldLabel(text: 'ACTIVE GOAL'),
    const SizedBox(height: 8),
    _GoalLinkPicker(
      goals: widget.activeGoals,
      selectedGoalId: _goalId,
      onChanged: (String? value) => setState(() => _goalId = value),
    ),
    const SizedBox(height: 18),
    const _FieldLabel(text: 'ESTIMATED DURATION'),
    const SizedBox(height: 8),
    _EstimatePicker(
      estimates: _estimates,
      selected: _estimatedDuration,
      onChanged: (Duration value) {
        setState(() => _estimatedDuration = value);
      },
    ),
    const SizedBox(height: 18),
    KeyedSubtree(
      key: widget.guidedFirstTask
          ? FirstRunTutorialTargets.creatorPriority
          : null,
      child: _PriorityPicker(
        value: _priority,
        onChanged: (int value) {
          widget.onPriorityChosen?.call();
          setState(() => _priority = value);
        },
      ),
    ),
    const SizedBox(height: 18),
    KeyedSubtree(
      key: widget.guidedFirstTask
          ? FirstRunTutorialTargets.creatorSchedule
          : null,
      child: _DateField(
        label: 'SCHEDULE',
        emptyLabel: 'Schedule date and time...',
        selected: _scheduledFor,
        includeTime: true,
        accent: AppColors.neonCyan,
        onVisibilityChanged: widget.onPickerVisibilityChanged,
        onPick: (DateTime? date) {
          widget.onScheduleValidityChanged?.call(date != null);
          setState(() => _scheduledFor = date);
        },
      ),
    ),
    const SizedBox(height: 18),
    _DateField(
      label: 'DEADLINE',
      emptyLabel: 'Add deadline...',
      selected: _dueDate,
      includeTime: false,
      accent: AppColors.memoryAmber,
      onVisibilityChanged: widget.onPickerVisibilityChanged,
      onPick: (DateTime? date) => setState(() => _dueDate = date),
    ),
  ];

  List<Widget> _buildGoalFields() => <Widget>[
    const SizedBox(height: 18),
    _DateField(
      label: 'TARGET DATE',
      emptyLabel: 'Add target date...',
      selected: _targetDate,
      includeTime: false,
      accent: AppColors.neonViolet,
      onVisibilityChanged: widget.onPickerVisibilityChanged,
      onPick: (DateTime? date) => setState(() => _targetDate = date),
    ),
  ];

  List<Widget> _buildRhythmFields() => <Widget>[
    const SizedBox(height: 18),
    const _FieldLabel(text: 'CADENCE / RECURRENCE'),
    const SizedBox(height: 8),
    _CadencePicker(
      selected: _habitCadence,
      onChanged: (HabitCadence value) {
        setState(() => _habitCadence = value);
      },
    ),
    const SizedBox(height: 18),
    _TargetCountPicker(
      value: _habitTargetCount,
      cadence: _habitCadence,
      onChanged: (int value) => setState(() => _habitTargetCount = value),
    ),
  ];

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    Key? key,
    int maxLines = 1,
  }) {
    return TextField(
      key: key,
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
      decoration: _inputDecoration(hint, _accentFor(_type)),
    );
  }
}

class _CreatorTypePicker extends StatelessWidget {
  const _CreatorTypePicker({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final CreatorFormKind selected;
  final bool enabled;
  final ValueChanged<CreatorFormKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('creator-type-selector'),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accentFor(selected).withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CreatorFormKind>(
          value: selected,
          isExpanded: true,
          dropdownColor: AppColors.bgSecondary,
          iconEnabledColor: _accentFor(selected),
          onChanged: enabled
              ? (CreatorFormKind? value) {
                  if (value != null) onChanged(value);
                }
              : null,
          items: CreatorFormKind.values
              .map(
                (CreatorFormKind type) => DropdownMenuItem<CreatorFormKind>(
                  value: type,
                  child: Row(
                    children: <Widget>[
                      Icon(_iconFor(type), size: 18, color: _accentFor(type)),
                      const SizedBox(width: 10),
                      Text(
                        type.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _GoalLinkPicker extends StatelessWidget {
  const _GoalLinkPicker({
    required this.goals,
    required this.selectedGoalId,
    required this.onChanged,
  });

  final List<GoalEntity> goals;
  final String? selectedGoalId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<GoalEntity> active = goals
        .where((GoalEntity goal) => goal.isActive)
        .toList(growable: false);
    final String? selected =
        active.any((GoalEntity goal) => goal.id == selectedGoalId)
        ? selectedGoalId
        : null;
    return _DropdownShell(
      accent: AppColors.neonViolet,
      child: DropdownButton<String?>(
        key: const Key('creator-task-goal-link'),
        value: selected,
        isExpanded: true,
        dropdownColor: AppColors.bgSecondary,
        iconEnabledColor: AppColors.neonViolet,
        onChanged: onChanged,
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('No linked goal'),
          ),
          ...active.map(
            (GoalEntity goal) => DropdownMenuItem<String?>(
              value: goal.id,
              child: Text(goal.title, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstimatePicker extends StatelessWidget {
  const _EstimatePicker({
    required this.estimates,
    required this.selected,
    required this.onChanged,
  });

  final List<Duration> estimates;
  final Duration selected;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DropdownShell(
      accent: AppColors.neonCyan,
      child: DropdownButton<Duration>(
        key: const Key('creator-task-estimate'),
        value: selected,
        isExpanded: true,
        dropdownColor: AppColors.bgSecondary,
        iconEnabledColor: AppColors.neonCyan,
        onChanged: (Duration? value) {
          if (value != null) onChanged(value);
        },
        items: estimates
            .map(
              (Duration value) => DropdownMenuItem<Duration>(
                value: value,
                child: Text(_durationLabel(value)),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _DropdownShell extends StatelessWidget {
  const _DropdownShell({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const _FieldLabel(text: 'PRIORITY'),
            const Spacer(),
            Text(
              '$value / 5',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.neonCyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double trackWidth = constraints.maxWidth - 48;
              final double activeWidth = trackWidth * (value - 1) / 4;
              final double thumbLeft = 24 + activeWidth - 10;
              return Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  Positioned(
                    left: 24,
                    right: 24,
                    top: 22,
                    child: Container(height: 4, color: Colors.white24),
                  ),
                  Positioned(
                    left: 24,
                    top: 22,
                    child: Container(
                      width: activeWidth,
                      height: 4,
                      color: AppColors.neonCyan,
                    ),
                  ),
                  Positioned(
                    left: thumbLeft,
                    top: 14,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.neonCyan,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.neonCyan.withValues(alpha: 0.45),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: List<Widget>.generate(5, (int index) {
                        final int level = index + 1;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: value == level,
                            label: 'Set priority level $level',
                            onTap: () => onChanged(level),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onChanged(level),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('LOW', style: _rangeLabelStyle),
            Text('BALANCED', style: _rangeLabelStyle),
            Text('CRITICAL', style: _rangeLabelStyle),
          ],
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.emptyLabel,
    required this.selected,
    required this.includeTime,
    required this.accent,
    required this.onPick,
    this.onVisibilityChanged,
  });

  final String label;
  final String emptyLabel;
  final DateTime? selected;
  final bool includeTime;
  final Color accent;
  final ValueChanged<DateTime?> onPick;
  final ValueChanged<bool>? onVisibilityChanged;

  Future<void> _pick(BuildContext context) async {
    onVisibilityChanged?.call(true);
    try {
      final DateTime now = DateTime.now();
      final DateTime firstDate = DateTime(now.year, now.month, now.day);
      final DateTime? date = await showDatePicker(
        context: context,
        initialDate: selected == null || selected!.isBefore(firstDate)
            ? firstDate
            : selected!,
        firstDate: firstDate,
        lastDate: DateTime(now.year + 10, 12, 31),
        builder: (BuildContext context, Widget? child) => Theme(
          data: ThemeData.dark(),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (date == null || !context.mounted) return;
      if (!includeTime) {
        onPick(DateTime(date.year, date.month, date.day));
        return;
      }
      final DateTime suggested = selected ?? now.add(const Duration(hours: 1));
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(suggested),
        builder: (BuildContext context, Widget? child) => Theme(
          data: ThemeData.dark(),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (time == null) return;
      onPick(DateTime(date.year, date.month, date.day, time.hour, time.minute));
    } finally {
      onVisibilityChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _FieldLabel(text: label, color: accent),
        const SizedBox(height: 8),
        SmartPressable(
          onTap: () => _pick(context),
          semanticLabel: emptyLabel.replaceAll('...', ''),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.calendar_today_outlined, size: 16, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selected == null
                        ? emptyLabel
                        : _formatDate(context, selected!, includeTime),
                    style: TextStyle(
                      fontSize: 13,
                      color: selected == null
                          ? const Color(0xFFAEB9D0)
                          : Colors.white70,
                    ),
                  ),
                ),
                if (selected != null)
                  SmartPressable(
                    onTap: () => onPick(null),
                    semanticLabel: 'Clear ${label.toLowerCase()}',
                    child: const Padding(
                      padding: EdgeInsets.all(11),
                      child: Icon(Icons.close, size: 15, color: Colors.white54),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CadencePicker extends StatelessWidget {
  const _CadencePicker({required this.selected, required this.onChanged});

  final HabitCadence selected;
  final ValueChanged<HabitCadence> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<HabitCadence>(
      key: const Key('creator-rhythm-cadence'),
      segments: const <ButtonSegment<HabitCadence>>[
        ButtonSegment<HabitCadence>(
          value: HabitCadence.daily,
          label: Text('Daily'),
        ),
        ButtonSegment<HabitCadence>(
          value: HabitCadence.weekly,
          label: Text('Weekly'),
        ),
        ButtonSegment<HabitCadence>(
          value: HabitCadence.monthly,
          label: Text('Monthly'),
        ),
      ],
      selected: <HabitCadence>{selected},
      showSelectedIcon: false,
      onSelectionChanged: (Set<HabitCadence> value) => onChanged(value.single),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 48)),
        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? AppColors.memoryAmber
              : Colors.white70,
        ),
      ),
    );
  }
}

class _TargetCountPicker extends StatelessWidget {
  const _TargetCountPicker({
    required this.value,
    required this.cadence,
    required this.onChanged,
  });

  final int value;
  final HabitCadence cadence;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _FieldLabel(text: 'TARGET COUNT'),
              const SizedBox(height: 4),
              Text(
                '$value ${value == 1 ? 'time' : 'times'} per ${cadence.name}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          key: const Key('creator-rhythm-decrease'),
          tooltip: 'Decrease target count',
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          key: const Key('creator-rhythm-increase'),
          tooltip: 'Increase target count',
          onPressed: value < 365 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({this.text = '', this.color = AppColors.neonCyan});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 2,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hint, Color accent) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFFAEB9D0), fontSize: 14),
  filled: true,
  fillColor: Colors.white.withValues(alpha: 0.04),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: accent.withValues(alpha: 0.15)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: accent.withValues(alpha: 0.15)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: accent.withValues(alpha: 0.5)),
  ),
);

Color _accentFor(CreatorFormKind type) => switch (type) {
  CreatorFormKind.task => AppColors.neonCyan,
  CreatorFormKind.goal => AppColors.neonViolet,
  CreatorFormKind.habit => AppColors.memoryAmber,
  CreatorFormKind.note => const Color(0xFF79D9B2),
};

IconData _iconFor(CreatorFormKind type) => switch (type) {
  CreatorFormKind.task => Icons.add_task_rounded,
  CreatorFormKind.goal => Icons.flag_outlined,
  CreatorFormKind.habit => Icons.repeat_rounded,
  CreatorFormKind.note => Icons.sticky_note_2_outlined,
};

String _durationLabel(Duration duration) {
  final int minutes = duration.inMinutes;
  return minutes < 60
      ? '$minutes minutes'
      : '${minutes ~/ 60} hour${minutes == 60 ? '' : 's'} ${minutes % 60 == 0 ? '' : '${minutes % 60} min'}'
            .trim();
}

String _formatDate(BuildContext context, DateTime value, bool includeTime) {
  final String date = '${value.month}/${value.day}/${value.year}';
  if (!includeTime) return date;
  return '$date  ${TimeOfDay.fromDateTime(value).format(context)}';
}

const TextStyle _rangeLabelStyle = TextStyle(
  color: Colors.white54,
  fontSize: 10,
  letterSpacing: 0,
);
