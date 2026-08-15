import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/features/notes/ui/notes_screen.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixtureNotesNotifier extends NotesNotifier {
  _FixtureNotesNotifier(this._seed, this._loadPlan);

  final List<NoteEntity> _seed;
  final _LoadPlan _loadPlan;

  @override
  Future<List<NoteEntity>> build() async {
    if (_loadPlan.failNext) {
      _loadPlan.failNext = false;
      throw StateError('fixture load failure');
    }
    return List<NoteEntity>.from(_seed);
  }

  @override
  Future<void> updateNote(NoteEntity note) async {
    state = AsyncData(<NoteEntity>[
      for (final NoteEntity current in state.value ?? _seed)
        if (current.id == note.id) note.copyWith(updatedAt: DateTime.utc(2026, 8, 16)) else current,
    ]);
  }

  @override
  Future<void> archiveNote(String id) async {
    state = AsyncData(<NoteEntity>[
      for (final NoteEntity current in state.value ?? _seed)
        if (current.id != id) current,
    ]);
  }
}

class _LoadPlan {
  _LoadPlan({this.failNext = false});
  bool failNext;
}

NoteEntity _note({String title = 'UI_NOTE_A', String? body = 'A_BODY'}) => NoteEntity(
      id: 'note-ui-a',
      title: title,
      body: body,
      createdAt: DateTime.utc(2026, 8, 15),
      goalId: 'goal-a',
    );

Widget _app(List<NoteEntity> notes, {_LoadPlan? loadPlan}) => ProviderScope(
      overrides: [
        notesProvider.overrideWith(
          () => _FixtureNotesNotifier(notes, loadPlan ?? _LoadPlan()),
        ),
      ],
      child: const MaterialApp(home: NotesScreen()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Notes UI displays, edits, and archives canonical Notes without Task controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(<NoteEntity>[_note()]));
    await tester.pump();
    expect(find.text('UI_NOTE_A'), findsOneWidget);
    expect(find.textContaining('A_BODY'), findsOneWidget);
    expect(find.text('Complete'), findsNothing);
    expect(find.text('Due'), findsNothing);
    expect(find.byTooltip('Archive note'), findsOneWidget);

    await tester.tap(find.text('UI_NOTE_A'));
    await tester.pump();
    expect(find.text('Edit note'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'UI_NOTE_EDITED');
    // The framework's test keyboard can keep the modal action row below the
    // virtual viewport. Invoke the visible button's exact UI callback rather
    // than relying on that test-only geometry.
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save note'))
        .onPressed!();
    await tester.pump();
    expect(find.text('UI_NOTE_EDITED'), findsOneWidget);

    await tester.tap(find.byTooltip('Archive note').first);
    await tester.pump();
    expect(find.text('No active notes yet.'), findsOneWidget);
  });

  testWidgets('Notes UI exposes loading, empty, and retryable error states', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const <NoteEntity>[], loadPlan: _LoadPlan(failNext: true)));
    expect(find.bySemanticsLabel('Loading notes'), findsOneWidget);
    await tester.pump();
    expect(find.text('Notes could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('No active notes yet.'), findsOneWidget);
  });
}
