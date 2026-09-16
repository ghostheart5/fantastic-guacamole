import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/features/notes/ui/note_detail_screen.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'opens exact saved content and removes it when account data changes',
    (tester) async {
      final container = ProviderContainer(
        overrides: [notesProvider.overrideWith(_Notes.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: NoteDetailScreen(noteId: 'saved-note'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Demo reflection'), findsOneWidget);
      expect(find.text('Review what made the plan useful.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('REVIEW CHANGES'), findsNothing);
      final notes = container.read(notesProvider.notifier) as _Notes;
      notes.clearAccount();
      await tester.pump();
      expect(find.text('Demo reflection'), findsNothing);
      expect(
        find.text('This note is no longer available in this account.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _Notes extends NotesNotifier {
  @override
  Future<List<NoteEntity>> build() async => [
    NoteEntity(
      id: 'saved-note',
      title: 'Demo reflection',
      body: 'Review what made the plan useful.',
      createdAt: DateTime.utc(2026, 9, 8),
    ),
  ];
  void clearAccount() => state = const AsyncData([]);
}
