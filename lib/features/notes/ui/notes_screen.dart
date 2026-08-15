import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A presentation-only surface. Note reads and commands stay in NotesNotifier.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<NoteEntity>> notes = ref.watch(notesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: notes.when(
        loading: () => Center(child: Semantics(label: 'Loading notes', child: const CircularProgressIndicator())),
        error: (Object _, StackTrace _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const Text('Notes could not be loaded.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.invalidate(notesProvider), child: const Text('Retry')),
          ]),
        ),
        data: (List<NoteEntity> values) => values.isEmpty
            ? Center(child: Semantics(label: 'No active notes', child: const Text('No active notes yet.')))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) => _NoteTile(note: values[index]),
              ),
      ),
    );
  }
}

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.note});
  final NoteEntity note;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    label: 'Note ${note.title}',
    button: true,
    child: Card(
      child: ListTile(
        title: Text(note.title),
        subtitle: Text(
          '${note.body?.trim().isEmpty ?? true ? 'No content' : note.body}\nUpdated ${MaterialLocalizations.of(context).formatShortDate(note.updatedAt)}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _NoteDetail(note: note),
        ),
        trailing: IconButton(
          tooltip: 'Archive note',
          icon: const Icon(Icons.archive_outlined),
          onPressed: () => ref.read(notesProvider.notifier).archiveNote(note.id),
        ),
      ),
    ),
  );
}

class _NoteDetail extends ConsumerStatefulWidget {
  const _NoteDetail({required this.note});
  final NoteEntity note;

  @override
  ConsumerState<_NoteDetail> createState() => _NoteDetailState();
}

class _NoteDetailState extends ConsumerState<_NoteDetail> {
  late final TextEditingController _title = TextEditingController(text: widget.note.title);
  late final TextEditingController _body = TextEditingController(text: widget.note.body ?? '');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Edit note', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _body, maxLines: 6, decoration: const InputDecoration(labelText: 'Content')),
          const SizedBox(height: 8),
          Text('Created ${MaterialLocalizations.of(context).formatShortDate(widget.note.createdAt)}'),
          Text('Updated ${MaterialLocalizations.of(context).formatShortDate(widget.note.updatedAt)}'),
          if (widget.note.goalId != null || widget.note.taskId != null || widget.note.habitId != null)
            const Padding(padding: EdgeInsets.only(top: 8), child: Text('Linked context is available for this note.')),
          const SizedBox(height: 16),
          Row(children: <Widget>[
            Expanded(child: FilledButton(
              onPressed: () async {
                await ref.read(notesProvider.notifier).updateNote(widget.note.copyWith(title: _title.text.trim(), body: _body.text));
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Save note'),
            )),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Archive note',
              icon: const Icon(Icons.archive_outlined),
              onPressed: () async {
                await ref.read(notesProvider.notifier).archiveNote(widget.note.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ]),
        ],
      )),
    ),
  );
}
