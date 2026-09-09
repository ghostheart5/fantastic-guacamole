import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_read_health.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/widgets/text_controller_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoteActions extends ConsumerStatefulWidget {
  const NoteActions({required this.note, super.key});
  final NoteEntity note;
  @override
  ConsumerState<NoteActions> createState() => _NoteActionsState();
}

class _NoteActionsState extends ConsumerState<NoteActions> {
  bool busy = false;
  bool get es => Localizations.localeOf(context).languageCode == 'es';
  (String?, int) get currentOwner => (
    ref.read(accountStorageScopeProvider).v2Namespace,
    ref.read(authSessionBoundaryProvider).generation,
  );
  bool sameOwner((String?, int) owner) =>
      mounted &&
      owner.$1 != null &&
      ref.read(accountStorageScopeProvider).isWritable &&
      currentOwner == owner;
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> edit() async {
    final owner = currentOwner;
    if (!sameOwner(owner)) return;
    setState(() => busy = true);
    try {
      final goals = readAvailableGoals(ref.read(domainGoalRepositoryProvider));
      final taskRepository = ref.read(domainTaskRepositoryProvider);
      final habitRepository = ref.read(domainHabitRepositoryProvider);
      final tasks = await taskRepository.getAllTasks();
      final habits = await habitRepository.getHabits();
      if (!mounted || !sameOwner(owner)) return;
      final note = widget.note;
      String? goal = goals.any((g) => g.id == note.goalId) ? note.goalId : null;
      String? task = tasks.any((t) => t.id == note.taskId) ? note.taskId : null;
      String? habit = habits.any((h) => h.id == note.habitId)
          ? note.habitId
          : null;
      final result = await showDialog<NoteEntity>(
        context: context,
        builder: (_) => TextControllerScope(
          initialTexts: [note.title, note.body ?? ''],
          builder: (context, controllers) => StatefulBuilder(
            builder: (context, update) {
              Widget links(
                String label,
                String? value,
                List<(String, String)> items,
                void Function(String?) select,
              ) => DropdownButtonFormField<String>(
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(es ? 'Sin vínculo' : 'No link'),
                  ),
                  for (final item in items)
                    DropdownMenuItem(
                      value: item.$1,
                      child: Text(item.$2, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => update(() => select(value)),
              );
              return AlertDialog(
                title: Text(
                  es ? 'Editar nota y vínculos' : 'Edit note and links',
                ),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          key: const Key('note-edit-title'),
                          controller: controllers[0],
                          decoration: InputDecoration(
                            labelText: es ? 'Título' : 'Title',
                          ),
                          onChanged: (_) => update(() {}),
                        ),
                        TextField(
                          key: const Key('note-edit-body'),
                          controller: controllers[1],
                          minLines: 3,
                          maxLines: 6,
                          decoration: InputDecoration(
                            labelText: es ? 'Contenido' : 'Contents',
                          ),
                        ),
                        links(es ? 'Meta' : 'Goal', goal, [
                          for (final g in goals) (g.id, g.title),
                        ], (value) => goal = value),
                        links(es ? 'Tarea' : 'Task', task, [
                          for (final t in tasks) (t.id, t.title),
                        ], (value) => task = value),
                        links(
                          es ? 'Ritmo diario' : 'Daily Rhythm',
                          habit,
                          [for (final h in habits) (h.id, h.title)],
                          (value) => habit = value,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(es ? 'Cancelar' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: controllers[0].text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(
                            context,
                            note.copyWith(
                              title: controllers[0].text.trim(),
                              body: controllers[1].text.trim(),
                              goalId: goal,
                              taskId: task,
                              habitId: habit,
                              clearGoalId: goal == null,
                              clearTaskId: task == null,
                              clearHabitId: habit == null,
                            ),
                          ),
                    child: Text(es ? 'Guardar' : 'Save'),
                  ),
                ],
              );
            },
          ),
        ),
      );
      if (result != null && sameOwner(owner)) {
        await ref.read(notesProvider.notifier).updateNote(result);
      }
    } catch (_) {
      if (sameOwner(owner)) {
        message(
          es
              ? 'No se pudo guardar. Revisa los vínculos y vuelve a abrir la nota.'
              : 'Could not save. Check the links and reopen the note.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> useInPlanning() async {
    final owner = currentOwner;
    if (!sameOwner(owner)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          es
              ? '¿Usar esta nota en la planificación?'
              : 'Use this note in planning?',
        ),
        content: Text(
          es
              ? 'Compartir solo esta nota con el Planificador Inteligente local durante dos horas. Puedes quitarla en el planificador. Esta selección no la envía a IA externa ni se infiere tu emoción.'
              : 'Share only this note with the local Smart Planner for two hours. You can remove it in the planner. This selection does not send it to external AI, and your emotion is not inferred.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(es ? 'Cancelar' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(es ? 'Usar esta nota' : 'Use this note'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted && sameOwner(owner)) {
      ref.read(planningNoteSelectionProvider.notifier).select(widget.note.id);
      goToAppView(context, ref, AppView.smartPlanner);
    }
  }

  Future<void> archive() async {
    final owner = currentOwner;
    if (!sameOwner(owner)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(es ? '¿Archivar esta nota?' : 'Archive this note?'),
        content: Text(
          es
              ? 'Se conservará guardada, pero dejará de aparecer en las notas activas y en la planificación.'
              : 'It stays stored, but will leave active notes and planning context.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(es ? 'Cancelar' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(es ? 'Archivar' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !sameOwner(owner)) return;
    setState(() => busy = true);
    try {
      await ref.read(notesProvider.notifier).archiveNote(widget.note.id);
    } catch (_) {
      if (sameOwner(owner)) {
        message(
          es
              ? 'No se pudo archivar. Reintenta.'
              : 'Could not archive. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      TextButton(
        onPressed: busy ? null : edit,
        child: Text(es ? 'Editar y vincular' : 'Edit and link'),
      ),
      FilledButton(
        onPressed: busy ? null : useInPlanning,
        child: Text(es ? 'Usar en la planificación' : 'Use in planning'),
      ),
      TextButton(
        onPressed: busy ? null : archive,
        child: Text(es ? 'Archivar' : 'Archive'),
      ),
    ],
  );
}
