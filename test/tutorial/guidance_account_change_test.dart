import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Not now" on a hint card and "Restart the guide" in Settings write
/// guide state after several waits. If the account changes during any of
/// them, nothing may land in the next account's state and nothing may fail.
const String _first = 'guidance-change-first';
const String _second = 'guidance-change-second';

void main() {
  Future<void> expectNoLeak(
    String label,
    Future<void> Function(AdaptiveGuidanceNotifier notifier) action,
  ) async {
    // Switch accounts after every possible number of waits, so each gap
    // between an await and the next state write is covered.
    for (int turns = 0; turns < 60; turns++) {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWith(
            (Ref ref) =>
                AccountStorageScope.authenticated(ref.watch(_accountProvider)),
          ),
          domainTaskRepositoryProvider.overrideWithValue(_NoTasks()),
        ],
      );
      final ProviderSubscription<AsyncValue<AdaptiveGuidanceState>> sub =
          container.listen(adaptiveGuidanceProvider, (_, _) {});
      await container.read(adaptiveGuidanceProvider.future);

      Object? failure;
      final Future<void> running = action(
        container.read(adaptiveGuidanceProvider.notifier),
      ).catchError((Object error) => failure = error);
      for (int i = 0; i < turns; i++) {
        await Future<void>.value();
      }
      container.read(_accountProvider.notifier).switchTo(_second);
      // Rebuild for the new account now, as a screen watching the guide
      // would, so the old account's work resumes after the switch landed.
      container.read(adaptiveGuidanceProvider);
      await running;
      final AdaptiveGuidanceState next = await container.read(
        adaptiveGuidanceProvider.future,
      );

      expect(failure, isNull, reason: '$label, switched after $turns waits');
      expect(
        next.skippedLessons,
        isEmpty,
        reason: '$label, switched after $turns waits',
      );
      expect(
        next.replayLessons,
        isEmpty,
        reason: '$label, switched after $turns waits',
      );
      sub.close();
      container.dispose();
    }
  }

  test('"Not now" on a hint never lands in the next account', () async {
    await expectNoLeak(
      'skip',
      (AdaptiveGuidanceNotifier notifier) =>
          notifier.skip(GuidanceLessonId.nexus),
    );
  });

  test('restarting the guide never lands in the next account', () async {
    await expectNoLeak(
      'restart',
      (AdaptiveGuidanceNotifier notifier) => notifier.restartLessons(),
    );
  });
}

final NotifierProvider<_Account, String> _accountProvider =
    NotifierProvider<_Account, String>(_Account.new);

class _Account extends Notifier<String> {
  @override
  String build() => _first;

  void switchTo(String account) => state = account;
}

class _NoTasks implements ITaskRepository {
  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[];

  @override
  Future<TaskEntity?> getTaskById(String id) async => null;

  @override
  Future<void> saveTask(TaskEntity task) async {}
}
