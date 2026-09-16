import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/storage/hive_boxes.dart';
import 'package:fantastic_guacamole/data/storage/hive_service.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_read_health.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Corrupted storage must not be silently indistinguishable from "the user has
/// no goals". The read still degrades to an empty list so the app stays usable,
/// but the corruption is flagged and the unreadable payload is preserved.
void main() {
  late Directory tempDir;
  late HiveStorage<String> storage;
  late GoalRepository repository;

  const String key = 'goals_v2';
  const String backupKey = 'goals_v2_corrupt_backup';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('goal_repository_test_');
    await Hive.close();
    Hive.init(tempDir.path);
    storage = HiveStorage<String>(HiveBoxes.goals, hive: _DirectHiveStore());
    await storage.open();
    repository = GoalRepository(storage);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  GoalEntity goal(String id) => GoalEntity(
    id: id,
    title: 'Goal $id',
    createdAt: DateTime.utc(2026, 7, 4),
  );

  test('genuinely empty storage is not flagged as corrupted', () {
    expect(repository.getGoals(), isEmpty);
    expect(repository.lastReadCorrupted, isFalse);
  });

  test('a valid payload round trips and is not flagged', () async {
    await repository.saveGoals(<GoalEntity>[goal('a'), goal('b')]);

    expect(repository.getGoals(), hasLength(2));
    expect(repository.lastReadCorrupted, isFalse);
  });

  test('completion state survives a real storage round trip', () async {
    await repository.saveGoal(
      goal('a').markCompleted(DateTime.utc(2026, 7, 6)),
    );

    final GoalEntity stored = repository.getGoals().single;
    expect(stored.isCompleted, isTrue);
    expect(stored.completedAt, DateTime.utc(2026, 7, 6));
  });

  test('a corrupted payload is flagged rather than read as empty', () async {
    await storage.put(key, 'this is not json');

    await Logger.withMutedErrors(() async {
      expect(repository.getGoals(), isEmpty);
    });

    expect(
      repository.lastReadCorrupted,
      isTrue,
      reason:
          'an empty result from a corrupted read must be distinguishable '
          'from a genuinely empty collection',
    );
  });

  test('a structurally wrong payload is also flagged', () async {
    await storage.put(key, jsonEncode(<String, dynamic>{'not': 'a list'}));

    await Logger.withMutedErrors(() async {
      expect(repository.getGoals(), isEmpty);
    });

    expect(repository.lastReadCorrupted, isTrue);
  });

  test(
    'mixed records are unavailable and original bytes are preserved',
    () async {
      final String original = jsonEncode(<Object?>[
        goal('valid').toJson(),
        'malformed record',
        <int>[1, 2],
      ]);
      await storage.put(key, original);
      await Logger.withMutedErrors(() async {
        expect(
          () => readAvailableGoals(repository),
          throwsA(isA<GoalReadUnavailable>()),
        );
        expect(repository.lastReadCorrupted, isTrue);
        expect(storage.get(key), original);
        await repository.saveGoal(goal('new'));
      });
      expect(storage.get(backupKey), original);
      expect(repository.getGoals().single.id, 'new');
    },
  );

  test(
    'bulk save detects corrupt data even without a preceding read',
    () async {
      const String original = '{broken json';
      await storage.put(key, original);
      await Logger.withMutedErrors(() async {
        await GoalRepository(storage).saveGoals(<GoalEntity>[goal('new')]);
      });
      expect(storage.get(backupKey), original);
      expect(repository.getGoals().single.id, 'new');
    },
  );

  for (final String invalidField in <String>[
    'title',
    'targetDate',
    'completedAt',
  ]) {
    test(
      'invalid $invalidField cannot silently become healthy goal data',
      () async {
        final Map<String, dynamic> record = goal('valid').toJson();
        record[invalidField] = invalidField == 'title' ? '   ' : 'invalid-date';
        final String original = jsonEncode(<Object>[record]);
        await storage.put(key, original);
        await Logger.withMutedErrors(() async {
          expect(
            () => readAvailableGoals(repository),
            throwsA(isA<GoalReadUnavailable>()),
          );
        });
        expect(repository.lastReadCorrupted, isTrue);
        expect(storage.get(key), original);
      },
    );
  }

  test(
    'failed quarantine prevents primary overwrite and a later retry is safe',
    () async {
      const String original = 'recoverable but invalid JSON';
      await storage.put(key, original);
      final _FailingBackupStorage failing = _FailingBackupStorage(storage);
      final GoalRepository guarded = GoalRepository(failing);
      await Logger.withMutedErrors(() async {
        await expectLater(guarded.saveGoal(goal('new')), throwsStateError);
      });
      expect(storage.get(key), original);
      expect(storage.get(backupKey), isNull);
      expect(guarded.lastReadCorrupted, isTrue);
      expect(failing.primaryWrites, 0);
      failing.failBackup = false;
      await Logger.withMutedErrors(() async {
        await guarded.saveGoal(goal('new'));
      });
      expect(storage.get(backupKey), original);
      expect(guarded.getGoals().single.id, 'new');
    },
  );

  test(
    'a later corrupt payload does not replace an earlier quarantine',
    () async {
      await storage.put(backupKey, 'first preserved payload');
      await storage.put(key, 'second corrupt payload');
      await Logger.withMutedErrors(
        () async => repository.saveGoal(goal('new')),
      );
      expect(storage.get(backupKey), 'first preserved payload');
      final Box<String> box = await storage.open();
      expect(box.values, contains('second corrupt payload'));
    },
  );

  test(
    'the unreadable payload is quarantined before being overwritten',
    () async {
      const String corrupt = 'this is not json';
      await storage.put(key, corrupt);

      await Logger.withMutedErrors(() async {
        // Simulates the real data-loss chain: corrupt read -> empty list ->
        // user adds a goal -> save would overwrite the original.
        await repository.saveGoal(goal('new'));
      });

      expect(
        storage.get(backupKey),
        corrupt,
        reason: 'the original payload must remain recoverable',
      );
      expect(repository.getGoals().single.id, 'new');
    },
  );

  test('a normal save does not create a quarantine backup', () async {
    await repository.saveGoals(<GoalEntity>[goal('a')]);

    expect(storage.get(backupKey), isNull);
  });

  test('the corrupted flag clears after a successful read', () async {
    await storage.put(key, 'not json');
    await Logger.withMutedErrors(() async => repository.getGoals());
    expect(repository.lastReadCorrupted, isTrue);

    await Logger.withMutedErrors(() async {
      await repository.saveGoals(<GoalEntity>[goal('a')]);
    });
    repository.getGoals();

    expect(repository.lastReadCorrupted, isFalse);
  });

  test('concurrent saves do not lose either goal', () async {
    await Future.wait(<Future<void>>[
      repository.saveGoal(goal('first')),
      repository.saveGoal(goal('second')),
    ]);

    expect(
      repository.getGoals().map((GoalEntity item) => item.id),
      containsAll(<String>['first', 'second']),
    );
    expect(repository.getGoals(), hasLength(2));
  });

  for (final String operation in <String>['add', 'update', 'delete', 'bulk']) {
    for (final bool failBeforeWrite in <bool>[false, true]) {
      test(
        '$operation aborts a transient ${failBeforeWrite ? 'final' : 'first'} '
        'read failure and retries from preserved bytes',
        () async {
          await repository.saveGoals(<GoalEntity>[
            goal('keep'),
            goal('change'),
          ]);
          final String? original = storage.get(key);
          final _InterruptedReadStorage interrupted = _InterruptedReadStorage(
            storage,
            failOnRead: failBeforeWrite ? (operation == 'bulk' ? 2 : 3) : 1,
          );
          final GoalRepository guarded = GoalRepository(interrupted);
          Future<void> mutate() => switch (operation) {
            'add' => guarded.saveGoal(goal('new')),
            'update' => guarded.saveGoal(
              goal('change').markCompleted(DateTime.utc(2026, 9, 9)),
            ),
            'delete' => guarded.deleteGoal('change'),
            _ => guarded.saveGoals(<GoalEntity>[goal('replacement')]),
          };

          await expectLater(mutate(), throwsStateError);
          expect(storage.get(key), original);
          expect(storage.get(backupKey), isNull);
          expect(interrupted.primaryWrites, 0);
          expect(guarded.lastReadCorrupted, isTrue);

          // The injected failure lasts one read. The same queued repository
          // must accept an explicit retry, starting from all retained goals.
          await mutate();
          final List<GoalEntity> result = guarded.getGoals();
          expect(interrupted.primaryWrites, 1);
          expect(guarded.lastReadCorrupted, isFalse);
          switch (operation) {
            case 'add':
              expect(
                result.map((value) => value.id),
                unorderedEquals(<String>['keep', 'change', 'new']),
              );
            case 'update':
              expect(
                result.map((value) => value.id),
                unorderedEquals(<String>['keep', 'change']),
              );
              expect(
                result.singleWhere((value) => value.id == 'change').isCompleted,
                isTrue,
              );
            case 'delete':
              expect(result.single.id, 'keep');
            default:
              expect(result.single.id, 'replacement');
          }
        },
      );
    }
  }

  for (final bool deleting in <bool>[false, true]) {
    test(
      '${deleting ? 'delete' : 'save'} aborts a failed preservation reread',
      () async {
        await repository.saveGoals(<GoalEntity>[goal('keep'), goal('change')]);
        final String? original = storage.get(key);
        final _InterruptedReadStorage interrupted = _InterruptedReadStorage(
          storage,
          failOnRead: 2,
        );
        final GoalRepository guarded = GoalRepository(interrupted);
        await expectLater(
          deleting
              ? guarded.deleteGoal('change')
              : guarded.saveGoal(goal('new')),
          throwsStateError,
        );
        expect(storage.get(key), original);
        expect(interrupted.primaryWrites, 0);
      },
    );

    test(
      '${deleting ? 'delete' : 'save'} rejects bytes changed while reopening',
      () async {
        await repository.saveGoal(goal('old'));
        final String recovered = jsonEncode(<Map<String, dynamic>>[
          goal('recovered').toJson(),
        ]);
        final _InterruptedReadStorage interrupted = _InterruptedReadStorage(
          storage,
        );
        interrupted.beforeSecondOpen = () => storage.put(key, recovered);
        final GoalRepository guarded = GoalRepository(interrupted);
        await expectLater(
          deleting ? guarded.deleteGoal('old') : guarded.saveGoal(goal('new')),
          throwsStateError,
        );
        expect(storage.get(key), recovered);
        expect(interrupted.primaryWrites, 0);
        expect(storage.get(backupKey), isNull);
      },
    );
  }

  test(
    'quarantine await cannot mask a changed payload with a healthy read',
    () async {
      const String corrupt = 'preserve these undecodable bytes';
      final String recovered = jsonEncode(<Map<String, dynamic>>[
        goal('recovered').toJson(),
      ]);
      await storage.put(key, corrupt);
      final _InterruptedReadStorage interrupted = _InterruptedReadStorage(
        storage,
      );
      final GoalRepository guarded = GoalRepository(interrupted);
      interrupted.afterBackup = () async {
        await storage.put(key, recovered);
        expect(guarded.getGoals().single.id, 'recovered');
        expect(guarded.lastReadCorrupted, isFalse);
      };
      await Logger.withMutedErrors(() async {
        await expectLater(
          guarded.saveGoals(<GoalEntity>[goal('new')]),
          throwsStateError,
        );
      });
      expect(storage.get(key), recovered);
      expect(storage.get(backupKey), corrupt);
      expect(interrupted.primaryWrites, 0);
    },
  );

  test('saving after a cold close preserves existing goals', () async {
    await repository.saveGoal(goal('existing'));
    await storage.close();
    await repository.saveGoal(goal('new'));
    expect(
      repository.getGoals().map((value) => value.id),
      containsAll(<String>['existing', 'new']),
    );
    expect(repository.getGoals(), hasLength(2));
  });

  test('deleting after a cold close preserves unrelated goals', () async {
    await repository.saveGoals([goal('keep'), goal('remove')]);
    await storage.close();
    await repository.deleteGoal('remove');
    expect(repository.getGoals().single.id, 'keep');
  });
}

class _InterruptedReadStorage implements HiveStorage<String> {
  _InterruptedReadStorage(this.delegate, {this.failOnRead});

  final HiveStorage<String> delegate;
  final int? failOnRead;
  int reads = 0;
  int opens = 0;
  int primaryWrites = 0;
  Future<void> Function()? beforeSecondOpen;
  Future<void> Function()? afterBackup;

  @override
  String? get(String key) {
    if (key == 'goals_v2') {
      reads += 1;
      if (reads == failOnRead) {
        throw StateError('Injected transient unavailable goals storage');
      }
    }
    return delegate.get(key);
  }

  @override
  Future<Box<String>> open() async {
    opens += 1;
    if (opens == 2) await beforeSecondOpen?.call();
    return delegate.open();
  }

  @override
  Future<void> put(String key, String value) async {
    if (key == 'goals_v2') primaryWrites += 1;
    await delegate.put(key, value);
    if (key.startsWith('goals_v2_corrupt_backup')) await afterBackup?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingBackupStorage implements HiveStorage<String> {
  _FailingBackupStorage(this.delegate);
  final HiveStorage<String> delegate;
  bool failBackup = true;
  int primaryWrites = 0;

  @override
  String? get(String key) => delegate.get(key);

  @override
  Future<Box<String>> open() => delegate.open();

  @override
  Future<void> put(String key, String value) async {
    if (key.startsWith('goals_v2_corrupt_backup') && failBackup) {
      throw StateError('Injected unavailable quarantine storage');
    }
    if (key == 'goals_v2') primaryWrites += 1;
    await delegate.put(key, value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DirectHiveStore implements HiveStore {
  @override
  Future<void> init() async {}

  @override
  bool isBoxOpen(String key) => Hive.isBoxOpen(key);

  @override
  Future<Box<T>> openBox<T>(String key) async {
    if (Hive.isBoxOpen(key)) {
      return Hive.box<T>(key);
    }
    return Hive.openBox<T>(key);
  }

  @override
  Box<T> box<T>(String key) => Hive.box<T>(key);

  @override
  Future<void> clearBox(String key) async {
    final Box<String> box = Hive.isBoxOpen(key)
        ? Hive.box<String>(key)
        : await Hive.openBox<String>(key);
    await box.clear();
  }

  @override
  Future<void> closeBox(String key) async {
    if (Hive.isBoxOpen(key)) {
      await Hive.box<String>(key).close();
    }
  }
}
