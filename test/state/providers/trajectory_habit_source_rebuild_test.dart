import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/habit_occurrence_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_habit_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/habit_usecases.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/habit_occurrence_provider.dart';
import 'package:fantastic_guacamole/state/providers/habits_provider.dart';
import 'package:fantastic_guacamole/state/providers/trajectory_habit_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A habit change while the habit lines are being read rebuilds the source.
/// The outdated read must end quietly: no "could not be read" error logged
/// for a read nobody uses any more.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final bool changeFirst in const <bool>[true, false]) {
    test(
      'a habit change during the read logs no error '
      '(${changeFirst ? 'change, then the read finishes' : 'the read finishes, then change in the same turn'})',
      () async {
        final List<String> printed = <String>[];
        final DebugPrintCallback previous = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) printed.add(message);
        };
        addTearDown(() => debugPrint = previous);

        final _GatedHabits repository = _GatedHabits();
        final AccountStorageScope scope = AccountStorageScope.authenticated(
          'rebuild-account',
        );
        final ProviderContainer container = ProviderContainer(
          overrides: [
            accountStorageScopeProvider.overrideWithValue(scope),
            authSessionBoundaryProvider.overrideWith(_Boundary.new),
            getHabitsUseCaseProvider.overrideWithValue(GetHabits(repository)),
            habitOccurrencesProvider.overrideWith(
              (Ref ref) async => const <HabitOccurrenceEntity>[],
            ),
            habitsProvider.overrideWith(_Habits.new),
          ],
        );
        addTearDown(container.dispose);
        final String key = trajectoryHabitAccountKey(scope.v2Namespace, 1);
        // The habit list has loaded once (its first load is not a change).
        await container.read(habitsProvider.future);
        final ProviderSubscription<AsyncValue<TrajectoryHabitSource>> sub =
            container.listen(
              trajectoryHabitSourceForAccountProvider(key),
              (_, _) {},
            );
        addTearDown(sub.close);
        await Future<void>.delayed(Duration.zero);
        expect(repository.pending, hasLength(1));

        // The list changes while the first read waits, just before or just
        // after that read finishes (same event-loop turn).
        final Completer<List<HabitEntity>> first = repository.pending.first;
        if (changeFirst) {
          (container.read(habitsProvider.notifier) as _Habits).change();
          first.complete(<HabitEntity>[_habit('old')]);
        } else {
          first.complete(<HabitEntity>[_habit('old')]);
          (container.read(habitsProvider.notifier) as _Habits).change();
        }
        for (int i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
          for (final Completer<List<HabitEntity>> c in repository.pending) {
            if (!c.isCompleted) c.complete(<HabitEntity>[_habit('new')]);
          }
        }

        final AsyncValue<TrajectoryHabitSource> value = container.read(
          trajectoryHabitSourceForAccountProvider(key),
        );
        expect(value.hasError, isFalse, reason: '${value.error}');
        expect(value.value?.habits.map((HabitEntity h) => h.id), <String>[
          'new',
        ]);
        expect(
          printed.where((String line) => line.contains('could not be read')),
          isEmpty,
          reason: printed.join('\n'),
        );
      },
    );
  }
}

HabitEntity _habit(String id) =>
    HabitEntity(id: id, title: 'Habit $id', createdAt: DateTime(2026, 10, 1));

class _GatedHabits implements IHabitRepository {
  final List<Completer<List<HabitEntity>>> pending =
      <Completer<List<HabitEntity>>>[];

  @override
  Future<List<HabitEntity>> getHabits() {
    final Completer<List<HabitEntity>> c = Completer<List<HabitEntity>>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<void> saveHabits(List<HabitEntity> habits) async {}
}

class _Habits extends HabitsNotifier {
  @override
  Future<List<HabitEntity>> build() async => <HabitEntity>[_habit('old')];

  void change() =>
      state = AsyncData<List<HabitEntity>>(<HabitEntity>[_habit('new')]);
}

class _Boundary extends AuthSessionBoundaryNotifier {
  @override
  AuthSessionBoundary build() => const AuthSessionBoundary(
    generation: 1,
    userId: 'rebuild-account',
    isTransitioning: false,
    isStorageReady: true,
  );
}
