import 'package:fantastic_guacamole/domain/entities/recurrence_rule.dart';
import 'package:fantastic_guacamole/features/creator/models/creator_workspace_mode.dart';
import 'package:fantastic_guacamole/features/creator/widgets/type_selector.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/system/audio/audio_service.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';

class DynamicForm extends StatefulWidget {
  const DynamicForm({
    super.key,
    required this.onSubmit,
    this.workspaceMode = CreatorWorkspaceMode.tasks,
    this.preferredType,
    this.taskTitleController,
    this.goalTitleController,
    this.memoryController,
    this.notesController,
    this.soundEnabled = true,
    this.advancedAudioEnabled = false,
  });

  final Future<void> Function(CreatorFormData data) onSubmit;
  final CreatorWorkspaceMode workspaceMode;
  final String? preferredType;
  final TextEditingController? taskTitleController;
  final TextEditingController? goalTitleController;
  final TextEditingController? memoryController;
  final TextEditingController? notesController;
  final bool soundEnabled;
  final bool advancedAudioEnabled;

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  late final TextEditingController _taskTitleController;
  late final TextEditingController _goalTitleController;
  late final TextEditingController _memoryController;
  late final TextEditingController _notesController;
  late final bool _ownsTaskTitleController;
  late final bool _ownsGoalTitleController;
  late final bool _ownsMemoryController;
  late final bool _ownsNotesController;
  String _selectedType = 'Task';
  int _priority = 3;
  DateTime? _scheduledFor;
  RecurrenceRule _recurrenceRule = RecurrenceRule.none;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ownsTaskTitleController = widget.taskTitleController == null;
    _ownsGoalTitleController = widget.goalTitleController == null;
    _ownsMemoryController = widget.memoryController == null;
    _ownsNotesController = widget.notesController == null;
    _taskTitleController =
        widget.taskTitleController ?? TextEditingController();
    _goalTitleController =
        widget.goalTitleController ?? TextEditingController();
    _memoryController = widget.memoryController ?? TextEditingController();
    _notesController = widget.notesController ?? TextEditingController();

    final String? preferred = widget.preferredType?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      _selectedType = preferred;
    }
  }

  @override
  void didUpdateWidget(covariant DynamicForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String? previous = oldWidget.preferredType?.trim().toLowerCase();
    final String? next = widget.preferredType?.trim();
    if (next == null || next.isEmpty) {
      return;
    }
    if (next.toLowerCase() == previous) {
      return;
    }
    if (_selectedType != next) {
      setState(() {
        _selectedType = next;
      });
    }
  }

  TextEditingController get _titleController {
    if (widget.workspaceMode == CreatorWorkspaceMode.goals) {
      return _goalTitleController;
    }
    return _taskTitleController;
  }

  TextEditingController get _detailController {
    if (_selectedType.trim().toLowerCase() == 'note') {
      return _memoryController;
    }
    return _notesController;
  }

  String get _entryType {
    if (widget.workspaceMode == CreatorWorkspaceMode.tasks) {
      return _selectedType;
    }

    return widget.workspaceMode.label;
  }

  String get _submitLabel {
    switch (widget.workspaceMode) {
      case CreatorWorkspaceMode.tasks:
        return 'Create item';
      case CreatorWorkspaceMode.goals:
        return 'Create goal';
      case CreatorWorkspaceMode.milestones:
        return 'Save milestone';
      case CreatorWorkspaceMode.plan:
        return 'Create plan item';
    }
  }

  @override
  void dispose() {
    if (_ownsTaskTitleController) {
      _taskTitleController.dispose();
    }
    if (_ownsGoalTitleController) {
      _goalTitleController.dispose();
    }
    if (_ownsMemoryController) {
      _memoryController.dispose();
    }
    if (_ownsNotesController) {
      _notesController.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AudioService.playError(
        widget.soundEnabled,
        advancedProfileEnabled: widget.advancedAudioEnabled,
      );
      setState(() => _errorMessage = 'Add a title before creating the entry.');
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
          description: _detailController.text.trim().isEmpty
              ? null
              : _detailController.text.trim(),
          type: _entryType,
          priority: _priority,
          scheduledFor: _scheduledFor,
          creatorMode: widget.workspaceMode.name,
          recurrenceRule: _recurrenceRule,
        ),
      );
      if (!mounted) return;
      _titleController.clear();
      _detailController.clear();
      setState(() {
        _priority = 3;
        _scheduledFor = null;
        _recurrenceRule = RecurrenceRule.none;
      });
    } catch (_) {
      if (!mounted) return;
      AudioService.playError(
        widget.soundEnabled,
        advancedProfileEnabled: widget.advancedAudioEnabled,
      );
      setState(() {
        _errorMessage =
            'The item could not be saved. Your entry is still here. Try again.';
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
          _sectionLabel('ITEM DETAILS', AppColors.memoryAmber),
          const SizedBox(height: 14),
          _buildTextField(_titleController, 'Item title *', maxLines: 1),
          const SizedBox(height: 10),
          _buildTextField(
            _detailController,
            _selectedType.toLowerCase() == 'note'
                ? 'Notes or details (optional)'
                : 'Description or details (optional)',
            maxLines: _selectedType.toLowerCase() == 'note' ? 5 : 3,
          ),
          const SizedBox(height: 20),
          RepaintBoundary(
            child: TypeSelector(
              selected: _selectedType,
              onSelect: (t) => setState(() {
                _selectedType = t;
                final String kind = t.trim().toLowerCase();
                if ((kind == 'routine' || kind == 'habit') &&
                    _recurrenceRule == RecurrenceRule.none) {
                  _recurrenceRule = RecurrenceRule.daily;
                }
              }),
            ),
          ),
          const SizedBox(height: 12),
          _QuickCheatSheet(selectedType: _selectedType),
          const SizedBox(height: 20),
          _PriorityPicker(
            value: _priority,
            onChanged: (v) => setState(() => _priority = v),
          ),
          const SizedBox(height: 20),
          _RecurrencePicker(
            selected: _recurrenceRule,
            onChanged: (value) => setState(() => _recurrenceRule = value),
          ),
          const SizedBox(height: 20),
          _ScheduleDatePicker(
            selected: _scheduledFor,
            onPick: (date) => setState(() => _scheduledFor = date),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.recallRed, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          SmartPressable(
            onTap: _submitting ? () {} : _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                      _submitLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.memoryAmber,
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
    int maxLines = 1,
  }) {
    return TextField(
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
            letterSpacing: 0.8,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _QuickCheatSheet extends StatelessWidget {
  const _QuickCheatSheet({required this.selectedType});

  final String selectedType;

  @override
  Widget build(BuildContext context) {
    final String normalized = selectedType.trim().toLowerCase();
    final String heading = normalized == 'habit'
        ? 'Daily rhythm = repeatable rhythm'
        : normalized == 'goal'
        ? 'Goal = bigger outcome'
        : normalized == 'note'
        ? 'Note = capture context'
        : 'Task = one next action';

    final String body = normalized == 'habit'
        ? 'Use daily rhythms for the small repeatable actions that shape your day.'
        : normalized == 'goal'
        ? 'Use goals when you want a longer outcome to work toward.'
        : normalized == 'note'
        ? 'Use notes for context, ideas, or reminders you want to keep nearby.'
        : 'Use tasks for concrete actions you can finish soon.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
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
                              color: AppColors.recallRed.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
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
  const _ScheduleDatePicker({required this.selected, required this.onPick});

  final DateTime? selected;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: () {
        showDatePicker(
          context: context,
          initialDate: selected ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) => Theme(
            data: ThemeData.dark(),
            child: child ?? const SizedBox.shrink(),
          ),
        ).then(onPick);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  ? 'Schedule for...'
                  : '${selected!.day}/${selected!.month}/${selected!.year}',
              style: TextStyle(
                fontSize: 13,
                color: selected == null ? Colors.white24 : Colors.white70,
              ),
            ),
            const Spacer(),
            if (selected != null)
              SmartPressable(
                onTap: () => onPick(null),
                child: const Icon(Icons.close, size: 14, color: Colors.white38),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
