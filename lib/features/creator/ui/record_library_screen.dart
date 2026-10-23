import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/features/creator/ui/daily_rhythms_screen.dart';
import 'package:fantastic_guacamole/ui/navigation/open_schedule.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/features/creator/ui/open_creator.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
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

enum _LibraryKind { tasks, notes, goals, completed }

/// Searchable account library for records that are intentionally absent from
/// the date-bound Timeline, including completed tasks and archived notes.
class RecordLibraryScreen extends ConsumerStatefulWidget {
  const RecordLibraryScreen({
    super.key,
    this.asPlan = false,
    this.initialKind = CreatorFormKind.task,
  });

  final bool asPlan;
  final CreatorFormKind initialKind;

  @override
  ConsumerState<RecordLibraryScreen> createState() =>
      _RecordLibraryScreenState();
}

class _RecordLibraryScreenState extends ConsumerState<RecordLibraryScreen> {
  final TextEditingController _search = TextEditingController();
  _LibraryKind _kind = _LibraryKind.tasks;
  bool _taskBusy = false;

  // These controls sit on the fixed dark artwork/glass surfaces, while form
  // fields and popup menus continue to use the selected app theme.
  ButtonStyle get _surfaceButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: const Color(0xFF10203F),
    disabledForegroundColor: Colors.white38,
    side: const BorderSide(color: Colors.white54),
  );

  @override
  void initState() {
    super.initState();
    _kind = switch (widget.initialKind) {
      CreatorFormKind.goal => _LibraryKind.goals,
      CreatorFormKind.note => _LibraryKind.notes,
      _ => _LibraryKind.tasks,
    };
  }

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
        automaticallyImplyLeading: !widget.asPlan,
        title: Text(
          widget.asPlan
              ? (es ? 'Mi plan' : 'My plan')
              : (es ? 'Guardado' : 'Saved'),
        ),
        backgroundColor: const Color(0xFF030812),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: Colors.white),
        actions: [
          if (widget.asPlan)
            IconButton(
              tooltip: es ? 'Todos los elementos guardados' : 'All saved items',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const RecordLibraryScreen()),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                children: <Widget>[
                  if (widget.asPlan)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: _surfaceButtonStyle,
                            onPressed: () =>
                                goToAppView(context, ref, AppView.goals),
                            icon: const Icon(Icons.flag_outlined),
                            label: Text(es ? 'Metas' : 'Goals'),
                          ),
                          OutlinedButton.icon(
                            style: _surfaceButtonStyle,
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => const DailyRhythmsScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.repeat_rounded),
                            label: Text(es ? 'Hábitos' : 'Habits'),
                          ),
                          OutlinedButton.icon(
                            style: _surfaceButtonStyle,
                            onPressed: () => openSchedule(context),
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(es ? 'Agenda' : 'Schedule'),
                          ),
                          FilledButton.icon(
                            onPressed: () => openCreatorForItem(
                              context,
                              ref,
                              CreatorFormKind.task,
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(es ? 'Añadir tarea' : 'Add task'),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      style: const TextStyle(color: Colors.white70),
                      widget.asPlan
                          ? (es
                                ? 'Tus tareas, incluidas las que no tienen fecha. Abre una para editarla.'
                                : 'Your tasks, including those without a date. Open one to edit it.')
                          : es
                          ? 'Busca una tarea, nota o meta guardada. Abre un elemento para revisarlo.'
                          : 'Find a saved task, note, or goal. Open an item to review it.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      key: const Key('record-library-search'),
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: es
                            ? 'Buscar elementos guardados'
                            : 'Search saved items',
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<_LibraryKind>(
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? const Color(0xFF030812)
                              : Colors.white,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.neonCyan
                              : const Color(0xFF10203F),
                        ),
                        side: const WidgetStatePropertyAll(
                          BorderSide(color: Colors.white54),
                        ),
                      ),
                      segments: <ButtonSegment<_LibraryKind>>[
                        ButtonSegment(
                          value: _LibraryKind.tasks,
                          label: Text(es ? 'Tareas' : 'Tasks'),
                        ),
                        if (widget.asPlan)
                          ButtonSegment(
                            value: _LibraryKind.completed,
                            label: Text(es ? 'Completadas' : 'Completed'),
                          ),
                        ButtonSegment(
                          value: _LibraryKind.notes,
                          label: Text(es ? 'Notas' : 'Notes'),
                        ),
                        if (!widget.asPlan)
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
                ],
              ),
            ),
          ],
          body: _body(es),
        ),
      ),
    );
  }

  Widget _body(bool es) => switch (_kind) {
    _LibraryKind.tasks => _tasks(es),
    _LibraryKind.completed => _tasks(es),
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
        final visibleItems = widget.asPlan
            ? items
                  .where(
                    (task) => _kind == _LibraryKind.completed
                        ? task.isCompleted
                        : task.isActive,
                  )
                  .toList()
            : items;
        return _list(
          visibleItems
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
                      textColor: Colors.white,
                      iconColor: Colors.white70,
                      titleTextStyle: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      subtitleTextStyle: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      key: ValueKey('library-task-${task.id}'),
                      leading: widget.asPlan && actionable
                          ? IconButton(
                              color: Colors.white70,
                              tooltip: es ? 'Completar tarea' : 'Complete task',
                              onPressed: !enabled
                                  ? null
                                  : () => _manageTask(
                                      task,
                                      'complete',
                                      es,
                                      boundary,
                                      scope.v2Namespace,
                                    ),
                              icon: const Icon(
                                Icons.radio_button_unchecked_rounded,
                              ),
                            )
                          : Icon(
                              task.isCompleted
                                  ? Icons.check_circle_outline
                                  : Icons.task_alt_rounded,
                              color: AppColors.neonCyan,
                            ),
                      title: Text(task.title),
                      subtitle: Text(
                        '$status${timing == null ? '' : ' · ${MaterialLocalizations.of(context).formatMediumDate(timing.toLocal())}'}',
                      ),
                      trailing: widget.asPlan
                          ? PopupMenuButton<String>(
                              iconColor: Colors.white70,
                              tooltip: es ? 'Más opciones' : 'More options',
                              enabled: enabled,
                              onSelected: (action) => _manageTask(
                                task,
                                action,
                                es,
                                boundary,
                                scope.v2Namespace,
                              ),
                              itemBuilder: (_) => [
                                if (actionable)
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(es ? 'Editar' : 'Edit'),
                                  ),
                                if (actionable)
                                  PopupMenuItem(
                                    value: 'skip',
                                    child: Text(es ? 'Omitir' : 'Skip'),
                                  ),
                                if (!task.isCanceled)
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(es ? 'Eliminar' : 'Delete'),
                                  ),
                              ],
                            )
                          : null,
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
                    if (!widget.asPlan)
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
                                style: _surfaceButtonStyle,
                                key: ValueKey(
                                  'library-task-${task.id}-$action',
                                ),
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
                  ? '«${existing.title}» se cancelará. Podrás encontrarla en Guardado.'
                  : '"${existing.title}" will be canceled. You can still find it in Saved.',
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
              textColor: Colors.white,
              iconColor: Colors.white70,
              titleTextStyle: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
              subtitleTextStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
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
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.neonCyan,
                        backgroundColor: const Color(0xFF10203F),
                      ),
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
              textColor: Colors.white,
              iconColor: Colors.white70,
              titleTextStyle: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
              subtitleTextStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
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
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.neonCyan,
                        backgroundColor: const Color(0xFF10203F),
                      ),
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
          style: const TextStyle(color: Colors.white70),
          widget.asPlan && _search.text.trim().isEmpty
              ? (_kind == _LibraryKind.completed
                    ? (es
                          ? 'Aquí aparecerán las tareas que completes.'
                          : 'Tasks you complete will appear here.')
                    : _kind == _LibraryKind.tasks
                    ? (es
                          ? 'No hay tareas pendientes. Añade una cuando quieras.'
                          : 'No open tasks. Add one whenever you’re ready.')
                    : (es
                          ? 'Tus notas aparecerán aquí.'
                          : 'Your notes will appear here.'))
              : es
              ? 'No hay registros coincidentes.'
              : 'No matching records.',
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
          style: const TextStyle(color: Colors.white70),
          es
              ? 'No se pudieron leer los registros.'
              : 'Records could not be read.',
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.neonCyan,
            backgroundColor: const Color(0xFF10203F),
          ),
          onPressed: retry,
          child: Text(es ? 'Reintentar' : 'Retry'),
        ),
      ],
    ),
  );
}
