import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';

class DynamicForm extends StatefulWidget {
  const DynamicForm({
    super.key,
    required this.onSubmit,
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
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _priority = 3;
  DateTime? _scheduledFor;
  RecurrenceRule _recurrenceRule = RecurrenceRule.none;
  bool _submitting = false;
  String? _errorMessage;
  String? _appliedDraftId;
  late final Future<void> Function() _tutorialSubmitAction;

  String get _createActionLabel => widget.submitLabel ?? 'CREATE TASK';

  @override
  void initState() {
    super.initState();
    _tutorialSubmitAction = _submit;
    widget.tutorialController?.attach(_tutorialSubmitAction);
    _titleController.addListener(_notifyTitleValidity);
    _applyDraftIfNeeded();
  }

  @override
  void didUpdateWidget(covariant DynamicForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDraftId != widget.initialDraftId) {
      if (oldWidget.initialDraftId != null && widget.initialDraftId == null) {
        _appliedDraftId = null;
        _titleController.clear();
        _descController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _notifyTitleValidity();
        });
      } else {
        _applyDraftIfNeeded();
      }
    }
  }

  void _applyDraftIfNeeded() {
    final String? draftId = widget.initialDraftId;
    if (draftId == null || draftId == _appliedDraftId) return;
    _appliedDraftId = draftId;
    _titleController.text = widget.initialTitle?.trim() ?? '';
    _descController.text = widget.initialDescription?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyTitleValidity();
    });
  }

  void _notifyTitleValidity() {
    widget.onTitleValidityChanged?.call(
      _titleController.text.trim().isNotEmpty,
    );
  }

  @override
  void dispose() {
    widget.tutorialController?.detach(_tutorialSubmitAction);
    _titleController.removeListener(_notifyTitleValidity);
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Add a title before creating the task.');
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
      await widget.onSubmit(
        CreatorFormData(
          title: title,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          type: 'Task',
          priority: _priority,
          scheduledFor: _scheduledFor,
          recurrenceRule: _recurrenceRule,
        ),
      );
      if (!mounted) return;
      if (widget.clearAfterSubmit) {
        _titleController.clear();
        _descController.clear();
        setState(() {
          _priority = 3;
          _scheduledFor = null;
          _recurrenceRule = RecurrenceRule.none;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'The task could not be saved. Your entry is still here—retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TemporalGlassSurface(
      padding: const EdgeInsets.all(16),
      accent: AppColors.neonCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ENTRY DETAILS', AppColors.neonCyan),
          const SizedBox(height: 14),
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
            _descController,
            'Description (optional)',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          KeyedSubtree(
            key: widget.guidedFirstTask
                ? FirstRunTutorialTargets.creatorPriority
                : null,
            child: _PriorityPicker(
              value: _priority,
              onChanged: (v) {
                widget.onPriorityChosen?.call();
                setState(() => _priority = v);
              },
            ),
          ),
          const SizedBox(height: 20),
          _RecurrencePicker(
            selected: _recurrenceRule,
            onChanged: (value) => setState(() => _recurrenceRule = value),
          ),
          const SizedBox(height: 20),
          KeyedSubtree(
            key: widget.guidedFirstTask
                ? FirstRunTutorialTargets.creatorSchedule
                : null,
            child: _ScheduleDatePicker(
              selected: _scheduledFor,
              onVisibilityChanged: widget.onPickerVisibilityChanged,
              onPick: (date) {
                widget.onScheduleValidityChanged?.call(true);
                setState(() => _scheduledFor = date);
              },
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
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
              icon: _submitting
                  ? Icons.hourglass_top_rounded
                  : Icons.add_task_rounded,
              accent: AppColors.neonCyan,
            ),
          ),
        ],
      ),
    );
  }

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
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAEB9D0), fontSize: 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Row(
      children: [
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

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 2,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.neonCyan,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'PRIORITY',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0,
                color: AppColors.neonCyan,
                fontWeight: FontWeight.w700,
              ),
            ),
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
            Text(
              'LOW',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                letterSpacing: 0,
              ),
            ),
            Text(
              'BALANCED',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                letterSpacing: 0,
              ),
            ),
            Text(
              'CRITICAL',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScheduleDatePicker extends StatelessWidget {
  const _ScheduleDatePicker({
    required this.selected,
    required this.onPick,
    this.onVisibilityChanged,
  });

  final DateTime? selected;
  final ValueChanged<DateTime?> onPick;
  final ValueChanged<bool>? onVisibilityChanged;

  Future<void> _pickDateAndTime(BuildContext context) async {
    onVisibilityChanged?.call(true);
    try {
      final DateTime now = DateTime.now();
      final DateTime? date = await showDatePicker(
        context: context,
        initialDate: selected ?? now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 365)),
        builder: (context, child) => Theme(
          data: ThemeData.dark(),
          child: child ?? const SizedBox.shrink(),
        ),
      );
      if (date == null || !context.mounted) return;

      final DateTime suggested = selected ?? now.add(const Duration(hours: 1));
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(suggested),
        builder: (context, child) => Theme(
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
    return SmartPressable(
      onTap: () => _pickDateAndTime(context),
      semanticLabel: 'Schedule date',
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.neonViolet.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: AppColors.neonViolet.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Text(
              selected == null
                  ? 'Schedule date and time...'
                  : '${selected!.day}/${selected!.month}/${selected!.year}  ${TimeOfDay.fromDateTime(selected!).format(context)}',
              style: TextStyle(
                fontSize: 13,
                color: selected == null
                    ? const Color(0xFFAEB9D0)
                    : Colors.white70,
              ),
            ),
            const Spacer(),
            if (selected != null)
              SmartPressable(
                onTap: () => onPick(null),
                semanticLabel: 'Clear schedule date',
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(Icons.close, size: 14, color: Colors.white38),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecurrencePicker extends StatelessWidget {
  const _RecurrencePicker({required this.selected, required this.onChanged});

  final RecurrenceRule selected;
  final ValueChanged<RecurrenceRule> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 2,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.neonCyan,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'REPEAT',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0,
                color: AppColors.neonCyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.neonViolet.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _RepeatChip(
                    label: 'One-time',
                    active: selected == RecurrenceRule.none,
                    showDivider: true,
                    onTap: () => onChanged(RecurrenceRule.none),
                  ),
                ),
                Expanded(
                  child: _RepeatChip(
                    label: 'Every day',
                    active: selected == RecurrenceRule.daily,
                    showDivider: true,
                    onTap: () => onChanged(RecurrenceRule.daily),
                  ),
                ),
                Expanded(
                  child: _RepeatChip(
                    label: 'Every week',
                    active: selected == RecurrenceRule.weekly,
                    onTap: () => onChanged(RecurrenceRule.weekly),
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

class _RepeatChip extends StatelessWidget {
  const _RepeatChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.showDivider = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: active
            ? AppColors.neonViolet.withValues(alpha: 0.16)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                right: showDivider
                    ? BorderSide(
                        color: AppColors.neonViolet.withValues(alpha: 0.24),
                      )
                    : BorderSide.none,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: active ? AppColors.neonViolet : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
