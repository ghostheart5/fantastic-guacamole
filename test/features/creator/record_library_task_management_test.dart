import 'dart:async';
import 'dart:io';

import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/repositories/task_occurrence_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/engine/learning/learning_state.dart';
import 'package:fantastic_guacamole/features/creator/ui/record_library_screen.dart';
import 'package:fantastic_guacamole/features/timeline/logic/timeline_projection.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/learning_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/notification_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/state/providers/task_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'unscheduled Library task is tappable and has lifecycle controls',
    (tester) async {
      final h = _Harness();
      await h.pump(tester);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('library-task-a')))
            .onTap,
        isNotNull,
      );
      expect(find.byKey(const ValueKey('library-task-a-skip')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('library-task-a-complete')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'two-row selection edit cancel preserves both canonical records',
    (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final before = h.snapshot();
      await tester.tap(find.byKey(const ValueKey('library-task-b')));
      await tester.pumpAndSettle();
      final title = find.byKey(const Key('timeline-task-title-field'));
      expect(tester.widget<TextFormField>(title).initialValue, 'Second task');
      await tester.enterText(title, 'Discard this draft');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.snapshot(), before);
    },
  );

  testWidgets(
    'Library editor saves exact selected task description and explicit schedule',
    (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final firstBefore = h.repo.records['a']!.toJson();
      await tester.tap(find.byKey(const ValueKey('library-task-b-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('timeline-task-title-field')),
        'Second updated',
      );
      await tester.enterText(
        find.byKey(const Key('timeline-task-description-field')),
        'Saved detail',
      );
      final pickSchedule = find.byTooltip('Choose scheduled time');
      await tester.ensureVisible(pickSchedule);
      await tester.tap(pickSchedule);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = h.repo.records['b']!;
      expect(saved.title, 'Second updated');
      expect(saved.description, 'Saved detail');
      expect(saved.scheduledFor, isNotNull);
      expect(saved.dueDate, isNull);
      expect(h.repo.records['a']!.toJson(), firstBefore);
      final projected = projectTimelineEvents(
        now: DateTime.now(),
        tasks: [
          for (final task in h.repo.records.values)
            Task(
              id: task.id,
              title: task.title,
              priority: task.priority,
              difficulty: task.difficulty,
              energyRequired: task.energyRequired,
              scheduledFor: task.scheduledFor,
              dueDate: task.dueDate,
            ),
        ],
        goals: [],
      );
      expect(projected.map((event) => event.relatedId), ['b']);
      expect(find.text('Second updated'), findsOneWidget);
    },
  );

  testWidgets('unscheduled Skip uses canonical outcome once and awards no XP', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    final unrelated = h.repo.records['b']!.toJson();
    final xp = h.container.read(profileProvider).xp;
    await tester.tap(find.byKey(const ValueKey('library-task-a-skip')));
    await tester.pumpAndSettle();
    expect(h.repo.records['a']!.isSkipped, isTrue);
    expect(h.repo.records['a']!.isCompleted, isFalse);
    expect(h.repo.records, hasLength(2));
    expect(h.repo.records['b']!.toJson(), unrelated);
    expect(
      h.ledger.records.values.single.terminalOutcome,
      TaskOccurrenceOutcome.skipped,
    );
    expect(h.container.read(profileProvider).xp, xp);
    expect(find.byKey(const ValueKey('library-task-a-skip')), findsNothing);
    expect(find.byKey(const ValueKey('library-task-a-complete')), findsNothing);
    expect(find.text('Skipped'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(h.ledger.records, hasLength(1));
  });

  testWidgets('delete requires confirmation and preserves unrelated task', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    final before = h.snapshot();
    await tester.tap(find.byKey(const ValueKey('library-task-b-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.snapshot(), before);
    await tester.tap(find.byKey(const ValueKey('library-task-b-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove task'));
    await tester.pumpAndSettle();
    expect(h.repo.records.keys, ['a', 'b']);
    expect(h.repo.records['b']!.isCanceled, isTrue);
    expect(h.repo.records['a']!.toJson(), before.first);
    expect(find.text('Second task'), findsOneWidget);
    expect(find.text('Canceled'), findsOneWidget);
  });

  testWidgets(
    'real repository retains canceled Library record with truthful removal and readonly controls',
    (tester) async {
      late Directory directory;
      late TaskRepository repository;
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'library_cancel_retention_',
        );
        Hive.init(directory.path);
        final storage = HiveStorage<String>(
          'library-task-retention',
          hive: _DirectHiveStore(),
        );
        await storage.open();
        repository = TaskRepository(
          storage: storage,
          scope: AccountStorageScope.authenticated('library-test'),
        );
        await repository.saveTask(
          TaskEntity(
            id: 'a',
            title: 'First task',
            createdAt: DateTime.utc(2026, 10, 14),
          ),
        );
        await repository.saveTask(
          TaskEntity(
            id: 'b',
            title: 'Second task',
            createdAt: DateTime.utc(2026, 10, 13),
          ),
        );
      });
      addTearDown(() async {
        await tester.runAsync(() async {
          try {
            await Hive.close().timeout(const Duration(seconds: 5));
          } finally {
            await directory
                .delete(recursive: true)
                .timeout(const Duration(seconds: 5));
          }
        });
      });
      final h = _Harness(canonicalRepository: repository);
      await h.pump(tester);
      final before = await tester.runAsync(repository.getAllTasks);
      final xp = h.container.read(profileProvider).xp;
      await tester.tap(find.byKey(const ValueKey('library-task-b-delete')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('You can still find it in Saved'),
        findsOneWidget,
      );
      expect(find.textContaining('permanently deleted'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          repository.getAllTasks,
        ))!.map((t) => t.toJson()).toList(),
        before!.map((t) => t.toJson()).toList(),
      );
      await tester.tap(find.byKey(const ValueKey('library-task-b-delete')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Remove task'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      final after = (await tester.runAsync(repository.getAllTasks))!;
      expect(after, hasLength(2));
      expect(
        after.singleWhere((t) => t.id == 'a').toJson(),
        before.singleWhere((t) => t.id == 'a').toJson(),
      );
      final canceled = after.singleWhere((t) => t.id == 'b');
      expect(canceled.isCanceled, isTrue);
      expect(canceled.updatedAt, isNotNull);
      expect(await tester.runAsync(() => repository.getTaskById('b')), isNull);
      // Flush real Hive I/O before advancing the ordinary widget frame.
      for (
        var attempt = 0;
        attempt < 10 && find.text('Canceled').evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(() async {
          await repository.getAllTasks();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pump();
      }
      expect(find.text('Second task'), findsOneWidget);
      expect(find.text('Canceled'), findsOneWidget);
      expect(
        find.text('Task canceled. Its record remains in Library.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('library-task-b')))
            .onTap,
        isNull,
      );
      for (final action in ['edit', 'complete', 'skip', 'delete']) {
        expect(find.byKey(ValueKey('library-task-b-$action')), findsNothing);
      }
      expect(h.container.read(profileProvider).xp, xp);
      expect(h.ledger.records, isEmpty);
    },
  );

  testWidgets('unscheduled Complete reaches one canonical completion', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    final other = h.repo.records['b']!.toJson();
    await tester.tap(find.byKey(const ValueKey('library-task-a-complete')));
    await tester.pumpAndSettle();
    expect(h.repo.records['a']!.isCompleted, isTrue);
    expect(h.repo.records['b']!.toJson(), other);
    expect(
      h.ledger.records.values.single.terminalOutcome,
      TaskOccurrenceOutcome.completed,
    );
    expect(find.byKey(const ValueKey('library-task-a-complete')), findsNothing);
    expect(find.byKey(const ValueKey('library-task-a-skip')), findsNothing);
  });

  testWidgets(
    'stale rendered row cannot act in a new account before its next frame',
    (tester) async {
      final h = _Harness();
      await h.pump(tester);
      final before = h.snapshot();
      h.transition('switch');
      await tester.tap(find.byKey(const ValueKey('library-task-a-skip')));
      await tester.pumpAndSettle();
      expect(h.repo.lookups, 0);
      expect(h.snapshot(), before);
      expect(h.ledger.records, isEmpty);
    },
  );

  testWidgets('pending lookup finishing after account switch cannot Skip', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    final before = h.snapshot();
    final gate = Completer<TaskEntity?>();
    h.repo.lookupGate = gate;
    await tester.tap(find.byKey(const ValueKey('library-task-a-skip')));
    await tester.pumpAndSettle();
    h.transition('switch');
    gate.complete(h.repo.records['a']);
    await tester.pumpAndSettle();
    expect(h.snapshot(), before);
    expect(h.ledger.records, isEmpty);
  });

  for (final status in ['completed', 'skipped', 'canceled']) {
    testWidgets('$status task has no Complete or Skip control', (tester) async {
      final h = _Harness(terminal: status);
      await h.pump(tester);
      expect(
        find.byKey(const ValueKey('library-task-a-complete')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('library-task-a-skip')), findsNothing);
      expect(find.byKey(const ValueKey('library-task-a-edit')), findsNothing);
      expect(
        tester
            .widget<ListTile>(find.byKey(const ValueKey('library-task-a')))
            .onTap,
        isNull,
      );
      expect(
        find.byKey(const ValueKey('library-task-a-delete')),
        status == 'canceled' ? findsNothing : findsOneWidget,
      );
    });
  }

  for (final action in ['edit', 'delete']) {
    for (final transition in ['switch', 'reset', 'return']) {
      testWidgets('$action dialog cannot mutate after account $transition', (
        tester,
      ) async {
        final h = _Harness();
        await h.pump(tester);
        final before = h.snapshot();
        await tester.tap(find.byKey(ValueKey('library-task-a-$action')));
        await tester.pumpAndSettle();
        if (action == 'edit') {
          await tester.enterText(
            find.byKey(const Key('timeline-task-title-field')),
            'Old account draft',
          );
        }
        h.transition(transition);
        await tester.tap(find.text(action == 'edit' ? 'Save' : 'Remove task'));
        await tester.pumpAndSettle();
        expect(h.snapshot(), before);
        expect(h.ledger.records, isEmpty);
      });
    }
  }

  testWidgets('pending canonical read disables repeat actions', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    final gate = Completer<TaskEntity?>();
    h.repo.lookupGate = gate;
    await tester.tap(find.byKey(const ValueKey('library-task-a-skip')));
    await tester.pumpAndSettle();
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('library-task-a-skip')),
    );
    expect(button.onPressed, isNull);
    expect(h.repo.lookups, 1);
    gate.complete(h.repo.records['a']);
    await tester.pumpAndSettle();
    expect(h.ledger.records, hasLength(1));
    expect(h.repo.records['a']!.isSkipped, isTrue);
  });
  testWidgets(
    'My plan completes an undated task and reads it back under Completed',
    (tester) async {
      final h = _Harness();
      await h.pump(tester, asPlan: true);
      expect(find.text('My plan'), findsOneWidget);
      expect(find.byKey(const ValueKey('library-task-a-skip')), findsNothing);
      expect(find.byKey(const ValueKey('library-task-a-delete')), findsNothing);
      final row = find.byKey(const ValueKey('library-task-a'));
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Complete task')),
      );
      await tester.pumpAndSettle();
      expect(h.repo.records['a']!.isCompleted, isTrue);
      expect(h.ledger.records, hasLength(1));
      expect(row, findsNothing);
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text('First task'), findsOneWidget);
      expect(find.text('Second task'), findsNothing);
      expect(tester.widget<ListTile>(row).onTap, isNull);
    },
  );
}

final _scope = NotifierProvider<_Scope, AccountStorageScope>(_Scope.new);

class _Scope extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() =>
      AccountStorageScope.authenticated('library-test');
  void set(AccountStorageScope value) => state = value;
}

class _Harness {
  _Harness({String? terminal, ITaskRepository? canonicalRepository}) {
    repo.records['a'] = TaskEntity(
      id: 'a',
      title: 'First task',
      createdAt: DateTime.utc(2026, 10, 14),
      isCompleted: terminal == 'completed',
      isSkipped: terminal == 'skipped',
      isCanceled: terminal == 'canceled',
    );
    repo.records['b'] = TaskEntity(
      id: 'b',
      title: 'Second task',
      createdAt: DateTime.utc(2026, 10, 13),
    );
    container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((ref) => ref.watch(_scope)),
        accountLegacyOwnershipProvider.overrideWithValue(
          LegacyScopeOwnership.provenNotOwned,
        ),
        secureStoreProvider.overrideWithValue(
          SecureStore(backend: InMemorySecureStoreBackend()),
        ),
        domainTaskRepositoryProvider.overrideWithValue(
          canonicalRepository ?? repo,
        ),
        goalsProvider.overrideWith(_EmptyGoals.new),
        taskOccurrenceRepositoryProvider.overrideWithValue(ledger),
        taskOccurrenceCloudReplicaProvider.overrideWithValue(null),
        learningProvider.overrideWith(_MemoryLearning.new),
        profileProvider.overrideWith(_Profile.new),
        logsActionsProvider.overrideWith(_Logs.new),
        timelineActionsProvider.overrideWith(_Timeline.new),
        notificationActionsProvider.overrideWith(_Notifications.new),
      ],
    );
    final boundary = container.read(authSessionBoundaryProvider.notifier);
    final generation = boundary.begin(
      userId: 'library-test',
      isTransitioning: true,
    );
    boundary.complete(generation);
  }
  final repo = _Repo();
  final ledger = _Ledger();
  late final ProviderContainer container;
  List<Map<String, dynamic>> snapshot() =>
      repo.records.values.map((task) => task.toJson()).toList();
  Future<void> pump(WidgetTester tester, {bool asPlan = false}) async {
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            ChronoSparkLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: RecordLibraryScreen(asPlan: asPlan),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void transition(String kind) {
    final boundary = container.read(authSessionBoundaryProvider.notifier);
    final gen = boundary.begin(
      userId: kind == 'reset' ? null : 'other',
      isTransitioning: true,
    );
    container
        .read(_scope.notifier)
        .set(
          kind == 'reset'
              ? const AccountStorageScope.signedOut()
              : AccountStorageScope.authenticated('other'),
        );
    boundary.complete(gen);
    if (kind == 'return') {
      container
          .read(_scope.notifier)
          .set(AccountStorageScope.authenticated('library-test'));
      final back = boundary.begin(
        userId: 'library-test',
        isTransitioning: true,
      );
      boundary.complete(back);
    }
  }
}

class _Repo implements ITaskRepository {
  final records = <String, TaskEntity>{};
  Completer<TaskEntity?>? lookupGate;
  int lookups = 0;
  @override
  Future<List<TaskEntity>> getAllTasks() async => records.values.toList();
  @override
  Future<TaskEntity?> getTaskById(String id) async {
    lookups++;
    final gate = lookupGate;
    lookupGate = null;
    final task = gate == null ? records[id] : await gate.future;
    return task?.isCanceled == true ? null : task;
  }

  @override
  Future<void> saveTask(TaskEntity task) async {
    records[task.id] = task;
  }

  @override
  Future<void> deleteTask(String id) async {
    final task = records[id];
    if (task != null && !task.isCanceled) records[id] = task.cancel();
  }
}

class _Ledger extends TaskOccurrenceRepository {
  _Ledger() : super.unavailable();
  final records = <String, TaskOccurrence>{};
  @override
  Future<TaskOccurrence?> getOccurrence(
    String taskId,
    String occurrenceKey,
  ) async => records['$taskId::$occurrenceKey'];
  @override
  Future<void> save(TaskOccurrence value) async {
    records[value.id] = value;
  }

  @override
  Future<List<TaskOccurrence>> listOccurrences() async =>
      records.values.toList();
  @override
  Future<List<TaskOccurrence>> listOccurrencesForTask(String taskId) async =>
      records.values.where((v) => v.taskId == taskId).toList();
}

class _EmptyGoals extends GoalsNotifier {
  @override
  List<GoalEntity> build() => [];
}

class _MemoryLearning extends LearningController {
  @override
  LearningState build() => const LearningState();
  @override
  Future<void> apply(LearningState updated) async {
    state = updated;
  }
}

class _Profile extends ProfileController {
  @override
  ProfileState build() => ProfileState();
  @override
  Future<void> addXP(int amount) async {
    state = state.copyWith(xp: state.xp + amount);
  }
}

class _Logs extends LogsActions {
  _Logs(super.ref);
  @override
  Future<void> addMirroredEntry({
    required String source,
    required String message,
    String? id,
    DateTime? timestamp,
    bool Function()? shouldContinue,
  }) async {}
}

class _Timeline extends TimelineActions {
  _Timeline(super.ref);
  @override
  Future<void> addMirroredEvent(
    TimelineEventEntity event, {
    bool Function()? shouldContinue,
  }) async {}
}

class _Notifications extends NotificationActions {
  _Notifications(super.ref);
  @override
  Future<void> pushMirroredTaskSkipped(String taskTitle) async {}
  @override
  Future<void> pushMirroredCompletionFeedback(String taskTitle) async {}
}

class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}
  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);
  @override
  Future<Box<T>> openBox<T>(String key) async =>
      Hive.isBoxOpen(key) ? Hive.box<T>(key) : await Hive.openBox<T>(key);
  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);
  @override
  Future<void> clearBox(String key) async {
    final box = await openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) await Hive.box<String>(key).close();
  }
}
