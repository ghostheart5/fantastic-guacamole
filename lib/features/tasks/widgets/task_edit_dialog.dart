import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/ui/widgets/dropdown_route_keyboard_guard.dart';
import 'package:flutter/material.dart';

class TaskEditDraft {
  const TaskEditDraft({
    required this.title,
    required this.description,
    required this.priority,
    required this.estimatedDuration,
    required this.scheduledFor,
    required this.dueDate,
    required this.goalId,
  });

  final String title;
  final String? description;
  final int priority;
  final Duration? estimatedDuration;
  final DateTime? scheduledFor;
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
  String descriptionText = editable.description ?? '';
  int priority = editable.priority;
  String durationText = editable.estimatedDuration?.inMinutes.toString() ?? '';
  String? selectedGoalId =
      goals.any((GoalEntity goal) => goal.id == editable.goalId)
      ? editable.goalId
      : null;
  DateTime? dueDate = editable.dueDate;
  DateTime? scheduledFor = editable.scheduledFor;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  return showDialog<TaskEditDraft>(
    context: context,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
        title: Text(journeyText(context, 'Edit task', 'Editar tarea')),
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
                  decoration: InputDecoration(
                    labelText: journeyText(
                      context,
                      'Task title',
                      'Título de la tarea',
                    ),
                  ),
                  validator: (String? value) =>
                      value == null || value.trim().isEmpty
                      ? journeyText(
                          context,
                          'Enter a task title.',
                          'Escribe un título para la tarea.',
                        )
                      : null,
                  onChanged: (String value) => draftTitle = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('timeline-task-description-field'),
                  initialValue: descriptionText,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: journeyText(
                      context,
                      'Description',
                      'Descripción',
                    ),
                  ),
                  onChanged: (String value) => descriptionText = value,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: const Key('timeline-task-priority-field'),
                  initialValue: priority,
                  decoration: InputDecoration(
                    labelText: journeyText(context, 'Priority', 'Prioridad'),
                  ),
                  items: <int>[1, 2, 3, 4, 5]
                      .map(
                        (value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            '$value · ${value == 1
                                ? journeyText(context, 'lowest', 'mínima')
                                : value == 5
                                ? journeyText(context, 'highest', 'máxima')
                                : journeyText(context, 'normal', 'normal')}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (int? value) {
                    if (value != null) setDialogState(() => priority = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownRouteKeyboardGuard(
                  child: DropdownButtonFormField<String?>(
                    key: const Key('timeline-task-goal-field'),
                    isExpanded: true,
                    initialValue: selectedGoalId,
                    decoration: InputDecoration(
                      labelText: journeyText(context, 'Goal', 'Meta'),
                    ),
                    items: <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(
                        child: Text(
                          journeyText(
                            context,
                            'No linked goal',
                            'Sin meta vinculada',
                          ),
                        ),
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
                  decoration: InputDecoration(
                    labelText: journeyText(
                      context,
                      'Estimated minutes',
                      'Minutos estimados',
                    ),
                    hintText: journeyText(context, 'Optional', 'Opcional'),
                  ),
                  validator: (String? value) {
                    final String normalized = value?.trim() ?? '';
                    if (normalized.isEmpty) return null;
                    final int? minutes = int.tryParse(normalized);
                    return minutes == null || minutes < 1 || minutes > 1440
                        ? journeyText(
                            context,
                            'Use 1 to 1440 minutes.',
                            'Usa de 1 a 1440 minutos.',
                          )
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
                            ? journeyText(
                                context,
                                'No deadline',
                                'Sin fecha límite',
                              )
                            : journeyText(
                                context,
                                'Deadline ${dueDate!.month}/${dueDate!.day}/${dueDate!.year}',
                                'Fecha límite ${MaterialLocalizations.of(context).formatCompactDate(dueDate!)}',
                              ),
                      ),
                    ),
                    if (dueDate != null)
                      IconButton(
                        tooltip: journeyText(
                          context,
                          'Clear deadline',
                          'Quitar fecha límite',
                        ),
                        onPressed: () => setDialogState(() => dueDate = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      key: const Key('timeline-task-deadline-field'),
                      tooltip: journeyText(
                        context,
                        'Choose deadline',
                        'Elegir fecha límite',
                      ),
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        scheduledFor == null
                            ? journeyText(
                                context,
                                'No scheduled time',
                                'Sin horario programado',
                              )
                            : '${journeyText(context, 'Scheduled', 'Programada')}: ${MaterialLocalizations.of(context).formatMediumDate(scheduledFor!)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(scheduledFor!))}',
                      ),
                    ),
                    if (scheduledFor != null)
                      IconButton(
                        tooltip: journeyText(
                          context,
                          'Clear scheduled time',
                          'Quitar horario',
                        ),
                        onPressed: () =>
                            setDialogState(() => scheduledFor = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      key: const Key('timeline-task-schedule-field'),
                      tooltip: journeyText(
                        context,
                        'Choose scheduled time',
                        'Elegir horario',
                      ),
                      onPressed: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? day = await showDatePicker(
                          context: dialogContext,
                          initialDate: scheduledFor ?? now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (day == null || !dialogContext.mounted) return;
                        final TimeOfDay? time = await showTimePicker(
                          context: dialogContext,
                          initialTime: TimeOfDay.fromDateTime(
                            scheduledFor ?? now,
                          ),
                        );
                        if (time != null) {
                          setDialogState(
                            () => scheduledFor = DateTime(
                              day.year,
                              day.month,
                              day.day,
                              time.hour,
                              time.minute,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.schedule_rounded),
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
            child: Text(journeyText(context, 'Cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final String normalizedDuration = durationText.trim();
              Navigator.of(dialogContext).pop(
                TaskEditDraft(
                  title: draftTitle.trim(),
                  description: descriptionText.trim().isEmpty
                      ? null
                      : descriptionText.trim(),
                  priority: priority,
                  estimatedDuration: normalizedDuration.isEmpty
                      ? null
                      : Duration(minutes: int.parse(normalizedDuration)),
                  scheduledFor: scheduledFor,
                  dueDate: dueDate,
                  goalId: selectedGoalId,
                ),
              );
            },
            child: Text(journeyText(context, 'Save', 'Guardar')),
          ),
        ],
      ),
    ),
  );
}
