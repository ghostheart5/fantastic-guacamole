import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/features/creator/widgets/type_selector.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/tutorial/first_run_tutorial_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';

class DynamicForm extends StatefulWidget {
  const DynamicForm({
    super.key,
    required this.onSubmit,
    this.guidedFirstTask = false,
    this.onTitleValidityChanged,
    this.onTypeChosen,
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
  final VoidCallback? onTypeChosen;
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
  String _selectedType = 'Task';
  int _priority = 3;
  DateTime? _scheduledFor;
  RecurrenceRule _recurrenceRule = RecurrenceRule.none;
  bool _submitting = false;
  String? _errorMessage;
  String? _appliedDraftId;
  late final Future<void> Function() _tutorialSubmitAction;

  String get _selectedTypeNoun => _selectedType.trim().toLowerCase();

  String get _createActionLabel =>
      widget.submitLabel ?? 'CREATE ${_selectedType.toUpperCase()}';

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
      setState(
        () => _errorMessage =
            'Add a title before creating the $_selectedTypeNoun.',
      );
      return;
    }
    if (widget.guidedFirstTask && _scheduledFor == null) {
      setState(
        () => _errorMessage =
            'Choose a date and time so your first $_selectedTypeNoun can appear on Timeline.',
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
          type: _selectedType,
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
          _selectedType = 'Task';
          _priority = 3;
          _scheduledFor = null;
          _recurrenceRule = RecurrenceRule.none;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'The $_selectedTypeNoun could not be saved. Your entry is still here—retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.memoryAmber.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ENTRY DETAILS', AppColors.memoryAmber),
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
            _selectedType.toLowerCase() == 'note'
                ? 'Notes (optional)'
                : 'Description (optional)',
            maxLines: _selectedType.toLowerCase() == 'note' ? 5 : 3,
          ),
          const SizedBox(height: 20),
          KeyedSubtree(
            key: widget.guidedFirstTask
                ? FirstRunTutorialTargets.creatorType
                : null,
            child: TypeSelector(
              selected: _selectedType,
              onSelect: (t) {
                widget.onTypeChosen?.call();
                setState(() {
                  _selectedType = t;
                  final String kind = t.trim().toLowerCase();
                  if (kind == 'routine' &&
                      _recurrenceRule == RecurrenceRule.none) {
                    _recurrenceRule = RecurrenceRule.daily;
                  }
                });
              },
            ),
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
            child: SmartPressable(
              onTap: _submitting ? () {} : _submit,
              semanticLabel: _createActionLabel.toLowerCase(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.memoryAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.memoryAmber.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.memoryAmber.withValues(alpha: 0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: _submitting
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.memoryAmber,
                          ),
                        ),
                      )
                    : Text(
                        _createActionLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 2.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.memoryAmber,
                        ),
                      ),
              ),
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
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
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
            letterSpacing: 2.5,
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
                color: AppColors.recallRed,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'PRIORITY',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.5,
                color: AppColors.recallRed,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$value / 5',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.recallRed.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final level = i + 1;
            final isActive = level <= value;
            return Expanded(
              child: SmartPressable(
                onTap: () => onChanged(level),
                semanticLabel: 'Set priority level $level',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.recallRed.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.recallRed.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            );
          }),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
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
                color: selected == null ? Colors.white24 : Colors.white70,
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
                letterSpacing: 2.5,
                color: AppColors.neonCyan,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RepeatChip(
              label: 'One-time',
              active: selected == RecurrenceRule.none,
              onTap: () => onChanged(RecurrenceRule.none),
            ),
            _RepeatChip(
              label: 'Every day',
              active: selected == RecurrenceRule.daily,
              onTap: () => onChanged(RecurrenceRule.daily),
            ),
            _RepeatChip(
              label: 'Every week',
              active: selected == RecurrenceRule.weekly,
              onTap: () => onChanged(RecurrenceRule.weekly),
            ),
          ],
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
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.neonCyan.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppColors.neonCyan.withValues(alpha: 0.6)
                : AppColors.neonCyan.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.neonCyan : Colors.white70,
          ),
        ),
      ),
    );
  }
}
