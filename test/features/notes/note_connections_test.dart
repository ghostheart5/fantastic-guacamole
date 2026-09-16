import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'dart:async';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/note_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_goal_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_note_repository.dart';
import 'package:fantastic_guacamole/features/notes/ui/note_detail_screen.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fantastic_guacamole/data/adapters/note_timeline_adapter.dart';
import '../../helpers/fake_task_repository.dart';

void main() {
  late ProviderContainer container;
  late _Notes repository;
  late AccountStorageScope scope;
  final now = DateTime.utc(2026, 9, 8);
  setUp(() {
    repository = _Notes([
      NoteEntity(
        id: 'note',
        title: 'Planning constraint',
        body: 'I only have 15 minutes',
        createdAt: now,
      ),
    ]);
    scope = AccountStorageScope.authenticated('owner-a');
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((ref) => scope),
        domainNoteRepositoryProvider.overrideWithValue(repository),
        domainGoalRepositoryProvider.overrideWithValue(
          _Goals([
            GoalEntity(id: 'goal', title: 'Finish album', createdAt: now),
          ]),
        ),
        domainTaskRepositoryProvider.overrideWithValue(
          FakeTaskRepository([
            TaskEntity(
              id: 'task',
              title: 'Mix song',
              createdAt: now,
              goalId: 'goal',
            ),
          ]),
        ),
        domainHabitRepositoryProvider.overrideWithValue(_Habits()),
        noteTimelineAdapterProvider.overrideWithValue(_Projection()),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'note links survive edit and require an existing matching commitment',
    () async {
      final note = (await container.read(notesProvider.future)).single;
      await container
          .read(notesProvider.notifier)
          .updateNote(note.copyWith(goalId: 'goal', taskId: 'task'));
      expect(repository.items.single.goalId, 'goal');
      expect(repository.items.single.taskId, 'task');
      final current = repository.items.single;
      await expectLater(
        container
            .read(notesProvider.notifier)
            .updateNote(current.copyWith(taskId: 'missing')),
        throwsStateError,
      );
      expect(repository.items.single.taskId, 'task');
      await container
          .read(notesProvider.notifier)
          .updateNote(current.copyWith(clearGoalId: true, clearTaskId: true));
      expect(repository.items.single.goalId, isNull);
      expect(repository.items.single.taskId, isNull);
    },
  );

  test(
    'selection is explicit, reads current edits and disappears on archive or account change',
    () async {
      expect(await container.read(selectedPlanningNoteProvider.future), isNull);
      container.read(planningNoteSelectionProvider.notifier).select('note');
      expect(
        (await container.read(selectedPlanningNoteProvider.future))?.id,
        'note',
      );
      final note = (await container.read(notesProvider.future)).single;
      await container
          .read(notesProvider.notifier)
          .updateNote(note.copyWith(body: 'I only have 10 minutes'));
      expect(
        (await container.read(selectedPlanningNoteProvider.future))?.body,
        contains('10 minutes'),
      );
      await container.read(notesProvider.notifier).archiveNote('note');
      expect(await container.read(selectedPlanningNoteProvider.future), isNull);
      scope = AccountStorageScope.authenticated('owner-b');
      container.invalidate(accountStorageScopeProvider);
      expect(container.read(planningNoteSelectionProvider), isNull);
      expect(await container.read(selectedPlanningNoteProvider.future), isNull);
    },
  );

  test(
    'an edit waiting on storage cannot cross an account generation',
    () async {
      final note = (await container.read(notesProvider.future)).single;
      final gate = Completer<void>();
      repository.readGate = gate.future;
      final update = container
          .read(notesProvider.notifier)
          .updateNote(note.copyWith(title: 'Stale edit'));
      container
          .read(authSessionBoundaryProvider.notifier)
          .begin(userId: 'owner-a', isTransitioning: true);
      gate.complete();
      await update;
      expect(repository.items.single.title, 'Planning constraint');
    },
  );

  for (final es in [false, true]) {
    testWidgets(
      '${es ? 'Spanish' : 'English'} note edit and explicit planning consent controls',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(es ? 'es' : 'en'),
              supportedLocales: const [Locale('en'), Locale('es')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: const NoteDetailScreen(noteId: 'note'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(es ? 'Editar y vincular' : 'Edit and link'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('note-edit-title')),
          'Updated constraint',
        );
        await tester.tap(find.text(es ? 'Guardar' : 'Save'));
        await tester.pumpAndSettle();
        expect(find.text('Updated constraint'), findsOneWidget);
        expect(repository.items, hasLength(1));
        await tester.tap(
          find.text(es ? 'Usar en la planificación' : 'Use in planning'),
        );
        await tester.pumpAndSettle();
        expect(container.read(planningNoteSelectionProvider), isNull);
        await tester.tap(find.text(es ? 'Cancelar' : 'Cancel'));
        await tester.pumpAndSettle();
        expect(container.read(planningNoteSelectionProvider), isNull);
        await tester.tap(
          find.text(es ? 'Usar en la planificación' : 'Use in planning'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(es ? 'Usar esta nota' : 'Use this note'));
        await tester.pumpAndSettle();
        expect(container.read(planningNoteSelectionProvider), 'note');
        container.read(planningNoteSelectionProvider.notifier).clear();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Projection implements NoteTimelineAdapter {
  @override
  Future<void> record(NoteEntity note, NoteTimelineMutation mutation) async {}
}

class _Notes implements INoteRepository {
  _Notes(this.items);
  List<NoteEntity> items;
  Future<void>? readGate;
  @override
  Future<List<NoteEntity>> getNotes() async {
    await readGate;
    return List.of(items);
  }

  @override
  Future<void> saveNote(NoteEntity note) async {
    items = [note, ...items.where((n) => n.id != note.id)];
  }

  @override
  Future<void> deleteNote(String id) async {
    items.removeWhere((n) => n.id == id);
  }
}

class _Goals implements IGoalRepository {
  _Goals(this.items);
  final List<GoalEntity> items;
  @override
  List<GoalEntity> getGoals() => List.of(items);
  @override
  Future<void> saveGoal(GoalEntity goal) async {}
  @override
  Future<void> saveGoals(List<GoalEntity> goals) async {}
  @override
  Future<void> deleteGoal(String id) async {}
}

class _Habits implements IHabitRepository {
  @override
  Future<List<HabitEntity>> getHabits() async => [];
  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {}
}
