import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/notes/ui/note_detail_screen.dart';
import 'package:fantastic_guacamole/features/tasks/widgets/task_edit_dialog.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _LibraryKind { tasks, notes, goals }

/// Searchable account library for records that are intentionally absent from
/// the date-bound Timeline, including completed tasks and archived notes.
class RecordLibraryScreen extends ConsumerStatefulWidget {
  const RecordLibraryScreen({super.key});

  @override
  ConsumerState<RecordLibraryScreen> createState() =>
      _RecordLibraryScreenState();
}

class _RecordLibraryScreenState extends ConsumerState<RecordLibraryScreen> {
  final TextEditingController _search = TextEditingController();
  _LibraryKind _kind = _LibraryKind.tasks;
  bool _taskBusy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      backgroundColor: const Color(0xFF030812),
      appBar: AppBar(
        title: Text(es ? 'Biblioteca' : 'Library'),
        backgroundColor: const Color(0xFF030812),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const Key('record-library-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: es ? 'Buscar registros' : 'Search records',
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<_LibraryKind>(
                segments: <ButtonSegment<_LibraryKind>>[
                  ButtonSegment(
                    value: _LibraryKind.tasks,
                    label: Text(es ? 'Tareas' : 'Tasks'),
                  ),
                  ButtonSegment(
                    value: _LibraryKind.notes,
                    label: Text(es ? 'Notas' : 'Notes'),
                  ),
                  ButtonSegment(
                    value: _LibraryKind.goals,
                    label: Text(es ? 'Metas' : 'Goals'),
                  ),
                ],
                selected: <_LibraryKind>{_kind},
                onSelectionChanged: (value) =>
                    setState(() => _kind = value.single),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(es)),
          ],
        ),
      ),
    );
  }

  Widget _body(bool es) => switch (_kind) {
    _LibraryKind.tasks => _tasks(es),
    _LibraryKind.notes => _notes(es),
    _LibraryKind.goals => _goals(es),
  };

  bool _matches(String title, [String? body]) {
    final query = _search.text.trim().toLowerCase();
    return query.isEmpty ||
        title.toLowerCase().contains(query) ||
        (body?.toLowerCase().contains(query) ?? false);
  }

  Widget _tasks(bool es) {
    final tasks = ref.watch(getTasksUseCaseProvider);
    final boundary = ref.watch(authSessionBoundaryProvider);
    final scope = ref.watch(accountStorageScopeProvider);
    final enabled =
        !_taskBusy &&
        scope.isWritable &&
        boundary.isStorageReady &&
        !boundary.isTransitioning &&
        boundary.blockingIssue == null;
    return FutureBuilder<List<TaskEntity>>(
      future: tasks.call(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _error(es, () => setState(() {}));
        final items =
            (snapshot.data ?? const <TaskEntity>[])
                .where((task) => _matches(task.title, task.description))
                .toList(growable: false)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return _list(
          items
              .map((task) {
                final status = task.isCompleted
                    ? (es ? 'Completada' : 'Completed')
                    : task.isCanceled
                    ? (es ? 'Cancelada' : 'Canceled')
                    : task.isSkipped
                    ? (es ? 'Omitida' : 'Skipped')
                    : (es ? 'Activa' : 'Active');
                final timing = task.scheduledFor ?? task.dueDate;
                final actionable =
                    !task.isCompleted && !task.isCanceled && !task.isSkipped;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      key: ValueKey('library-task-${task.id}'),
                      leading: Icon(
                        task.isCompleted
                            ? Icons.check_circle_outline
                            : Icons.task_alt_rounded,
                        color: AppColors.neonCyan,
                      ),
                      title: Text(task.title),
                      subtitle: Text(
                        '$status${timing == null ? '' : ' · ${MaterialLocalizations.of(context).formatMediumDate(timing.toLocal())}'}',
                      ),
                      onTap: !enabled || !actionable
                          ? null
                          : () => _manageTask(
                              task,
                              'edit',
                              es,
                              boundary,
                              scope.v2Namespace,
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final action in [
                            if (actionable) 'edit',
                            if (actionable) 'complete',
                            if (actionable) 'skip',
                            if (!task.isCanceled) 'delete',
                          ])
                            OutlinedButton(
                              key: ValueKey('library-task-${task.id}-$action'),
                              onPressed: !enabled
                                  ? null
                                  : () => _manageTask(
                                      task,
                                      action,
                                      es,
                                      boundary,
                                      scope.v2Namespace,
                                    ),
                              child: Text(switch (action) {
                                'edit' => es ? 'Editar' : 'Edit',
                                'complete' => es ? 'Completar' : 'Complete',
                                'skip' => es ? 'Omitir' : 'Skip',
                                _ => es ? 'Eliminar' : 'Delete',
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              })
              .toList(growable: false),
          es,
        );
      },
    );
  }

  Future<void> _manageTask(
    TaskEntity task,
    String action,
    bool es,
    AuthSessionBoundary boundary,
    String? namespace,
  ) async {
    if (_taskBusy) return;
    bool current() {
      if (!mounted) return false;
      final now = ref.read(authSessionBoundaryProvider);
      final scope = ref.read(accountStorageScopeProvider);
      return scope.isWritable &&
          scope.v2Namespace == namespace &&
          now.generation == boundary.generation &&
          now.userId == boundary.userId &&
          now.isStorageReady &&
          !now.isTransitioning &&
          now.blockingIssue == null;
    }

    if (!current()) return;
    setState(() => _taskBusy = true);
    try {
      final existing = await ref
          .read(domainTaskRepositoryProvider)
          .getTaskById(task.id);
      if (!mounted || !current()) return;
      if (existing == null) throw StateError('Task not found');
      final actions = ref.read(taskActionsProvider);
      if (action == 'edit') {
        final draft = await showTaskEditDialog(
          context: context,
          editable: existing,
          goals: ref.read(goalsProvider),
        );
        if (draft == null || !current()) return;
        await actions.updateTaskDetails(
          id: existing.id,
          title: draft.title,
          description: draft.description,
          clearDescription: draft.description == null,
          priority: draft.priority,
          estimatedDuration: draft.estimatedDuration,
          clearEstimatedDuration: draft.estimatedDuration == null,
          scheduledFor: draft.scheduledFor,
          clearScheduledFor: draft.scheduledFor == null,
          dueDate: draft.dueDate,
          clearDueDate: draft.dueDate == null,
          goalId: draft.goalId,
          clearGoalId: draft.goalId == null,
        );
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              es
                  ? '¿Quitar la tarea de la planificación?'
                  : 'Remove task from active planning?',
            ),
            content: Text(
              es
                  ? '«${existing.title}» se cancelará. Su registro cancelado permanecerá en la Biblioteca.'
                  : '"${existing.title}" will be canceled. A canceled record remains in Library.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(es ? 'Cancelar' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(es ? 'Quitar tarea' : 'Remove task'),
              ),
            ],
          ),
        );
        if (confirmed != true || !current()) return;
        await actions.deleteTask(existing.id);
      } else {
        if (existing.isCompleted || existing.isSkipped || existing.isCanceled) {
          return;
        }
        if (action == 'complete') {
          await actions.completeTask(existing.id);
        } else {
          await actions.skipTask(existing.id);
        }
      }
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            'edit' => es ? 'Tarea actualizada.' : 'Task updated.',
            'complete' => es ? 'Tarea completada.' : 'Task completed.',
            'skip' => es ? 'Tarea omitida.' : 'Task skipped.',
            _ =>
              es
                  ? 'Tarea cancelada. Su registro permanece en la Biblioteca.'
                  : 'Task canceled. Its record remains in Library.',
          }),
        ),
      );
    } catch (_) {
      if (!mounted || !current()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            es
                ? 'No se pudo cambiar la tarea. Inténtalo de nuevo.'
                : 'Task could not be changed. Try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _taskBusy = false);
    }
  }

  Widget _notes(bool es) {
    final read = ref.watch(notesProvider);
    if (read.isLoading) return const Center(child: CircularProgressIndicator());
    if (read.hasError) return _error(es, () => ref.invalidate(notesProvider));
    final items =
        (read.asData?.value ?? const <NoteEntity>[])
            .where((note) => _matches(note.title, note.body))
            .toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _list(
      items
          .map(
            (note) => ListTile(
              key: ValueKey('library-note-${note.id}'),
              leading: Icon(
                note.isArchived ? Icons.archive_outlined : Icons.note_outlined,
                color: AppColors.memoryAmber,
              ),
              title: Text(note.title),
              subtitle: Text(
                note.isArchived
                    ? (es ? 'Archivada' : 'Archived')
                    : (es ? 'Activa' : 'Active'),
              ),
              onTap: note.isArchived
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NoteDetailScreen(noteId: note.id),
                      ),
                    ),
              trailing: note.isArchived
                  ? TextButton(
                      onPressed: () =>
                          ref.read(notesProvider.notifier).restoreNote(note.id),
                      child: Text(es ? 'Restaurar' : 'Restore'),
                    )
                  : null,
            ),
          )
          .toList(growable: false),
      es,
    );
  }

  Widget _goals(bool es) {
    final read = ref.watch(goalsReadProvider);
    if (read.isLoading) return const Center(child: CircularProgressIndicator());
    if (read.hasError) {
      return _error(es, () => ref.invalidate(goalsReadProvider));
    }
    final items =
        (read.asData?.value ?? const <GoalEntity>[])
            .where((goal) => _matches(goal.title, goal.description))
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _list(
      items
          .map(
            (goal) => ListTile(
              key: ValueKey('library-goal-${goal.id}'),
              leading: Icon(
                goal.isCompleted
                    ? Icons.check_circle_outline
                    : Icons.track_changes_rounded,
                color: Color(goal.colorHex),
              ),
              title: Text(goal.title),
              subtitle: Text(
                goal.isCompleted
                    ? (es ? 'Completada' : 'Completed')
                    : (es ? 'Activa' : 'Active'),
              ),
              trailing: goal.isCompleted
                  ? TextButton(
                      onPressed: () =>
                          ref.read(goalsProvider.notifier).reopen(goal),
                      child: Text(es ? 'Reabrir' : 'Reopen'),
                    )
                  : null,
            ),
          )
          .toList(growable: false),
      es,
    );
  }

  Widget _list(List<Widget> children, bool es) {
    if (children.isEmpty) {
      return Center(
        child: Text(
          es ? 'No hay registros coincidentes.' : 'No matching records.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, index) => TemporalGlassSurface(
        padding: EdgeInsets.zero,
        child: children[index],
      ),
    );
  }

  Widget _error(bool es, VoidCallback retry) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          es
              ? 'No se pudieron leer los registros.'
              : 'Records could not be read.',
        ),
        TextButton(onPressed: retry, child: Text(es ? 'Reintentar' : 'Retry')),
      ],
    ),
  );
}
