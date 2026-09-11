import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/ui/widgets/dropdown_route_keyboard_guard.dart';
import 'package:flutter/material.dart';

class TaskEditDraft {
  const TaskEditDraft({
    required this.title,
    required this.estimatedDuration,
    required this.dueDate,
    required this.goalId,
  });

  final String title;
  final Duration? estimatedDuration;
  final DateTime? dueDate;
  final String? goalId;
}

/// Edits a draft only; the caller owns persistence and account-boundary checks.
Future<TaskEditDraft?> showTaskEditDialog({
  required BuildContext context,
  required TaskEntity editable,
  required List<GoalEntity> goals,
}) {
  String draftTitle = editable.title;
  String durationText = editable.estimatedDuration?.inMinutes.toString() ?? '';
  String? selectedGoalId =
      goals.any((GoalEntity goal) => goal.id == editable.goalId)
      ? editable.goalId
      : null;
  DateTime? dueDate = editable.dueDate;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  return showDialog<TaskEditDraft>(
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
                DropdownRouteKeyboardGuard(
                  child: DropdownButtonFormField<String?>(
                    key: const Key('timeline-task-goal-field'),
                    isExpanded: true,
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
                TaskEditDraft(
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
}
