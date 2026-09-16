import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/notes/ui/note_detail_screen.dart';
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
                    : (es ? 'Activa' : 'Active');
                final timing = task.scheduledFor ?? task.dueDate;
                return ListTile(
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
                );
              })
              .toList(growable: false),
          es,
        );
      },
    );
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
